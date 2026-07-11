-- T-283 removes the circular RLS dependency introduced by T-263:
-- groomer_profiles -> profiles -> bookings -> groomer_profiles.

create or replace function app_private.customer_can_view_groomer_avatar(
  p_groomer_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_groomer_id is not null
    and (select auth.uid()) is not null
    and not coalesce(
      ((select auth.jwt()) ->> 'is_anonymous')::boolean,
      false
    )
    and exists (
      select 1
      from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.role = 'customer'::public.user_role
    )
    and (
      exists (
        select 1
        from public.bookings
        where bookings.groomer_id = p_groomer_id
          and bookings.customer_id = (select auth.uid())
      )
      or exists (
        select 1
        from public.groomer_offers
        where groomer_offers.groomer_id = p_groomer_id
          and groomer_offers.customer_id = (select auth.uid())
      )
    );
$$;

comment on function app_private.customer_can_view_groomer_avatar(uuid) is
  'Returns whether the authenticated customer has an offer or booking relationship with the Groomer. SECURITY DEFINER avoids recursive RLS evaluation.';

revoke all on function app_private.customer_can_view_groomer_avatar(uuid)
from public, anon, authenticated, service_role;

grant execute on function app_private.customer_can_view_groomer_avatar(uuid)
to authenticated;

drop policy profiles_select_own_or_customer_groomer_avatar
on public.profiles;

create policy profiles_select_own_or_customer_groomer_avatar
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
  )
);

drop policy groomer_avatar_objects_select_owner_or_customer
on storage.objects;

create policy groomer_avatar_objects_select_owner_or_customer
on storage.objects
for select
to authenticated
using (
  bucket_id = 'groomer-avatars'
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
          and profiles.role = 'groomer'::public.user_role
      )
    )
    or case
      when (storage.foldername(storage.objects.name))[1] ~*
        '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then app_private.customer_can_view_groomer_avatar(
        (storage.foldername(storage.objects.name))[1]::uuid
      )
      else false
    end
  )
);
