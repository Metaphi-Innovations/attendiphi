-- Supabase storage upsert reads the object first. Without anon SELECT,
-- x-upsert=true returns HTTP 400 AccessDenied ("new row violates RLS").
-- Already applied on staging via hotfix; keep migration for other envs.

drop policy if exists checkin_photos_anon_select on storage.objects;
create policy checkin_photos_anon_select on storage.objects
  for select to anon
  using (bucket_id = 'check-in-photos');
