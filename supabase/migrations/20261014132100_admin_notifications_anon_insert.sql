-- Allow QR (anon) check-in flow to write notification triggers.
-- Same posture as check_ins_anon_insert; tighten later with Edge Function if needed.

begin;

drop policy if exists admin_notifications_anon_insert on public.admin_notifications;
create policy admin_notifications_anon_insert on public.admin_notifications
  for insert to anon
  with check (true);

-- Admins still need to read their notifications stream / table.
drop policy if exists admin_notifications_anon_select on public.admin_notifications;
create policy admin_notifications_anon_select on public.admin_notifications
  for select to anon
  using (true);

commit;
