begin;

create temporary table t355_avatar_pair on commit drop as
select
  conversation.customer_id,
  conversation.groomer_id,
  profile.avatar_path,
  avatar_object.name is not null as has_avatar_object
from public.conversations as conversation
join public.profiles as profile
  on profile.id = conversation.customer_id
left join storage.objects as avatar_object
  on avatar_object.bucket_id = 'customer-avatars'
  and avatar_object.name = profile.avatar_path
where profile.role = 'customer'::public.user_role
order by (avatar_object.name is not null) desc, conversation.updated_at desc
limit 1;

create temporary table t355_unrelated_customer on commit drop as
select profiles.id
from public.profiles
cross join t355_avatar_pair as pair
where profiles.role = 'customer'::public.user_role
  and profiles.id <> pair.customer_id
  and not exists (
    select 1
    from public.conversations
    where conversations.customer_id = profiles.id
      and conversations.groomer_id = pair.groomer_id
  )
limit 1;

do $$
begin
  if not exists (select 1 from t355_avatar_pair) then
    raise exception 'T-355 verification requires one existing conversation';
  end if;
end;
$$;

grant select on t355_avatar_pair, t355_unrelated_customer to authenticated;

do $$
declare
  v_groomer_id uuid;
begin
  select groomer_id
  into v_groomer_id
  from t355_avatar_pair;

  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', v_groomer_id,
      'role', 'authenticated',
      'is_anonymous', false
    )::text,
    true
  );
end;
$$;

set local role authenticated;

do $$
declare
  v_customer_id uuid;
  v_avatar_path text;
  v_has_avatar_object boolean;
  v_unrelated_customer_id uuid;
begin
  select customer_id, avatar_path, has_avatar_object
  into v_customer_id, v_avatar_path, v_has_avatar_object
  from t355_avatar_pair;

  if not app_private.groomer_can_view_customer_avatar(v_customer_id) then
    raise exception 'conversation Groomer cannot view the related Customer avatar';
  end if;

  if not exists (
    select 1
    from public.profiles
    where profiles.id = v_customer_id
      and profiles.role = 'customer'::public.user_role
  ) then
    raise exception 'related Customer profile is not visible to the conversation Groomer';
  end if;

  if v_has_avatar_object and not exists (
    select 1
    from storage.objects
    where storage.objects.bucket_id = 'customer-avatars'
      and storage.objects.name = v_avatar_path
  ) then
    raise exception 'related Customer avatar object is not visible to the conversation Groomer';
  end if;

  select id
  into v_unrelated_customer_id
  from t355_unrelated_customer;

  if v_unrelated_customer_id is null then
    raise exception 'T-355 verification requires one unrelated Customer';
  end if;

  if app_private.groomer_can_view_customer_avatar(v_unrelated_customer_id) then
    raise exception 'Groomer can view an unrelated Customer avatar';
  end if;

  if exists (
    select 1
    from public.profiles
    where profiles.id = v_unrelated_customer_id
  ) then
    raise exception 'unrelated Customer profile is visible to the Groomer';
  end if;
end;
$$;

reset role;
rollback;
