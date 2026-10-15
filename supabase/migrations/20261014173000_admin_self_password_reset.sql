-- Allow an authenticated admin to clear their own must_reset_password /
-- password metadata after Auth password change (forgot-password or forced reset).
-- Previously only superadmin could UPDATE public.admins, so must_reset_password
-- stayed true forever for normal admins → login always redirected to reset.

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

  update public.admins
  set
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

create or replace function public.touch_own_admin_login()
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
    last_login_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where is_active = true
    and (
      auth_user_id = auth.uid()
      or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    );
end;
$$;

revoke all on function public.complete_own_password_reset(text, text) from public;
revoke all on function public.touch_own_admin_login() from public;
grant execute on function public.complete_own_password_reset(text, text) to authenticated;
grant execute on function public.touch_own_admin_login() to authenticated;
