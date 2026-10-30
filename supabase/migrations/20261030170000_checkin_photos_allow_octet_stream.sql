-- Flutter web storage.uploadBinary multipart parts often advertise
-- application/octet-stream even when the bytes are JPEG. The bucket MIME
-- allow-list then returns HTTP 400 InvalidMimeType.
-- Keep JPEG/PNG/WebP and also accept octet-stream as a safety net.
-- The app still uploads re-encoded JPEG bytes with Content-Type: image/jpeg.

update storage.buckets
set
  file_size_limit = null,
  allowed_mime_types = array[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'application/octet-stream'
  ]
where id = 'check-in-photos';
