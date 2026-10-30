-- Public QR success deep-link: anon cannot SELECT check_ins. After refresh /
-- paste of /checkin-result?checkinId=… the GoRouter extra is gone — return a
-- minimal summary for that single id so the card shows name / phone / type.

create or replace function public.get_public_check_in_summary(
  p_check_in_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id text := trim(coalesce(p_check_in_id, ''));
  v_row public.check_ins%rowtype;
begin
  if v_id = '' then
    return null;
  end if;

  select *
  into v_row
  from public.check_ins c
  where c.id = v_id
  limit 1;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'check_in_id', v_row.id,
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
    'photo_path', v_row.photo_path,
    'substitute_for_member', v_row.substitute_for_member,
    'substitute_name', v_row.substitute_name,
    'company_name', v_row.company_name,
    'category', v_row.category,
    'invited_by_member', v_row.invited_by_member
  );
end;
$$;

comment on function public.get_public_check_in_summary(text) is
  'Anon-safe: check-in summary for one check_in id (success deep-link hydration).';

revoke all on function public.get_public_check_in_summary(text) from public;
grant execute on function public.get_public_check_in_summary(text)
  to anon, authenticated;
