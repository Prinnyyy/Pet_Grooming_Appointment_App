-- T-263 permits a customer to render the private avatar of a Groomer who sent
-- that customer an offer or is attached to one of the customer's bookings.
-- Ownership policies remain unchanged.

create policy profiles_select_booking_groomer_avatar
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and profiles.role = 'groomer'::public.user_role
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
);

create policy groomer_avatar_objects_select_booking_customer
on storage.objects
for select
to authenticated
using (
  bucket_id = 'groomer-avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (
    exists (
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
