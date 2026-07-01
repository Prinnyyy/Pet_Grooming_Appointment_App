-- T-127 customer profile settings and dedicated customer avatar Storage bucket.

alter table public.customer_profiles
  add column if not exists street_address text,
  add column if not exists city text,
  add column if not exists state text,
  add column if not exists zip_code text,
  add column if not exists contact_email text,
  add column if not exists phone_number text;

alter table public.customer_profiles
  add constraint customer_profiles_street_address_check check (
    street_address is null
    or (
      street_address = btrim(street_address)
      and char_length(street_address) between 1 and 160
    )
  ),
  add constraint customer_profiles_city_check check (
    city is null
    or (
      city = btrim(city)
      and char_length(city) between 1 and 80
    )
  ),
  add constraint customer_profiles_state_check check (
    state is null
    or state ~ '^[A-Z]{2}$'
  ),
  add constraint customer_profiles_zip_code_check check (
    zip_code is null
    or zip_code ~ '^[0-9]{5}(-[0-9]{4})?$'
  ),
  add constraint customer_profiles_contact_email_check check (
    contact_email is null
    or (
      contact_email = btrim(contact_email)
      and char_length(contact_email) between 3 and 254
      and contact_email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    )
  ),
  add constraint customer_profiles_phone_number_check check (
    phone_number is null
    or (
      phone_number = btrim(phone_number)
      and char_length(phone_number) between 7 and 32
      and phone_number ~ '^[0-9+(). -]+$'
    )
  );

comment on column public.customer_profiles.street_address is
  'Customer-owned profile street address for account/contact settings.';
comment on column public.customer_profiles.city is
  'Customer-owned profile city for account/contact settings.';
comment on column public.customer_profiles.state is
  'Customer-owned two-letter state code for account/contact settings.';
comment on column public.customer_profiles.zip_code is
  'Customer-owned postal ZIP code for account/contact settings.';
comment on column public.customer_profiles.contact_email is
  'Customer-owned contact email display value; auth email remains the sign-in identity.';
comment on column public.customer_profiles.phone_number is
  'Customer-owned profile phone number for account/contact settings.';

grant insert (
  user_id,
  street_address,
  city,
  state,
  zip_code,
  contact_email,
  phone_number
)
on table public.customer_profiles to authenticated;

grant update (
  street_address,
  city,
  state,
  zip_code,
  contact_email,
  phone_number
)
on table public.customer_profiles to authenticated;

create policy customer_profiles_update_own
on public.customer_profiles
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and user_id = (select auth.uid())
)
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

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'customer-avatars',
  'customer-avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy customer_avatar_objects_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'customer-avatars'
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
      and role = 'customer'::public.user_role
  )
);

create policy customer_avatar_objects_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'customer-avatars'
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
      and role = 'customer'::public.user_role
  )
);

create policy customer_avatar_objects_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'customer-avatars'
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
      and role = 'customer'::public.user_role
  )
)
with check (
  bucket_id = 'customer-avatars'
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
      and role = 'customer'::public.user_role
  )
);

create policy customer_avatar_objects_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'customer-avatars'
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
      and role = 'customer'::public.user_role
  )
);
