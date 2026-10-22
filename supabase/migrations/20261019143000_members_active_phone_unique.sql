-- One active member per normalized phone digits.
-- Inactive members may keep historical duplicate phones.
--
-- If this migration fails with a unique_violation, find duplicates first:
--   select regexp_replace(phone, '\D', '', 'g') as digits, count(*), array_agg(id), array_agg(name)
--   from public.members
--   where is_active = true
--     and regexp_replace(phone, '\D', '', 'g') <> ''
--   group by 1
--   having count(*) > 1;
-- Resolve by deactivating or changing phones, then re-run.

begin;

create unique index if not exists members_active_phone_unique_idx
  on public.members (regexp_replace(phone, '\D', '', 'g'))
  where is_active = true
    and regexp_replace(phone, '\D', '', 'g') <> '';

comment on index public.members_active_phone_unique_idx is
  'Active members must have unique normalized phone digits; inactive rows excluded.';

commit;
