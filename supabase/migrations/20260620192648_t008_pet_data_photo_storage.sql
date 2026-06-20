-- T-008 reviewed draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create table public.pets (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  name text not null,
  species text not null,
  breed text,
  size text,
  weight_lbs numeric(6, 2),
  birthday date,
  temperament text,
  medical_notes text,
  grooming_notes text,
  is_active boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pets_owner_key unique (id, customer_id),
  constraint pets_name_check check (
    name = btrim(name)
    and char_length(name) between 1 and 80
  ),
  constraint pets_species_check check (
    species = btrim(species)
    and char_length(species) between 1 and 40
  ),
  constraint pets_breed_check check (
    breed is null
    or (
      breed = btrim(breed)
      and char_length(breed) between 1 and 80
    )
  ),
  constraint pets_size_check check (
    size is null
    or (
      size = btrim(size)
      and char_length(size) between 1 and 40
    )
  ),
  constraint pets_weight_lbs_check check (
    weight_lbs is null
    or weight_lbs > 0 and weight_lbs <= 1000
  ),
  constraint pets_birthday_check check (
    birthday is null
    or birthday <= current_date
  ),
  constraint pets_temperament_check check (
    temperament is null
    or (
      temperament = btrim(temperament)
      and char_length(temperament) between 1 and 500
    )
  ),
  constraint pets_medical_notes_check check (
    medical_notes is null
    or (
      medical_notes = btrim(medical_notes)
      and char_length(medical_notes) between 1 and 2000
    )
  ),
  constraint pets_grooming_notes_check check (
    grooming_notes is null
    or (
      grooming_notes = btrim(grooming_notes)
      and char_length(grooming_notes) between 1 and 2000
    )
  ),
  constraint pets_soft_delete_check check (
    (is_active and deleted_at is null)
    or (not is_active and deleted_at is not null)
  )
);

comment on table public.pets is
  'Customer-owned pet profiles. Client deletion is a soft-delete state.';

create table public.pet_photos (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null,
  customer_id uuid not null,
  storage_bucket text not null default 'pet-photos',
  storage_path text not null,
  caption text,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  constraint pet_photos_pet_owner_fkey
    foreign key (pet_id, customer_id)
    references public.pets (id, customer_id)
    on delete cascade,
  constraint pet_photos_bucket_check check (
    storage_bucket = 'pet-photos'
  ),
  constraint pet_photos_path_check check (
    storage_path = btrim(storage_path)
    and char_length(storage_path) between 1 and 512
    and array_length(string_to_array(storage_path, '/'), 1) = 3
    and split_part(storage_path, '/', 1) = customer_id::text
    and split_part(storage_path, '/', 2) = pet_id::text
    and lower(split_part(storage_path, '/', 3)) ~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpe?g|png|heic|heif)$'
  ),
  constraint pet_photos_caption_check check (
    caption is null
    or (
      caption = btrim(caption)
      and char_length(caption) between 1 and 500
    )
  ),
  constraint pet_photos_sort_order_check check (
    sort_order between 0 and 9999
  ),
  constraint pet_photos_storage_path_key unique (
    storage_bucket,
    storage_path
  )
);

comment on table public.pet_photos is
  'Owner-scoped metadata for private pet-photo Storage objects.';

create unique index pet_photos_one_primary_per_pet_idx
on public.pet_photos (pet_id)
where is_primary;

create index pets_customer_active_created_idx
on public.pets (customer_id, is_active, created_at desc);

create index pet_photos_customer_pet_sort_idx
on public.pet_photos (customer_id, pet_id, sort_order, created_at);

create trigger pets_set_updated_at
before update on public.pets
for each row execute function app_private.set_updated_at();

alter table public.pets enable row level security;
alter table public.pet_photos enable row level security;

revoke all on table public.pets from public, anon, authenticated;
revoke all on table public.pet_photos from public, anon, authenticated;

grant select on table public.pets to authenticated;
grant insert (
  customer_id,
  name,
  species,
  breed,
  size,
  weight_lbs,
  birthday,
  temperament,
  medical_notes,
  grooming_notes,
  is_active,
  deleted_at
) on table public.pets to authenticated;
grant update (
  name,
  species,
  breed,
  size,
  weight_lbs,
  birthday,
  temperament,
  medical_notes,
  grooming_notes,
  is_active,
  deleted_at
) on table public.pets to authenticated;

grant select on table public.pet_photos to authenticated;
grant insert (
  pet_id,
  customer_id,
  storage_bucket,
  storage_path,
  caption,
  sort_order,
  is_primary
) on table public.pet_photos to authenticated;
grant update (
  caption,
  sort_order,
  is_primary
) on table public.pet_photos to authenticated;
grant delete on table public.pet_photos to authenticated;

grant select, insert, update, delete
on table public.pets, public.pet_photos
to service_role;

create policy pets_select_customer_own
on public.pets
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
);

create policy pets_insert_customer_own
on public.pets
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and is_active
  and deleted_at is null
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
);

create policy pets_update_customer_own
on public.pets
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
)
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
);

create policy pet_photos_select_customer_own
on public.pet_photos
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
);

create policy pet_photos_insert_customer_active_pet
on public.pet_photos
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.pets
    where id = pet_photos.pet_id
      and customer_id = (select auth.uid())
      and is_active
      and deleted_at is null
  )
);

create policy pet_photos_update_customer_active_pet
on public.pet_photos
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
)
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.pets
    where id = pet_photos.pet_id
      and customer_id = (select auth.uid())
      and is_active
      and deleted_at is null
  )
);

create policy pet_photos_delete_customer_own
on public.pet_photos
for delete
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
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
  'pet-photos',
  'pet-photos',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']::text[]
);

create policy pet_photos_objects_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'pet-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 2
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
);

create policy pet_photos_objects_insert_active_owned_pet
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'pet-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 2
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
  and lower(storage.extension(storage.objects.name)) in (
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif'
  )
  and lower(split_part(storage.objects.name, '/', 3)) ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpe?g|png|heic|heif)$'
  and exists (
    select 1
    from public.pets
    where customer_id = (select auth.uid())
      and id::text = (storage.foldername(storage.objects.name))[2]
      and is_active
      and deleted_at is null
  )
);

create policy pet_photos_objects_update_active_owned_pet
on storage.objects
for update
to authenticated
using (
  bucket_id = 'pet-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 2
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
)
with check (
  bucket_id = 'pet-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 2
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
  and lower(storage.extension(storage.objects.name)) in (
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif'
  )
  and lower(split_part(storage.objects.name, '/', 3)) ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpe?g|png|heic|heif)$'
  and exists (
    select 1
    from public.pets
    where customer_id = (select auth.uid())
      and id::text = (storage.foldername(storage.objects.name))[2]
      and is_active
      and deleted_at is null
  )
);

create policy pet_photos_objects_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'pet-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 2
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
);
