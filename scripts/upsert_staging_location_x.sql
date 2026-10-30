-- Upsert staging check-in pin for location_x on attendiphi-test ONLY.
-- Project ref: ofieqhdkvofsjnpxkmee (https://attendiphi.staging.metaphi.in)
-- DO NOT run against production (fzghxzybyygslfjyfewu / Jade).
--
-- Example:
--   npx supabase db execute --project-ref ofieqhdkvofsjnpxkmee \
--     --file scripts/upsert_staging_location_x.sql
-- Or paste into the Supabase SQL editor for attendiphi-test.
--
-- Verify:
--   select id,name,address,latitude,longitude from locations where id='location_x';
--
-- After deploying a new web-staging.zip: hard-refresh the browser (or unregister
-- the service worker) if the Location Access card still shows an old venue name.

insert into public.locations (
  id,
  name,
  address,
  latitude,
  longitude,
  radius_meters,
  is_active,
  updated_at,
  raw
)
values (
  'location_x',
  'Metaphi',
  'Excel Plaza, 90 Feet Road, Behind Durga Parmeshwari Mandir, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400075, India',
  19.083304,
  72.913425,
  500,
  true,
  timezone('utc', now()),
  jsonb_build_object('source', 'upsert_staging_location_x')
)
on conflict (id) do update set
  name = excluded.name,
  address = excluded.address,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  radius_meters = excluded.radius_meters,
  is_active = excluded.is_active,
  updated_at = excluded.updated_at,
  raw = excluded.raw;
