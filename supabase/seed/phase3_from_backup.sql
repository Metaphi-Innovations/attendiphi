-- Attendiphi Phase 3 seed from backup XLSX
-- Source: attendiphi-full-backup-2026-10-14T06-14-35-829Z.xlsx
-- Run in Supabase SQL Editor on project fzghxzybyygslfjyfewu
begin;

-- members (96)
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '0NpKiI52f8u1YI7c2mN3',
  'Radhaa Mandani',
  '',
  '9372396434',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '1pz1pTr24UfsQgE5a5mS',
  'Mohammed Bhinderwala',
  '',
  '9820468398',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '265douUObB15WjWVQ1bF',
  'Purvi Asher',
  '',
  '9820316991',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '38bMsFmUl9iCtbWxsJla',
  'Karim Siddiqui',
  '',
  '9769761138',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '3TSGL7Nv9B5G522sgi6F',
  'Gautam Nagda',
  '',
  '9967964998',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '3uH5TwgMs56MDD9bf2zP',
  'Rahul Mehta',
  '',
  '9820247668',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '53vEkKwMI0qOaoNa7iMx',
  'Nishit Doshi',
  '',
  '9769759749',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '6Xllh1pAIXO0Ujjxeg8x',
  'Priyank Deshmukh',
  '',
  '9833855671',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '6oPcL73xegjQFC57QYBD',
  'Sabina Gupta',
  '',
  '9821739597',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '7HC3LlSmBOUWRZsxWDOi',
  'Rohit Tawari',
  '',
  '7043297313',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '7WXDMQUKWFtSSoZmlMAC',
  'Rushabh Kubadia',
  '',
  '8291899291',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '8KGbuKitInhCySeS7571',
  'Siraj Kherodawala',
  '',
  '9004716222',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '90cIjE4Q6QtWAVE5CSJd',
  'Mohammad Valiullah Shariff',
  '',
  '9004956768',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '9B4iEOInwkvXl6kpbjHA',
  'Harshita Kala',
  '',
  '7506256356',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  '9mhsIRiU7APSfut6e3xo',
  'Prasanna Thakkar',
  '',
  '9820071007',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'AO7zyh6RKPwuMOSv6Nd5',
  'Hemali Girish Ashar',
  '',
  '9136365652',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'AqLY9voWQ6kVkeq0uAsH',
  'Kailas Jadhav',
  '',
  '9867876600',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'BaDs9pnytP3hvkHS1xCG',
  'Hashim Bhinderwala',
  '',
  '9819201789',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'DS7l5ZPKHNxuFscqbHIT',
  'Ajay Bajaj',
  '',
  '9223291871',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'DobQyNV4KKdvFoXDYK79',
  'Ubed Chowhan',
  '',
  '9987028576',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'EFm6fdLH4mKbKmncFMtl',
  'Mahesh Shah',
  '',
  '9821050853',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'FRVIPK6pU5lLcRGH8lOu',
  'Vaibhav R Shah',
  '',
  '8879238658',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'FidOmKXyDsF9FWUaRZgw',
  'Mayank Gosar',
  '',
  '9870590475',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'FxEVoDNdNSMb0EuxwJTj',
  'Akanksha Bector',
  '',
  '8879656690',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'Gdp0zJ0h7bVTqu4RNnFK',
  'Kavan Modi',
  '',
  '7977754515',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'H13YFlNoona9pWgK8L1c',
  'Urvi Shah',
  '',
  '9819886633',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'IWMVr2NgFYo38xBOFvkN',
  'Prabhakar Nakashe',
  '',
  '9820448799',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'IX7StO77cKIhI8HkpTL0',
  'Saifuddin Lakdawala',
  '',
  '9820186619',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'J0IvzhqFCInXaznHdjfg',
  'Jayesh Ruparel',
  '',
  '8097366666',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'JPE7PtJnkJ5zxdiAUZCa',
  'Sandeep Bisla',
  '',
  '9899971660',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'JPogNVmdSSZGBIzzYenC',
  'Indrani Sant',
  '',
  '7506436689',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'KhOdndsiVvz292c5tJYk',
  'Vishal Kakde',
  '',
  '8454984654',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'KiFhmXqmFAJu4r4FgXWp',
  'Sachin Gada',
  '',
  '9833083169',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'KlBKzSWOEJcM0w0sl8FT',
  'Rakesh Ashar',
  '',
  '9324086435',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'LkpE5XhAIPcX01Xe0Cge',
  'Preeti Lalwani',
  '',
  '9820006774',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'Ls2QHZXIyflFFt9wltbM',
  'Varun Rajaram',
  '',
  '9545712120',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'Lu46vgfmc8o5kqzyxIGg',
  'Yash Haria',
  '',
  '9930043683',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'LxWJRt2UUrpop4VliTlh',
  'Manan Vasa',
  '',
  '8097010410',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'MfXvO5nB4Py3UXa9LyM4',
  'Hussain Rassai',
  '',
  '9821045110',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'Mt6FLuWeYlXpKBlljyLS',
  'Pal Jain',
  '',
  '7977083342',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'MuVuPRDgb7Ru2ETswaJa',
  'Ansh Kapoor',
  '',
  '9930430483',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'PS8iRRZuAEFdaJbN1BKV',
  'Tejashree Vinayak Sane',
  '',
  '9819055132',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'PeNnZQ5PuFqYU1bTb08x',
  'Atul Gupta',
  '',
  '9870402502',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'Q5hpJYOEybtkyopobLCo',
  'Aakriti Sunder',
  '',
  '9326274360',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'QKj0vU3n1pasWTG6nIQM',
  'Hari Ayyappan',
  '',
  '9820075320',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'Qu21MsYqvySMG3UotzkI',
  'Saloni Shah',
  '',
  '9821800071',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'Qwag7uNhRrXcpobn24zd',
  'Parthesh Savla',
  '',
  '9892209899',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'RT4LY0FAcSP3VqvyFYxA',
  'Hitesh Gadhia',
  '',
  '9819827814',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'TGsSahqSrbKg5isJ5adG',
  'Ketan Lotia',
  '',
  '9820478924',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'UCcv2AMJjlS7VT4l43MK',
  'Avnish Mehta',
  '',
  '9702464242',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'UpBz5LGUJMIk7ohwb8ZZ',
  'Shefali Soman Bapat',
  '',
  '9326262804',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'Vevx5J2UBqJ5Hj2qB4Qd',
  'Imran Petiwala',
  '',
  '9004854786',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'VnhCS4Yw909ZAfJPj9Yf',
  'Manan Sanghai',
  '',
  '8080250800',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'XSvSmdSucf2Iww8AGYd3',
  'Mayank Mehta',
  '',
  '8369180984',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'ZDCa5FPDEIgahIXgtlrJ',
  'Jay Dhakan',
  '',
  '7738208090',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'ZzKmlW7fuyT93dJxPFkM',
  'Bhavin Shah',
  '',
  '9870089414',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'aQ5Ihm2OqxQqKz1aPXPO',
  'Jagat Mehta',
  '',
  '9821064854',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'bXYXbdfx01NMGDNPlNtY',
  'Mitesh Vora',
  '',
  '9867039491',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'bj44kfd2SuPEwiSsv80l',
  'Kaamini Suhas',
  '',
  '9667122717',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'dpAD4wg9CQ0GtmXQ8QHW',
  'Indraneel Vaidya',
  '',
  '9820059694',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'eZvhNlWQ2593I9qJkzOj',
  'Jay Dalal',
  '',
  '9769563124',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'iuHuucPi6vdbMN2XnMNM',
  'Shatul Gupta',
  '',
  '9820625506',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'jfDDqQnt5mY1S1w7uqhE',
  'Shimoni Kadakia',
  '',
  '9820097716',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'kYpS7tpiGt3XosvTb6mE',
  'Neha Gupta',
  '',
  '9820037444',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'kin0gBScMVbWdaRmUXG2',
  'Shibaz Patel',
  '',
  '9890001903',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'ksdnwjeMhPkQlWqNhBgs',
  'Mitul Shingadia',
  '',
  '9967533315',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'lGL99wmRNCppOlkmR6Oj',
  'Sanjay Bengali',
  '',
  '9820447128',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'mHyV5robnQmOIHIEZoor',
  'Jimit Jhaveri',
  '',
  '9930566225',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'mkbQ5LmHMmkUj1zlaQ9T',
  'Shobha Pillai Coutinho',
  '',
  '9820506506',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'nQJG57Kl9taZlMkLgC0N',
  'Viral Gosar',
  '',
  '8108156000',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'nisHwof0WmvAePs7LclP',
  'Vishwatmika Jadhav',
  '',
  '9920734142',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'o3n5JBBx7AX6VYkZlph7',
  'Chirag Merchant',
  '',
  '9004043167',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'oWDDHimFVinBCkn6UCVq',
  'Siddharth Nair',
  '',
  '7506090337',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'ofhv6bMhOkXbj57xdBrx',
  'Gaurav Thakker',
  '',
  '9769655090',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'quDand8LH8giQXs5v5N0',
  'Sandeep Chavada',
  '',
  '8898341341',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'rE6ztLfjyrvXqwEsOiDL',
  'Rushabh Gandhi',
  '',
  '9839834944',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'rN1W2Y167i0oBlNUgfpR',
  'Amrita Kotak',
  '',
  '9167486070',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'rQSD7oEgee2FwO6xFfa4',
  'Rutvi Sanghvi',
  '',
  '8369492613',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'sQHsXe5C45MEhDHacG2u',
  'Harvinder Singh Wasan',
  '',
  '9322600486',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'sZ8MDEhhUastj39PFwbZ',
  'Amar Parekh',
  '',
  '9167932980',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'sobf9E6koFqVxhbeuy3C',
  'Rahul Shroff',
  '',
  '9137174281',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'syGVK5cPhtfPtbVUNtbY',
  'Bharat Kankariya',
  '',
  '9321510005',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'tLsFF41wmi6MepYkF7iB',
  'Monish Gala',
  '',
  '9769751753',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'uOPFKQQ1VZK2ytszgbrH',
  'Aruna Mookhey',
  '',
  '9820183227',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'ui8vhADN5gTnEwbNr6sU',
  'Pallavi Todi',
  '',
  '7738022490',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'ulifv2z1uZXMYuyHHPEU',
  'Tejas Savla',
  '',
  '9664775997',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'uqSFTxaeaNIQH3R8NlwG',
  'Twinkal Gupta',
  '',
  '9820373726',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'wVDflKDCQiipccIqrwCB',
  'Dhiren Dedhia',
  '',
  '9322214771',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'wyyytYwiUB1B3Wz7rN9u',
  'Kashyap Anandpara',
  '',
  '9930859152',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'x2uy5sfE75x5QOvcGT75',
  'Anna Singh',
  '',
  '9820698887',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'xMDXjTaD1XhWD5cN3FZN',
  'Darshan Shah',
  '',
  '9920628333',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'xQcHTY5UKO8poTfMM1UZ',
  'Huzefa Lokhandwala',
  '',
  '9702305358',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'xXzOOujsz7yKiMvFQb3C',
  'Alia Kantawala',
  '',
  '7045922253',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'xdw1Wfux9tLePJPgbSpi',
  'Sachit Dedhia',
  '',
  '9820623331',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'xmxCzhsAOU1TAagU4yQn',
  'Sunnyraj Sharma',
  '',
  '9326490289',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());
insert into public.members (id, name, email, phone, role, designation, is_active, photo_url, face_enrolled, face_registered, created_at, updated_at)
values (
  'yiAO69rUrytFKXUZuVxc',
  'Mihir Bala',
  '',
  '8849853291',
  'Member',
  '',
  coalesce(TRUE, TRUE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  '2026-10-07T09:54:04.804Z',
  coalesce('2026-10-07T09:54:04.804Z', timezone('utc', now()))
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  designation = excluded.designation,
  is_active = excluded.is_active,
  photo_url = excluded.photo_url,
  face_enrolled = excluded.face_enrolled,
  face_registered = excluded.face_registered,
  updated_at = timezone('utc', now());

-- admins (6)
insert into public.admins (
  id, uid, name, email, phone, role, must_reset_password, is_active,
  created_by, assigned_location_ids, password_hash, password_salt,
  created_at, last_login_at
) values (
  '65luNOEIicPaXNLiNvdBvDIkChw2',
  '65luNOEIicPaXNLiNvdBvDIkChw2',
  'Nishit Jhosi',
  'nishit@shriseys.com',
  '9769759749',
  'admin'::public.admin_role,
  coalesce(TRUE, FALSE),
  coalesce(TRUE, TRUE),
  '7Bl8KLfKS1g2n2LQQ8XJnEbcw602',
  '{}',
  NULL,
  NULL,
  '2026-10-07T12:11:16.399Z',
  NULL
)
on conflict (id) do update set
  uid = excluded.uid,
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  must_reset_password = excluded.must_reset_password,
  is_active = excluded.is_active,
  assigned_location_ids = excluded.assigned_location_ids,
  updated_at = timezone('utc', now());
insert into public.admins (
  id, uid, name, email, phone, role, must_reset_password, is_active,
  created_by, assigned_location_ids, password_hash, password_salt,
  created_at, last_login_at
) values (
  '7Bl8KLfKS1g2n2LQQ8XJnEbcw602',
  '7Bl8KLfKS1g2n2LQQ8XJnEbcw602',
  'Rinku',
  'rinku.s@metaphi.in',
  '',
  'superadmin'::public.admin_role,
  coalesce(FALSE, FALSE),
  coalesce(TRUE, TRUE),
  '7Bl8KLfKS1g2n2LQQ8XJnEbcw602',
  '{}',
  NULL,
  NULL,
  '2026-10-07T09:43:38.467Z',
  '2026-10-14T05:23:08.832Z'
)
on conflict (id) do update set
  uid = excluded.uid,
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  must_reset_password = excluded.must_reset_password,
  is_active = excluded.is_active,
  assigned_location_ids = excluded.assigned_location_ids,
  updated_at = timezone('utc', now());
insert into public.admins (
  id, uid, name, email, phone, role, must_reset_password, is_active,
  created_by, assigned_location_ids, password_hash, password_salt,
  created_at, last_login_at
) values (
  'KW9np96Yc5UAwkG3N1jMqcvKLoz1',
  'KW9np96Yc5UAwkG3N1jMqcvKLoz1',
  'Jimit Jhaveri',
  'jimjh92@gmail.com',
  '9930566225',
  'admin'::public.admin_role,
  coalesce(TRUE, FALSE),
  coalesce(TRUE, TRUE),
  '7Bl8KLfKS1g2n2LQQ8XJnEbcw602',
  '{}',
  NULL,
  NULL,
  '2026-10-07T12:10:01.054Z',
  NULL
)
on conflict (id) do update set
  uid = excluded.uid,
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  must_reset_password = excluded.must_reset_password,
  is_active = excluded.is_active,
  assigned_location_ids = excluded.assigned_location_ids,
  updated_at = timezone('utc', now());
insert into public.admins (
  id, uid, name, email, phone, role, must_reset_password, is_active,
  created_by, assigned_location_ids, password_hash, password_salt,
  created_at, last_login_at
) values (
  'Q427eFgMlHRg9gRYnhjvMmsUtVn2',
  'Q427eFgMlHRg9gRYnhjvMmsUtVn2',
  'Avnish',
  'avnish@metaphi.in',
  '',
  'superadmin'::public.admin_role,
  coalesce(FALSE, FALSE),
  coalesce(TRUE, TRUE),
  'Q427eFgMlHRg9gRYnhjvMmsUtVn2',
  '{}',
  NULL,
  NULL,
  '2026-10-07T09:43:40.492Z',
  '2026-10-07T15:33:22.759Z'
)
on conflict (id) do update set
  uid = excluded.uid,
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  must_reset_password = excluded.must_reset_password,
  is_active = excluded.is_active,
  assigned_location_ids = excluded.assigned_location_ids,
  updated_at = timezone('utc', now());
insert into public.admins (
  id, uid, name, email, phone, role, must_reset_password, is_active,
  created_by, assigned_location_ids, password_hash, password_salt,
  created_at, last_login_at
) values (
  'cGgm1N1yYbYrla7WPARm8kgg1CS2',
  'cGgm1N1yYbYrla7WPARm8kgg1CS2',
  'Yash Haria',
  'yash.haria@cooverji.com',
  '9930043683',
  'admin'::public.admin_role,
  coalesce(FALSE, FALSE),
  coalesce(TRUE, TRUE),
  '7Bl8KLfKS1g2n2LQQ8XJnEbcw602',
  '{}',
  NULL,
  NULL,
  '2026-10-07T12:08:13.633Z',
  '2026-10-07T12:20:20.228Z'
)
on conflict (id) do update set
  uid = excluded.uid,
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  must_reset_password = excluded.must_reset_password,
  is_active = excluded.is_active,
  assigned_location_ids = excluded.assigned_location_ids,
  updated_at = timezone('utc', now());
insert into public.admins (
  id, uid, name, email, phone, role, must_reset_password, is_active,
  created_by, assigned_location_ids, password_hash, password_salt,
  created_at, last_login_at
) values (
  'jF8quoQ0Yshj4vvtqbbefPhmEmO2',
  'jF8quoQ0Yshj4vvtqbbefPhmEmO2',
  'Monish Gala',
  'monish@justracks.in',
  '9769751753',
  'admin'::public.admin_role,
  coalesce(TRUE, FALSE),
  coalesce(TRUE, TRUE),
  '7Bl8KLfKS1g2n2LQQ8XJnEbcw602',
  '{}',
  NULL,
  NULL,
  '2026-10-07T12:09:06.005Z',
  NULL
)
on conflict (id) do update set
  uid = excluded.uid,
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  role = excluded.role,
  must_reset_password = excluded.must_reset_password,
  is_active = excluded.is_active,
  assigned_location_ids = excluded.assigned_location_ids,
  updated_at = timezone('utc', now());

-- check_ins (97)
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '01153ad2-ce4b-43db-b77b-a4bb7929e0ea',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Amar Parekh',
  '9167932980',
  NULL,
  'sZ8MDEhhUastj39PFwbZ',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T12:00:08.602Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T12:00:08.602Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '040b819f-a5ab-45b2-a475-2102c73df455',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Harshita Kala',
  '7506256356',
  NULL,
  '9B4iEOInwkvXl6kpbjHA',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:59:01.162Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:59:01.162Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '05057275-02ff-4abb-abc7-d8529c8ff3ea',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Indrani Sant',
  '7506436689',
  NULL,
  'JPogNVmdSSZGBIzzYenC',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:58:00.285Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:58:00.285Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '0540dedf-a713-49ea-a102-27350a181d3a',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Vishwatmika Jadhav',
  '9920734142',
  NULL,
  'nisHwof0WmvAePs7LclP',
  'Vishwatmika Jadhav',
  'Alzaba Feroz',
  '9920734142',
  NULL,
  NULL,
  NULL,
  coalesce(TRUE, FALSE),
  'fp_a45b5b7d4452176cfb425f10b57640c6ef3dd5c3b2f9544c9b16cf4f80b468f6',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T02:26:06.113Z',
  '2026-10-08T02:26:05.101Z',
  coalesce('2026-10-08T02:26:06.113Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '0d0f581e-b0f2-460e-b3d3-ca10733cee0d',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Darshan Shah',
  '9920628333',
  NULL,
  'xMDXjTaD1XhWD5cN3FZN',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_9cbc86e6171cc3e3be658c71f4ef211c9bcf9a7c8bfea5e22aca9062473453c8',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:57:11.319Z',
  '2026-10-08T02:57:09.521Z',
  coalesce('2026-10-08T02:57:11.319Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '13d28a81-0d04-42f2-a8e8-a43f5db94753',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Imran Petiwala',
  '9004854786',
  NULL,
  'Vevx5J2UBqJ5Hj2qB4Qd',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_17e0299c62fa4ae62d0d558eb053814bc16e073cb62c1abbed95b983609f3d77',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:19:11.369Z',
  '2026-10-08T02:19:10.432Z',
  coalesce('2026-10-08T02:19:11.369Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '14e1f788-5f82-4b82-b54d-89652b5804aa',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Pal Jain',
  '7977083342',
  NULL,
  'Mt6FLuWeYlXpKBlljyLS',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_0f4367bbc8054033ba09600a658776e4926f2518110c0e1dd723f10107105f6e',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:16:25.749Z',
  '2026-10-08T02:16:25.299Z',
  coalesce('2026-10-08T02:16:25.749Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '1a6cfd12-8de5-4ef1-a735-514424b3a6d5',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Huzefa Lokhandwala',
  '9702305358',
  NULL,
  'xQcHTY5UKO8poTfMM1UZ',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_c4951dc0c7a3f5ade18db75b7a6b964cc116dcf70c45df526eec08d8f92ad9ee',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:21:14.413Z',
  '2026-10-08T02:21:13.909Z',
  coalesce('2026-10-08T02:21:14.413Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '1f55fb99-01a4-4076-9eda-dabd49a131f7',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Sanjay Bengali',
  '9820447128',
  NULL,
  'lGL99wmRNCppOlkmR6Oj',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_386cf90ff468fbb0f2ef83fd2412a5ce24abc5fe377088a1e1b8da8d5eebc7dd',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:48:37.150Z',
  '2026-10-08T01:48:36.536Z',
  coalesce('2026-10-08T01:48:37.150Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '1fdb2844-c270-4405-96b3-c0c2e6acb485',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Urvi Shah',
  '9819886633',
  NULL,
  'H13YFlNoona9pWgK8L1c',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_79271af8713354624326ebb316cc783765c8f798087bd68e7510f6031a7c4ac8',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:53:18.888Z',
  '2026-10-08T01:53:18.400Z',
  coalesce('2026-10-08T01:53:18.888Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '20403735-e1e0-42e0-9b91-f18efc5bda8a',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Kashyap Anandpara',
  '9930859152',
  NULL,
  'wyyytYwiUB1B3Wz7rN9u',
  'Kashyap Anandpara',
  'Divyesh Gaikwad',
  '9930859152',
  NULL,
  NULL,
  NULL,
  coalesce(TRUE, FALSE),
  'fp_52b29030df45777315ad6b7e3f9cd256136279a69918ab321b19404afddbd855',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T02:18:09.801Z',
  '2026-10-08T02:18:09.192Z',
  coalesce('2026-10-08T02:18:09.801Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '21feefe8-4e72-4d31-ba7e-9d866a5fe846',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Amrita Kotak',
  '9167486070',
  NULL,
  'rN1W2Y167i0oBlNUgfpR',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_ea04eb0507cb8bc21d32b6757a62d7f8210c96aea24f0c8378f880a1a191007c',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:15:59.994Z',
  '2026-10-08T02:15:59.625Z',
  coalesce('2026-10-08T02:15:59.994Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '2321adcb-93df-486d-95ff-31de45695073',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Rushabh Kubadia',
  '8291899291',
  NULL,
  '7WXDMQUKWFtSSoZmlMAC',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_8eb57f19d723d47ee5911191364f4e473eb11bef424e41c26a0fa144cf832cb9',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:05:19.264Z',
  '2026-10-08T02:05:18.816Z',
  coalesce('2026-10-08T02:05:19.264Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '27507f6f-c562-41c5-9282-b0177193550b',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Purvi Asher',
  '9820316991',
  NULL,
  '265douUObB15WjWVQ1bF',
  NULL,
  NULL,
  '9820316991',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:09:59.309Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:09:59.309Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '276f9bb9-9acb-4db3-b902-54d092c7c33b',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Pallavi Todi',
  '7738022490',
  NULL,
  'ui8vhADN5gTnEwbNr6sU',
  NULL,
  NULL,
  '7738022490',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:41:58.706Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:41:58.706Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '28fc881a-103d-4ec2-9a4b-21bbdb0e83d7',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Sunnyraj Sharma',
  '9326490289',
  NULL,
  'xmxCzhsAOU1TAagU4yQn',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_58e7ce5b87c0bb1ccf7ee61c6460c453f8e5b30ee7a8dfae65ded03667b65e0a',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T03:29:56.095Z',
  '2026-10-08T03:29:53.518Z',
  coalesce('2026-10-08T03:29:56.095Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '29d3a652-e998-4223-8601-311f7283350f',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Radhaa Mandani',
  '9372396434',
  NULL,
  '0NpKiI52f8u1YI7c2mN3',
  NULL,
  NULL,
  '9372396434',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:26:18.877Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:26:18.877Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '29f10bd0-d0ec-44c9-9869-f78dad0b8b7c',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Alia Kantawala',
  '7045922253',
  NULL,
  'xXzOOujsz7yKiMvFQb3C',
  NULL,
  NULL,
  '7045922253',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:14:35.690Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:14:35.690Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '2dab945b-3958-4950-a45d-fd1dc8f48381',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Vishal Kakde',
  '8454984654',
  NULL,
  'KhOdndsiVvz292c5tJYk',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_9eb9ca72c6315b29e4c793ef1d0a6fbea1c37a267f2a810a48a8aefe49f084cc',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:17:05.793Z',
  '2026-10-08T02:16:39.623Z',
  coalesce('2026-10-08T02:17:05.793Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '2db75312-ea5f-4093-9db2-e2bf6ac9f902',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Saloni Shah',
  '9821800071',
  NULL,
  'Qu21MsYqvySMG3UotzkI',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_c68f75629ef08bdd6cb1f2103da2d2ac96501b1e48a7c17c608ef6e2a950fa8b',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:59:08.862Z',
  '2026-10-08T01:59:08.519Z',
  coalesce('2026-10-08T01:59:08.862Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '30dfc556-c6db-493e-9356-f5d2217bd47b',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Rakesh Ashar',
  '9324086435',
  NULL,
  'KlBKzSWOEJcM0w0sl8FT',
  NULL,
  NULL,
  '9324086435',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:42:59.444Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:42:59.444Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '34a63c3d-66de-4a57-8afd-465b151e8d39',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Monish Gala',
  '9769751753',
  NULL,
  'tLsFF41wmi6MepYkF7iB',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_2fe52d132a6bc08978585e01e3b63e519439074c60b8f9037dbdf6d588140abc',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:04:21.771Z',
  '2026-10-08T02:04:19.486Z',
  coalesce('2026-10-08T02:04:21.771Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '35663d20-c82a-4dc1-b1e4-2cca0d613a72',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Shimoni Kadakia',
  '9820097716',
  NULL,
  'jfDDqQnt5mY1S1w7uqhE',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_1bea0739041debb3cecb0c7edc12fc92ec86255fe489d0973a24139b81deeebf',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:22:32.367Z',
  '2026-10-08T02:22:32.064Z',
  coalesce('2026-10-08T02:22:32.367Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '3a39954f-d6e0-4bf2-a39e-4ae19bf2f26e',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Jayesh Ruparel',
  '8097366666',
  NULL,
  'J0IvzhqFCInXaznHdjfg',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_ce6f5760b9027d422fed6afd7e063e21b04567ce7d665ac2bdadbb9619aaad39',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:13:46.648Z',
  '2026-10-08T02:13:46.213Z',
  coalesce('2026-10-08T02:13:46.648Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '3d8ee5d5-1d8b-4cc6-a026-0f53e4cbd656',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Anna Singh',
  '9820698887',
  NULL,
  'x2uy5sfE75x5QOvcGT75',
  NULL,
  NULL,
  '9820698887',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:49:29.586Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:49:29.586Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '49657ac7-86b3-4e9a-9a0e-78744688048b',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Gautam Nagda',
  '9967964998',
  NULL,
  '3TSGL7Nv9B5G522sgi6F',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_bc6c8ff4499b361066cdda568714f462cb25611bb0ed1e8a9341bf6744692246',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:56:42.034Z',
  '2026-10-08T01:56:41.171Z',
  coalesce('2026-10-08T01:56:42.034Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '4abfb973-8075-4643-a2c7-fe6d0959e643',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Aruna Mookhey',
  '9820183227',
  NULL,
  'uOPFKQQ1VZK2ytszgbrH',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_d66e2a1e93e0e56cc4ec36ca92e527e2281f247e20371beac2025a2a188637fd',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:22:08.368Z',
  '2026-10-08T02:22:08.033Z',
  coalesce('2026-10-08T02:22:08.368Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '4c15bfa2-6b8b-4220-b435-e4bd4ae70b03',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Siddharth Nair',
  '7506090337',
  NULL,
  'oWDDHimFVinBCkn6UCVq',
  NULL,
  NULL,
  '7506090337',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:51:06.163Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:51:06.163Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '4df0c7be-0dfd-4eb2-8d3e-d59cf6b1d495',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Hemali Girish Ashar',
  '9136365652',
  NULL,
  'AO7zyh6RKPwuMOSv6Nd5',
  NULL,
  NULL,
  '9136365652',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:25:00.356Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:25:00.356Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '4f23dfab-798b-46dc-94e6-ac08f346ddb9',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Shobha Pillai Coutinho',
  '9820506506',
  NULL,
  'mkbQ5LmHMmkUj1zlaQ9T',
  NULL,
  NULL,
  '9820506506',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:57:00.127Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:57:00.127Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '56b8ad33-e6fd-4ebc-ac5f-b31f6840262b',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Mahesh Shah',
  '9821050853',
  NULL,
  'EFm6fdLH4mKbKmncFMtl',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_55ae1c9bad27fc5144f3221e54c3142f2b41eba98c7422fcfe9449b13db0d41e',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:57:40.967Z',
  '2026-10-08T01:57:40.503Z',
  coalesce('2026-10-08T01:57:40.967Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '5a898b7c-6fec-4df0-96fb-0e011fa84808',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Shatul Gupta',
  '9820625506',
  NULL,
  'iuHuucPi6vdbMN2XnMNM',
  NULL,
  NULL,
  '9820625506',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:10:25.949Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:10:25.949Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '5d975e41-1bc2-46af-9540-cfd559d0a752',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Parthesh Savla',
  '9892209899',
  NULL,
  'Qwag7uNhRrXcpobn24zd',
  NULL,
  NULL,
  '9892209899',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:16:35.852Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:16:35.852Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '5e5a1744-ab4d-4d57-b47e-8b8b8d6fba41',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Jay Dalal',
  '9769563124',
  NULL,
  'eZvhNlWQ2593I9qJkzOj',
  NULL,
  NULL,
  '9769563124',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:15:20.150Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:15:20.150Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '60242217-5d1d-47ac-9437-90bab8eeaef6',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Akanksha Bector',
  '8879656690',
  NULL,
  'FxEVoDNdNSMb0EuxwJTj',
  NULL,
  NULL,
  '8879656690',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:34:34.562Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:34:34.562Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '61c59141-e654-4522-b47c-806266b02c7d',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Avnish Mehta',
  '9702464242',
  NULL,
  'UCcv2AMJjlS7VT4l43MK',
  NULL,
  NULL,
  '9702464242',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:49:37.047Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:49:37.047Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '62b77f84-454f-4ebe-a51e-870399b85ffd',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Nishit Doshi',
  '9769759749',
  NULL,
  '53vEkKwMI0qOaoNa7iMx',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_5837a685823fd74fd5b9d4d2e7c1e01ee6f7b51cac86e1f3f08f90d4a295898b',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:40:18.668Z',
  '2026-10-08T01:40:17.934Z',
  coalesce('2026-10-08T01:40:18.668Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '631c7b1d-0231-4d2c-97a6-d9a24fddedb3',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Hitesh Gadhia',
  '9819827814',
  NULL,
  'RT4LY0FAcSP3VqvyFYxA',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_d7c430497062eb4caa5aac4a9826193b78c2669c1f80b504ef0a6229cc1c78df',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T03:39:01.591Z',
  '2026-10-08T03:38:51.488Z',
  coalesce('2026-10-08T03:39:01.591Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '6374cbc6-b56d-49c3-a659-6d16a7d5a3c8',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Saifuddin Lakdawala',
  '9820186619',
  NULL,
  'IX7StO77cKIhI8HkpTL0',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_d4911911826851175117b92ad72fd720ba73ca145cb4e63f9656f35a1c75c1c1',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:13:00.712Z',
  '2026-10-08T02:13:00.170Z',
  coalesce('2026-10-08T02:13:00.712Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '65e4f765-c079-4de4-bcac-e632e49739de',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Viral Gosar',
  '8108156000',
  NULL,
  'nQJG57Kl9taZlMkLgC0N',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_f8499162e6c4f8227e1d02c20330ac1a400a49073d757a6acc1e9cea9c84a47d',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:04:18.573Z',
  '2026-10-08T02:04:18.333Z',
  coalesce('2026-10-08T02:04:18.573Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '66183859-12ab-4b27-a3bc-0da28e87efb8',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Sachit Dedhia',
  '9820623331',
  NULL,
  'xdw1Wfux9tLePJPgbSpi',
  'Sachit Dedhia',
  'ram',
  '9820623331',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:54:06.810Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:54:06.810Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '68386ce6-9828-45a7-8782-c2b3b9edd3ac',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Ansh Kapoor',
  '9930430483',
  NULL,
  'MuVuPRDgb7Ru2ETswaJa',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_7f5db2c77e5866b13620455e14ffe1e52f3469e3a9d276645c5a5314cae13906',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:10:31.862Z',
  '2026-10-08T02:10:30.950Z',
  coalesce('2026-10-08T02:10:31.862Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '69da4446-ae4b-4b36-9b66-1f98ecef28e5',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Rutvi Sanghvi',
  '8369492613',
  NULL,
  'rQSD7oEgee2FwO6xFfa4',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_bfc2766c4bd4952f3ff7da00a0d7747ca5c3e0413c010135c01c2872bb7f0ce4',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:53:50.558Z',
  '2026-10-08T01:53:50.059Z',
  coalesce('2026-10-08T01:53:50.558Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '6cfe82ca-f18c-4885-a46f-24bb7162857d',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Jay Dhakan',
  '7738208090',
  NULL,
  'ZDCa5FPDEIgahIXgtlrJ',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_ef35bd6dd86eb241156453d6a3171d941059636db2f2b6568667e6d88e131701',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:29:54.796Z',
  '2026-10-08T02:29:53.907Z',
  coalesce('2026-10-08T02:29:54.796Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '6e1ea425-08a8-4603-9abc-74f6499cc682',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Indraneel Vaidya',
  '9820059694',
  NULL,
  'dpAD4wg9CQ0GtmXQ8QHW',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_86edd104d1979ae1b9414ea175b6d1554d2e0f3708fd483d2bf644395d8a8f8d',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:21:01.226Z',
  '2026-10-08T02:21:00.556Z',
  coalesce('2026-10-08T02:21:01.226Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '6e21cf45-7a91-4fef-ab72-45337c8abf12',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Shibaz Patel',
  '9890001903',
  NULL,
  'kin0gBScMVbWdaRmUXG2',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:58:35.860Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:58:35.860Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '6e9c978d-9f59-4589-98d1-b489b24d3bbc',
  'visitor'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Prasham Munjal',
  '+918233813031',
  'prasham@fundclub.in',
  NULL,
  NULL,
  NULL,
  NULL,
  'Fundclub',
  'Finance',
  'Nishit Doshi',
  coalesce(FALSE, FALSE),
  'fp_940bf9a799137ea3100f9abae93144022a4e8a267be7a11df7d21e9c7f30aecc',
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T02:08:02.229Z',
  '2026-10-08T02:08:01.737Z',
  coalesce('2026-10-08T02:08:02.229Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '73eb4644-d162-43d6-ae5d-b00af1ad3ff9',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Jagat Mehta',
  '9821064854',
  NULL,
  'aQ5Ihm2OqxQqKz1aPXPO',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_379170628a4e0c1eff55d37c32ec362938841d47a0e41fa8c1818a0b97cb7365',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:58:43.751Z',
  '2026-10-08T01:58:43.231Z',
  coalesce('2026-10-08T01:58:43.751Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '7675d688-1b60-4478-a7de-f95424f3d1bc',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Kaamini Suhas',
  '9667122717',
  NULL,
  'bj44kfd2SuPEwiSsv80l',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:58:10.265Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:58:10.265Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '76e1e9df-2dc5-4bf0-b1b9-3533605745d4',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Atul Gupta',
  '9870402502',
  NULL,
  'PeNnZQ5PuFqYU1bTb08x',
  'Atul Gupta',
  'Pooja ATUL Gupta',
  '9870402502',
  NULL,
  NULL,
  NULL,
  coalesce(TRUE, FALSE),
  'fp_8b101fcee4e04b41984b4c2155400b7f21caf6ba60dd97c272547675e694fcf4',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T01:54:35.696Z',
  '2026-10-08T01:54:34.870Z',
  coalesce('2026-10-08T01:54:35.696Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '7b977162-2071-4b21-8abd-a5591e25f71b',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Ketan Lotia',
  '9820478924',
  NULL,
  'TGsSahqSrbKg5isJ5adG',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_b9e7c7d91442131c02001147644848a2a576b033acab0bd1c1713b6890b77172',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:35:00.744Z',
  '2026-10-08T02:35:00.020Z',
  coalesce('2026-10-08T02:35:00.744Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '80ef3e3b-6b9a-4e58-b034-d3dd84adc64b',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Neha Gupta',
  '9820037444',
  NULL,
  'kYpS7tpiGt3XosvTb6mE',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_da06ffec2e49201b9347e581c5377eabb8de14182af2fbcbea5fc8756655ef8b',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:29:28.904Z',
  '2026-10-08T02:29:28.459Z',
  coalesce('2026-10-08T02:29:28.904Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '8a40ab93-8320-4bcf-80ac-2647ab5b68fd',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Dhiren Dedhia',
  '9322214771',
  NULL,
  'wVDflKDCQiipccIqrwCB',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:59:58.097Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:59:58.097Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '8dbd35f6-0564-4500-825b-412fe4d8b19e',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Tejas Savla',
  '9664775997',
  NULL,
  'ulifv2z1uZXMYuyHHPEU',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_c9d3b3fad2eb579647635d69dc557cb33b7b61c141ba7f591ac14d51ed9c8577',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:35:04.473Z',
  '2026-10-08T01:35:05.074Z',
  coalesce('2026-10-08T01:35:04.473Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '90cc12f2-d4d6-441f-8c2b-58ac22685f09',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Twinkal Gupta',
  '9820373726',
  NULL,
  'uqSFTxaeaNIQH3R8NlwG',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_3f9369d68c014e9ba9d5d4b3c7e90a354f3d422f2f7a66d0d41a03c9c88c5a10',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:31:14.706Z',
  '2026-10-08T02:31:13.300Z',
  coalesce('2026-10-08T02:31:14.706Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '9148278e-13bd-401c-b005-d9752f6db1fa',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Hashim Bhinderwala',
  '9819201789',
  NULL,
  'BaDs9pnytP3hvkHS1xCG',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T12:00:27.511Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T12:00:27.511Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '91ad77a0-68ae-4c0f-ad0b-06b636142503',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Ajay Bajaj',
  '9223291871',
  NULL,
  'DS7l5ZPKHNxuFscqbHIT',
  NULL,
  NULL,
  '9223291871',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T10:00:09.397Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T10:00:09.397Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '9266ff86-b1de-446e-a27d-fb15618fdd24',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Mohammad Valiullah Shariff',
  '9004956768',
  NULL,
  '90cIjE4Q6QtWAVE5CSJd',
  NULL,
  NULL,
  '9004956768',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:19:59.031Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:19:59.031Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '94d899b5-2f3f-4ca1-9737-433c997166bc',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Tejashree Vinayak Sane',
  '9819055132',
  NULL,
  'PS8iRRZuAEFdaJbN1BKV',
  'Tejashree Vinayak Sane',
  'Tejashree Vinayak Sane',
  '9819055132',
  NULL,
  NULL,
  NULL,
  coalesce(TRUE, FALSE),
  'fp_93bc4ffa926b037c8a8ab069c86574088243de9bef1b80a1df2fc2ed652bc5da',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T04:52:14.914Z',
  '2026-10-08T04:52:08.199Z',
  coalesce('2026-10-08T04:52:14.914Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '97301a13-e985-4d74-8206-8a983efd7bfc',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Sandeep Chavada',
  '8898341341',
  NULL,
  'quDand8LH8giQXs5v5N0',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_7a5ad3e8863916dd9f4cdaedffce8828999db4c505c6460ef3e75e39cdca5e93',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:17:52.502Z',
  '2026-10-08T02:17:31.963Z',
  coalesce('2026-10-08T02:17:52.502Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '9963eb6b-26f7-474a-959d-9d81f95f10e0',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Karim Siddiqui',
  '9769761138',
  NULL,
  '38bMsFmUl9iCtbWxsJla',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_4778dfe7a648ef01c26302febfd68e760eb4d640d8c8c1f27a382e0a05e9aec7',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:53:12.500Z',
  '2026-10-08T01:53:11.642Z',
  coalesce('2026-10-08T01:53:12.500Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  '9e7d8f08-9085-4999-972d-95c06f928d06',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Varun Rajaram',
  '9545712120',
  NULL,
  'Ls2QHZXIyflFFt9wltbM',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_c7e1e00fdb4709325dedb0f67699159da788ea25c00a98a51700a7201485b158',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:14:25.067Z',
  '2026-10-08T02:14:24.154Z',
  coalesce('2026-10-08T02:14:25.067Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'a103bf18-69f0-412b-ae8b-57ec95a05a65',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Manan Vasa',
  '8097010410',
  NULL,
  'LxWJRt2UUrpop4VliTlh',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:58:26.277Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:58:26.277Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'a84a8ffa-786f-42cf-ab82-a15244a313e1',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Prasanna Thakkar',
  '9820071007',
  NULL,
  '9mhsIRiU7APSfut6e3xo',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_c0476186a6ff5b15e35964d54f96ffa93e6032d5a5118f36cb72f139f221c867',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:01:50.968Z',
  '2026-10-08T02:01:50.500Z',
  coalesce('2026-10-08T02:01:50.968Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'a89f2e57-74e2-48ff-af27-652d472af9d1',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Shefali Soman Bapat',
  '9326262804',
  NULL,
  'UpBz5LGUJMIk7ohwb8ZZ',
  NULL,
  NULL,
  '9326262804',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:22:32.433Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:22:32.433Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'ab1eacde-0eaa-4e43-8401-147dfaeb56b1',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Hussain Rassai',
  '9821045110',
  NULL,
  'MfXvO5nB4Py3UXa9LyM4',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_cd8b8a2760836066d744a0f93fa968f67d4483fc4fae8fefceb0f43340557dc1',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:16:01.946Z',
  '2026-10-08T02:15:53.881Z',
  coalesce('2026-10-08T02:16:01.946Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'adfdeb5a-37fd-43d3-9091-7883eb0f3ac7',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Mitesh Vora',
  '9867039491',
  NULL,
  'bXYXbdfx01NMGDNPlNtY',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_81abbacb7d5df0514ee4e68f5bb98e5ab3f5aecf86c40a2ececcd910e85f8960',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:01:24.750Z',
  '2026-10-08T02:01:24.150Z',
  coalesce('2026-10-08T02:01:24.750Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'b0a20b8e-3442-48fa-a4ae-2e1e875d85ed',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Ubed Chowhan',
  '9987028576',
  NULL,
  'DobQyNV4KKdvFoXDYK79',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_7bdc9c3abb46ba482c6ab70b1d7e983920ee3477188bea402e90c5330b4a180b',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:15:30.369Z',
  '2026-10-08T02:15:12.293Z',
  coalesce('2026-10-08T02:15:30.369Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'b12ce98f-af43-45af-830a-ea8ae5dd2eb5',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Preeti Lalwani',
  '9820006774',
  NULL,
  'LkpE5XhAIPcX01Xe0Cge',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:59:40.860Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:59:40.860Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'b493482b-537e-4b0d-b8a1-a545c8b67c5a',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Mohammed Bhinderwala',
  '9820468398',
  NULL,
  '1pz1pTr24UfsQgE5a5mS',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_8d63b15f6a4bc4ee3c181af6054299719d21446c1c146b16cf2e04f8f5368287',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:19:42.558Z',
  '2026-10-08T02:19:23.664Z',
  coalesce('2026-10-08T02:19:42.558Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'b69bb4a9-b7b8-4e11-87c7-c42185ed829e',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Rohit Tawari',
  '7043297313',
  NULL,
  '7HC3LlSmBOUWRZsxWDOi',
  'Rohit Tawari',
  NULL,
  '7043297313',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_2149fd75bdd162ed18d8628ebcebf83d7cb603b335d37e9d68e17f7d21d28c99',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:52:53.149Z',
  '2026-10-08T01:52:52.448Z',
  coalesce('2026-10-08T01:52:53.149Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'b8260ebc-a49f-4075-8dee-3d94b0925304',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Vaibhav R Shah',
  '8879238658',
  NULL,
  'FRVIPK6pU5lLcRGH8lOu',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_d43f3646e3d3f510de50a5cf2e6038dcda65eff3116b99ed3767163ea28c27bc',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:27:00.426Z',
  '2026-10-08T02:26:57.754Z',
  coalesce('2026-10-08T02:27:00.426Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'c1fdfece-0a44-44b7-bcc0-8dae835b4340',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Hari Ayyappan',
  '9820075320',
  NULL,
  'QKj0vU3n1pasWTG6nIQM',
  'Hari Ayyappan',
  'Raj',
  '9820075320',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:51:44.729Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:51:44.729Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'c4c0f8b0-7bb6-49bb-9bac-3cac1e679348',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Mitul Shingadia',
  '9967533315',
  NULL,
  'ksdnwjeMhPkQlWqNhBgs',
  'Mitul Shingadia',
  'Asrar Ansari',
  '9967533315',
  NULL,
  NULL,
  NULL,
  coalesce(TRUE, FALSE),
  'fp_25c0e79a4327db325d07a263fd94615fd0136cdddcf4ca8c04a33f900d84dfca',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T02:12:46.388Z',
  '2026-10-08T02:12:44.435Z',
  coalesce('2026-10-08T02:12:46.388Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'c8574a56-0de8-4ee0-89eb-d79c9514449c',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Jimit Jhaveri',
  '9930566225',
  NULL,
  'mHyV5robnQmOIHIEZoor',
  NULL,
  NULL,
  '9930566225',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:25:14.891Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:25:14.891Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'c8c86a3a-a83f-4f34-89ce-e5342d7eeba6',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Kavan Modi',
  '7977754515',
  NULL,
  'Gdp0zJ0h7bVTqu4RNnFK',
  NULL,
  NULL,
  '7977754515',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:25:42.731Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:25:42.731Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'c9c1ba9b-1c21-4f69-9269-b75f0b9209da',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Aakriti Sunder',
  '9326274360',
  NULL,
  'Q5hpJYOEybtkyopobLCo',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T10:00:01.384Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T10:00:01.384Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'cbd71896-e1c7-42ce-915e-45b1926db41a',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Kailas Jadhav',
  '9867876600',
  NULL,
  'AqLY9voWQ6kVkeq0uAsH',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_b73da59298da90cdc6626c994a0a9a0c81c6088b76713eaa54c279865e27775f',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T03:32:57.667Z',
  '2026-10-08T03:32:57.426Z',
  coalesce('2026-10-08T03:32:57.667Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'cd6bd05f-1530-4d7d-99dc-b3aa78c09755',
  'absent'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Mihir Bala',
  '8849853291',
  NULL,
  'yiAO69rUrytFKXUZuVxc',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:59:24.614Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:59:24.614Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'cdf83bf0-2dc8-46db-a9b7-478d6e5cca76',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Sandeep Bisla',
  '9899971660',
  NULL,
  'JPE7PtJnkJ5zxdiAUZCa',
  NULL,
  NULL,
  '9899971660',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:50:35.129Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:50:35.129Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'd11bee24-ead8-49bd-a912-e224c0edfab7',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Rushabh Gandhi',
  '9839834944',
  NULL,
  'rE6ztLfjyrvXqwEsOiDL',
  NULL,
  NULL,
  '9839834944',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:43:06.480Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:43:06.480Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'd4b3ccd9-f4d0-4dd3-97ab-06adc2245e11',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Yash Haria',
  '9930043683',
  NULL,
  'Lu46vgfmc8o5kqzyxIGg',
  NULL,
  NULL,
  '9930043683',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:16:15.232Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:16:15.232Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'd4f7d313-7389-4ac0-9d2f-4030ff18ff0d',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Sachin Gada',
  '9833083169',
  NULL,
  'KiFhmXqmFAJu4r4FgXWp',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_e65728505eae9d631dacea3f9b2915a7d8b3e336d3038a5715f18167c1d20bf1',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:15:59.489Z',
  '2026-10-08T02:15:57.240Z',
  coalesce('2026-10-08T02:15:59.489Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'd5f14f74-4b9e-4efb-8e1c-84ddcc5462fe',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Prabhakar Nakashe',
  '9820448799',
  NULL,
  'IWMVr2NgFYo38xBOFvkN',
  'Prabhakar Nakashe',
  'Yogesh kanade',
  '9820448799',
  NULL,
  NULL,
  NULL,
  coalesce(TRUE, FALSE),
  'fp_0fe7ef491678717f36c7dca6f291cd0a6695096defc9d548f46ca92ff3ef6176',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T02:20:33.764Z',
  '2026-10-08T02:20:32.969Z',
  coalesce('2026-10-08T02:20:33.764Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'd64d23f4-ac55-458b-a2d4-9c88a141dd2c',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Sabina Gupta',
  '9821739597',
  NULL,
  '6oPcL73xegjQFC57QYBD',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_b4ba1b5c6de411fd659b0252246e74148f377151a7f812c7999c04297ff3f2fe',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:01:33.997Z',
  '2026-10-08T02:01:33.407Z',
  coalesce('2026-10-08T02:01:33.997Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'd74b66b4-7ae3-4371-b397-b5ad0c3dcb4c',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Siraj Kherodawala',
  '9004716222',
  NULL,
  '8KGbuKitInhCySeS7571',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_b3c2854e9d9c589d26212b0e5b6061b0d8b7ea703cdb8f74e536a84eb41f9c56',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:03:16.113Z',
  '2026-10-08T02:03:15.499Z',
  coalesce('2026-10-08T02:03:16.113Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'd7dac14b-45ee-4087-825d-9d7ebe0564fe',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Harvinder Singh Wasan',
  '9322600486',
  NULL,
  'sQHsXe5C45MEhDHacG2u',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_b4e4250919a69e06fcf253d47d07b8b44006f1d7e835da0878ce83cd821b759c',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:04:07.100Z',
  '2026-10-08T02:04:06.461Z',
  coalesce('2026-10-08T02:04:07.100Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'dc532656-bc2a-4d74-8777-cd1045f8dd2d',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Manan Sanghai',
  '8080250800',
  NULL,
  'VnhCS4Yw909ZAfJPj9Yf',
  NULL,
  NULL,
  '8080250800',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:08:41.822Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:08:41.822Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'ddcd91a0-fe60-45de-affc-d8da04b32a5a',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Mayank Mehta',
  '8369180984',
  NULL,
  'XSvSmdSucf2Iww8AGYd3',
  'Mayank Mehta',
  'Dharmendra Gautam',
  '8369180984',
  NULL,
  NULL,
  NULL,
  coalesce(TRUE, FALSE),
  'fp_b15163b7f203a2b2aebd2237a3946b1c66a6228b1d8da80f4c29d05b26201715',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T01:54:10.798Z',
  '2026-10-08T01:54:09.729Z',
  coalesce('2026-10-08T01:54:10.798Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'e1caa451-14b9-4301-8123-9844b2923228',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Rahul Mehta',
  '9820247668',
  NULL,
  '3uH5TwgMs56MDD9bf2zP',
  NULL,
  NULL,
  '9820247668',
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-12T11:16:01.209Z',
  '2026-10-07T18:30:00.000Z',
  coalesce('2026-10-12T11:16:01.209Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'e2c78778-bf78-4656-85f7-f90828b3c429',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Priyank Deshmukh',
  '9833855671',
  NULL,
  '6Xllh1pAIXO0Ujjxeg8x',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_39ddfb3244ba6bb8197c21dd66f443193dde61d705acff3f6994c151252d10bc',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T03:30:39.418Z',
  '2026-10-08T03:30:35.750Z',
  coalesce('2026-10-08T03:30:39.418Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'e4b3e308-6309-44a7-884c-63e593622727',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Rahul Shroff',
  '9137174281',
  NULL,
  'sobf9E6koFqVxhbeuy3C',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_1a63cb6b7f37830f8373ca30bad6f0138ad3b7766df54217d1daae2588a94d9f',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:56:42.447Z',
  '2026-10-08T01:56:41.840Z',
  coalesce('2026-10-08T01:56:42.447Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'ed83f958-588d-444c-be5c-26d62623cf87',
  'substitute'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Bharat Kankariya',
  '9321510005',
  NULL,
  'syGVK5cPhtfPtbVUNtbY',
  'Bharat Kankariya',
  'Mohammad Jaffer Quadri',
  '9321510005',
  NULL,
  NULL,
  NULL,
  coalesce(TRUE, FALSE),
  'fp_dc0aa486eaabe6fc3b2c7f3308a7f4bbbe1b8768944b9a7cf121a30c1ee1831b',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  NULL,
  DATE '2026-10-08',
  '2026-10-08T02:23:32.023Z',
  '2026-10-08T02:23:28.070Z',
  coalesce('2026-10-08T02:23:32.023Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'f5715f4a-d022-4382-9647-95744b5cbe19',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Gaurav Thakker',
  '9769655090',
  NULL,
  'ofhv6bMhOkXbj57xdBrx',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_b6a1a59e9b37fd00168b18a18c79a00dd6bcbd37420b098d4e1bbbd0b73faa6e',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:03:07.854Z',
  '2026-10-08T02:03:07.205Z',
  coalesce('2026-10-08T02:03:07.854Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'f78f1cee-b270-4720-bdb2-65757bfd9a3d',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Chirag Merchant',
  '9004043167',
  NULL,
  'o3n5JBBx7AX6VYkZlph7',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_151019d6000d5ac85dcff9189d75ccbc0f6490db807983fc4434b1f8ee800916',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T01:39:09.314Z',
  '2026-10-08T01:39:08.926Z',
  coalesce('2026-10-08T01:39:09.314Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'fde8e92b-eb3a-4a63-9e36-fab6f92431a9',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Mayank Gosar',
  '9870590475',
  NULL,
  'FidOmKXyDsF9FWUaRZgw',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_917dee1777cb2e1a004909b121f46b6d1c1b7a17dfa3873603aaeba885bcaaf6',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:51:29.458Z',
  '2026-10-08T02:51:25.324Z',
  coalesce('2026-10-08T02:51:29.458Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());
insert into public.check_ins (
  id, type, location_id, location_name, user_name, user_phone, user_email,
  member_id, substitute_for_member, substitute_name, substitute_phone,
  company_name, category, invited_by_member, has_photo, device_id,
  is_verified, is_flagged, flag_reason, face_verified, verification_method,
  session_date, attended_at, "timestamp", created_at
) values (
  'fe386962-80da-4875-9830-e93653cbeace',
  'member'::public.check_in_type,
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Bhavin Shah',
  '9870089414',
  NULL,
  'ZzKmlW7fuyT93dJxPFkM',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  coalesce(FALSE, FALSE),
  'fp_8ac1270b5edb56cc6c98aa69fcaaceb51a4253223885426389d01520b1f95cf4',
  coalesce(TRUE, FALSE),
  coalesce(FALSE, FALSE),
  NULL,
  coalesce(FALSE, FALSE),
  'manual',
  DATE '2026-10-08',
  '2026-10-08T02:28:59.978Z',
  '2026-10-08T02:28:58.144Z',
  coalesce('2026-10-08T02:28:59.978Z', timezone('utc', now()))
)
on conflict (id) do update set
  type = excluded.type,
  location_name = excluded.location_name,
  user_name = excluded.user_name,
  user_phone = excluded.user_phone,
  member_id = excluded.member_id,
  substitute_for_member = excluded.substitute_for_member,
  substitute_name = excluded.substitute_name,
  substitute_phone = excluded.substitute_phone,
  is_verified = excluded.is_verified,
  is_flagged = excluded.is_flagged,
  session_date = excluded.session_date,
  attended_at = excluded.attended_at,
  updated_at = timezone('utc', now());

-- session_attendance (4)
insert into public.session_attendance (id, session_date, checked_in_member_ids, updated_at)
values (
  '2026-10-01',
  coalesce(DATE '2026-10-01', DATE '2026-10-01'),
  '{"hZyEGH7VIgCWEE0zUOYG","5bLTXQUAHK5Atxib2Imj"}',
  coalesce('2026-10-09T07:54:36.486Z', timezone('utc', now()))
)
on conflict (id) do update set
  session_date = excluded.session_date,
  checked_in_member_ids = excluded.checked_in_member_ids,
  updated_at = timezone('utc', now());
insert into public.session_attendance (id, session_date, checked_in_member_ids, updated_at)
values (
  '2026-10-08',
  coalesce(DATE '2026-10-08', DATE '2026-10-08'),
  '{"ulifv2z1uZXMYuyHHPEU","o3n5JBBx7AX6VYkZlph7","53vEkKwMI0qOaoNa7iMx","lGL99wmRNCppOlkmR6Oj","7HC3LlSmBOUWRZsxWDOi","38bMsFmUl9iCtbWxsJla","H13YFlNoona9pWgK8L1c","rQSD7oEgee2FwO6xFfa4","XSvSmdSucf2Iww8AGYd3","PeNnZQ5PuFqYU1bTb08x","3TSGL7Nv9B5G522sgi6F","sobf9E6koFqVxhbeuy3C","EFm6fdLH4mKbKmncFMtl","aQ5Ihm2OqxQqKz1aPXPO","Qu21MsYqvySMG3UotzkI","bXYXbdfx01NMGDNPlNtY","6oPcL73xegjQFC57QYBD","9mhsIRiU7APSfut6e3xo","ofhv6bMhOkXbj57xdBrx","8KGbuKitInhCySeS7571","sQHsXe5C45MEhDHacG2u","nQJG57Kl9taZlMkLgC0N","tLsFF41wmi6MepYkF7iB","7WXDMQUKWFtSSoZmlMAC","MuVuPRDgb7Ru2ETswaJa","ksdnwjeMhPkQlWqNhBgs","IX7StO77cKIhI8HkpTL0","J0IvzhqFCInXaznHdjfg","Ls2QHZXIyflFFt9wltbM","DobQyNV4KKdvFoXDYK79","KiFhmXqmFAJu4r4FgXWp","rN1W2Y167i0oBlNUgfpR","MfXvO5nB4Py3UXa9LyM4","Mt6FLuWeYlXpKBlljyLS","KhOdndsiVvz292c5tJYk","quDand8LH8giQXs5v5N0","wyyytYwiUB1B3Wz7rN9u","Vevx5J2UBqJ5Hj2qB4Qd","1pz1pTr24UfsQgE5a5mS","IWMVr2NgFYo38xBOFvkN","dpAD4wg9CQ0GtmXQ8QHW","xQcHTY5UKO8poTfMM1UZ","uOPFKQQ1VZK2ytszgbrH","jfDDqQnt5mY1S1w7uqhE","syGVK5cPhtfPtbVUNtbY","nisHwof0WmvAePs7LclP","FRVIPK6pU5lLcRGH8lOu","ZzKmlW7fuyT93dJxPFkM","kYpS7tpiGt3XosvTb6mE","ZDCa5FPDEIgahIXgtlrJ","uqSFTxaeaNIQH3R8NlwG","TGsSahqSrbKg5isJ5adG","FidOmKXyDsF9FWUaRZgw","xMDXjTaD1XhWD5cN3FZN","xmxCzhsAOU1TAagU4yQn","6Xllh1pAIXO0Ujjxeg8x","AqLY9voWQ6kVkeq0uAsH","RT4LY0FAcSP3VqvyFYxA","PS8iRRZuAEFdaJbN1BKV","hZyEGH7VIgCWEE0zUOYG"}',
  coalesce('2026-10-08T05:23:42.554Z', timezone('utc', now()))
)
on conflict (id) do update set
  session_date = excluded.session_date,
  checked_in_member_ids = excluded.checked_in_member_ids,
  updated_at = timezone('utc', now());
insert into public.session_attendance (id, session_date, checked_in_member_ids, updated_at)
values (
  '2026-10-15',
  coalesce(DATE '2026-10-15', DATE '2026-10-15'),
  '{"hZyEGH7VIgCWEE0zUOYG","5bLTXQUAHK5Atxib2Imj"}',
  coalesce('2026-10-09T05:58:34.030Z', timezone('utc', now()))
)
on conflict (id) do update set
  session_date = excluded.session_date,
  checked_in_member_ids = excluded.checked_in_member_ids,
  updated_at = timezone('utc', now());
insert into public.session_attendance (id, session_date, checked_in_member_ids, updated_at)
values (
  '2026-10-22',
  coalesce(DATE '2026-10-22', DATE '2026-10-22'),
  '{"hZyEGH7VIgCWEE0zUOYG","5bLTXQUAHK5Atxib2Imj"}',
  coalesce('2026-10-09T07:31:41.095Z', timezone('utc', now()))
)
on conflict (id) do update set
  session_date = excluded.session_date,
  checked_in_member_ids = excluded.checked_in_member_ids,
  updated_at = timezone('utc', now());

-- device_session_locks (60)
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_0f4367bbc8054033ba09600a658776e4926f2518110c0e1dd723f10107105f6e_2026-10-08',
  'fp_0f4367bbc8054033ba09600a658776e4926f2518110c0e1dd723f10107105f6e',
  DATE '2026-10-08',
  '14e1f788-5f82-4b82-b54d-89652b5804aa',
  coalesce('2026-10-08T02:16:25.749Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_0fe7ef491678717f36c7dca6f291cd0a6695096defc9d548f46ca92ff3ef6176_2026-10-08',
  'fp_0fe7ef491678717f36c7dca6f291cd0a6695096defc9d548f46ca92ff3ef6176',
  DATE '2026-10-08',
  'd5f14f74-4b9e-4efb-8e1c-84ddcc5462fe',
  coalesce('2026-10-08T02:20:33.764Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_151019d6000d5ac85dcff9189d75ccbc0f6490db807983fc4434b1f8ee800916_2026-10-08',
  'fp_151019d6000d5ac85dcff9189d75ccbc0f6490db807983fc4434b1f8ee800916',
  DATE '2026-10-08',
  'f78f1cee-b270-4720-bdb2-65757bfd9a3d',
  coalesce('2026-10-08T01:39:09.314Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_17e0299c62fa4ae62d0d558eb053814bc16e073cb62c1abbed95b983609f3d77_2026-10-08',
  'fp_17e0299c62fa4ae62d0d558eb053814bc16e073cb62c1abbed95b983609f3d77',
  DATE '2026-10-08',
  '13d28a81-0d04-42f2-a8e8-a43f5db94753',
  coalesce('2026-10-08T02:19:11.369Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_1a63cb6b7f37830f8373ca30bad6f0138ad3b7766df54217d1daae2588a94d9f_2026-10-08',
  'fp_1a63cb6b7f37830f8373ca30bad6f0138ad3b7766df54217d1daae2588a94d9f',
  DATE '2026-10-08',
  'e4b3e308-6309-44a7-884c-63e593622727',
  coalesce('2026-10-08T01:56:42.447Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_1bea0739041debb3cecb0c7edc12fc92ec86255fe489d0973a24139b81deeebf_2026-10-08',
  'fp_1bea0739041debb3cecb0c7edc12fc92ec86255fe489d0973a24139b81deeebf',
  DATE '2026-10-08',
  '35663d20-c82a-4dc1-b1e4-2cca0d613a72',
  coalesce('2026-10-08T02:22:32.367Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_2149fd75bdd162ed18d8628ebcebf83d7cb603b335d37e9d68e17f7d21d28c99_2026-10-08',
  'fp_2149fd75bdd162ed18d8628ebcebf83d7cb603b335d37e9d68e17f7d21d28c99',
  DATE '2026-10-08',
  'b69bb4a9-b7b8-4e11-87c7-c42185ed829e',
  coalesce('2026-10-08T01:52:53.149Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_25c0e79a4327db325d07a263fd94615fd0136cdddcf4ca8c04a33f900d84dfca_2026-10-08',
  'fp_25c0e79a4327db325d07a263fd94615fd0136cdddcf4ca8c04a33f900d84dfca',
  DATE '2026-10-08',
  'c4c0f8b0-7bb6-49bb-9bac-3cac1e679348',
  coalesce('2026-10-08T02:12:46.388Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_2fe52d132a6bc08978585e01e3b63e519439074c60b8f9037dbdf6d588140abc_2026-10-08',
  'fp_2fe52d132a6bc08978585e01e3b63e519439074c60b8f9037dbdf6d588140abc',
  DATE '2026-10-08',
  '34a63c3d-66de-4a57-8afd-465b151e8d39',
  coalesce('2026-10-08T02:04:21.771Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_379170628a4e0c1eff55d37c32ec362938841d47a0e41fa8c1818a0b97cb7365_2026-10-08',
  'fp_379170628a4e0c1eff55d37c32ec362938841d47a0e41fa8c1818a0b97cb7365',
  DATE '2026-10-08',
  '73eb4644-d162-43d6-ae5d-b00af1ad3ff9',
  coalesce('2026-10-08T01:58:43.751Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_386cf90ff468fbb0f2ef83fd2412a5ce24abc5fe377088a1e1b8da8d5eebc7dd_2026-10-08',
  'fp_386cf90ff468fbb0f2ef83fd2412a5ce24abc5fe377088a1e1b8da8d5eebc7dd',
  DATE '2026-10-08',
  '1f55fb99-01a4-4076-9eda-dabd49a131f7',
  coalesce('2026-10-08T01:48:37.150Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_39ddfb3244ba6bb8197c21dd66f443193dde61d705acff3f6994c151252d10bc_2026-10-08',
  'fp_39ddfb3244ba6bb8197c21dd66f443193dde61d705acff3f6994c151252d10bc',
  DATE '2026-10-08',
  'e2c78778-bf78-4656-85f7-f90828b3c429',
  coalesce('2026-10-08T03:30:39.418Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_3f9369d68c014e9ba9d5d4b3c7e90a354f3d422f2f7a66d0d41a03c9c88c5a10_2026-10-08',
  'fp_3f9369d68c014e9ba9d5d4b3c7e90a354f3d422f2f7a66d0d41a03c9c88c5a10',
  DATE '2026-10-08',
  '90cc12f2-d4d6-441f-8c2b-58ac22685f09',
  coalesce('2026-10-08T02:31:14.706Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_4778dfe7a648ef01c26302febfd68e760eb4d640d8c8c1f27a382e0a05e9aec7_2026-10-08',
  'fp_4778dfe7a648ef01c26302febfd68e760eb4d640d8c8c1f27a382e0a05e9aec7',
  DATE '2026-10-08',
  '9963eb6b-26f7-474a-959d-9d81f95f10e0',
  coalesce('2026-10-08T01:53:12.500Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_52b29030df45777315ad6b7e3f9cd256136279a69918ab321b19404afddbd855_2026-10-08',
  'fp_52b29030df45777315ad6b7e3f9cd256136279a69918ab321b19404afddbd855',
  DATE '2026-10-08',
  '20403735-e1e0-42e0-9b91-f18efc5bda8a',
  coalesce('2026-10-08T02:18:09.801Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_55ae1c9bad27fc5144f3221e54c3142f2b41eba98c7422fcfe9449b13db0d41e_2026-10-08',
  'fp_55ae1c9bad27fc5144f3221e54c3142f2b41eba98c7422fcfe9449b13db0d41e',
  DATE '2026-10-08',
  '56b8ad33-e6fd-4ebc-ac5f-b31f6840262b',
  coalesce('2026-10-08T01:57:40.967Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_5837a685823fd74fd5b9d4d2e7c1e01ee6f7b51cac86e1f3f08f90d4a295898b_2026-10-08',
  'fp_5837a685823fd74fd5b9d4d2e7c1e01ee6f7b51cac86e1f3f08f90d4a295898b',
  DATE '2026-10-08',
  '62b77f84-454f-4ebe-a51e-870399b85ffd',
  coalesce('2026-10-08T01:40:18.668Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_58e7ce5b87c0bb1ccf7ee61c6460c453f8e5b30ee7a8dfae65ded03667b65e0a_2026-10-08',
  'fp_58e7ce5b87c0bb1ccf7ee61c6460c453f8e5b30ee7a8dfae65ded03667b65e0a',
  DATE '2026-10-08',
  '28fc881a-103d-4ec2-9a4b-21bbdb0e83d7',
  coalesce('2026-10-08T03:29:56.095Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_79271af8713354624326ebb316cc783765c8f798087bd68e7510f6031a7c4ac8_2026-10-08',
  'fp_79271af8713354624326ebb316cc783765c8f798087bd68e7510f6031a7c4ac8',
  DATE '2026-10-08',
  '1fdb2844-c270-4405-96b3-c0c2e6acb485',
  coalesce('2026-10-08T01:53:18.888Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_7a5ad3e8863916dd9f4cdaedffce8828999db4c505c6460ef3e75e39cdca5e93_2026-10-08',
  'fp_7a5ad3e8863916dd9f4cdaedffce8828999db4c505c6460ef3e75e39cdca5e93',
  DATE '2026-10-08',
  '97301a13-e985-4d74-8206-8a983efd7bfc',
  coalesce('2026-10-08T02:17:52.502Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_7bdc9c3abb46ba482c6ab70b1d7e983920ee3477188bea402e90c5330b4a180b_2026-10-08',
  'fp_7bdc9c3abb46ba482c6ab70b1d7e983920ee3477188bea402e90c5330b4a180b',
  DATE '2026-10-08',
  'b0a20b8e-3442-48fa-a4ae-2e1e875d85ed',
  coalesce('2026-10-08T02:15:30.369Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_7f5db2c77e5866b13620455e14ffe1e52f3469e3a9d276645c5a5314cae13906_2026-10-08',
  'fp_7f5db2c77e5866b13620455e14ffe1e52f3469e3a9d276645c5a5314cae13906',
  DATE '2026-10-08',
  '68386ce6-9828-45a7-8782-c2b3b9edd3ac',
  coalesce('2026-10-08T02:10:31.862Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_81abbacb7d5df0514ee4e68f5bb98e5ab3f5aecf86c40a2ececcd910e85f8960_2026-10-08',
  'fp_81abbacb7d5df0514ee4e68f5bb98e5ab3f5aecf86c40a2ececcd910e85f8960',
  DATE '2026-10-08',
  'adfdeb5a-37fd-43d3-9091-7883eb0f3ac7',
  coalesce('2026-10-08T02:01:24.750Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_86edd104d1979ae1b9414ea175b6d1554d2e0f3708fd483d2bf644395d8a8f8d_2026-10-08',
  'fp_86edd104d1979ae1b9414ea175b6d1554d2e0f3708fd483d2bf644395d8a8f8d',
  DATE '2026-10-08',
  '6e1ea425-08a8-4603-9abc-74f6499cc682',
  coalesce('2026-10-08T02:21:01.226Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_8ac1270b5edb56cc6c98aa69fcaaceb51a4253223885426389d01520b1f95cf4_2026-10-08',
  'fp_8ac1270b5edb56cc6c98aa69fcaaceb51a4253223885426389d01520b1f95cf4',
  DATE '2026-10-08',
  'fe386962-80da-4875-9830-e93653cbeace',
  coalesce('2026-10-08T02:28:59.978Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_8b101fcee4e04b41984b4c2155400b7f21caf6ba60dd97c272547675e694fcf4_2026-10-08',
  'fp_8b101fcee4e04b41984b4c2155400b7f21caf6ba60dd97c272547675e694fcf4',
  DATE '2026-10-08',
  '76e1e9df-2dc5-4bf0-b1b9-3533605745d4',
  coalesce('2026-10-08T01:54:35.696Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_8d63b15f6a4bc4ee3c181af6054299719d21446c1c146b16cf2e04f8f5368287_2026-10-08',
  'fp_8d63b15f6a4bc4ee3c181af6054299719d21446c1c146b16cf2e04f8f5368287',
  DATE '2026-10-08',
  'b493482b-537e-4b0d-b8a1-a545c8b67c5a',
  coalesce('2026-10-08T02:19:42.558Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_8eb57f19d723d47ee5911191364f4e473eb11bef424e41c26a0fa144cf832cb9_2026-10-08',
  'fp_8eb57f19d723d47ee5911191364f4e473eb11bef424e41c26a0fa144cf832cb9',
  DATE '2026-10-08',
  '2321adcb-93df-486d-95ff-31de45695073',
  coalesce('2026-10-08T02:05:19.264Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_917dee1777cb2e1a004909b121f46b6d1c1b7a17dfa3873603aaeba885bcaaf6_2026-10-08',
  'fp_917dee1777cb2e1a004909b121f46b6d1c1b7a17dfa3873603aaeba885bcaaf6',
  DATE '2026-10-08',
  'fde8e92b-eb3a-4a63-9e36-fab6f92431a9',
  coalesce('2026-10-08T02:51:29.458Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_93bc4ffa926b037c8a8ab069c86574088243de9bef1b80a1df2fc2ed652bc5da_2026-10-08',
  'fp_93bc4ffa926b037c8a8ab069c86574088243de9bef1b80a1df2fc2ed652bc5da',
  DATE '2026-10-08',
  '94d899b5-2f3f-4ca1-9737-433c997166bc',
  coalesce('2026-10-08T04:52:14.914Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_940bf9a799137ea3100f9abae93144022a4e8a267be7a11df7d21e9c7f30aecc_2026-10-08',
  'fp_940bf9a799137ea3100f9abae93144022a4e8a267be7a11df7d21e9c7f30aecc',
  DATE '2026-10-08',
  '6e9c978d-9f59-4589-98d1-b489b24d3bbc',
  coalesce('2026-10-08T02:08:02.229Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_9cbc86e6171cc3e3be658c71f4ef211c9bcf9a7c8bfea5e22aca9062473453c8_2026-10-08',
  'fp_9cbc86e6171cc3e3be658c71f4ef211c9bcf9a7c8bfea5e22aca9062473453c8',
  DATE '2026-10-08',
  '0d0f581e-b0f2-460e-b3d3-ca10733cee0d',
  coalesce('2026-10-08T02:57:11.319Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_9eb9ca72c6315b29e4c793ef1d0a6fbea1c37a267f2a810a48a8aefe49f084cc_2026-10-08',
  'fp_9eb9ca72c6315b29e4c793ef1d0a6fbea1c37a267f2a810a48a8aefe49f084cc',
  DATE '2026-10-08',
  '2dab945b-3958-4950-a45d-fd1dc8f48381',
  coalesce('2026-10-08T02:17:05.793Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_a45b5b7d4452176cfb425f10b57640c6ef3dd5c3b2f9544c9b16cf4f80b468f6_2026-10-08',
  'fp_a45b5b7d4452176cfb425f10b57640c6ef3dd5c3b2f9544c9b16cf4f80b468f6',
  DATE '2026-10-08',
  '0540dedf-a713-49ea-a102-27350a181d3a',
  coalesce('2026-10-08T02:26:06.113Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_b15163b7f203a2b2aebd2237a3946b1c66a6228b1d8da80f4c29d05b26201715_2026-10-08',
  'fp_b15163b7f203a2b2aebd2237a3946b1c66a6228b1d8da80f4c29d05b26201715',
  DATE '2026-10-08',
  'ddcd91a0-fe60-45de-affc-d8da04b32a5a',
  coalesce('2026-10-08T01:54:10.798Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_b3c2854e9d9c589d26212b0e5b6061b0d8b7ea703cdb8f74e536a84eb41f9c56_2026-10-08',
  'fp_b3c2854e9d9c589d26212b0e5b6061b0d8b7ea703cdb8f74e536a84eb41f9c56',
  DATE '2026-10-08',
  'd74b66b4-7ae3-4371-b397-b5ad0c3dcb4c',
  coalesce('2026-10-08T02:03:16.113Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_b4ba1b5c6de411fd659b0252246e74148f377151a7f812c7999c04297ff3f2fe_2026-10-08',
  'fp_b4ba1b5c6de411fd659b0252246e74148f377151a7f812c7999c04297ff3f2fe',
  DATE '2026-10-08',
  'd64d23f4-ac55-458b-a2d4-9c88a141dd2c',
  coalesce('2026-10-08T02:01:33.997Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_b4e4250919a69e06fcf253d47d07b8b44006f1d7e835da0878ce83cd821b759c_2026-10-08',
  'fp_b4e4250919a69e06fcf253d47d07b8b44006f1d7e835da0878ce83cd821b759c',
  DATE '2026-10-08',
  'd7dac14b-45ee-4087-825d-9d7ebe0564fe',
  coalesce('2026-10-08T02:04:07.100Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_b6a1a59e9b37fd00168b18a18c79a00dd6bcbd37420b098d4e1bbbd0b73faa6e_2026-10-08',
  'fp_b6a1a59e9b37fd00168b18a18c79a00dd6bcbd37420b098d4e1bbbd0b73faa6e',
  DATE '2026-10-08',
  'f5715f4a-d022-4382-9647-95744b5cbe19',
  coalesce('2026-10-08T02:03:07.854Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_b73da59298da90cdc6626c994a0a9a0c81c6088b76713eaa54c279865e27775f_2026-10-08',
  'fp_b73da59298da90cdc6626c994a0a9a0c81c6088b76713eaa54c279865e27775f',
  DATE '2026-10-08',
  'cbd71896-e1c7-42ce-915e-45b1926db41a',
  coalesce('2026-10-08T03:32:57.667Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_b9e7c7d91442131c02001147644848a2a576b033acab0bd1c1713b6890b77172_2026-10-08',
  'fp_b9e7c7d91442131c02001147644848a2a576b033acab0bd1c1713b6890b77172',
  DATE '2026-10-08',
  '7b977162-2071-4b21-8abd-a5591e25f71b',
  coalesce('2026-10-08T02:35:00.744Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_bc6c8ff4499b361066cdda568714f462cb25611bb0ed1e8a9341bf6744692246_2026-10-08',
  'fp_bc6c8ff4499b361066cdda568714f462cb25611bb0ed1e8a9341bf6744692246',
  DATE '2026-10-08',
  '49657ac7-86b3-4e9a-9a0e-78744688048b',
  coalesce('2026-10-08T01:56:42.034Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_bfc2766c4bd4952f3ff7da00a0d7747ca5c3e0413c010135c01c2872bb7f0ce4_2026-10-08',
  'fp_bfc2766c4bd4952f3ff7da00a0d7747ca5c3e0413c010135c01c2872bb7f0ce4',
  DATE '2026-10-08',
  '69da4446-ae4b-4b36-9b66-1f98ecef28e5',
  coalesce('2026-10-08T01:53:50.558Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_c0476186a6ff5b15e35964d54f96ffa93e6032d5a5118f36cb72f139f221c867_2026-10-08',
  'fp_c0476186a6ff5b15e35964d54f96ffa93e6032d5a5118f36cb72f139f221c867',
  DATE '2026-10-08',
  'a84a8ffa-786f-42cf-ab82-a15244a313e1',
  coalesce('2026-10-08T02:01:50.968Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_c4951dc0c7a3f5ade18db75b7a6b964cc116dcf70c45df526eec08d8f92ad9ee_2026-10-08',
  'fp_c4951dc0c7a3f5ade18db75b7a6b964cc116dcf70c45df526eec08d8f92ad9ee',
  DATE '2026-10-08',
  '1a6cfd12-8de5-4ef1-a735-514424b3a6d5',
  coalesce('2026-10-08T02:21:14.413Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_c68f75629ef08bdd6cb1f2103da2d2ac96501b1e48a7c17c608ef6e2a950fa8b_2026-10-08',
  'fp_c68f75629ef08bdd6cb1f2103da2d2ac96501b1e48a7c17c608ef6e2a950fa8b',
  DATE '2026-10-08',
  '2db75312-ea5f-4093-9db2-e2bf6ac9f902',
  coalesce('2026-10-08T01:59:08.862Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_c7e1e00fdb4709325dedb0f67699159da788ea25c00a98a51700a7201485b158_2026-10-08',
  'fp_c7e1e00fdb4709325dedb0f67699159da788ea25c00a98a51700a7201485b158',
  DATE '2026-10-08',
  '9e7d8f08-9085-4999-972d-95c06f928d06',
  coalesce('2026-10-08T02:14:25.067Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_c9d3b3fad2eb579647635d69dc557cb33b7b61c141ba7f591ac14d51ed9c8577_2026-10-08',
  'fp_c9d3b3fad2eb579647635d69dc557cb33b7b61c141ba7f591ac14d51ed9c8577',
  DATE '2026-10-08',
  '8dbd35f6-0564-4500-825b-412fe4d8b19e',
  coalesce('2026-10-08T01:35:04.473Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_cd8b8a2760836066d744a0f93fa968f67d4483fc4fae8fefceb0f43340557dc1_2026-10-08',
  'fp_cd8b8a2760836066d744a0f93fa968f67d4483fc4fae8fefceb0f43340557dc1',
  DATE '2026-10-08',
  'ab1eacde-0eaa-4e43-8401-147dfaeb56b1',
  coalesce('2026-10-08T02:16:01.946Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_ce6f5760b9027d422fed6afd7e063e21b04567ce7d665ac2bdadbb9619aaad39_2026-10-08',
  'fp_ce6f5760b9027d422fed6afd7e063e21b04567ce7d665ac2bdadbb9619aaad39',
  DATE '2026-10-08',
  '3a39954f-d6e0-4bf2-a39e-4ae19bf2f26e',
  coalesce('2026-10-08T02:13:46.648Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_d43f3646e3d3f510de50a5cf2e6038dcda65eff3116b99ed3767163ea28c27bc_2026-10-08',
  'fp_d43f3646e3d3f510de50a5cf2e6038dcda65eff3116b99ed3767163ea28c27bc',
  DATE '2026-10-08',
  'b8260ebc-a49f-4075-8dee-3d94b0925304',
  coalesce('2026-10-08T02:27:00.426Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_d4911911826851175117b92ad72fd720ba73ca145cb4e63f9656f35a1c75c1c1_2026-10-08',
  'fp_d4911911826851175117b92ad72fd720ba73ca145cb4e63f9656f35a1c75c1c1',
  DATE '2026-10-08',
  '6374cbc6-b56d-49c3-a659-6d16a7d5a3c8',
  coalesce('2026-10-08T02:13:00.712Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_d66e2a1e93e0e56cc4ec36ca92e527e2281f247e20371beac2025a2a188637fd_2026-10-08',
  'fp_d66e2a1e93e0e56cc4ec36ca92e527e2281f247e20371beac2025a2a188637fd',
  DATE '2026-10-08',
  '4abfb973-8075-4643-a2c7-fe6d0959e643',
  coalesce('2026-10-08T02:22:08.368Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_d7c430497062eb4caa5aac4a9826193b78c2669c1f80b504ef0a6229cc1c78df_2026-10-08',
  'fp_d7c430497062eb4caa5aac4a9826193b78c2669c1f80b504ef0a6229cc1c78df',
  DATE '2026-10-08',
  '631c7b1d-0231-4d2c-97a6-d9a24fddedb3',
  coalesce('2026-10-08T03:39:01.591Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_da06ffec2e49201b9347e581c5377eabb8de14182af2fbcbea5fc8756655ef8b_2026-10-08',
  'fp_da06ffec2e49201b9347e581c5377eabb8de14182af2fbcbea5fc8756655ef8b',
  DATE '2026-10-08',
  '80ef3e3b-6b9a-4e58-b034-d3dd84adc64b',
  coalesce('2026-10-08T02:29:28.904Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_dc0aa486eaabe6fc3b2c7f3308a7f4bbbe1b8768944b9a7cf121a30c1ee1831b_2026-10-08',
  'fp_dc0aa486eaabe6fc3b2c7f3308a7f4bbbe1b8768944b9a7cf121a30c1ee1831b',
  DATE '2026-10-08',
  'ed83f958-588d-444c-be5c-26d62623cf87',
  coalesce('2026-10-08T02:23:32.023Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_e65728505eae9d631dacea3f9b2915a7d8b3e336d3038a5715f18167c1d20bf1_2026-10-08',
  'fp_e65728505eae9d631dacea3f9b2915a7d8b3e336d3038a5715f18167c1d20bf1',
  DATE '2026-10-08',
  'd4f7d313-7389-4ac0-9d2f-4030ff18ff0d',
  coalesce('2026-10-08T02:15:59.489Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_ea04eb0507cb8bc21d32b6757a62d7f8210c96aea24f0c8378f880a1a191007c_2026-10-08',
  'fp_ea04eb0507cb8bc21d32b6757a62d7f8210c96aea24f0c8378f880a1a191007c',
  DATE '2026-10-08',
  '21feefe8-4e72-4d31-ba7e-9d866a5fe846',
  coalesce('2026-10-08T02:15:59.994Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_ef35bd6dd86eb241156453d6a3171d941059636db2f2b6568667e6d88e131701_2026-10-08',
  'fp_ef35bd6dd86eb241156453d6a3171d941059636db2f2b6568667e6d88e131701',
  DATE '2026-10-08',
  '6cfe82ca-f18c-4885-a46f-24bb7162857d',
  coalesce('2026-10-08T02:29:54.796Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.device_session_locks (id, device_id, session_date, check_in_id, created_at)
values (
  'fp_f8499162e6c4f8227e1d02c20330ac1a400a49073d757a6acc1e9cea9c84a47d_2026-10-08',
  'fp_f8499162e6c4f8227e1d02c20330ac1a400a49073d757a6acc1e9cea9c84a47d',
  DATE '2026-10-08',
  '65e4f765-c079-4de4-bcac-e632e49739de',
  coalesce('2026-10-08T02:04:18.573Z', timezone('utc', now()))
)
on conflict (id) do update set
  device_id = excluded.device_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;

-- phone_session_locks (69)
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '7043297313_2026-10-08',
  '7043297313',
  DATE '2026-10-08',
  'b69bb4a9-b7b8-4e11-87c7-c42185ed829e',
  coalesce('2026-10-08T01:52:53.149Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '7666842678_2026-10-08',
  '7666842678',
  DATE '2026-10-08',
  '76e1e9df-2dc5-4bf0-b1b9-3533605745d4',
  coalesce('2026-10-08T01:54:35.696Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '7738208090_2026-10-08',
  '7738208090',
  DATE '2026-10-08',
  '6cfe82ca-f18c-4885-a46f-24bb7162857d',
  coalesce('2026-10-08T02:29:54.796Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '7900000438_2026-10-08',
  '7900000438',
  DATE '2026-10-08',
  'ddcd91a0-fe60-45de-affc-d8da04b32a5a',
  coalesce('2026-10-08T01:54:10.798Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '7977083342_2026-10-08',
  '7977083342',
  DATE '2026-10-08',
  '14e1f788-5f82-4b82-b54d-89652b5804aa',
  coalesce('2026-10-08T02:16:25.749Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8097366666_2026-10-08',
  '8097366666',
  DATE '2026-10-08',
  '3a39954f-d6e0-4bf2-a39e-4ae19bf2f26e',
  coalesce('2026-10-08T02:13:46.648Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8108156000_2026-10-08',
  '8108156000',
  DATE '2026-10-08',
  '65e4f765-c079-4de4-bcac-e632e49739de',
  coalesce('2026-10-08T02:04:18.573Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8233813031_2026-10-08',
  '8233813031',
  DATE '2026-10-08',
  '6e9c978d-9f59-4589-98d1-b489b24d3bbc',
  coalesce('2026-10-08T02:08:02.229Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8291899291_2026-10-08',
  '8291899291',
  DATE '2026-10-08',
  '2321adcb-93df-486d-95ff-31de45695073',
  coalesce('2026-10-08T02:05:19.264Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8356011246_2026-10-01',
  '8356011246',
  DATE '2026-10-01',
  '529b904a-6b1c-4cb4-a565-47d2dab21f2c',
  coalesce('2026-10-09T07:54:36.486Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8356011246_2026-10-15',
  '8356011246',
  DATE '2026-10-15',
  '782cb2ae-8056-43cf-ac79-7b490d7ec41f',
  coalesce('2026-10-09T05:58:34.030Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8369492613_2026-10-08',
  '8369492613',
  DATE '2026-10-08',
  '69da4446-ae4b-4b36-9b66-1f98ecef28e5',
  coalesce('2026-10-08T01:53:50.558Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8379804651_2026-10-08',
  '8379804651',
  DATE '2026-10-08',
  'd5f14f74-4b9e-4efb-8e1c-84ddcc5462fe',
  coalesce('2026-10-08T02:20:33.764Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8454984654_2026-10-08',
  '8454984654',
  DATE '2026-10-08',
  '2dab945b-3958-4950-a45d-fd1dc8f48381',
  coalesce('2026-10-08T02:17:05.793Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8879238658_2026-10-08',
  '8879238658',
  DATE '2026-10-08',
  'b8260ebc-a49f-4075-8dee-3d94b0925304',
  coalesce('2026-10-08T02:27:00.426Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '8898341341_2026-10-08',
  '8898341341',
  DATE '2026-10-08',
  '97301a13-e985-4d74-8206-8a983efd7bfc',
  coalesce('2026-10-08T02:17:52.502Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9004043167_2026-10-08',
  '9004043167',
  DATE '2026-10-08',
  'f78f1cee-b270-4720-bdb2-65757bfd9a3d',
  coalesce('2026-10-08T01:39:09.314Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9004716222_2026-10-08',
  '9004716222',
  DATE '2026-10-08',
  'd74b66b4-7ae3-4371-b397-b5ad0c3dcb4c',
  coalesce('2026-10-08T02:03:16.113Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9004854786_2026-10-08',
  '9004854786',
  DATE '2026-10-08',
  '13d28a81-0d04-42f2-a8e8-a43f5db94753',
  coalesce('2026-10-08T02:19:11.369Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9137174281_2026-10-08',
  '9137174281',
  DATE '2026-10-08',
  'e4b3e308-6309-44a7-884c-63e593622727',
  coalesce('2026-10-08T01:56:42.447Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9137948424_2026-10-08',
  '9137948424',
  DATE '2026-10-08',
  'ed83f958-588d-444c-be5c-26d62623cf87',
  coalesce('2026-10-08T02:23:32.023Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9167486070_2026-10-08',
  '9167486070',
  DATE '2026-10-08',
  '21feefe8-4e72-4d31-ba7e-9d866a5fe846',
  coalesce('2026-10-08T02:15:59.994Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9320238774_2026-10-08',
  '9320238774',
  DATE '2026-10-08',
  '94d899b5-2f3f-4ca1-9737-433c997166bc',
  coalesce('2026-10-08T04:52:14.914Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9322600486_2026-10-08',
  '9322600486',
  DATE '2026-10-08',
  'd7dac14b-45ee-4087-825d-9d7ebe0564fe',
  coalesce('2026-10-08T02:04:07.100Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9326440158_2026-10-08',
  '9326440158',
  DATE '2026-10-08',
  'c4c0f8b0-7bb6-49bb-9bac-3cac1e679348',
  coalesce('2026-10-08T02:12:46.388Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9326490289_2026-10-08',
  '9326490289',
  DATE '2026-10-08',
  '28fc881a-103d-4ec2-9a4b-21bbdb0e83d7',
  coalesce('2026-10-08T03:29:56.095Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9545712120_2026-10-08',
  '9545712120',
  DATE '2026-10-08',
  '9e7d8f08-9085-4999-972d-95c06f928d06',
  coalesce('2026-10-08T02:14:25.067Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9664775997_2026-10-08',
  '9664775997',
  DATE '2026-10-08',
  '8dbd35f6-0564-4500-825b-412fe4d8b19e',
  coalesce('2026-10-08T01:35:04.473Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9702305358_2026-10-08',
  '9702305358',
  DATE '2026-10-08',
  '1a6cfd12-8de5-4ef1-a735-514424b3a6d5',
  coalesce('2026-10-08T02:21:14.413Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9769655090_2026-10-08',
  '9769655090',
  DATE '2026-10-08',
  'f5715f4a-d022-4382-9647-95744b5cbe19',
  coalesce('2026-10-08T02:03:07.854Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9769751753_2026-10-08',
  '9769751753',
  DATE '2026-10-08',
  '34a63c3d-66de-4a57-8afd-465b151e8d39',
  coalesce('2026-10-08T02:04:21.771Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9769759749_2026-10-08',
  '9769759749',
  DATE '2026-10-08',
  '62b77f84-454f-4ebe-a51e-870399b85ffd',
  coalesce('2026-10-08T01:40:18.668Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9769761138_2026-10-08',
  '9769761138',
  DATE '2026-10-08',
  '9963eb6b-26f7-474a-959d-9d81f95f10e0',
  coalesce('2026-10-08T01:53:12.500Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9819827814_2026-10-08',
  '9819827814',
  DATE '2026-10-08',
  '631c7b1d-0231-4d2c-97a6-d9a24fddedb3',
  coalesce('2026-10-08T03:39:01.591Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9819886633_2026-10-08',
  '9819886633',
  DATE '2026-10-08',
  '1fdb2844-c270-4405-96b3-c0c2e6acb485',
  coalesce('2026-10-08T01:53:18.888Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820037444_2026-10-08',
  '9820037444',
  DATE '2026-10-08',
  '80ef3e3b-6b9a-4e58-b034-d3dd84adc64b',
  coalesce('2026-10-08T02:29:28.904Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820059694_2026-10-08',
  '9820059694',
  DATE '2026-10-08',
  '6e1ea425-08a8-4603-9abc-74f6499cc682',
  coalesce('2026-10-08T02:21:01.226Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820071007_2026-10-08',
  '9820071007',
  DATE '2026-10-08',
  'a84a8ffa-786f-42cf-ab82-a15244a313e1',
  coalesce('2026-10-08T02:01:50.968Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820097716_2026-10-08',
  '9820097716',
  DATE '2026-10-08',
  '35663d20-c82a-4dc1-b1e4-2cca0d613a72',
  coalesce('2026-10-08T02:22:32.367Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820183227_2026-10-08',
  '9820183227',
  DATE '2026-10-08',
  '4abfb973-8075-4643-a2c7-fe6d0959e643',
  coalesce('2026-10-08T02:22:08.368Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820186619_2026-10-08',
  '9820186619',
  DATE '2026-10-08',
  '6374cbc6-b56d-49c3-a659-6d16a7d5a3c8',
  coalesce('2026-10-08T02:13:00.712Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820373726_2026-10-08',
  '9820373726',
  DATE '2026-10-08',
  '90cc12f2-d4d6-441f-8c2b-58ac22685f09',
  coalesce('2026-10-08T02:31:14.706Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820447128_2026-10-08',
  '9820447128',
  DATE '2026-10-08',
  '1f55fb99-01a4-4076-9eda-dabd49a131f7',
  coalesce('2026-10-08T01:48:37.150Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820468398_2026-10-08',
  '9820468398',
  DATE '2026-10-08',
  'b493482b-537e-4b0d-b8a1-a545c8b67c5a',
  coalesce('2026-10-08T02:19:42.558Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9820478924_2026-10-08',
  '9820478924',
  DATE '2026-10-08',
  '7b977162-2071-4b21-8abd-a5591e25f71b',
  coalesce('2026-10-08T02:35:00.744Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9821045110_2026-10-08',
  '9821045110',
  DATE '2026-10-08',
  'ab1eacde-0eaa-4e43-8401-147dfaeb56b1',
  coalesce('2026-10-08T02:16:01.946Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9821050853_2026-10-08',
  '9821050853',
  DATE '2026-10-08',
  '56b8ad33-e6fd-4ebc-ac5f-b31f6840262b',
  coalesce('2026-10-08T01:57:40.967Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9821064854_2026-10-08',
  '9821064854',
  DATE '2026-10-08',
  '73eb4644-d162-43d6-ae5d-b00af1ad3ff9',
  coalesce('2026-10-08T01:58:43.751Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9821655607_2026-10-08',
  '9821655607',
  DATE '2026-10-08',
  '0540dedf-a713-49ea-a102-27350a181d3a',
  coalesce('2026-10-08T02:26:06.113Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9821739597_2026-10-08',
  '9821739597',
  DATE '2026-10-08',
  'd64d23f4-ac55-458b-a2d4-9c88a141dd2c',
  coalesce('2026-10-08T02:01:33.997Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9821800071_2026-10-08',
  '9821800071',
  DATE '2026-10-08',
  '2db75312-ea5f-4093-9db2-e2bf6ac9f902',
  coalesce('2026-10-08T01:59:08.862Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9833083169_2026-10-08',
  '9833083169',
  DATE '2026-10-08',
  'd4f7d313-7389-4ac0-9d2f-4030ff18ff0d',
  coalesce('2026-10-08T02:15:59.489Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9833855671_2026-10-08',
  '9833855671',
  DATE '2026-10-08',
  'e2c78778-bf78-4656-85f7-f90828b3c429',
  coalesce('2026-10-08T03:30:39.418Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9867039491_2026-10-08',
  '9867039491',
  DATE '2026-10-08',
  'adfdeb5a-37fd-43d3-9091-7883eb0f3ac7',
  coalesce('2026-10-08T02:01:24.750Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9867876600_2026-10-08',
  '9867876600',
  DATE '2026-10-08',
  'cbd71896-e1c7-42ce-915e-45b1926db41a',
  coalesce('2026-10-08T03:32:57.667Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9870089414_2026-10-08',
  '9870089414',
  DATE '2026-10-08',
  'fe386962-80da-4875-9830-e93653cbeace',
  coalesce('2026-10-08T02:28:59.978Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9870590475_2026-10-08',
  '9870590475',
  DATE '2026-10-08',
  'fde8e92b-eb3a-4a63-9e36-fab6f92431a9',
  coalesce('2026-10-08T02:51:29.458Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9876543214_2026-10-15',
  '9876543214',
  DATE '2026-10-15',
  '9d802a2d-ebf2-478e-912b-a541d012bbc3',
  coalesce('2026-10-09T06:02:34.552Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9876543214_2026-10-22',
  '9876543214',
  DATE '2026-10-22',
  '1e1cc6de-ba70-4abf-9b1b-705a66b8ed24',
  coalesce('2026-10-09T07:31:41.095Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9876543215_2026-10-01',
  '9876543215',
  DATE '2026-10-01',
  'd25b2a0c-f0ca-4edd-b5d6-768904a5d3d2',
  coalesce('2026-10-09T07:53:52.150Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9876543215_2026-10-08',
  '9876543215',
  DATE '2026-10-08',
  '5ce3d1b7-0ab7-42d9-b119-2565e8588950',
  coalesce('2026-10-08T05:23:42.554Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9876543215_2026-10-15',
  '9876543215',
  DATE '2026-10-15',
  '2ac3fe07-46d3-4098-a49b-473d0e4eeeaa',
  coalesce('2026-10-09T05:56:07.362Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9876543215_2026-10-22',
  '9876543215',
  DATE '2026-10-22',
  '903cddbe-5631-4808-9a3f-7a0727cb30d0',
  coalesce('2026-10-09T07:30:18.352Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9876543265_2026-10-01',
  '9876543265',
  DATE '2026-10-01',
  'ec5dbf81-57ba-4e56-8247-5f52aa0880bc',
  coalesce('2026-10-09T07:55:20.140Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9920628333_2026-10-08',
  '9920628333',
  DATE '2026-10-08',
  '0d0f581e-b0f2-460e-b3d3-ca10733cee0d',
  coalesce('2026-10-08T02:57:11.319Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9930430483_2026-10-08',
  '9930430483',
  DATE '2026-10-08',
  '68386ce6-9828-45a7-8782-c2b3b9edd3ac',
  coalesce('2026-10-08T02:10:31.862Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9967964998_2026-10-08',
  '9967964998',
  DATE '2026-10-08',
  '49657ac7-86b3-4e9a-9a0e-78744688048b',
  coalesce('2026-10-08T01:56:42.034Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9987028576_2026-10-08',
  '9987028576',
  DATE '2026-10-08',
  'b0a20b8e-3442-48fa-a4ae-2e1e875d85ed',
  coalesce('2026-10-08T02:15:30.369Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.phone_session_locks (id, phone_digits, session_date, check_in_id, created_at)
values (
  '9987665588_2026-10-08',
  '9987665588',
  DATE '2026-10-08',
  '20403735-e1e0-42e0-9b91-f18efc5bda8a',
  coalesce('2026-10-08T02:18:09.801Z', timezone('utc', now()))
)
on conflict (id) do update set
  phone_digits = excluded.phone_digits,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;

-- member_session_locks (66)
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '1pz1pTr24UfsQgE5a5mS_2026-10-08',
  '1pz1pTr24UfsQgE5a5mS',
  DATE '2026-10-08',
  'b493482b-537e-4b0d-b8a1-a545c8b67c5a',
  coalesce('2026-10-08T02:19:42.558Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '38bMsFmUl9iCtbWxsJla_2026-10-08',
  '38bMsFmUl9iCtbWxsJla',
  DATE '2026-10-08',
  '9963eb6b-26f7-474a-959d-9d81f95f10e0',
  coalesce('2026-10-08T01:53:12.500Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '3TSGL7Nv9B5G522sgi6F_2026-10-08',
  '3TSGL7Nv9B5G522sgi6F',
  DATE '2026-10-08',
  '49657ac7-86b3-4e9a-9a0e-78744688048b',
  coalesce('2026-10-08T01:56:42.034Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '53vEkKwMI0qOaoNa7iMx_2026-10-08',
  '53vEkKwMI0qOaoNa7iMx',
  DATE '2026-10-08',
  '62b77f84-454f-4ebe-a51e-870399b85ffd',
  coalesce('2026-10-08T01:40:18.668Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '5bLTXQUAHK5Atxib2Imj_2026-10-01',
  '5bLTXQUAHK5Atxib2Imj',
  DATE '2026-10-01',
  '529b904a-6b1c-4cb4-a565-47d2dab21f2c',
  coalesce('2026-10-09T07:54:36.486Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '5bLTXQUAHK5Atxib2Imj_2026-10-15',
  '5bLTXQUAHK5Atxib2Imj',
  DATE '2026-10-15',
  '782cb2ae-8056-43cf-ac79-7b490d7ec41f',
  coalesce('2026-10-09T05:58:34.030Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '5bLTXQUAHK5Atxib2Imj_2026-10-22',
  '5bLTXQUAHK5Atxib2Imj',
  DATE '2026-10-22',
  '1e1cc6de-ba70-4abf-9b1b-705a66b8ed24',
  coalesce('2026-10-09T07:31:41.095Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '6Xllh1pAIXO0Ujjxeg8x_2026-10-08',
  '6Xllh1pAIXO0Ujjxeg8x',
  DATE '2026-10-08',
  'e2c78778-bf78-4656-85f7-f90828b3c429',
  coalesce('2026-10-08T03:30:39.418Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '6oPcL73xegjQFC57QYBD_2026-10-08',
  '6oPcL73xegjQFC57QYBD',
  DATE '2026-10-08',
  'd64d23f4-ac55-458b-a2d4-9c88a141dd2c',
  coalesce('2026-10-08T02:01:33.997Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '7HC3LlSmBOUWRZsxWDOi_2026-10-08',
  '7HC3LlSmBOUWRZsxWDOi',
  DATE '2026-10-08',
  'b69bb4a9-b7b8-4e11-87c7-c42185ed829e',
  coalesce('2026-10-08T01:52:53.149Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '7WXDMQUKWFtSSoZmlMAC_2026-10-08',
  '7WXDMQUKWFtSSoZmlMAC',
  DATE '2026-10-08',
  '2321adcb-93df-486d-95ff-31de45695073',
  coalesce('2026-10-08T02:05:19.264Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '8KGbuKitInhCySeS7571_2026-10-08',
  '8KGbuKitInhCySeS7571',
  DATE '2026-10-08',
  'd74b66b4-7ae3-4371-b397-b5ad0c3dcb4c',
  coalesce('2026-10-08T02:03:16.113Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  '9mhsIRiU7APSfut6e3xo_2026-10-08',
  '9mhsIRiU7APSfut6e3xo',
  DATE '2026-10-08',
  'a84a8ffa-786f-42cf-ab82-a15244a313e1',
  coalesce('2026-10-08T02:01:50.968Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'AqLY9voWQ6kVkeq0uAsH_2026-10-08',
  'AqLY9voWQ6kVkeq0uAsH',
  DATE '2026-10-08',
  'cbd71896-e1c7-42ce-915e-45b1926db41a',
  coalesce('2026-10-08T03:32:57.667Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'DobQyNV4KKdvFoXDYK79_2026-10-08',
  'DobQyNV4KKdvFoXDYK79',
  DATE '2026-10-08',
  'b0a20b8e-3442-48fa-a4ae-2e1e875d85ed',
  coalesce('2026-10-08T02:15:30.369Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'EFm6fdLH4mKbKmncFMtl_2026-10-08',
  'EFm6fdLH4mKbKmncFMtl',
  DATE '2026-10-08',
  '56b8ad33-e6fd-4ebc-ac5f-b31f6840262b',
  coalesce('2026-10-08T01:57:40.967Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'FRVIPK6pU5lLcRGH8lOu_2026-10-08',
  'FRVIPK6pU5lLcRGH8lOu',
  DATE '2026-10-08',
  'b8260ebc-a49f-4075-8dee-3d94b0925304',
  coalesce('2026-10-08T02:27:00.426Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'FidOmKXyDsF9FWUaRZgw_2026-10-08',
  'FidOmKXyDsF9FWUaRZgw',
  DATE '2026-10-08',
  'fde8e92b-eb3a-4a63-9e36-fab6f92431a9',
  coalesce('2026-10-08T02:51:29.458Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'H13YFlNoona9pWgK8L1c_2026-10-08',
  'H13YFlNoona9pWgK8L1c',
  DATE '2026-10-08',
  '1fdb2844-c270-4405-96b3-c0c2e6acb485',
  coalesce('2026-10-08T01:53:18.888Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'IWMVr2NgFYo38xBOFvkN_2026-10-08',
  'IWMVr2NgFYo38xBOFvkN',
  DATE '2026-10-08',
  'd5f14f74-4b9e-4efb-8e1c-84ddcc5462fe',
  coalesce('2026-10-08T02:20:33.764Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'IX7StO77cKIhI8HkpTL0_2026-10-08',
  'IX7StO77cKIhI8HkpTL0',
  DATE '2026-10-08',
  '6374cbc6-b56d-49c3-a659-6d16a7d5a3c8',
  coalesce('2026-10-08T02:13:00.712Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'J0IvzhqFCInXaznHdjfg_2026-10-08',
  'J0IvzhqFCInXaznHdjfg',
  DATE '2026-10-08',
  '3a39954f-d6e0-4bf2-a39e-4ae19bf2f26e',
  coalesce('2026-10-08T02:13:46.648Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'KhOdndsiVvz292c5tJYk_2026-10-08',
  'KhOdndsiVvz292c5tJYk',
  DATE '2026-10-08',
  '2dab945b-3958-4950-a45d-fd1dc8f48381',
  coalesce('2026-10-08T02:17:05.793Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'KiFhmXqmFAJu4r4FgXWp_2026-10-08',
  'KiFhmXqmFAJu4r4FgXWp',
  DATE '2026-10-08',
  'd4f7d313-7389-4ac0-9d2f-4030ff18ff0d',
  coalesce('2026-10-08T02:15:59.489Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'Ls2QHZXIyflFFt9wltbM_2026-10-08',
  'Ls2QHZXIyflFFt9wltbM',
  DATE '2026-10-08',
  '9e7d8f08-9085-4999-972d-95c06f928d06',
  coalesce('2026-10-08T02:14:25.067Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'MfXvO5nB4Py3UXa9LyM4_2026-10-08',
  'MfXvO5nB4Py3UXa9LyM4',
  DATE '2026-10-08',
  'ab1eacde-0eaa-4e43-8401-147dfaeb56b1',
  coalesce('2026-10-08T02:16:01.946Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'Mt6FLuWeYlXpKBlljyLS_2026-10-08',
  'Mt6FLuWeYlXpKBlljyLS',
  DATE '2026-10-08',
  '14e1f788-5f82-4b82-b54d-89652b5804aa',
  coalesce('2026-10-08T02:16:25.749Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'MuVuPRDgb7Ru2ETswaJa_2026-10-08',
  'MuVuPRDgb7Ru2ETswaJa',
  DATE '2026-10-08',
  '68386ce6-9828-45a7-8782-c2b3b9edd3ac',
  coalesce('2026-10-08T02:10:31.862Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'PS8iRRZuAEFdaJbN1BKV_2026-10-08',
  'PS8iRRZuAEFdaJbN1BKV',
  DATE '2026-10-08',
  '94d899b5-2f3f-4ca1-9737-433c997166bc',
  coalesce('2026-10-08T04:52:14.914Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'PeNnZQ5PuFqYU1bTb08x_2026-10-08',
  'PeNnZQ5PuFqYU1bTb08x',
  DATE '2026-10-08',
  '76e1e9df-2dc5-4bf0-b1b9-3533605745d4',
  coalesce('2026-10-08T01:54:35.696Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'Qu21MsYqvySMG3UotzkI_2026-10-08',
  'Qu21MsYqvySMG3UotzkI',
  DATE '2026-10-08',
  '2db75312-ea5f-4093-9db2-e2bf6ac9f902',
  coalesce('2026-10-08T01:59:08.862Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'RT4LY0FAcSP3VqvyFYxA_2026-10-08',
  'RT4LY0FAcSP3VqvyFYxA',
  DATE '2026-10-08',
  '631c7b1d-0231-4d2c-97a6-d9a24fddedb3',
  coalesce('2026-10-08T03:39:01.591Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'TGsSahqSrbKg5isJ5adG_2026-10-08',
  'TGsSahqSrbKg5isJ5adG',
  DATE '2026-10-08',
  '7b977162-2071-4b21-8abd-a5591e25f71b',
  coalesce('2026-10-08T02:35:00.744Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'Vevx5J2UBqJ5Hj2qB4Qd_2026-10-08',
  'Vevx5J2UBqJ5Hj2qB4Qd',
  DATE '2026-10-08',
  '13d28a81-0d04-42f2-a8e8-a43f5db94753',
  coalesce('2026-10-08T02:19:11.369Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'XSvSmdSucf2Iww8AGYd3_2026-10-08',
  'XSvSmdSucf2Iww8AGYd3',
  DATE '2026-10-08',
  'ddcd91a0-fe60-45de-affc-d8da04b32a5a',
  coalesce('2026-10-08T01:54:10.798Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'ZDCa5FPDEIgahIXgtlrJ_2026-10-08',
  'ZDCa5FPDEIgahIXgtlrJ',
  DATE '2026-10-08',
  '6cfe82ca-f18c-4885-a46f-24bb7162857d',
  coalesce('2026-10-08T02:29:54.796Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'ZzKmlW7fuyT93dJxPFkM_2026-10-08',
  'ZzKmlW7fuyT93dJxPFkM',
  DATE '2026-10-08',
  'fe386962-80da-4875-9830-e93653cbeace',
  coalesce('2026-10-08T02:28:59.978Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'aQ5Ihm2OqxQqKz1aPXPO_2026-10-08',
  'aQ5Ihm2OqxQqKz1aPXPO',
  DATE '2026-10-08',
  '73eb4644-d162-43d6-ae5d-b00af1ad3ff9',
  coalesce('2026-10-08T01:58:43.751Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'bXYXbdfx01NMGDNPlNtY_2026-10-08',
  'bXYXbdfx01NMGDNPlNtY',
  DATE '2026-10-08',
  'adfdeb5a-37fd-43d3-9091-7883eb0f3ac7',
  coalesce('2026-10-08T02:01:24.750Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'dpAD4wg9CQ0GtmXQ8QHW_2026-10-08',
  'dpAD4wg9CQ0GtmXQ8QHW',
  DATE '2026-10-08',
  '6e1ea425-08a8-4603-9abc-74f6499cc682',
  coalesce('2026-10-08T02:21:01.226Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'hZyEGH7VIgCWEE0zUOYG_2026-10-01',
  'hZyEGH7VIgCWEE0zUOYG',
  DATE '2026-10-01',
  'd25b2a0c-f0ca-4edd-b5d6-768904a5d3d2',
  coalesce('2026-10-09T07:53:52.150Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'hZyEGH7VIgCWEE0zUOYG_2026-10-08',
  'hZyEGH7VIgCWEE0zUOYG',
  DATE '2026-10-08',
  '5ce3d1b7-0ab7-42d9-b119-2565e8588950',
  coalesce('2026-10-08T05:23:42.554Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'hZyEGH7VIgCWEE0zUOYG_2026-10-15',
  'hZyEGH7VIgCWEE0zUOYG',
  DATE '2026-10-15',
  '2ac3fe07-46d3-4098-a49b-473d0e4eeeaa',
  coalesce('2026-10-09T05:56:07.362Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'hZyEGH7VIgCWEE0zUOYG_2026-10-22',
  'hZyEGH7VIgCWEE0zUOYG',
  DATE '2026-10-22',
  '903cddbe-5631-4808-9a3f-7a0727cb30d0',
  coalesce('2026-10-09T07:30:18.352Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'jfDDqQnt5mY1S1w7uqhE_2026-10-08',
  'jfDDqQnt5mY1S1w7uqhE',
  DATE '2026-10-08',
  '35663d20-c82a-4dc1-b1e4-2cca0d613a72',
  coalesce('2026-10-08T02:22:32.367Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'kYpS7tpiGt3XosvTb6mE_2026-10-08',
  'kYpS7tpiGt3XosvTb6mE',
  DATE '2026-10-08',
  '80ef3e3b-6b9a-4e58-b034-d3dd84adc64b',
  coalesce('2026-10-08T02:29:28.904Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'ksdnwjeMhPkQlWqNhBgs_2026-10-08',
  'ksdnwjeMhPkQlWqNhBgs',
  DATE '2026-10-08',
  'c4c0f8b0-7bb6-49bb-9bac-3cac1e679348',
  coalesce('2026-10-08T02:12:46.388Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'lGL99wmRNCppOlkmR6Oj_2026-10-08',
  'lGL99wmRNCppOlkmR6Oj',
  DATE '2026-10-08',
  '1f55fb99-01a4-4076-9eda-dabd49a131f7',
  coalesce('2026-10-08T01:48:37.150Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'nQJG57Kl9taZlMkLgC0N_2026-10-08',
  'nQJG57Kl9taZlMkLgC0N',
  DATE '2026-10-08',
  '65e4f765-c079-4de4-bcac-e632e49739de',
  coalesce('2026-10-08T02:04:18.573Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'nisHwof0WmvAePs7LclP_2026-10-08',
  'nisHwof0WmvAePs7LclP',
  DATE '2026-10-08',
  '0540dedf-a713-49ea-a102-27350a181d3a',
  coalesce('2026-10-08T02:26:06.113Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'o3n5JBBx7AX6VYkZlph7_2026-10-08',
  'o3n5JBBx7AX6VYkZlph7',
  DATE '2026-10-08',
  'f78f1cee-b270-4720-bdb2-65757bfd9a3d',
  coalesce('2026-10-08T01:39:09.314Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'ofhv6bMhOkXbj57xdBrx_2026-10-08',
  'ofhv6bMhOkXbj57xdBrx',
  DATE '2026-10-08',
  'f5715f4a-d022-4382-9647-95744b5cbe19',
  coalesce('2026-10-08T02:03:07.854Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'quDand8LH8giQXs5v5N0_2026-10-08',
  'quDand8LH8giQXs5v5N0',
  DATE '2026-10-08',
  '97301a13-e985-4d74-8206-8a983efd7bfc',
  coalesce('2026-10-08T02:17:52.502Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'rN1W2Y167i0oBlNUgfpR_2026-10-08',
  'rN1W2Y167i0oBlNUgfpR',
  DATE '2026-10-08',
  '21feefe8-4e72-4d31-ba7e-9d866a5fe846',
  coalesce('2026-10-08T02:15:59.994Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'rQSD7oEgee2FwO6xFfa4_2026-10-08',
  'rQSD7oEgee2FwO6xFfa4',
  DATE '2026-10-08',
  '69da4446-ae4b-4b36-9b66-1f98ecef28e5',
  coalesce('2026-10-08T01:53:50.558Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'sQHsXe5C45MEhDHacG2u_2026-10-08',
  'sQHsXe5C45MEhDHacG2u',
  DATE '2026-10-08',
  'd7dac14b-45ee-4087-825d-9d7ebe0564fe',
  coalesce('2026-10-08T02:04:07.100Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'sobf9E6koFqVxhbeuy3C_2026-10-08',
  'sobf9E6koFqVxhbeuy3C',
  DATE '2026-10-08',
  'e4b3e308-6309-44a7-884c-63e593622727',
  coalesce('2026-10-08T01:56:42.447Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'syGVK5cPhtfPtbVUNtbY_2026-10-08',
  'syGVK5cPhtfPtbVUNtbY',
  DATE '2026-10-08',
  'ed83f958-588d-444c-be5c-26d62623cf87',
  coalesce('2026-10-08T02:23:32.023Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'tLsFF41wmi6MepYkF7iB_2026-10-08',
  'tLsFF41wmi6MepYkF7iB',
  DATE '2026-10-08',
  '34a63c3d-66de-4a57-8afd-465b151e8d39',
  coalesce('2026-10-08T02:04:21.771Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'uOPFKQQ1VZK2ytszgbrH_2026-10-08',
  'uOPFKQQ1VZK2ytszgbrH',
  DATE '2026-10-08',
  '4abfb973-8075-4643-a2c7-fe6d0959e643',
  coalesce('2026-10-08T02:22:08.368Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'ulifv2z1uZXMYuyHHPEU_2026-10-08',
  'ulifv2z1uZXMYuyHHPEU',
  DATE '2026-10-08',
  '8dbd35f6-0564-4500-825b-412fe4d8b19e',
  coalesce('2026-10-08T01:35:04.473Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'uqSFTxaeaNIQH3R8NlwG_2026-10-08',
  'uqSFTxaeaNIQH3R8NlwG',
  DATE '2026-10-08',
  '90cc12f2-d4d6-441f-8c2b-58ac22685f09',
  coalesce('2026-10-08T02:31:14.706Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'wyyytYwiUB1B3Wz7rN9u_2026-10-08',
  'wyyytYwiUB1B3Wz7rN9u',
  DATE '2026-10-08',
  '20403735-e1e0-42e0-9b91-f18efc5bda8a',
  coalesce('2026-10-08T02:18:09.801Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'xMDXjTaD1XhWD5cN3FZN_2026-10-08',
  'xMDXjTaD1XhWD5cN3FZN',
  DATE '2026-10-08',
  '0d0f581e-b0f2-460e-b3d3-ca10733cee0d',
  coalesce('2026-10-08T02:57:11.319Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'xQcHTY5UKO8poTfMM1UZ_2026-10-08',
  'xQcHTY5UKO8poTfMM1UZ',
  DATE '2026-10-08',
  '1a6cfd12-8de5-4ef1-a735-514424b3a6d5',
  coalesce('2026-10-08T02:21:14.413Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;
insert into public.member_session_locks (id, member_id, session_date, check_in_id, created_at)
values (
  'xmxCzhsAOU1TAagU4yQn_2026-10-08',
  'xmxCzhsAOU1TAagU4yQn',
  DATE '2026-10-08',
  '28fc881a-103d-4ec2-9a4b-21bbdb0e83d7',
  coalesce('2026-10-08T03:29:56.095Z', timezone('utc', now()))
)
on conflict (id) do update set
  member_id = excluded.member_id,
  session_date = excluded.session_date,
  check_in_id = excluded.check_in_id;

-- app_config (1)
insert into public.app_config (id, restrictions_enabled, updated_by, updated_by_email, updated_at)
values (
  'checkInRestrictions',
  coalesce(TRUE, FALSE),
  '7Bl8KLfKS1g2n2LQQ8XJnEbcw602',
  'rinku.s@metaphi.in',
  coalesce('2026-10-09T08:03:55.370Z', timezone('utc', now()))
)
on conflict (id) do update set
  restrictions_enabled = excluded.restrictions_enabled,
  updated_by = excluded.updated_by,
  updated_by_email = excluded.updated_by_email,
  updated_at = timezone('utc', now());

-- face_templates (0 kept, 3 skipped — orphan member_id)
-- skipped face_template '8TqLWru8BFgtPJu1XGvc' member_id='8TqLWru8BFgtPJu1XGvc' name='Omkar Anarse'
-- skipped face_template 'GXXFTKvr9FNwb5fJgFvH' member_id='GXXFTKvr9FNwb5fJgFvH' name='Pratham kadam'
-- skipped face_template 'pzY337noviMAdnwqwGl2' member_id='pzY337noviMAdnwqwGl2' name='Rinku Saroj'

-- admin_notifications (8)
insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  '1e1cc6de-ba70-4abf-9b1b-705a66b8ed24',
  'New Attendance Submission',
  'oiuytrewq (substitute) has submitted the attendance form.',
  '1e1cc6de-ba70-4abf-9b1b-705a66b8ed24',
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'oiuytrewq',
  '+919876543214',
  'substitute',
  'pending',
  'admin',
  '2026-10-09T07:31:41.206Z'
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;
insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  '2ac3fe07-46d3-4098-a49b-473d0e4eeeaa',
  'New Attendance Submission',
  'Omkar anarse (member) has submitted the attendance form.',
  '2ac3fe07-46d3-4098-a49b-473d0e4eeeaa',
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Omkar anarse',
  '+919876543215',
  'member',
  'pending',
  'admin',
  '2026-10-09T05:56:07.480Z'
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;
insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  '529b904a-6b1c-4cb4-a565-47d2dab21f2c',
  'New Attendance Submission',
  'omkar (substitute) has submitted the attendance form.',
  '529b904a-6b1c-4cb4-a565-47d2dab21f2c',
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'omkar',
  '+918356011246',
  'substitute',
  'pending',
  'admin',
  '2026-10-09T07:54:36.529Z'
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;
insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  '782cb2ae-8056-43cf-ac79-7b490d7ec41f',
  'New Attendance Submission',
  'omkar (substitute) has submitted the attendance form.',
  '782cb2ae-8056-43cf-ac79-7b490d7ec41f',
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'omkar',
  '+918356011246',
  'substitute',
  'pending',
  'admin',
  '2026-10-09T05:58:34.143Z'
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;
insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  '903cddbe-5631-4808-9a3f-7a0727cb30d0',
  'New Attendance Submission',
  'Omkar anarse (member) has submitted the attendance form.',
  '903cddbe-5631-4808-9a3f-7a0727cb30d0',
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Omkar anarse',
  '+919876543215',
  'member',
  'pending',
  'admin',
  '2026-10-09T07:30:18.458Z'
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;
insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  '9d802a2d-ebf2-478e-912b-a541d012bbc3',
  'New Attendance Submission',
  'oiuytrew (visitor) has submitted the attendance form.',
  '9d802a2d-ebf2-478e-912b-a541d012bbc3',
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'oiuytrew',
  '+919876543214',
  'visitor',
  'pending',
  'admin',
  '2026-10-09T06:02:34.643Z'
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;
insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  'd25b2a0c-f0ca-4edd-b5d6-768904a5d3d2',
  'New Attendance Submission',
  'Omkar anarse (member) has submitted the attendance form.',
  'd25b2a0c-f0ca-4edd-b5d6-768904a5d3d2',
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Omkar anarse',
  '+919876543215',
  'member',
  'pending',
  'admin',
  '2026-10-09T07:53:52.250Z'
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;
insert into public.admin_notifications (
  id, title, body, submission_id, location_id, location_name,
  user_name, user_phone, check_in_type, status, target_role, "timestamp"
) values (
  'ec5dbf81-57ba-4e56-8247-5f52aa0880bc',
  'New Attendance Submission',
  'oiuytre (visitor) has submitted the attendance form.',
  'ec5dbf81-57ba-4e56-8247-5f52aa0880bc',
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'oiuytre',
  '+919876543265',
  'visitor',
  'pending',
  'admin',
  '2026-10-09T07:55:20.181Z'
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = excluded.status;

-- admin_mail_dispatch (5)
insert into public.admin_mail_dispatch (
  id, recipient_email, recipient_name, role, portal_url, subject,
  status, delivery, automatic_send, created_at
) values (
  '0TQRaMmFeZLL3F3LiWcL',
  'omkaranarse.metaphi@gmail.com',
  'omkar anarse',
  'Admin',
  'https://attendiphi-by-metaphi.web.app/',
  'Your QR Check-in Admin Login Credentials',
  'manual_draft',
  'mailto_or_copy_by_super_admin',
  FALSE,
  '2026-09-21T11:16:12.527Z'
)
on conflict (id) do update set
  status = excluded.status,
  subject = excluded.subject;
insert into public.admin_mail_dispatch (
  id, recipient_email, recipient_name, role, portal_url, subject,
  status, delivery, automatic_send, created_at
) values (
  '8l00gl463tUX3UoKOnV7',
  NULL,
  'test',
  NULL,
  'https://attendiphi-by-metaphi.web.app/',
  'Welcome to QR Check-in Portal — Your Admin Login Credentials',
  'pending',
  NULL,
  NULL,
  '2026-09-21T06:24:19.897Z'
)
on conflict (id) do update set
  status = excluded.status,
  subject = excluded.subject;
insert into public.admin_mail_dispatch (
  id, recipient_email, recipient_name, role, portal_url, subject,
  status, delivery, automatic_send, created_at
) values (
  'Fmr5ViBzJDRuvHYwzSBB',
  'omkaranarse.metaphi@gmail.com',
  'uytrew',
  'Admin',
  'https://attendiphi-by-metaphi.web.app/',
  'Your QR Check-in Admin Login Credentials',
  'manual_draft',
  'mailto_or_copy_by_super_admin',
  FALSE,
  '2026-09-21T11:25:19.400Z'
)
on conflict (id) do update set
  status = excluded.status,
  subject = excluded.subject;
insert into public.admin_mail_dispatch (
  id, recipient_email, recipient_name, role, portal_url, subject,
  status, delivery, automatic_send, created_at
) values (
  'NEkUozmkKss1iG6tPrFL',
  NULL,
  'Omkar Anarse',
  NULL,
  'https://qr-checkin-dev.web.app/',
  'Welcome to QR Check-in Portal — Your Admin Login Credentials',
  'pending',
  NULL,
  NULL,
  '2026-09-09T07:20:19.999Z'
)
on conflict (id) do update set
  status = excluded.status,
  subject = excluded.subject;
insert into public.admin_mail_dispatch (
  id, recipient_email, recipient_name, role, portal_url, subject,
  status, delivery, automatic_send, created_at
) values (
  'knTO7kCpNfQRXwad46H8',
  NULL,
  'testing',
  NULL,
  'https://attendiphi-by-metaphi.web.app/',
  'Welcome to QR Check-in Portal — Your Admin Login Credentials',
  'pending',
  NULL,
  NULL,
  '2026-09-21T06:21:24.798Z'
)
on conflict (id) do update set
  status = excluded.status,
  subject = excluded.subject;

commit;

-- Verify:
-- select count(*) from public.members;
-- select count(*) from public.check_ins;
-- select type, count(*) from public.check_ins group by type;
-- select count(*) from public.admins;