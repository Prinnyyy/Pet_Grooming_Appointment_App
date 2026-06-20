-- T-004 advisor remediation: initialize auth.jwt() once per statement.

alter policy profiles_select_own
on public.profiles
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and id = (select auth.uid())
);

alter policy profiles_insert_own
on public.profiles
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and id = (select auth.uid())
);

alter policy profiles_update_own
on public.profiles
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and id = (select auth.uid())
)
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and id = (select auth.uid())
);

alter policy customer_profiles_select_own
on public.customer_profiles
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and user_id = (select auth.uid())
);

alter policy customer_profiles_insert_own_role
on public.customer_profiles
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and user_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'customer'::public.user_role
  )
);

alter policy groomer_profiles_select_own
on public.groomer_profiles
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and user_id = (select auth.uid())
);

alter policy groomer_profiles_insert_own_role
on public.groomer_profiles
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and user_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

alter policy avatars_select_own
on storage.objects
using (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

alter policy avatars_insert_own_folder
on storage.objects
with check (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'heic', 'heif')
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
  )
);

alter policy avatars_update_own
on storage.objects
using (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'heic', 'heif')
);

alter policy avatars_delete_own
on storage.objects
using (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
