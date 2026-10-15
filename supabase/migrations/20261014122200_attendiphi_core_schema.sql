-- Attendiphi Phase 2: core Postgres schema + RLS
-- Target project: fzghxzybyygslfjyfewu (attendiphi.metaphi@gmail.com)
--
-- Primary keys keep Firestore document IDs (text) for stable XLSX import.
-- Do NOT put service-role keys in the Flutter app.

begin;

create extension if not exists "pgcrypto";

do $$ begin
  create type public.check_in_type as enum (
    'member',
    'substitute',
    'visitor',
    'absent',
    'notCheckedIn'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.admin_role as enum ('superadmin', 'admin');
exception when duplicate_object then null;
end $$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- ── Tables (before admin helper functions) ───────────────────────────────
create table if not exists public.members (
  id text primary key,
  name text not null default '',
  email text not null default '',
  phone text not null default '',
  role text not null default 'Member',
  designation text not null default '',
  is_active boolean not null default true,
  admin_id text,
  photo_url text,
  face_enrolled boolean not null default false,
  face_registered boolean not null default false,
  face_model text,
  face_model_version text,
  created_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists members_phone_idx on public.members (phone);
create index if not exists members_name_lower_idx on public.members (lower(name));
create index if not exists members_is_active_idx on public.members (is_active);

create table if not exists public.admins (
  id text primary key,
  auth_user_id uuid unique references auth.users (id) on delete set null,
  uid text not null default '',
  name text not null default '',
  email text not null unique,
  phone text not null default '',
  role public.admin_role not null default 'admin',
  must_reset_password boolean not null default false,
  is_active boolean not null default true,
  created_by text,
  assigned_location_ids text[] not null default '{}',
  password_hash text,
  password_salt text,
  created_at timestamptz,
  last_login_at timestamptz,
  password_updated_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists admins_email_idx on public.admins (lower(email));
create index if not exists admins_auth_user_id_idx on public.admins (auth_user_id);

create table if not exists public.locations (
  id text primary key,
  name text not null default '',
  address text,
  latitude double precision,
  longitude double precision,
  radius_meters double precision,
  is_active boolean not null default true,
  created_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now()),
  raw jsonb not null default '{}'::jsonb
);

create table if not exists public.check_ins (
  id text primary key,
  type public.check_in_type not null default 'member',
  location_id text not null default '',
  location_name text not null default '',
  user_name text not null default '',
  user_phone text not null default '',
  user_email text,
  user_latitude double precision not null default 0,
  user_longitude double precision not null default 0,
  gps_accuracy double precision not null default 0,
  distance_meters double precision not null default 0,
  member_id text references public.members (id) on delete set null,
  substitute_for_member text,
  substitute_name text,
  substitute_phone text,
  company_name text,
  category text,
  invited_by_member text,
  photo_base64 text,
  photo_path text,
  has_photo boolean not null default false,
  admin_id text,
  device_id text,
  is_verified boolean not null default false,
  verified_at timestamptz,
  verified_by text,
  is_edited boolean not null default false,
  edited_at timestamptz,
  is_flagged boolean not null default false,
  flag_reason text,
  face_verified boolean not null default false,
  verification_method text,
  session_date date,
  attended_at timestamptz,
  "timestamp" timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  raw jsonb not null default '{}'::jsonb
);

create index if not exists check_ins_type_idx on public.check_ins (type);
create index if not exists check_ins_session_date_idx on public.check_ins (session_date);
create index if not exists check_ins_member_id_idx on public.check_ins (member_id);
create index if not exists check_ins_created_at_idx on public.check_ins (created_at desc);
create index if not exists check_ins_user_phone_idx on public.check_ins (user_phone);
create index if not exists check_ins_substitute_phone_idx on public.check_ins (substitute_phone);

create table if not exists public.session_attendance (
  id text primary key,
  session_date date not null,
  checked_in_member_ids text[] not null default '{}',
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists session_attendance_session_date_uidx
  on public.session_attendance (session_date);

create table if not exists public.device_session_locks (
  id text primary key,
  device_id text not null,
  session_date date not null,
  check_in_id text,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists device_session_locks_uidx
  on public.device_session_locks (device_id, session_date);

create table if not exists public.phone_session_locks (
  id text primary key,
  phone_digits text not null,
  session_date date not null,
  check_in_id text,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists phone_session_locks_uidx
  on public.phone_session_locks (phone_digits, session_date);

create table if not exists public.member_session_locks (
  id text primary key,
  member_id text not null,
  session_date date not null,
  check_in_id text,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists member_session_locks_uidx
  on public.member_session_locks (member_id, session_date);

create table if not exists public.face_templates (
  id text primary key,
  member_id text references public.members (id) on delete cascade,
  name text,
  chapter_id text,
  model text,
  model_version text,
  embedding double precision[],
  updated_at timestamptz not null default timezone('utc', now()),
  raw jsonb not null default '{}'::jsonb
);

create index if not exists face_templates_member_id_idx
  on public.face_templates (member_id);

create table if not exists public.app_config (
  id text primary key,
  restrictions_enabled boolean not null default false,
  updated_by text,
  updated_by_email text,
  updated_at timestamptz not null default timezone('utc', now()),
  raw jsonb not null default '{}'::jsonb
);

create table if not exists public.admin_devices (
  id text primary key,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.admin_notifications (
  id text primary key,
  title text,
  body text,
  submission_id text,
  location_id text,
  location_name text,
  user_name text,
  user_phone text,
  check_in_type text,
  status text,
  target_role text,
  data jsonb not null default '{}'::jsonb,
  "timestamp" timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.admin_mail_dispatch (
  id text primary key,
  recipient_email text,
  recipient_name text,
  role text,
  portal_url text,
  subject text,
  status text,
  delivery text,
  automatic_send boolean,
  created_at timestamptz,
  raw jsonb not null default '{}'::jsonb
);

create table if not exists public.mail (
  id text primary key,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

-- ── Admin helpers (after admins table exists) ────────────────────────────
create or replace function public.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admins a
    where a.is_active = true
      and (
        a.auth_user_id = auth.uid()
        or lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admins a
    where a.is_active = true
      and a.role = 'superadmin'
      and (
        a.auth_user_id = auth.uid()
        or lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  );
$$;

revoke all on function public.is_active_admin() from public;
revoke all on function public.is_super_admin() from public;
grant execute on function public.is_active_admin() to authenticated, anon;
grant execute on function public.is_super_admin() to authenticated, anon;

-- ── updated_at triggers ──────────────────────────────────────────────────
drop trigger if exists members_set_updated_at on public.members;
create trigger members_set_updated_at
  before update on public.members
  for each row execute function public.set_updated_at();

drop trigger if exists admins_set_updated_at on public.admins;
create trigger admins_set_updated_at
  before update on public.admins
  for each row execute function public.set_updated_at();

drop trigger if exists check_ins_set_updated_at on public.check_ins;
create trigger check_ins_set_updated_at
  before update on public.check_ins
  for each row execute function public.set_updated_at();

-- ── RLS ──────────────────────────────────────────────────────────────────
alter table public.members enable row level security;
alter table public.admins enable row level security;
alter table public.locations enable row level security;
alter table public.check_ins enable row level security;
alter table public.session_attendance enable row level security;
alter table public.device_session_locks enable row level security;
alter table public.phone_session_locks enable row level security;
alter table public.member_session_locks enable row level security;
alter table public.face_templates enable row level security;
alter table public.app_config enable row level security;
alter table public.admin_devices enable row level security;
alter table public.admin_notifications enable row level security;
alter table public.admin_mail_dispatch enable row level security;
alter table public.mail enable row level security;

drop policy if exists members_admin_all on public.members;
create policy members_admin_all on public.members
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists members_anon_read_active on public.members;
create policy members_anon_read_active on public.members
  for select to anon
  using (is_active = true);

drop policy if exists admins_admin_read on public.admins;
create policy admins_admin_read on public.admins
  for select to authenticated
  using (public.is_active_admin());

drop policy if exists admins_superadmin_write on public.admins;
create policy admins_superadmin_write on public.admins
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists check_ins_admin_all on public.check_ins;
create policy check_ins_admin_all on public.check_ins
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists check_ins_anon_insert on public.check_ins;
create policy check_ins_anon_insert on public.check_ins
  for insert to anon
  with check (true);

drop policy if exists check_ins_anon_select on public.check_ins;
create policy check_ins_anon_select on public.check_ins
  for select to anon
  using (true);

drop policy if exists session_attendance_admin_all on public.session_attendance;
create policy session_attendance_admin_all on public.session_attendance
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists session_attendance_anon_rw on public.session_attendance;
create policy session_attendance_anon_rw on public.session_attendance
  for all to anon
  using (true)
  with check (true);

drop policy if exists device_locks_admin_all on public.device_session_locks;
create policy device_locks_admin_all on public.device_session_locks
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists device_locks_anon_rw on public.device_session_locks;
create policy device_locks_anon_rw on public.device_session_locks
  for all to anon
  using (true)
  with check (true);

drop policy if exists phone_locks_admin_all on public.phone_session_locks;
create policy phone_locks_admin_all on public.phone_session_locks
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists phone_locks_anon_rw on public.phone_session_locks;
create policy phone_locks_anon_rw on public.phone_session_locks
  for all to anon
  using (true)
  with check (true);

drop policy if exists member_locks_admin_all on public.member_session_locks;
create policy member_locks_admin_all on public.member_session_locks
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists member_locks_anon_rw on public.member_session_locks;
create policy member_locks_anon_rw on public.member_session_locks
  for all to anon
  using (true)
  with check (true);

drop policy if exists face_templates_admin_all on public.face_templates;
create policy face_templates_admin_all on public.face_templates
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists app_config_admin_all on public.app_config;
create policy app_config_admin_all on public.app_config
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists app_config_anon_read on public.app_config;
create policy app_config_anon_read on public.app_config
  for select to anon
  using (true);

drop policy if exists locations_admin_all on public.locations;
create policy locations_admin_all on public.locations
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists locations_anon_read on public.locations;
create policy locations_anon_read on public.locations
  for select to anon
  using (is_active = true);

drop policy if exists admin_devices_admin_all on public.admin_devices;
create policy admin_devices_admin_all on public.admin_devices
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists admin_notifications_admin_all on public.admin_notifications;
create policy admin_notifications_admin_all on public.admin_notifications
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists admin_mail_dispatch_admin_all on public.admin_mail_dispatch;
create policy admin_mail_dispatch_admin_all on public.admin_mail_dispatch
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

drop policy if exists mail_admin_all on public.mail;
create policy mail_admin_all on public.mail
  for all to authenticated
  using (public.is_active_admin())
  with check (public.is_active_admin());

-- ── Realtime (Flutter stream / live dashboard) ───────────────────────────
do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'check_ins'
  ) then
    alter publication supabase_realtime add table public.check_ins;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'members'
  ) then
    alter publication supabase_realtime add table public.members;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'session_attendance'
  ) then
    alter publication supabase_realtime add table public.session_attendance;
  end if;
end $$;

commit;
