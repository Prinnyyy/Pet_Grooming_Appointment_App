create or replace function app_private.groomer_can_view_customer_avatar(
  p_customer_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_customer_id is not null
    and (select auth.uid()) is not null
    and not coalesce(
      ((select auth.jwt()) ->> 'is_anonymous')::boolean,
      false
    )
    and exists (
      select 1
      from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.role = 'groomer'::public.user_role
    )
    and exists (
      select 1
      from public.conversations
      where conversations.customer_id = p_customer_id
        and conversations.groomer_id = (select auth.uid())
    );
$$;

comment on function app_private.groomer_can_view_customer_avatar(uuid) is
  'Returns whether the authenticated Groomer shares a conversation with the Customer. SECURITY DEFINER avoids recursive RLS evaluation.';

revoke all on function app_private.groomer_can_view_customer_avatar(uuid)
from public, anon, authenticated, service_role;

grant execute on function app_private.groomer_can_view_customer_avatar(uuid)
to authenticated;

drop policy profiles_select_own_or_customer_groomer_avatar
on public.profiles;

create policy profiles_select_own_or_related_participant_avatar
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    profiles.id = (select auth.uid())
    or (
      profiles.role = 'groomer'::public.user_role
      and app_private.customer_can_view_groomer_avatar(profiles.id)
    )
    or (
      profiles.role = 'customer'::public.user_role
      and app_private.groomer_can_view_customer_avatar(profiles.id)
    )
  )
);

drop policy customer_avatar_objects_select_own
on storage.objects;

create policy customer_avatar_objects_select_owner_or_conversation_groomer
on storage.objects
for select
to authenticated
using (
  bucket_id = 'customer-avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (
    (
      owner_id = (select auth.uid())::text
      and (storage.foldername(storage.objects.name))[1] =
        (select auth.uid())::text
      and exists (
        select 1
        from public.profiles
        where profiles.id = (select auth.uid())
          and profiles.role = 'customer'::public.user_role
      )
    )
    or case
      when (storage.foldername(storage.objects.name))[1] ~*
        '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then app_private.groomer_can_view_customer_avatar(
        (storage.foldername(storage.objects.name))[1]::uuid
      )
      else false
    end
  )
);
