-- QR typeahead hides members listed in session_attendance.checked_in_member_ids.
-- That array can drift from real check_ins (e.g. admin upserts bypass the RPC),
-- which shows "All members have already checked in" while Daily Attendance still
-- has many Not Checked In rows. Rebuild the projection from check_ins.

insert into public.session_attendance (id, session_date, checked_in_member_ids, updated_at)
select
  to_char(c.session_date, 'YYYY-MM-DD') as id,
  c.session_date,
  coalesce(
    array_agg(distinct nullif(trim(c.member_id), ''))
      filter (where nullif(trim(c.member_id), '') is not null),
    '{}'::text[]
  ) as checked_in_member_ids,
  timezone('utc', now()) as updated_at
from public.check_ins c
where c.session_date is not null
group by c.session_date
on conflict (session_date) do update
set
  checked_in_member_ids = excluded.checked_in_member_ids,
  updated_at = excluded.updated_at;

-- Dates with a session_attendance row but zero check_ins → empty list.
update public.session_attendance sa
set
  checked_in_member_ids = '{}'::text[],
  updated_at = timezone('utc', now())
where not exists (
  select 1
  from public.check_ins c
  where c.session_date = sa.session_date
);
