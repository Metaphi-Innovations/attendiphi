-- Seed default venue (Jade) — backup XLSX had no locations rows.
-- Safe to re-run (upsert).

begin;

insert into public.locations (
  id, name, address, latitude, longitude, radius_meters, is_active, created_at, updated_at, raw
) values (
  'location_x',
  'Jade Luxury Banquets, Mumbai',
  'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
  18.9888622,
  72.8152475,
  500,
  true,
  timezone('utc', now()),
  timezone('utc', now()),
  '{"source":"phase6_seed"}'::jsonb
)
on conflict (id) do update set
  name = excluded.name,
  address = excluded.address,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  radius_meters = excluded.radius_meters,
  is_active = excluded.is_active,
  updated_at = timezone('utc', now());

commit;
