-- Harden first-login / forgot-password flag clearing.
-- Regular admins cannot UPDATE public.admins (superadmin-only RLS), so the
-- app MUST clear must_reset_password via SECURITY DEFINER RPCs. Also link
-- auth_user_id for the signed-in user so future matches are stable.

create or replace function public.link_own_admin_auth()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  update public.admins
  set
    auth_user_id = auth.uid(),
    updated_at = timezone('utc', now())
  where is_active = true
    and (
      auth_user_id = auth.uid()
      or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    );
end;
$$;

create or replace function public.complete_own_password_reset(
  p_password_hash text default null,
  p_password_salt text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  -- Ensure Auth uid is linked before (or while) clearing the flag.
  update public.admins
  set
    auth_user_id = coalesce(auth_user_id, auth.uid()),
    must_reset_password = false,
    password_hash = coalesce(nullif(p_password_hash, ''), password_hash),
    password_salt = coalesce(nullif(p_password_salt, ''), password_salt),
    password_updated_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where is_active = true
    and (
      auth_user_id = auth.uid()
      or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    );

  if not found then
    raise exception 'admin_profile_not_found';
  end if;
end;
$$;

revoke all on function public.link_own_admin_auth() from public;
revoke all on function public.complete_own_password_reset(text, text) from public;
grant execute on function public.link_own_admin_auth() to authenticated;
grant execute on function public.complete_own_password_reset(text, text) to authenticated;
