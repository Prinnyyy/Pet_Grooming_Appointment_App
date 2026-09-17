-- T-059 Groomer profile full address, multi-location mode, and avatar-ready profile updates.
-- Authorized target: lqmasbuqzvcvtawonjlb.

create or replace function app_private.normalize_groomer_service_location_modes(p_modes text[])
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(mode order by sort_order), array[]::text[])
  from (
    select distinct
      mode,
      case mode
        when 'groomer_comes_to_customer' then 1
        when 'customer_comes_to_groomer' then 2
        else 99
      end as sort_order
    from unnest(coalesce(p_modes, array[]::text[])) as input(mode)
    where mode in (
      'groomer_comes_to_customer',
      'customer_comes_to_groomer'
    )
  ) as normalized;
$$;

create or replace function app_private.valid_groomer_service_location_modes(p_modes text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_modes is not null
    and cardinality(p_modes) between 1 and 2
    and p_modes = app_private.normalize_groomer_service_location_modes(p_modes);
$$;

revoke all on function app_private.normalize_groomer_service_location_modes(text[])
from public, anon, authenticated;
revoke all on function app_private.valid_groomer_service_location_modes(text[])
from public, anon, authenticated;

grant execute on function app_private.normalize_groomer_service_location_modes(text[])
to authenticated, service_role;
grant execute on function app_private.valid_groomer_service_location_modes(text[])
to authenticated, service_role;

alter table public.groomer_profiles
  add column if not exists base_street_address text,
  add column if not exists base_zip_code text,
  add column if not exists service_location_modes text[];

update public.groomer_profiles
set
  years_experience = least(greatest(years_experience, 0), 5)
where years_experience is not null
  and years_experience not between 0 and 5;

update public.groomer_profiles
set
  service_radius_miles = least(greatest(service_radius_miles, 5), 50)
where service_radius_miles is not null
  and service_radius_miles not between 5 and 50;

update public.groomer_profiles
set service_location_modes = app_private.normalize_groomer_service_location_modes(
  coalesce(service_location_modes, array[service_location_mode]::text[])
)
where service_location_modes is null
  and service_location_mode is not null;

create or replace function app_private.sync_groomer_profile_location_modes()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.service_location_modes is null
    or cardinality(new.service_location_modes) = 0
  then
    if new.service_location_mode is null then
      new.service_location_modes := null;
    else
      new.service_location_modes :=
        app_private.normalize_groomer_service_location_modes(
          array[new.service_location_mode]::text[]
        );
      new.service_location_mode := new.service_location_modes[1];
    end if;
  else
    new.service_location_modes :=
      app_private.normalize_groomer_service_location_modes(new.service_location_modes);
    new.service_location_mode := new.service_location_modes[1];
  end if;

  return new;
end;
$$;

revoke all on function app_private.sync_groomer_profile_location_modes()
from public, anon, authenticated;
grant execute on function app_private.sync_groomer_profile_location_modes()
to authenticated, service_role;

drop trigger if exists groomer_profiles_sync_location_modes
on public.groomer_profiles;

create trigger groomer_profiles_sync_location_modes
before insert or update of service_location_mode, service_location_modes
on public.groomer_profiles
for each row execute function app_private.sync_groomer_profile_location_modes();

alter table public.groomer_profiles
  drop constraint if exists groomer_profiles_years_experience_check,
  drop constraint if exists groomer_profiles_service_radius_check,
  drop constraint if exists groomer_profiles_base_street_address_check,
  drop constraint if exists groomer_profiles_base_zip_code_check,
  drop constraint if exists groomer_profiles_service_location_modes_check,
  drop constraint if exists groomer_profiles_active_completeness_check,
  add constraint groomer_profiles_years_experience_check check (
    years_experience is null
    or years_experience between 0 and 5
  ),
  add constraint groomer_profiles_service_radius_check check (
    service_radius_miles is null
    or service_radius_miles between 5 and 50
  ),
  add constraint groomer_profiles_base_street_address_check check (
    base_street_address is null
    or (
      base_street_address = btrim(base_street_address)
      and char_length(base_street_address) between 1 and 160
    )
  ),
  add constraint groomer_profiles_base_zip_code_check check (
    base_zip_code is null
    or base_zip_code ~ '^[0-9]{5}(-[0-9]{4})?$'
  ),
  add constraint groomer_profiles_service_location_modes_check check (
    service_location_modes is null
    or app_private.valid_groomer_service_location_modes(service_location_modes)
  ),
  add constraint groomer_profiles_active_completeness_check check (
    not is_active
    or (
      business_name is not null
      and base_city is not null
      and base_state is not null
      and service_radius_miles is not null
      and service_location_modes is not null
      and cardinality(service_location_modes) > 0
    )
  );

comment on column public.groomer_profiles.base_street_address is
  'Street address for groomer-hosted appointments or the groomer base address for mobile service.';
comment on column public.groomer_profiles.base_zip_code is
  'ZIP code for groomer-hosted appointments or the groomer base ZIP for mobile service.';
comment on column public.groomer_profiles.service_location_modes is
  'Canonical service-location capabilities supported by the groomer. Replaces the legacy single service_location_mode for matching.';
comment on column public.groomer_profiles.service_location_mode is
  'Legacy primary service-location mode kept for compatibility; synced from service_location_modes.';

grant update (
  business_name,
  bio,
  years_experience,
  base_street_address,
  base_city,
  base_state,
  base_zip_code,
  service_radius_miles,
  service_location_mode,
  service_location_modes,
  is_active
) on table public.groomer_profiles to authenticated;

create index if not exists groomer_profiles_location_modes_gin_idx
on public.groomer_profiles using gin (service_location_modes);

drop function if exists public.create_grooming_request(
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
    and (
      groomer_profile.service_location_modes @> array[v_location_mode]::text[]
      or (
        groomer_profile.service_location_modes is null
        and groomer_profile.service_location_mode = v_location_mode
      )
    )
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
  'Creates a fixed-service customer grooming request with persisted location mode/address and creates eligible groomer matches by multi-location groomer capabilities.';

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
