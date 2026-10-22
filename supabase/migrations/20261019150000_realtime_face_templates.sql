-- Publish face_templates so Face check-in candidates refresh via Realtime.
begin;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'face_templates'
  ) then
    alter publication supabase_realtime add table public.face_templates;
  end if;
end $$;

commit;
