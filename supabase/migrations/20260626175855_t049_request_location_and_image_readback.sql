-- T-049 local migration draft.
-- Purpose: persist request location inputs and allow authenticated UI surfaces
-- to display private Storage images through signed URLs.

alter table public.grooming_requests
  add column location_mode text not null default 'come_to_me',
  add column street_address text,
  add column travel_radius_miles integer;

alter table public.grooming_requests
  add constraint grooming_requests_location_mode_check check (
    location_mode in ('come_to_me', 'visit_groomer')
  ),
  add constraint grooming_requests_street_address_check check (
    street_address is null
    or (
      street_address = btrim(street_address)
      and char_length(street_address) between 1 and 200
    )
  ),
  add constraint grooming_requests_travel_radius_miles_check check (
    travel_radius_miles is null
    or travel_radius_miles between 1 and 250
  ),
  add constraint grooming_requests_visit_range_check check (
    location_mode <> 'visit_groomer'
    or travel_radius_miles is not null
  );

comment on column public.grooming_requests.location_mode is
  'Customer-selected service location mode captured when the request is created.';
comment on column public.grooming_requests.street_address is
  'Optional street address captured from the request wizard.';
comment on column public.grooming_requests.travel_radius_miles is
  'Customer travel range in miles when the customer can visit a groomer.';

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
  p_city text,
  p_state text,
  p_zip_code text,
  p_location_mode text default 'come_to_me',
  p_street_address text default null,
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
  v_service_type text := btrim(p_service_type);
  v_service_notes text := nullif(btrim(p_service_notes), '');
  v_city text := btrim(p_city);
  v_state text := btrim(p_state);
  v_zip_code text := btrim(p_zip_code);
  v_location_mode text := coalesce(nullif(btrim(p_location_mode), ''), 'come_to_me');
  v_street_address text := nullif(btrim(p_street_address), '');
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

  if v_service_type is null
    or char_length(v_service_type) not between 1 and 80
  then
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

  if v_location_mode not in ('come_to_me', 'visit_groomer') then
    raise exception using
      errcode = '22023',
      message = 'invalid_location_mode';
  end if;

  if v_street_address is not null
    and char_length(v_street_address) > 200
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_street_address';
  end if;

  if v_location_mode = 'visit_groomer'
    and (
      v_travel_radius_miles is null
      or v_travel_radius_miles not between 1 and 250
    )
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_travel_radius_miles';
  end if;

  if v_location_mode <> 'visit_groomer' then
    v_travel_radius_miles := null;
  end if;

  if v_city is null
    or char_length(v_city) not between 1 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_city';
  end if;

  if v_state is null
    or char_length(v_state) not between 2 and 80
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_state';
  end if;

  if v_zip_code is null
    or char_length(v_zip_code) not between 3 and 20
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_zip_code';
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
    travel_radius_miles,
    city,
    state,
    zip_code,
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
    v_travel_radius_miles,
    v_city,
    v_state,
    v_zip_code,
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
      when lower(groomer_profile.base_state) = lower(v_state)
        and lower(groomer_profile.base_city) = lower(v_city)
      then 100
      when lower(groomer_profile.base_state) = lower(v_state)
      then 60
      else 40
    end,
    case
      when lower(groomer_profile.base_state) = lower(v_state)
        and lower(groomer_profile.base_city) = lower(v_city)
      then 'same_city_and_state'
      when lower(groomer_profile.base_state) = lower(v_state)
      then 'same_state'
      else 'same_city'
    end,
    'visible'
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile
    on profile.id = groomer_profile.user_id
  where profile.role = 'groomer'::public.user_role
    and groomer_profile.is_active
    and (
      lower(groomer_profile.base_state) = lower(v_state)
      or lower(groomer_profile.base_city) = lower(v_city)
    )
    and exists (
      select 1
      from public.groomer_services as groomer_service
      where groomer_service.groomer_id = groomer_profile.user_id
        and groomer_service.is_active
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
  'Creates a customer grooming request, freezes pet/photo snapshots and request location, and creates eligible groomer matches atomically.';

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

drop policy if exists pet_photos_objects_select_own
on storage.objects;

create policy pet_photos_objects_select_owner_or_matched_groomer
on storage.objects
for select
to authenticated
using (
  bucket_id = 'pet-photos'
  and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and array_length(storage.foldername(storage.objects.name), 1) = 2
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
        from public.grooming_requests as request
        join public.request_matches as request_match
          on request_match.request_id = request.id
        where request_match.groomer_id = (select auth.uid())
          and request_match.status in ('visible', 'viewed', 'offered')
          and request.status in ('open', 'has_offers')
          and request.expires_at > statement_timestamp()
          and request.photo_snapshot @> jsonb_build_array(
            jsonb_build_object(
              'storage_bucket',
              'pet-photos',
              'storage_path',
              storage.objects.name
            )
          )
      )
    )
  )
);
