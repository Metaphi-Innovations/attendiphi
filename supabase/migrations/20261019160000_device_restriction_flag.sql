-- Add device_restriction_enabled to public check-in RPC.
-- When ON (default / missing key → master), claim device_session_locks for
-- p_row.device_id so one device = one check-in per session day.
-- When OFF, skip device locks (shared venue standee mode).

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
  v_device_id text := nullif(trim(coalesce(p_row ->> 'device_id', '')), '');
  v_device_lock_id text;
  v_lat double precision := coalesce((p_row ->> 'user_latitude')::double precision, 0);
  v_lon double precision := coalesce((p_row ->> 'user_longitude')::double precision, 0);
  v_dist double precision;
  v_radius double precision;
  v_loc_lat double precision;
  v_loc_lon double precision;
  v_master boolean := true;
  v_date_restriction boolean := true;
  v_location_restriction boolean := true;
  v_device_restriction boolean := true;
  v_raw jsonb := '{}'::jsonb;
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
  if v_device_id is not null then
    v_device_lock_id := v_device_id || '_' || to_char(p_session_date, 'YYYY-MM-DD');
  end if;

  select
    coalesce(restrictions_enabled, true),
    coalesce(raw, '{}'::jsonb)
    into v_master, v_raw
  from public.app_config
  where id = 'checkInRestrictions';
  if not found then
    v_master := true;
    v_raw := '{}'::jsonb;
  end if;

  v_date_restriction := coalesce(
    (v_raw ->> 'date_restriction_enabled')::boolean,
    v_master,
    true
  );
  v_location_restriction := coalesce(
    (v_raw ->> 'location_restriction_enabled')::boolean,
    v_master,
    true
  );
  v_device_restriction := coalesce(
    (v_raw ->> 'device_restriction_enabled')::boolean,
    v_master,
    true
  );

  if p_enforce_restrictions and v_date_restriction then
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

  if p_enforce_restrictions and v_location_restriction then
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

  -- Device lock only when device restriction is ON and device_id is present.
  if v_device_restriction and v_device_lock_id is not null then
    begin
      insert into public.device_session_locks (id, device_id, session_date, check_in_id)
      values (v_device_lock_id, v_device_id, p_session_date, v_id);
    exception when unique_violation then
      select check_in_id into v_existing_check_in
      from public.device_session_locks where id = v_device_lock_id;
      if v_existing_check_in is null
         or trim(v_existing_check_in) = ''
         or not exists (select 1 from public.check_ins c where c.id = v_existing_check_in)
      then
        delete from public.device_session_locks where id = v_device_lock_id;
        insert into public.device_session_locks (id, device_id, session_date, check_in_id)
        values (v_device_lock_id, v_device_id, p_session_date, v_id);
      else
        delete from public.phone_session_locks where id = v_phone_lock_id;
        if v_member_lock_id is not null then
          delete from public.member_session_locks where id = v_member_lock_id;
        end if;
        raise exception 'duplicate_device' using errcode = 'P0001';
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
      null,
      v_photo_path,
      v_has_photo,
      nullif(p_row ->> 'admin_id', ''),
      v_device_id,
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
    if v_device_lock_id is not null then
      delete from public.device_session_locks where id = v_device_lock_id;
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

comment on function public.submit_public_check_in(jsonb, date, text, text, boolean) is
  'Public check-in RPC. Location/date/device restrictions from app_config.raw (fallback: restrictions_enabled).';

revoke all on function public.submit_public_check_in(jsonb, date, text, text, boolean)
  from public;
grant execute on function public.submit_public_check_in(jsonb, date, text, text, boolean)
  to anon, authenticated;
