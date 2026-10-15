-- Morning-of Thursday 2026-10-15 pre-flight (BEFORE doors open).
-- Run in Supabase SQL Editor on fzghxzybyygslfjyfewu.
--
-- Clears smoke leftovers + any orphan locks so no member sees a false
-- "Already Responded" from a prior failed write / probe.
-- DO NOT run after real members have started checking in.

-- 1) Smoke / probe notification leftovers
delete from public.admin_notifications
where id in ('_smoke_member_n', '_smoke_sub_n', '_smoke_vis_n')
   or submission_id in ('_smoke_member', '_smoke_sub', '_smoke_vis', '_thu_probe_ci')
   or submission_id in (
     select id from public.check_ins where session_date = date '2026-10-15'
   );

-- 2) Wipe ALL Oct 15 attendance artifacts (safe only before real arrivals).
-- Includes probe/absent rows (e.g. admin "omkar" absent) that would otherwise
-- false-block that phone/member on QR submit.
delete from public.phone_session_locks where session_date = date '2026-10-15';
delete from public.member_session_locks where session_date = date '2026-10-15';
delete from public.device_session_locks where session_date = date '2026-10-15';
delete from public.session_attendance where session_date = date '2026-10-15';
delete from public.check_ins where session_date = date '2026-10-15';
delete from public.check_ins
where id in ('_smoke_member', '_smoke_sub', '_smoke_vis', '_thu_probe_ci')
   or user_name in ('Smoke Member', 'Smoke Sub', 'Smoke Visitor', 'probe');

-- 3) Inventory — expect zeros for locks / check_ins before first real arrival
select 'phone_locks' as kind, count(*)::int as n
  from public.phone_session_locks where session_date = date '2026-10-15'
union all
select 'member_locks', count(*)::int
  from public.member_session_locks where session_date = date '2026-10-15'
union all
select 'device_locks', count(*)::int
  from public.device_session_locks where session_date = date '2026-10-15'
union all
select 'check_ins', count(*)::int
  from public.check_ins where session_date = date '2026-10-15'
union all
select 'attendance_rows', count(*)::int
  from public.session_attendance where session_date = date '2026-10-15'
union all
select 'active_members', count(*)::int
  from public.members where is_active = true;
