-- Attendiphi P0+P1 apply bundle — project fzghxzybyygslfjyfewu
-- Generated for Dashboard SQL Editor. Review before run.

-- ========== P0 ==========
-- P0 production lockdown (fzghxzybyygslfjyfewu)
-- 1) Tighten anon RLS (no open SELECT on check_ins / members / notifications;
--    no anon DELETE/UPDATE on locks).
-- 2) public.public_members view for QR typeahead (id/name/phone only).
-- 3) SECURITY DEFINER submit_public_check_in (+ optional HMAC verify).
-- 4) app_secrets for CHECKIN_SESSION_TOKEN_SECRET (set after migrate).

begin;

create extension if not exists pgcrypto with schema extensions;

-- ── Secrets (not readable by anon/authenticated) ─────────────────────────
create table if not exists public.app_secrets (
  id text primary key,
  value text not null,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.app_secrets enable row level security;
-- No policies ⇒ deny all via RLS for anon/authenticated.
revoke all on table public.app_secrets from public, anon, authenticated;

-- ── public_members (QR directory) ────────────────────────────────────────
drop view if exists public.public_members;
create view public.public_members
with (security_invoker = false) as
select
  m.id,
  m.name,
  m.phone,
  m.is_active
from public.members m
where m.is_active = true;

revoke all on public.public_members from public;
grant select on public.public_members to anon, authenticated;

drop policy if exists members_anon_read_active on public.members;

-- ── check_ins: no direct anon access (writes only via submit_public_check_in)
drop policy if exists check_ins_anon_select on public.check_ins;
drop policy if exists check_ins_anon_insert on public.check_ins;

-- ── session_attendance: anon SELECT (member id list only) + INSERT ───────
drop policy if exists session_attendance_anon_rw on public.session_attendance;

drop policy if exists session_attendance_anon_select on public.session_attendance;
create policy session_attendance_anon_select on public.session_attendance
  for select to anon
  using (true);

drop policy if exists session_attendance_anon_insert on public.session_attendance;
create policy session_attendance_anon_insert on public.session_attendance
  for insert to anon
  with check (true);

-- ── locks: anon INSERT only (reclaim/delete via RPC) ─────────────────────
drop policy if exists phone_locks_anon_rw on public.phone_session_locks;
drop policy if exists member_locks_anon_rw on public.member_session_locks;
drop policy if exists device_locks_anon_rw on public.device_session_locks;

drop policy if exists phone_locks_anon_insert on public.phone_session_locks;
create policy phone_locks_anon_insert on public.phone_session_locks
  for insert to anon
  with check (true);

drop policy if exists member_locks_anon_insert on public.member_session_locks;
create policy member_locks_anon_insert on public.member_session_locks
  for insert to anon
  with check (true);

drop policy if exists device_locks_anon_insert on public.device_session_locks;
create policy device_locks_anon_insert on public.device_session_locks
  for insert to anon
  with check (true);

-- ── admin_notifications: remove anon SELECT ──────────────────────────────
drop policy if exists admin_notifications_anon_select on public.admin_notifications;
-- keep admin_notifications_anon_insert

-- ── Helpers ──────────────────────────────────────────────────────────────
create or replace function public._b64url_decode(p text)
returns bytea
language plpgsql
immutable
as $$
declare
  s text := replace(replace(p, '-', '+'), '_', '/');
  pad int;
begin
  pad := (4 - length(s) % 4) % 4;
  if pad > 0 then
    s := s || repeat('=', pad);
  end if;
  return decode(s, 'base64');
end;
$$;

create or replace function public.verify_checkin_session_token(
  p_token text,
  p_expected_location_id text,
  p_expected_session_date date
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  secret text;
  raw text := trim(coalesce(p_token, ''));
  parts text[];
  payload_bytes bytea;
  provided_mac bytea;
  expected_mac bytea;
  payload text;
  fields text[];
  loc text;
  date_txt text;
begin
  select value into secret from public.app_secrets where id = 'CHECKIN_SESSION_TOKEN_SECRET';
  -- If secret not configured yet, skip HMAC (business rules still enforced).
  if secret is null or length(trim(secret)) < 16 then
    return true;
  end if;

  if raw = '' or split_part(raw, '.', 1) <> 'v1' then
    return false;
  end if;
  parts := string_to_array(raw, '.');
  if array_length(parts, 1) <> 3 then
    return false;
  end if;

  begin
    payload_bytes := public._b64url_decode(parts[2]);
    provided_mac := public._b64url_decode(parts[3]);
  exception when others then
    return false;
  end;

  payload := convert_from(payload_bytes, 'utf8');
  expected_mac := extensions.hmac(payload_bytes, convert_to(secret, 'utf8'), 'sha256');
  if expected_mac is distinct from provided_mac then
    return false;
  end if;

  fields := string_to_array(payload, '|');
  if array_length(fields, 1) <> 3 then
    return false;
  end if;
  loc := trim(fields[1]);
  date_txt := trim(fields[2]);
  if loc = '' or date_txt !~ '^\d{4}-\d{2}-\d{2}$' then
    return false;
  end if;
  if loc is distinct from trim(coalesce(p_expected_location_id, '')) then
    return false;
  end if;
  if date_txt::date is distinct from p_expected_session_date then
    return false;
  end if;
  return true;
end;
$$;

create or replace function public._haversine_meters(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
)
returns double precision
language sql
immutable
as $$
  select 2 * 6371000 * asin(
    sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) *
      power(sin(radians(lon2 - lon1) / 2), 2)
    )
  );
$$;

-- Atomic public check-in (anon-callable). Device locks intentionally unused.
create or replace function public.submit_public_check_in(
  p_row jsonb,
  p_session_date date,
  p_claim_member_id text default null,
  p_session_token text default null,
  p_enforce_restrictions boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_id text := nullif(trim(coalesce(p_row ->> 'id', '')), '');
  v_type text := coalesce(nullif(trim(p_row ->> 'type'), ''), 'member');
  v_location_id text := trim(coalesce(p_row ->> 'location_id', ''));
  v_user_phone text := trim(coalesce(p_row ->> 'user_phone', ''));
  v_phone_digits text;
  v_phone_lock_id text;
  v_member_id text := nullif(trim(coalesce(p_claim_member_id, p_row ->> 'member_id', '')), '');
  v_member_lock_id text;
  v_lat double precision := coalesce((p_row ->> 'user_latitude')::double precision, 0);
  v_lon double precision := coalesce((p_row ->> 'user_longitude')::double precision, 0);
  v_dist double precision;
  v_radius double precision;
  v_loc_lat double precision;
  v_loc_lon double precision;
  v_restrictions boolean := true;
  v_existing_check_in text;
  v_ids text[];
begin
  if v_id is null then
    raise exception 'check_in_id_required' using errcode = 'P0001';
  end if;
  if v_location_id = '' or v_user_phone = '' then
    raise exception 'check_in_fields_required' using errcode = 'P0001';
  end if;
  if p_session_date is null then
    raise exception 'session_date_required' using errcode = 'P0001';
  end if;

  -- Normalize phone digits (last 10)
  v_phone_digits := regexp_replace(v_user_phone, '\D', '', 'g');
  if length(v_phone_digits) >= 10 then
    v_phone_digits := right(v_phone_digits, 10);
  end if;
  if length(v_phone_digits) < 10 then
    raise exception 'invalid_phone' using errcode = 'P0001';
  end if;
  v_phone_lock_id := v_phone_digits || '_' || to_char(p_session_date, 'YYYY-MM-DD');
  if v_member_id is not null then
    v_member_lock_id := v_member_id || '_' || to_char(p_session_date, 'YYYY-MM-DD');
  end if;

  select coalesce(restrictions_enabled, true)
    into v_restrictions
  from public.app_config
  where id = 'checkInRestrictions';
  if not found then
    v_restrictions := true;
  end if;

  if p_enforce_restrictions and v_restrictions then
    if extract(isodow from p_session_date)::int <> 4 then
      raise exception 'thursday_only' using errcode = 'P0001';
    end if;
    if (timezone('Asia/Kolkata', now()))::date is distinct from p_session_date then
      raise exception 'session_date_mismatch' using errcode = 'P0001';
    end if;
  end if;

  if p_session_token is not null and length(trim(p_session_token)) > 0 then
    if not public.verify_checkin_session_token(
      p_session_token, v_location_id, p_session_date
    ) then
      raise exception 'invalid_session_token' using errcode = 'P0001';
    end if;
  end if;

  select latitude, longitude, radius_meters
    into v_loc_lat, v_loc_lon, v_radius
  from public.locations
  where id = v_location_id and is_active = true;

  if p_enforce_restrictions and v_restrictions then
    if v_loc_lat is null then
      raise exception 'location_not_found' using errcode = 'P0001';
    end if;
    v_dist := public._haversine_meters(v_lat, v_lon, v_loc_lat, v_loc_lon);
    if v_dist > coalesce(v_radius, 500) then
      raise exception 'outside_radius' using errcode = 'P0001';
    end if;
  end if;

  -- Phone lock (reclaim orphan)
  begin
    insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id)
    values (v_phone_lock_id, v_phone_digits, p_session_date, v_id);
  exception when unique_violation then
    select check_in_id into v_existing_check_in
    from public.phone_session_locks where id = v_phone_lock_id;
    if v_existing_check_in is null
       or trim(v_existing_check_in) = ''
       or not exists (select 1 from public.check_ins c where c.id = v_existing_check_in)
    then
      delete from public.phone_session_locks where id = v_phone_lock_id;
      insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id)
      values (v_phone_lock_id, v_phone_digits, p_session_date, v_id);
    else
      raise exception 'duplicate_phone' using errcode = 'P0001';
    end if;
  end;

  -- Member lock
  if v_member_lock_id is not null then
    begin
      insert into public.member_session_locks (id, member_id, session_date, check_in_id)
      values (v_member_lock_id, v_member_id, p_session_date, v_id);
    exception when unique_violation then
      select check_in_id into v_existing_check_in
      from public.member_session_locks where id = v_member_lock_id;
      if v_existing_check_in is null
         or trim(v_existing_check_in) = ''
         or not exists (select 1 from public.check_ins c where c.id = v_existing_check_in)
      then
        delete from public.member_session_locks where id = v_member_lock_id;
        insert into public.member_session_locks (id, member_id, session_date, check_in_id)
        values (v_member_lock_id, v_member_id, p_session_date, v_id);
      else
        delete from public.phone_session_locks where id = v_phone_lock_id;
        raise exception 'duplicate_member' using errcode = 'P0001';
      end if;
    end;
  end if;

  begin
    insert into public.check_ins (
      id, type, location_id, location_name, user_name, user_phone, user_email,
      user_latitude, user_longitude, gps_accuracy, distance_meters, member_id,
      substitute_for_member, substitute_name, substitute_phone, company_name,
      category, invited_by_member, photo_base64, has_photo, admin_id, device_id,
      is_verified, is_edited, is_flagged, face_verified, verification_method,
      session_date, attended_at, "timestamp", created_at, updated_at
    ) values (
      v_id,
      v_type::public.check_in_type,
      v_location_id,
      coalesce(p_row ->> 'location_name', ''),
      coalesce(p_row ->> 'user_name', ''),
      v_user_phone,
      nullif(p_row ->> 'user_email', ''),
      v_lat,
      v_lon,
      coalesce((p_row ->> 'gps_accuracy')::double precision, 0),
      coalesce((p_row ->> 'distance_meters')::double precision, 0),
      v_member_id,
      nullif(p_row ->> 'substitute_for_member', ''),
      nullif(p_row ->> 'substitute_name', ''),
      nullif(p_row ->> 'substitute_phone', ''),
      nullif(p_row ->> 'company_name', ''),
      nullif(p_row ->> 'category', ''),
      nullif(p_row ->> 'invited_by_member', ''),
      nullif(p_row ->> 'photo_base64', ''),
      coalesce((p_row ->> 'has_photo')::boolean, false),
      nullif(p_row ->> 'admin_id', ''),
      nullif(p_row ->> 'device_id', ''),
      coalesce((p_row ->> 'is_verified')::boolean, false),
      coalesce((p_row ->> 'is_edited')::boolean, false),
      coalesce((p_row ->> 'is_flagged')::boolean, false),
      coalesce((p_row ->> 'face_verified')::boolean, false),
      nullif(p_row ->> 'verification_method', ''),
      p_session_date,
      coalesce((p_row ->> 'attended_at')::timestamptz, timezone('utc', now())),
      coalesce((p_row ->> 'timestamp')::timestamptz, timezone('utc', now())),
      coalesce((p_row ->> 'created_at')::timestamptz, timezone('utc', now())),
      timezone('utc', now())
    );
  exception when others then
    delete from public.phone_session_locks where id = v_phone_lock_id;
    if v_member_lock_id is not null then
      delete from public.member_session_locks where id = v_member_lock_id;
    end if;
    raise;
  end;

  if v_member_id is not null then
    select checked_in_member_ids into v_ids
    from public.session_attendance
    where session_date = p_session_date;
    if not found then
      insert into public.session_attendance (id, session_date, checked_in_member_ids, updated_at)
      values (
        to_char(p_session_date, 'YYYY-MM-DD'),
        p_session_date,
        array[v_member_id],
        timezone('utc', now())
      );
    else
      update public.session_attendance
      set
        checked_in_member_ids = (
          select array_agg(distinct x)
          from unnest(coalesce(v_ids, '{}') || v_member_id) as x
        ),
        updated_at = timezone('utc', now())
      where session_date = p_session_date;
    end if;
  end if;

  return jsonb_build_object('id', v_id, 'session_date', p_session_date);
end;
$$;

revoke all on function public.verify_checkin_session_token(text, text, date) from public;
revoke all on function public.submit_public_check_in(jsonb, date, text, text, boolean) from public;
grant execute on function public.submit_public_check_in(jsonb, date, text, text, boolean)
  to anon, authenticated;

comment on function public.submit_public_check_in is
  'P0: atomic QR check-in with phone/member locks, orphan reclaim, optional HMAC.';

commit;

-- AFTER migrate, set the same secret used by scripts/build_web_release.sh:
-- insert into public.app_secrets (id, value) values
--   ('CHECKIN_SESSION_TOKEN_SECRET', '<your-secret-min-16-chars>')
-- on conflict (id) do update set value = excluded.value, updated_at = now();

-- ========== P1 ==========
-- P1 production hardening (fzghxzybyygslfjyfewu)
-- 1) check-in-photos Storage bucket + policies
-- 2) submit_public_check_in stores photo_path (not photo_base64)
-- 3) Column grants: hide password_hash/password_salt from authenticated SELECT
-- 4) assigned_location_ids enforced on check_ins (admin RLS)
-- 5) Persist Edge email rate limits

begin;

-- ── Location scope helpers ───────────────────────────────────────────────
create or replace function public.admin_can_access_location(p_location_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_active_admin()
    and (
      public.is_super_admin()
      or exists (
        select 1
        from public.admins a
        where a.is_active = true
          and (
            a.auth_user_id = auth.uid()
            or lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
          )
          and (
            a.assigned_location_ids is null
            or coalesce(cardinality(a.assigned_location_ids), 0) = 0
            or trim(coalesce(p_location_id, '')) = any (a.assigned_location_ids)
          )
      )
    );
$$;

revoke all on function public.admin_can_access_location(text) from public;
grant execute on function public.admin_can_access_location(text)
  to authenticated, anon;

-- Tighten check_ins admin policy to assigned locations
drop policy if exists check_ins_admin_all on public.check_ins;
create policy check_ins_admin_all on public.check_ins
  for all to authenticated
  using (public.admin_can_access_location(location_id))
  with check (public.admin_can_access_location(location_id));

-- Locations: non-superadmin sees only assigned (empty = all)
drop policy if exists locations_admin_all on public.locations;
create policy locations_admin_select on public.locations
  for select to authenticated
  using (
    public.is_super_admin()
    or public.admin_can_access_location(id)
  );
create policy locations_admin_write on public.locations
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ── Admin password columns: revoke from authenticated table SELECT ───────
-- Prefer explicit safe projection from the client; also block column grants.
revoke select on table public.admins from authenticated;
grant select (
  id, uid, auth_user_id, name, email, phone, role,
  must_reset_password, is_active, created_at, created_by,
  last_login_at, password_updated_at, assigned_location_ids, updated_at
) on table public.admins to authenticated;
-- password_hash / password_salt intentionally not granted.
grant insert, update, delete on table public.admins to authenticated;
-- Keep service_role / postgres full access via ownership.

-- ── Storage bucket for check-in photos ───────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'check-in-photos',
  'check-in-photos',
  false,
  2097152, -- 2 MiB
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists checkin_photos_anon_insert on storage.objects;
create policy checkin_photos_anon_insert on storage.objects
  for insert to anon
  with check (bucket_id = 'check-in-photos');

drop policy if exists checkin_photos_admin_select on storage.objects;
create policy checkin_photos_admin_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'check-in-photos'
    and public.is_active_admin()
  );

drop policy if exists checkin_photos_admin_delete on storage.objects;
create policy checkin_photos_admin_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'check-in-photos'
    and public.is_super_admin()
  );

-- ── submit_public_check_in: prefer photo_path, never persist photo_base64 ─
create or replace function public.submit_public_check_in(
  p_row jsonb,
  p_session_date date,
  p_claim_member_id text default null,
  p_session_token text default null,
  p_enforce_restrictions boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_id text := nullif(trim(coalesce(p_row ->> 'id', '')), '');
  v_type text := coalesce(nullif(trim(p_row ->> 'type'), ''), 'member');
  v_location_id text := trim(coalesce(p_row ->> 'location_id', ''));
  v_user_phone text := trim(coalesce(p_row ->> 'user_phone', ''));
  v_phone_digits text;
  v_phone_lock_id text;
  v_member_id text := nullif(trim(coalesce(p_claim_member_id, p_row ->> 'member_id', '')), '');
  v_member_lock_id text;
  v_lat double precision := coalesce((p_row ->> 'user_latitude')::double precision, 0);
  v_lon double precision := coalesce((p_row ->> 'user_longitude')::double precision, 0);
  v_dist double precision;
  v_radius double precision;
  v_loc_lat double precision;
  v_loc_lon double precision;
  v_restrictions boolean := true;
  v_existing_check_in text;
  v_ids text[];
  v_photo_path text := nullif(trim(coalesce(p_row ->> 'photo_path', '')), '');
  v_has_photo boolean := coalesce((p_row ->> 'has_photo')::boolean, false)
    or v_photo_path is not null;
begin
  if v_id is null then
    raise exception 'check_in_id_required' using errcode = 'P0001';
  end if;
  if v_location_id = '' or v_user_phone = '' then
    raise exception 'check_in_fields_required' using errcode = 'P0001';
  end if;
  if p_session_date is null then
    raise exception 'session_date_required' using errcode = 'P0001';
  end if;

  v_phone_digits := regexp_replace(v_user_phone, '\D', '', 'g');
  if length(v_phone_digits) >= 10 then
    v_phone_digits := right(v_phone_digits, 10);
  end if;
  if length(v_phone_digits) < 10 then
    raise exception 'invalid_phone' using errcode = 'P0001';
  end if;
  v_phone_lock_id := v_phone_digits || '_' || to_char(p_session_date, 'YYYY-MM-DD');
  if v_member_id is not null then
    v_member_lock_id := v_member_id || '_' || to_char(p_session_date, 'YYYY-MM-DD');
  end if;

  select coalesce(restrictions_enabled, true)
    into v_restrictions
  from public.app_config
  where id = 'checkInRestrictions';
  if not found then
    v_restrictions := true;
  end if;

  if p_enforce_restrictions and v_restrictions then
    if extract(isodow from p_session_date)::int <> 4 then
      raise exception 'thursday_only' using errcode = 'P0001';
    end if;
    if (timezone('Asia/Kolkata', now()))::date is distinct from p_session_date then
      raise exception 'session_date_mismatch' using errcode = 'P0001';
    end if;
  end if;

  if p_session_token is not null and length(trim(p_session_token)) > 0 then
    if not public.verify_checkin_session_token(
      p_session_token, v_location_id, p_session_date
    ) then
      raise exception 'invalid_session_token' using errcode = 'P0001';
    end if;
  end if;

  select latitude, longitude, radius_meters
    into v_loc_lat, v_loc_lon, v_radius
  from public.locations
  where id = v_location_id and is_active = true;

  if p_enforce_restrictions and v_restrictions then
    if v_loc_lat is null then
      raise exception 'location_not_found' using errcode = 'P0001';
    end if;
    v_dist := public._haversine_meters(v_lat, v_lon, v_loc_lat, v_loc_lon);
    if v_dist > coalesce(v_radius, 500) then
      raise exception 'outside_radius' using errcode = 'P0001';
    end if;
  end if;

  begin
    insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id)
    values (v_phone_lock_id, v_phone_digits, p_session_date, v_id);
  exception when unique_violation then
    select check_in_id into v_existing_check_in
    from public.phone_session_locks where id = v_phone_lock_id;
    if v_existing_check_in is null
       or trim(v_existing_check_in) = ''
       or not exists (select 1 from public.check_ins c where c.id = v_existing_check_in)
    then
      delete from public.phone_session_locks where id = v_phone_lock_id;
      insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id)
      values (v_phone_lock_id, v_phone_digits, p_session_date, v_id);
    else
      raise exception 'duplicate_phone' using errcode = 'P0001';
    end if;
  end;

  if v_member_lock_id is not null then
    begin
      insert into public.member_session_locks (id, member_id, session_date, check_in_id)
      values (v_member_lock_id, v_member_id, p_session_date, v_id);
    exception when unique_violation then
      select check_in_id into v_existing_check_in
      from public.member_session_locks where id = v_member_lock_id;
      if v_existing_check_in is null
         or trim(v_existing_check_in) = ''
         or not exists (select 1 from public.check_ins c where c.id = v_existing_check_in)
      then
        delete from public.member_session_locks where id = v_member_lock_id;
        insert into public.member_session_locks (id, member_id, session_date, check_in_id)
        values (v_member_lock_id, v_member_id, p_session_date, v_id);
      else
        delete from public.phone_session_locks where id = v_phone_lock_id;
        raise exception 'duplicate_member' using errcode = 'P0001';
      end if;
    end;
  end if;

  begin
    insert into public.check_ins (
      id, type, location_id, location_name, user_name, user_phone, user_email,
      user_latitude, user_longitude, gps_accuracy, distance_meters, member_id,
      substitute_for_member, substitute_name, substitute_phone, company_name,
      category, invited_by_member, photo_base64, photo_path, has_photo, admin_id,
      device_id, is_verified, is_edited, is_flagged, face_verified,
      verification_method, session_date, attended_at, "timestamp", created_at,
      updated_at
    ) values (
      v_id,
      v_type::public.check_in_type,
      v_location_id,
      coalesce(p_row ->> 'location_name', ''),
      coalesce(p_row ->> 'user_name', ''),
      v_user_phone,
      nullif(p_row ->> 'user_email', ''),
      v_lat,
      v_lon,
      coalesce((p_row ->> 'gps_accuracy')::double precision, 0),
      coalesce((p_row ->> 'distance_meters')::double precision, 0),
      v_member_id,
      nullif(p_row ->> 'substitute_for_member', ''),
      nullif(p_row ->> 'substitute_name', ''),
      nullif(p_row ->> 'substitute_phone', ''),
      nullif(p_row ->> 'company_name', ''),
      nullif(p_row ->> 'category', ''),
      nullif(p_row ->> 'invited_by_member', ''),
      null, -- never persist base64 in P1+
      v_photo_path,
      v_has_photo,
      nullif(p_row ->> 'admin_id', ''),
      nullif(p_row ->> 'device_id', ''),
      coalesce((p_row ->> 'is_verified')::boolean, false),
      coalesce((p_row ->> 'is_edited')::boolean, false),
      coalesce((p_row ->> 'is_flagged')::boolean, false),
      coalesce((p_row ->> 'face_verified')::boolean, false),
      nullif(p_row ->> 'verification_method', ''),
      p_session_date,
      coalesce((p_row ->> 'attended_at')::timestamptz, timezone('utc', now())),
      coalesce((p_row ->> 'timestamp')::timestamptz, timezone('utc', now())),
      coalesce((p_row ->> 'created_at')::timestamptz, timezone('utc', now())),
      timezone('utc', now())
    );
  exception when others then
    delete from public.phone_session_locks where id = v_phone_lock_id;
    if v_member_lock_id is not null then
      delete from public.member_session_locks where id = v_member_lock_id;
    end if;
    raise;
  end;

  if v_member_id is not null then
    select checked_in_member_ids into v_ids
    from public.session_attendance
    where session_date = p_session_date;
    if not found then
      insert into public.session_attendance (id, session_date, checked_in_member_ids, updated_at)
      values (
        to_char(p_session_date, 'YYYY-MM-DD'),
        p_session_date,
        array[v_member_id],
        timezone('utc', now())
      );
    else
      update public.session_attendance
      set
        checked_in_member_ids = (
          select array_agg(distinct x)
          from unnest(coalesce(v_ids, '{}') || v_member_id) as x
        ),
        updated_at = timezone('utc', now())
      where session_date = p_session_date;
    end if;
  end if;

  return jsonb_build_object(
    'id', v_id,
    'session_date', p_session_date,
    'photo_path', v_photo_path,
    'has_photo', v_has_photo
  );
end;
$$;

revoke all on function public.submit_public_check_in(jsonb, date, text, text, boolean)
  from public;
grant execute on function public.submit_public_check_in(jsonb, date, text, text, boolean)
  to anon, authenticated;

-- ── Persisted rate limits for Edge password_reset ────────────────────────
create table if not exists public.email_rate_limits (
  bucket_key text primary key,
  hit_count int not null default 0,
  window_started_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.email_rate_limits enable row level security;
revoke all on table public.email_rate_limits from public, anon, authenticated;
-- Edge Function uses service role (bypasses RLS).

create or replace function public.bump_email_rate_limit(
  p_bucket_key text,
  p_max_hits int,
  p_window_seconds int
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_count int;
  v_started timestamptz;
begin
  if p_bucket_key is null or length(trim(p_bucket_key)) = 0 then
    return false;
  end if;

  insert into public.email_rate_limits (bucket_key, hit_count, window_started_at, updated_at)
  values (trim(p_bucket_key), 1, v_now, v_now)
  on conflict (bucket_key) do nothing;

  select hit_count, window_started_at
    into v_count, v_started
  from public.email_rate_limits
  where bucket_key = trim(p_bucket_key)
  for update;

  if v_started + make_interval(secs => greatest(p_window_seconds, 1)) < v_now then
    update public.email_rate_limits
    set hit_count = 1,
        window_started_at = v_now,
        updated_at = v_now
    where bucket_key = trim(p_bucket_key);
    return false;
  end if;

  if v_count >= p_max_hits then
    return true; -- limited
  end if;

  update public.email_rate_limits
  set hit_count = hit_count + 1,
      updated_at = v_now
  where bucket_key = trim(p_bucket_key);

  return false;
end;
$$;

revoke all on function public.bump_email_rate_limit(text, int, int) from public;
grant execute on function public.bump_email_rate_limit(text, int, int) to service_role;
-- Callable only with service role from Edge (no grant to anon/authenticated).

commit;

-- ========== app_secrets (replace PLACEHOLDER with .secrets value) ==========
insert into public.app_secrets (id, value)
values ('CHECKIN_SESSION_TOKEN_SECRET', 'PLACEHOLDER_REPLACE_WITH_LOCAL_SECRET')
on conflict (id) do update
set value = excluded.value,
    updated_at = timezone('utc', now());
