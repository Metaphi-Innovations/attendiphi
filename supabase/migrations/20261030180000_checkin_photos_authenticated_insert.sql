-- Public QR check-in photos are uploaded as anon. Admins often test the same
-- flow while signed in (authenticated). Without INSERT for authenticated,
-- Storage returns HTTP 400 / AccessDenied for substitute selfies.
-- Keep anon policies; add authenticated insert + update for standee testing.

drop policy if exists checkin_photos_authenticated_insert on storage.objects;
create policy checkin_photos_authenticated_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'check-in-photos');

drop policy if exists checkin_photos_authenticated_update on storage.objects;
create policy checkin_photos_authenticated_update on storage.objects
  for update to authenticated
  using (bucket_id = 'check-in-photos')
  with check (bucket_id = 'check-in-photos');
