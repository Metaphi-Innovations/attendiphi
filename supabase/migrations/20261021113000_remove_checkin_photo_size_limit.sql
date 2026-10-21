-- Allow check-in selfies of any size (no bucket file_size_limit).
-- Client no longer rejects large base64 payloads before upload.
update storage.buckets
set file_size_limit = null
where id = 'check-in-photos';
