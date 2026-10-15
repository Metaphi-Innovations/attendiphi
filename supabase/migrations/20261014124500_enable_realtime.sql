-- Phase 4 fix: enable Supabase Realtime for tables used by Flutter .stream()
-- Project: fzghxzybyygslfjyfewu
--
-- Paste into SQL Editor and run if Dashboard → Database → Publications
-- does not already list these tables under supabase_realtime.

begin;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'check_ins'
  ) then
    alter publication supabase_realtime add table public.check_ins;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'members'
  ) then
    alter publication supabase_realtime add table public.members;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'session_attendance'
  ) then
    alter publication supabase_realtime add table public.session_attendance;
  end if;
end $$;

commit;
