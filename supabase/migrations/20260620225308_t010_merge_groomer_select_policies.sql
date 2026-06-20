-- T-010 corrective draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Purpose: merge equivalent permissive SELECT policies reported by the
-- Supabase performance advisor without changing access boundaries.

drop policy groomer_profiles_select_own
on public.groomer_profiles;

drop policy groomer_profiles_select_active_authenticated
on public.groomer_profiles;

create policy groomer_profiles_select_own_or_active_authenticated
on public.groomer_profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    user_id = (select auth.uid())
    or is_active
  )
);

drop policy groomer_services_select_own
on public.groomer_services;

drop policy groomer_services_select_active_groomer
on public.groomer_services;

create policy groomer_services_select_own_or_active_groomer
on public.groomer_services
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    groomer_id = (select auth.uid())
    or (
      is_active
      and exists (
        select 1
        from public.groomer_profiles
        where user_id = groomer_services.groomer_id
          and is_active
      )
    )
  )
);

drop policy groomer_portfolio_select_own
on public.groomer_portfolio_photos;

drop policy groomer_portfolio_select_active_groomer
on public.groomer_portfolio_photos;

create policy groomer_portfolio_select_own_or_active_groomer
on public.groomer_portfolio_photos
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    groomer_id = (select auth.uid())
    or exists (
      select 1
      from public.groomer_profiles
      where user_id = groomer_portfolio_photos.groomer_id
        and is_active
    )
  )
);

drop policy groomer_portfolio_objects_select_own
on storage.objects;

drop policy groomer_portfolio_objects_select_active_authenticated
on storage.objects;

create policy groomer_portfolio_objects_select_own_or_active_authenticated
on storage.objects
for select
to authenticated
using (
  bucket_id = 'groomer-portfolio'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (
    (
      owner_id = (select auth.uid())::text
      and (storage.foldername(storage.objects.name))[1] =
        (select auth.uid())::text
    )
    or (
      storage.allow_any_operation(array[
        'object.get_authenticated_info',
        'object.get_authenticated'
      ])
      and exists (
        select 1
        from public.groomer_portfolio_photos as portfolio
        join public.groomer_profiles as groomer
          on groomer.user_id = portfolio.groomer_id
        where portfolio.storage_bucket = 'groomer-portfolio'
          and portfolio.storage_path = storage.objects.name
          and portfolio.groomer_id::text =
            (storage.foldername(storage.objects.name))[1]
          and groomer.is_active
      )
    )
  )
);
