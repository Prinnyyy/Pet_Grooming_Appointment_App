create function public.create_my_profile(
  p_role public.user_role,
  p_display_name text
)
returns table (
  id uuid,
  role public.user_role,
  display_name text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_display_name text := btrim(p_display_name);
  v_existing_role public.user_role;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_role is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_role';
  end if;

  if v_display_name is null
    or char_length(v_display_name) not between 1 and 80
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_display_name';
  end if;

  select profile.role
  into v_existing_role
  from public.profiles as profile
  where profile.id = v_user_id;

  if found and v_existing_role <> p_role then
    raise exception using
      errcode = 'P0001',
      message = 'profile_role_immutable';
  end if;

  insert into public.profiles (id, role, display_name)
  values (v_user_id, p_role, v_display_name)
  on conflict (id) do nothing;

  select profile.role
  into v_existing_role
  from public.profiles as profile
  where profile.id = v_user_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'profile_creation_failed';
  end if;

  if v_existing_role <> p_role then
    raise exception using
      errcode = 'P0001',
      message = 'profile_role_immutable';
  end if;

  case p_role
    when 'customer'::public.user_role then
      insert into public.customer_profiles (user_id)
      values (v_user_id)
      on conflict (user_id) do nothing;
    when 'groomer'::public.user_role then
      insert into public.groomer_profiles (user_id)
      values (v_user_id)
      on conflict (user_id) do nothing;
  end case;

  return query
  select profile.id, profile.role, profile.display_name
  from public.profiles as profile
  where profile.id = v_user_id;
end;
$$;

comment on function public.create_my_profile(public.user_role, text) is
  'Atomically creates the authenticated non-anonymous user profile and matching immutable role marker.';

revoke all on function public.create_my_profile(public.user_role, text)
from public, anon, authenticated;

grant execute on function public.create_my_profile(public.user_role, text)
to authenticated, service_role;
