-- T-110 dedicated groomer avatar Storage bucket.
--
-- This keeps the four app photo surfaces separated:
-- - groomer avatar: groomer-avatars
-- - groomer portfolio: groomer-portfolio
-- - customer pet profile photos: pet-photos
-- - grooming quest photos: request-photos

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'groomer-avatars',
  'groomer-avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy groomer_avatar_objects_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'groomer-avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

create policy groomer_avatar_objects_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'groomer-avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
  and lower(storage.extension(storage.objects.name)) in (
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif'
  )
  and lower(split_part(storage.objects.name, '/', 2)) ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpe?g|png|heic|heif)$'
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

create policy groomer_avatar_objects_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'groomer-avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
)
with check (
  bucket_id = 'groomer-avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
  and lower(storage.extension(storage.objects.name)) in (
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif'
  )
  and lower(split_part(storage.objects.name, '/', 2)) ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpe?g|png|heic|heif)$'
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

create policy groomer_avatar_objects_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'groomer-avatars'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

comment on constraint profiles_avatar_path_check on public.profiles is
  'Ensures private avatar_path stays under the owning user folder and uses an allowed image extension. Groomer avatar writes use the groomer-avatars bucket.';
