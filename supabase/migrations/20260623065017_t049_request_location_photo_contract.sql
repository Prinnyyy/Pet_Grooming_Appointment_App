-- T-049 reviewed draft. Remote migration version: 20260623065017.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Purpose: persist fixed service options, request location mode/address,
-- groomer service-location capability, and request-specific photo uploads.

update public.grooming_requests
set service_type = case
  when lower(service_type) in ('full groom', 'full_groom') then 'full_groom'
  when lower(service_type) in ('bath & brush', 'bath and brush', 'bath_and_brush', 'bath') then 'bath_and_brush'
  when lower(service_type) in ('haircut only', 'haircut_only', 'haircut') then 'haircut_only'
  when lower(service_type) in ('nail trim', 'nail_trim', 'nails') then 'nail_trim'
  when lower(service_type) in ('de-shedding', 'de shedding', 'deshedding', 'de_shedding') then 'de_shedding'
  when lower(service_type) in ('custom request', 'custom_request') then 'custom_request'
  else 'custom_request'
end;

update public.grooming_requests
set
  state = upper(btrim(state)),
  zip_code = btrim(zip_code);

alter table public.grooming_requests
  drop constraint if exists grooming_requests_service_type_check,
  drop constraint if exists grooming_requests_state_check,
  drop constraint if exists grooming_requests_zip_code_check,
  add column if not exists location_mode text not null default 'groomer_comes_to_customer',
  add column if not exists street_address text not null default 'Address unavailable',
  add column if not exists travel_radius_miles integer,
  add constraint grooming_requests_service_type_check check (
    service_type in (
      'full_groom',
      'bath_and_brush',
      'haircut_only',
      'nail_trim',
      'de_shedding',
      'custom_request'
    )
  ),
  add constraint grooming_requests_location_mode_check check (
    location_mode in (
      'groomer_comes_to_customer',
      'customer_comes_to_groomer'
    )
  ),
  add constraint grooming_requests_street_address_check check (
    street_address = btrim(street_address)
    and char_length(street_address) between 1 and 160
  ),
  add constraint grooming_requests_state_check check (
    state ~ '^[A-Z]{2}$'
  ),
  add constraint grooming_requests_zip_code_check check (
    zip_code ~ '^[0-9]{5}(-[0-9]{4})?$'
  ),
  add constraint grooming_requests_travel_radius_check check (
    (
      location_mode = 'groomer_comes_to_customer'
      and travel_radius_miles is null
    )
    or (
      location_mode = 'customer_comes_to_groomer'
      and travel_radius_miles between 5 and 100
    )
  );

comment on column public.grooming_requests.location_mode is
  'Service-location mode requested by the customer.';
comment on column public.grooming_requests.street_address is
  'Customer-entered normalized street address for matching and request context.';
comment on column public.grooming_requests.travel_radius_miles is
  'Customer travel radius when visiting a groomer location.';

update public.groomer_profiles
set base_state = upper(base_state)
where base_state is not null;

alter table public.groomer_profiles
  drop constraint if exists groomer_profiles_base_state_check,
  drop constraint if exists groomer_profiles_active_completeness_check,
  add column if not exists service_location_mode text;

update public.groomer_profiles
set service_location_mode = 'groomer_comes_to_customer'
where is_active
  and service_location_mode is null;

alter table public.groomer_profiles
  add constraint groomer_profiles_base_state_check check (
    base_state is null
    or base_state ~ '^[A-Z]{2}$'
  ),
  add constraint groomer_profiles_service_location_mode_check check (
    service_location_mode is null
    or service_location_mode in (
      'groomer_comes_to_customer',
      'customer_comes_to_groomer'
    )
  ),
  add constraint groomer_profiles_active_completeness_check check (
    not is_active
    or (
      business_name is not null
      and base_city is not null
      and base_state is not null
      and service_radius_miles is not null
      and service_location_mode is not null
    )
  );

comment on column public.groomer_profiles.service_location_mode is
  'Groomer service-location capability: travels to customers or hosts appointments at own location.';

grant update (
  business_name,
  bio,
  years_experience,
  base_city,
  base_state,
  service_radius_miles,
  service_location_mode,
  is_active
) on table public.groomer_profiles to authenticated;

alter table public.groomer_services
  add column if not exists service_type text;

update public.groomer_services
set service_type = case
  when lower(title) in ('full groom', 'full_groom') then 'full_groom'
  when lower(title) in ('bath & brush', 'bath and brush', 'bath_and_brush', 'bath') then 'bath_and_brush'
  when lower(title) in ('haircut only', 'haircut_only', 'haircut') then 'haircut_only'
  when lower(title) in ('nail trim', 'nail_trim', 'nails') then 'nail_trim'
  when lower(title) in ('de-shedding', 'de shedding', 'deshedding', 'de_shedding') then 'de_shedding'
  when lower(title) in ('custom request', 'custom_request') then 'custom_request'
  else 'custom_request'
end
where service_type is null;

alter table public.groomer_services
  alter column service_type set not null,
  alter column service_type set default 'custom_request',
  add constraint groomer_services_service_type_check check (
    service_type in (
      'full_groom',
      'bath_and_brush',
      'haircut_only',
      'nail_trim',
      'de_shedding',
      'custom_request'
    )
  );

comment on column public.groomer_services.service_type is
  'Fixed service option used for customer-request matching.';

grant insert (
  groomer_id,
  service_type,
  title,
  description,
  base_price,
  duration_minutes,
  accepted_pet_sizes,
  is_active
) on table public.groomer_services to authenticated;

grant update (
  service_type,
  title,
  description,
  base_price,
  duration_minutes,
  accepted_pet_sizes,
  is_active
) on table public.groomer_services to authenticated;

create table if not exists public.request_photos (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  storage_bucket text not null default 'request-photos',
  storage_path text not null,
  caption text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint request_photos_request_customer_fkey
    foreign key (request_id, customer_id)
    references public.grooming_requests (id, customer_id)
    on delete cascade,
  constraint request_photos_bucket_check check (
    storage_bucket = 'request-photos'
  ),
  constraint request_photos_path_check check (
    storage_path = btrim(storage_path)
    and char_length(storage_path) between 1 and 512
    and array_length(string_to_array(storage_path, '/'), 1) = 3
    and split_part(storage_path, '/', 1) = customer_id::text
    and split_part(storage_path, '/', 2) = request_id::text
    and lower(split_part(storage_path, '/', 3)) ~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpe?g|png|heic|heif)$'
  ),
  constraint request_photos_caption_check check (
    caption is null
    or (
      caption = btrim(caption)
      and char_length(caption) between 1 and 500
    )
  ),
  constraint request_photos_sort_order_check check (
    sort_order between 0 and 20
  ),
  constraint request_photos_storage_path_key unique (
    storage_bucket,
    storage_path
  )
);

comment on table public.request_photos is
  'Customer-owned metadata for request-specific Storage objects.';

create index if not exists grooming_requests_location_mode_state_city_idx
on public.grooming_requests (location_mode, state, city, status);

create index if not exists groomer_profiles_location_mode_state_city_idx
on public.groomer_profiles (service_location_mode, is_active, base_state, base_city);

create index if not exists groomer_services_type_active_idx
on public.groomer_services (service_type, is_active, groomer_id);

create index if not exists request_photos_request_sort_idx
on public.request_photos (request_id, sort_order, created_at);

alter table public.request_photos enable row level security;

revoke all on table public.request_photos from public, anon, authenticated;

grant select on table public.request_photos to authenticated;
grant insert (
  request_id,
  customer_id,
  storage_bucket,
  storage_path,
  caption,
  sort_order
) on table public.request_photos to authenticated;
grant update (
  caption,
  sort_order
) on table public.request_photos to authenticated;
grant delete on table public.request_photos to authenticated;

grant select, insert, update, delete
on table public.request_photos
to service_role;

create policy request_photos_select_customer_or_matched_groomer
on public.request_photos
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    customer_id = (select auth.uid())
    or exists (
      select 1
      from public.request_matches as request_match
      join public.grooming_requests as request
        on request.id = request_match.request_id
       and request.customer_id = request_match.customer_id
      where request_match.request_id = request_photos.request_id
        and request_match.groomer_id = (select auth.uid())
        and request_match.status in ('visible', 'viewed', 'offered')
        and request.status in ('open', 'has_offers')
        and request.expires_at > statement_timestamp()
    )
  )
);

create policy request_photos_insert_customer_own_open_request
on public.request_photos
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.grooming_requests as request
    where request.id = request_photos.request_id
      and request.customer_id = (select auth.uid())
      and request.status in ('open', 'has_offers')
  )
);

create policy request_photos_update_customer_own
on public.request_photos
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
)
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
);

create policy request_photos_delete_customer_own
on public.request_photos
for delete
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'request-photos',
  'request-photos',
  false,
  10485760,
  array[
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy request_photos_objects_select_customer_or_matched_groomer
on storage.objects
for select
to authenticated
using (
  bucket_id = 'request-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and array_length(storage.foldername(storage.objects.name), 1) = 2
  and (
    (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    or exists (
      select 1
      from public.request_photos as photo
      join public.request_matches as request_match
        on request_match.request_id = photo.request_id
       and request_match.customer_id = photo.customer_id
      join public.grooming_requests as request
        on request.id = photo.request_id
       and request.customer_id = photo.customer_id
      where photo.storage_bucket = storage.objects.bucket_id
        and photo.storage_path = storage.objects.name
        and request_match.groomer_id = (select auth.uid())
        and request_match.status in ('visible', 'viewed', 'offered')
        and request.status in ('open', 'has_offers')
        and request.expires_at > statement_timestamp()
    )
  )
);

create policy request_photos_objects_insert_customer_open_request
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'request-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and array_length(storage.foldername(storage.objects.name), 1) = 2
  and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
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
    from public.grooming_requests as request
    where request.id::text = (storage.foldername(storage.objects.name))[2]
      and request.customer_id = (select auth.uid())
      and request.status in ('open', 'has_offers')
  )
);

create policy request_photos_objects_delete_customer_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'request-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and array_length(storage.foldername(storage.objects.name), 1) = 2
  and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
);

drop function if exists public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text
);

create function public.create_grooming_request(
  p_pet_id uuid,
  p_service_type text,
  p_service_notes text,
  p_preferred_start timestamptz,
  p_preferred_end timestamptz,
  p_location_mode text,
  p_street_address text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_travel_radius_miles integer default null
)
returns table (
  request_id uuid,
  match_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_service_type text := lower(btrim(p_service_type));
  v_service_notes text := nullif(btrim(p_service_notes), '');
  v_location_mode text := lower(btrim(p_location_mode));
  v_street_address text := btrim(p_street_address);
  v_city text := btrim(p_city);
  v_state text := upper(btrim(p_state));
  v_zip_code text := btrim(p_zip_code);
  v_travel_radius_miles integer := p_travel_radius_miles;
  v_open_request_count integer;
  v_request_id uuid;
  v_match_count integer := 0;
  v_pet public.pets%rowtype;
  v_pet_snapshot jsonb;
  v_photo_snapshot jsonb;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  perform 1
  from public.customer_profiles as customer_profile
  join public.profiles as profile
    on profile.id = customer_profile.user_id
  where customer_profile.user_id = v_user_id
    and profile.role = 'customer'::public.user_role
  for update of customer_profile;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'customer_profile_required';
  end if;

  if p_pet_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_pet';
  end if;

  if v_service_type not in (
    'full_groom',
    'bath_and_brush',
    'haircut_only',
    'nail_trim',
    'de_shedding',
    'custom_request'
  ) then
    raise exception using
      errcode = '22023',
      message = 'invalid_service_type';
  end if;

  if v_service_notes is not null
    and char_length(v_service_notes) > 2000
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_service_notes';
  end if;

  if p_preferred_start is null
    or p_preferred_end is null
    or p_preferred_start <= statement_timestamp()
    or p_preferred_end <= p_preferred_start
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_preferred_range';
  end if;

  if v_location_mode not in (
    'groomer_comes_to_customer',
    'customer_comes_to_groomer'
  ) then
    raise exception using
      errcode = '22023',
      message = 'invalid_location_mode';
  end if;

  if v_street_address is null
    or char_length(v_street_address) not between 1 and 160
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_street_address';
  end if;

  if v_city is null
    or char_length(v_city) not between 1 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_city';
  end if;

  if v_state is null
    or v_state !~ '^[A-Z]{2}$'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_state';
  end if;

  if v_zip_code is null
    or v_zip_code !~ '^[0-9]{5}(-[0-9]{4})?$'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_zip_code';
  end if;

  if v_location_mode = 'groomer_comes_to_customer' then
    v_travel_radius_miles := null;
  elsif v_travel_radius_miles is null
    or v_travel_radius_miles not between 5 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_travel_radius';
  end if;

  select count(*)::integer
  into v_open_request_count
  from public.grooming_requests as request
  where request.customer_id = v_user_id
    and request.status in ('open', 'has_offers')
    and request.expires_at > statement_timestamp();

  if v_open_request_count >= 3 then
    raise exception using
      errcode = 'P0001',
      message = 'open_request_limit_exceeded';
  end if;

  select pet.*
  into v_pet
  from public.pets as pet
  where pet.id = p_pet_id
    and pet.customer_id = v_user_id
    and pet.is_active
    and pet.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'pet_not_found';
  end if;

  v_pet_snapshot := jsonb_build_object(
    'id', v_pet.id,
    'name', v_pet.name,
    'species', v_pet.species,
    'breed', v_pet.breed,
    'size', v_pet.size,
    'weight_lbs', v_pet.weight_lbs,
    'birthday', v_pet.birthday,
    'temperament', v_pet.temperament,
    'medical_notes', v_pet.medical_notes,
    'grooming_notes', v_pet.grooming_notes,
    'snapshot_at', statement_timestamp()
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', photo.id,
        'storage_bucket', photo.storage_bucket,
        'storage_path', photo.storage_path,
        'caption', photo.caption,
        'sort_order', photo.sort_order,
        'is_primary', photo.is_primary,
        'created_at', photo.created_at
      )
      order by photo.is_primary desc, photo.sort_order, photo.created_at
    ),
    '[]'::jsonb
  )
  into v_photo_snapshot
  from (
    select photo.*
    from public.pet_photos as photo
    where photo.customer_id = v_user_id
      and photo.pet_id = p_pet_id
    order by photo.is_primary desc, photo.sort_order, photo.created_at
    limit 20
  ) as photo;

  insert into public.grooming_requests (
    customer_id,
    pet_id,
    pet_snapshot,
    photo_snapshot,
    service_type,
    service_notes,
    preferred_start,
    preferred_end,
    location_mode,
    street_address,
    city,
    state,
    zip_code,
    travel_radius_miles,
    status,
    expires_at
  )
  values (
    v_user_id,
    p_pet_id,
    v_pet_snapshot,
    v_photo_snapshot,
    v_service_type,
    v_service_notes,
    p_preferred_start,
    p_preferred_end,
    v_location_mode,
    v_street_address,
    v_city,
    v_state,
    v_zip_code,
    v_travel_radius_miles,
    'open',
    statement_timestamp() + interval '48 hours'
  )
  returning id into v_request_id;

  insert into public.request_matches (
    request_id,
    groomer_id,
    customer_id,
    match_score,
    match_reason,
    status
  )
  select
    v_request_id,
    groomer_profile.user_id,
    v_user_id,
    case
      when groomer_profile.base_state = v_state
        and lower(groomer_profile.base_city) = lower(v_city)
      then 100
      when groomer_profile.base_state = v_state
      then 60
      else 40
    end,
    case
      when groomer_profile.base_state = v_state
        and lower(groomer_profile.base_city) = lower(v_city)
      then 'same_city_state_service_location'
      when groomer_profile.base_state = v_state
      then 'same_state_service_location'
      else 'same_city_service_location'
    end,
    'visible'
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile
    on profile.id = groomer_profile.user_id
  where profile.role = 'groomer'::public.user_role
    and groomer_profile.is_active
    and groomer_profile.service_location_mode = v_location_mode
    and (
      groomer_profile.base_state = v_state
      or lower(groomer_profile.base_city) = lower(v_city)
    )
    and exists (
      select 1
      from public.groomer_services as groomer_service
      where groomer_service.groomer_id = groomer_profile.user_id
        and groomer_service.is_active
        and groomer_service.service_type = v_service_type
    )
  on conflict on constraint request_matches_request_groomer_key do nothing;

  get diagnostics v_match_count = row_count;

  return query
  select v_request_id, v_match_count;
end;
$$;

comment on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text,
  text,
  integer
) is
  'Creates a fixed-service customer grooming request with persisted location mode/address and creates eligible groomer matches atomically.';

revoke all on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text,
  text,
  integer
) from public, anon, authenticated;

grant execute on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text,
  text,
  integer
) to authenticated, service_role;
