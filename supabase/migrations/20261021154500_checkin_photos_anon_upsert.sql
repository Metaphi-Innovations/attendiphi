-- Substitute / check-in selfie uploads use storage.upload with upsert.
-- Anon previously had INSERT only — upsert requires UPDATE as well.
-- Also re-clear file_size_limit (in case prior migration was not applied).

update storage.buckets
set file_size_limit = null
where id = 'check-in-photos';

-- Upsert / overwrite retries need UPDATE (INSERT alone is not enough).
drop policy if exists checkin_photos_anon_update on storage.objects;
create policy checkin_photos_anon_update on storage.objects
  for update to anon
  using (bucket_id = 'check-in-photos')
  with check (bucket_id = 'check-in-photos');
