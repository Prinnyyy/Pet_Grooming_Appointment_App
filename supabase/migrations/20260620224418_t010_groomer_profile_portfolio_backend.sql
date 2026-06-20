-- T-010 reviewed draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

alter table public.groomer_profiles
  add column business_name text,
  add column bio text,
  add column years_experience integer,
  add column base_city text,
  add column base_state text,
  add column service_radius_miles integer,
  add column rating_avg numeric(3, 2) not null default 0,
  add column rating_count integer not null default 0,
  add column is_active boolean not null default false,
  add column is_verified boolean not null default false,
  add constraint groomer_profiles_business_name_check check (
    business_name is null
    or (
      business_name = btrim(business_name)
      and char_length(business_name) between 1 and 120
    )
  ),
  add constraint groomer_profiles_bio_check check (
    bio is null
    or (
      bio = btrim(bio)
      and char_length(bio) between 1 and 2000
    )
  ),
  add constraint groomer_profiles_years_experience_check check (
    years_experience is null
    or years_experience between 0 and 80
  ),
  add constraint groomer_profiles_base_city_check check (
    base_city is null
    or (
      base_city = btrim(base_city)
      and char_length(base_city) between 1 and 100
    )
  ),
  add constraint groomer_profiles_base_state_check check (
    base_state is null
    or (
      base_state = btrim(base_state)
      and char_length(base_state) between 2 and 80
    )
  ),
  add constraint groomer_profiles_service_radius_check check (
    service_radius_miles is null
    or service_radius_miles between 1 and 250
  ),
  add constraint groomer_profiles_rating_check check (
    rating_avg between 0 and 5
    and rating_count >= 0
    and (
      (rating_count = 0 and rating_avg = 0)
      or rating_count > 0
    )
  ),
  add constraint groomer_profiles_active_completeness_check check (
    not is_active
    or (
      business_name is not null
      and base_city is not null
      and base_state is not null
      and service_radius_miles is not null
    )
  );

comment on column public.groomer_profiles.business_name is
  'Marketplace-facing groomer business name.';
comment on column public.groomer_profiles.bio is
  'Marketplace-facing groomer biography.';
comment on column public.groomer_profiles.rating_avg is
  'Server-maintained average review rating. Groomers cannot update this column directly.';
comment on column public.groomer_profiles.rating_count is
  'Server-maintained review count. Groomers cannot update this column directly.';
comment on column public.groomer_profiles.is_verified is
  'Server-maintained verification flag. Groomers cannot update this column directly.';

create table public.groomer_services (
  id uuid primary key default gen_random_uuid(),
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  title text not null,
  description text,
  base_price numeric(10, 2) not null,
  duration_minutes integer not null,
  accepted_pet_sizes text[] not null default '{}'::text[],
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groomer_services_title_check check (
    title = btrim(title)
    and char_length(title) between 1 and 80
  ),
  constraint groomer_services_description_check check (
    description is null
    or (
      description = btrim(description)
      and char_length(description) between 1 and 500
    )
  ),
  constraint groomer_services_base_price_check check (
    base_price >= 0
    and base_price <= 100000
  ),
  constraint groomer_services_duration_check check (
    duration_minutes between 15 and 720
  ),
  constraint groomer_services_sizes_check check (
    accepted_pet_sizes <@ array[
      'small',
      'medium',
      'large',
      'giant'
    ]::text[]
    and cardinality(accepted_pet_sizes) <= 4
  )
);

comment on table public.groomer_services is
  'Groomer-owned service offerings visible to authenticated users only when active and attached to an active groomer profile.';

create table public.groomer_portfolio_photos (
  id uuid primary key default gen_random_uuid(),
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  storage_bucket text not null default 'groomer-portfolio',
  storage_path text not null,
  caption text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint groomer_portfolio_bucket_check check (
    storage_bucket = 'groomer-portfolio'
  ),
  constraint groomer_portfolio_path_check check (
    storage_path = btrim(storage_path)
    and char_length(storage_path) between 1 and 512
    and array_length(string_to_array(storage_path, '/'), 1) = 2
    and split_part(storage_path, '/', 1) = groomer_id::text
    and lower(split_part(storage_path, '/', 2)) ~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpe?g|png|heic|heif)$'
  ),
  constraint groomer_portfolio_caption_check check (
    caption is null
    or (
      caption = btrim(caption)
      and char_length(caption) between 1 and 500
    )
  ),
  constraint groomer_portfolio_sort_order_check check (
    sort_order between 0 and 9999
  ),
  constraint groomer_portfolio_storage_path_key unique (
    storage_bucket,
    storage_path
  )
);

comment on table public.groomer_portfolio_photos is
  'Groomer-owned metadata for portfolio Storage objects.';

create index groomer_profiles_active_city_idx
on public.groomer_profiles (is_active, base_state, base_city);

create index groomer_services_groomer_active_created_idx
on public.groomer_services (groomer_id, is_active, created_at desc);

create index groomer_portfolio_groomer_sort_idx
on public.groomer_portfolio_photos (groomer_id, sort_order, created_at);

create trigger groomer_services_set_updated_at
before update on public.groomer_services
for each row execute function app_private.set_updated_at();

alter table public.groomer_services enable row level security;
alter table public.groomer_portfolio_photos enable row level security;

revoke all on table public.groomer_services from public, anon, authenticated;
revoke all on table public.groomer_portfolio_photos from public, anon, authenticated;

grant update (
  business_name,
  bio,
  years_experience,
  base_city,
  base_state,
  service_radius_miles,
  is_active
) on table public.groomer_profiles to authenticated;

grant select on table public.groomer_services to authenticated;
grant insert (
  groomer_id,
  title,
  description,
  base_price,
  duration_minutes,
  accepted_pet_sizes,
  is_active
) on table public.groomer_services to authenticated;
grant update (
  title,
  description,
  base_price,
  duration_minutes,
  accepted_pet_sizes,
  is_active
) on table public.groomer_services to authenticated;
grant delete on table public.groomer_services to authenticated;

grant select on table public.groomer_portfolio_photos to authenticated;
grant insert (
  groomer_id,
  storage_bucket,
  storage_path,
  caption,
  sort_order
) on table public.groomer_portfolio_photos to authenticated;
grant update (
  caption,
  sort_order
) on table public.groomer_portfolio_photos to authenticated;
grant delete on table public.groomer_portfolio_photos to authenticated;

grant select, insert, update, delete
on table public.groomer_services, public.groomer_portfolio_photos
to service_role;

create policy groomer_profiles_select_active_authenticated
on public.groomer_profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and is_active
);

create policy groomer_profiles_update_own
on public.groomer_profiles
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and user_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
)
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

create policy groomer_services_select_own
on public.groomer_services
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
);

create policy groomer_services_select_active_groomer
on public.groomer_services
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and is_active
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = groomer_services.groomer_id
      and is_active
  )
);

create policy groomer_services_insert_own
on public.groomer_services
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create policy groomer_services_update_own
on public.groomer_services
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
)
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create policy groomer_services_delete_own
on public.groomer_services
for delete
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create policy groomer_portfolio_select_own
on public.groomer_portfolio_photos
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
);

create policy groomer_portfolio_select_active_groomer
on public.groomer_portfolio_photos
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = groomer_portfolio_photos.groomer_id
      and is_active
  )
);

create policy groomer_portfolio_insert_own
on public.groomer_portfolio_photos
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create policy groomer_portfolio_update_own
on public.groomer_portfolio_photos
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
)
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create policy groomer_portfolio_delete_own
on public.groomer_portfolio_photos
for delete
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
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
  'groomer-portfolio',
  'groomer-portfolio',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']::text[]
);

create policy groomer_portfolio_objects_select_active_authenticated
on storage.objects
for select
to authenticated
using (
  bucket_id = 'groomer-portfolio'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and storage.allow_any_operation(array[
    'object.get_authenticated_info',
    'object.get_authenticated'
  ])
  and array_length(storage.foldername(storage.objects.name), 1) = 1
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
);

create policy groomer_portfolio_objects_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'groomer-portfolio'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
);

create policy groomer_portfolio_objects_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'groomer-portfolio'
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
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create policy groomer_portfolio_objects_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'groomer-portfolio'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
)
with check (
  bucket_id = 'groomer-portfolio'
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
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create policy groomer_portfolio_objects_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'groomer-portfolio'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 1
  and (storage.foldername(storage.objects.name))[1] =
    (select auth.uid())::text
);
