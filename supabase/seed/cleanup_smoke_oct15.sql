-- Remove Thursday readiness smoke-test rows (not real attendance).
-- Run in Supabase SQL Editor on project fzghxzybyygslfjyfewu.

delete from public.admin_notifications
where id in ('_smoke_member_n', '_smoke_sub_n', '_smoke_vis_n')
   or submission_id in ('_smoke_member', '_smoke_sub', '_smoke_vis', '_thu_probe_ci');

delete from public.phone_session_locks
where check_in_id in ('_smoke_member', '_smoke_sub', '_smoke_vis', '_thu_probe_ci')
   or phone_digits in ('9111111111', '9222222222', '9333333333');

delete from public.member_session_locks
where check_in_id in ('_smoke_member', '_smoke_sub', '_smoke_vis', '_thu_probe_ci');

delete from public.device_session_locks
where check_in_id in ('_smoke_member', '_smoke_sub', '_smoke_vis', '_thu_probe_ci')
   or device_id = 'smoke-device';

-- One row per session day with checked_in_member_ids[]; wipe smoke session
delete from public.session_attendance
where session_date = date '2026-10-15';

delete from public.check_ins
where id in ('_smoke_member', '_smoke_sub', '_smoke_vis', '_thu_probe_ci')
   or user_name in ('Smoke Member', 'Smoke Sub', 'Smoke Visitor', 'probe');
