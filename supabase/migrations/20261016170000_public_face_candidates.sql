-- Public Face check-in needs SFace templates without exposing full members rows.
-- Same pattern as public.public_members (security_invoker = false).

begin;

drop view if exists public.public_face_candidates;
create view public.public_face_candidates
with (security_invoker = false) as
select
  m.id as member_id,
  m.name,
  m.phone,
  m.is_active,
  ft.model,
  ft.model_version,
  ft.embedding,
  ft.raw,
  ft.updated_at
from public.members m
inner join public.face_templates ft
  on ft.member_id = m.id
where m.is_active = true
  and (
    ft.embedding is not null
    or (ft.raw ? 'faceTemplates')
  );

revoke all on public.public_face_candidates from public;
grant select on public.public_face_candidates to anon, authenticated;

commit;
