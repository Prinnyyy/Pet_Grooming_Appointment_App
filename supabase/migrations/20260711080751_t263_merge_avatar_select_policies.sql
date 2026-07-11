-- T-263 merges equivalent permissive avatar SELECT policies so each table has
-- one authenticated SELECT policy while preserving owner and participant access.

drop policy profiles_select_own
on public.profiles;

drop policy profiles_select_booking_groomer_avatar
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
      and (
        exists (
          select 1
          from public.bookings
          where bookings.groomer_id = profiles.id
            and bookings.customer_id = (select auth.uid())
        )
        or exists (
          select 1
          from public.groomer_offers
          where groomer_offers.groomer_id = profiles.id
            and groomer_offers.customer_id = (select auth.uid())
        )
      )
    )
  )
);

drop policy groomer_avatar_objects_select_own
on storage.objects;

drop policy groomer_avatar_objects_select_booking_customer
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
    or exists (
      select 1
      from public.bookings
      where bookings.groomer_id::text =
        (storage.foldername(storage.objects.name))[1]
        and bookings.customer_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.groomer_offers
      where groomer_offers.groomer_id::text =
        (storage.foldername(storage.objects.name))[1]
        and groomer_offers.customer_id = (select auth.uid())
    )
  )
);
