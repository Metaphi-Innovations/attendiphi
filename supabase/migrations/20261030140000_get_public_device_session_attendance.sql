-- Public QR: after clear-site-data, anon cannot SELECT device_session_locks /
-- check_ins (insert-only / lockdown). SECURITY DEFINER lookup returns this
-- device's prior attendance for the session so the client can skip the form.

create or replace function public.get_public_device_session_attendance(
  p_device_id text,
  p_session_date date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id text := trim(coalesce(p_device_id, ''));
  v_lock_id text;
  v_check_in_id text;
  v_row public.check_ins%rowtype;
begin
  if v_device_id = '' or p_session_date is null then
    return jsonb_build_object('locked', false);
  end if;

  v_lock_id := v_device_id || '_' || to_char(p_session_date, 'YYYY-MM-DD');

  select l.check_in_id
  into v_check_in_id
  from public.device_session_locks l
  where l.device_id = v_device_id
    and l.session_date = p_session_date
  limit 1;

  if not found then
    select l.check_in_id
    into v_check_in_id
    from public.device_session_locks l
    where l.id = v_lock_id
    limit 1;
  end if;

  if not found then
    return jsonb_build_object('locked', false);
  end if;

  if v_check_in_id is not null and trim(v_check_in_id) <> '' then
    select *
    into v_row
    from public.check_ins c
    where c.id = trim(v_check_in_id)
    limit 1;

    if found then
      return jsonb_build_object(
        'locked', true,
        'check_in_id', v_row.id,
        'id', v_row.id,
        'type', v_row.type::text,
        'location_id', v_row.location_id,
        'location_name', coalesce(v_row.location_name, ''),
        'user_name', coalesce(v_row.user_name, ''),
        'user_phone', coalesce(v_row.user_phone, ''),
        'member_id', v_row.member_id,
        'device_id', v_row.device_id,
        'user_latitude', coalesce(v_row.user_latitude, 0),
        'user_longitude', coalesce(v_row.user_longitude, 0),
        'gps_accuracy', coalesce(v_row.gps_accuracy, 0),
        'distance_meters', coalesce(v_row.distance_meters, 0),
        'timestamp', coalesce(v_row."timestamp", v_row.attended_at, v_row.created_at),
        'session_date', v_row.session_date,
        'has_photo', coalesce(v_row.has_photo, false),
        'photo_path', v_row.photo_path
      );
    end if;
  end if;

  return jsonb_build_object(
    'locked', true,
    'check_in_id', nullif(trim(coalesce(v_check_in_id, '')), '')
  );
end;
$$;

comment on function public.get_public_device_session_attendance(text, date) is
  'Anon-safe: returns locked + check-in summary for one device_id + session_date only.';

revoke all on function public.get_public_device_session_attendance(text, date)
  from public;
grant execute on function public.get_public_device_session_attendance(text, date)
  to anon, authenticated;
