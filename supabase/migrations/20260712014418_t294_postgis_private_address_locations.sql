-- T-294 private PostGIS address locations and distance-aware matching.
-- Local migration only; Q-108 owns authorized remote application.

create extension if not exists postgis with schema extensions;

create table app_private.address_locations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  provider text not null,
  place_id text,
  country_code text not null,
  latitude double precision not null,
  longitude double precision not null,
  location extensions.geography(point, 4326) generated always as (
    extensions.st_setsrid(
      extensions.st_makepoint(longitude, latitude),
      4326
    )::extensions.geography
  ) stored,
  resolution_source text not null,
  user_confirmed_at timestamptz not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint address_locations_provider_check check (provider = 'apple_maps'),
  constraint address_locations_place_id_check check (
    place_id is null
    or (
      place_id = btrim(place_id)
      and char_length(place_id) between 1 and 512
    )
  ),
  constraint address_locations_country_code_check check (country_code = 'US'),
  constraint address_locations_latitude_check check (latitude between -90 and 90),
  constraint address_locations_longitude_check check (longitude between -180 and 180),
  constraint address_locations_resolution_source_check check (
    resolution_source in (
      'autocomplete_selection',
      'manual_geocode',
      'legacy_backfill'
    )
  )
);

comment on table app_private.address_locations is
  'Private Apple Maps resolution metadata used for service-distance matching. Exact coordinates and complete Place IDs are never exposed through public table grants.';
comment on column app_private.address_locations.location is
  'Generated WGS84 geography point; longitude is X and latitude is Y.';

create index address_locations_location_gist_idx
on app_private.address_locations using gist (location);

create index address_locations_owner_idx
on app_private.address_locations (owner_id);

alter table app_private.address_locations enable row level security;

revoke all on table app_private.address_locations
from public, anon, authenticated;
grant select, insert, update, delete on table app_private.address_locations
to service_role;

create trigger address_locations_set_updated_at
before update on app_private.address_locations
for each row execute function app_private.set_updated_at();

alter table public.customer_profiles
  add column if not exists address_line_2 text,
  add column if not exists address_location_id uuid;

alter table public.customer_profiles
  add constraint customer_profiles_address_line_2_check check (
    address_line_2 is null
    or (
      address_line_2 = btrim(address_line_2)
      and char_length(address_line_2) between 1 and 60
    )
  ),
  add constraint customer_profiles_address_location_fkey
    foreign key (address_location_id)
    references app_private.address_locations (id)
    on delete set null;

alter table public.groomer_profiles
  add column if not exists base_address_line_2 text,
  add column if not exists address_location_id uuid;

alter table public.groomer_profiles
  add constraint groomer_profiles_base_address_line_2_check check (
    base_address_line_2 is null
    or (
      base_address_line_2 = btrim(base_address_line_2)
      and char_length(base_address_line_2) between 1 and 60
    )
  ),
  add constraint groomer_profiles_address_location_fkey
    foreign key (address_location_id)
    references app_private.address_locations (id)
    on delete set null;

alter table public.grooming_requests
  add column if not exists address_line_2 text,
  add column if not exists address_location_id uuid;

alter table public.grooming_requests
  add constraint grooming_requests_address_line_2_check check (
    address_line_2 is null
    or (
      address_line_2 = btrim(address_line_2)
      and char_length(address_line_2) between 1 and 60
    )
  ),
  add constraint grooming_requests_address_location_fkey
    foreign key (address_location_id)
    references app_private.address_locations (id)
    on delete set null;

create index customer_profiles_address_location_idx
on public.customer_profiles (address_location_id)
where address_location_id is not null;

create index groomer_profiles_address_location_idx
on public.groomer_profiles (address_location_id)
where address_location_id is not null;

create index grooming_requests_address_location_idx
on public.grooming_requests (address_location_id)
where address_location_id is not null;

comment on column public.customer_profiles.address_line_2 is
  'Optional customer profile apartment, unit, suite, floor, building, or room.';
comment on column public.groomer_profiles.base_address_line_2 is
  'Optional groomer base apartment, unit, suite, floor, building, or room.';
comment on column public.grooming_requests.address_line_2 is
  'Optional request-time service-location secondary address snapshot.';
comment on column public.customer_profiles.address_location_id is
  'Opaque reference to private Apple Maps resolution metadata.';
comment on column public.groomer_profiles.address_location_id is
  'Opaque reference to private Apple Maps resolution metadata.';
comment on column public.grooming_requests.address_location_id is
  'Opaque reference to private request-time Apple Maps resolution metadata.';

create function app_private.save_address_location_v2(
  p_owner_id uuid,
  p_existing_location_id uuid,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_location_id uuid;
  v_provider text := lower(btrim(p_provider));
  v_place_id text := nullif(btrim(p_place_id), '');
  v_country_code text := upper(btrim(p_country_code));
  v_resolution_source text := lower(btrim(p_resolution_source));
begin
  if p_owner_id is null
    or v_provider is null
    or v_provider <> 'apple_maps'
    or v_country_code is null
    or v_country_code <> 'US'
    or p_latitude is null
    or p_longitude is null
    or p_latitude not between -90 and 90
    or p_longitude not between -180 and 180
    or v_resolution_source is null
    or v_resolution_source not in (
      'autocomplete_selection',
      'manual_geocode',
      'legacy_backfill'
    )
    or p_user_confirmed_at is null
    or p_user_confirmed_at > statement_timestamp() + interval '5 minutes'
    or (v_place_id is not null and char_length(v_place_id) > 512)
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_confirmed_address';
  end if;

  if p_existing_location_id is not null then
    update app_private.address_locations as address_location
    set
      provider = v_provider,
      place_id = v_place_id,
      country_code = v_country_code,
      latitude = p_latitude,
      longitude = p_longitude,
      resolution_source = v_resolution_source,
      user_confirmed_at = p_user_confirmed_at
    where address_location.id = p_existing_location_id
      and address_location.owner_id = p_owner_id
    returning address_location.id into v_location_id;
  end if;

  if v_location_id is null then
    insert into app_private.address_locations (
      owner_id,
      provider,
      place_id,
      country_code,
      latitude,
      longitude,
      resolution_source,
      user_confirmed_at
    )
    values (
      p_owner_id,
      v_provider,
      v_place_id,
      v_country_code,
      p_latitude,
      p_longitude,
      v_resolution_source,
      p_user_confirmed_at
    )
    returning id into v_location_id;
  end if;

  return v_location_id;
end;
$$;

revoke all on function app_private.save_address_location_v2(
  uuid, uuid, text, text, text, double precision, double precision, text, timestamptz
) from public, anon, authenticated;
grant execute on function app_private.save_address_location_v2(
  uuid, uuid, text, text, text, double precision, double precision, text, timestamptz
) to service_role;

create function app_private.save_customer_profile_address_v2(
  p_line_1 text,
  p_line_2 text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz
)
returns uuid
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
  v_line_1 text := btrim(p_line_1);
  v_line_2 text := nullif(btrim(p_line_2), '');
  v_city text := btrim(p_city);
  v_state text := upper(btrim(p_state));
  v_zip_code text := btrim(p_zip_code);
  v_existing_location_id uuid;
  v_location_id uuid;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using errcode = '28000', message = 'authenticated_user_required';
  end if;

  select customer_profile.address_location_id
  into v_existing_location_id
  from public.customer_profiles as customer_profile
  join public.profiles as profile on profile.id = customer_profile.user_id
  where customer_profile.user_id = v_user_id
    and profile.role = 'customer'::public.user_role
  for update of customer_profile;

  if not found then
    raise exception using errcode = 'P0001', message = 'customer_profile_required';
  end if;

  if v_line_1 is null
    or char_length(v_line_1) not between 1 and 160
    or v_city is null
    or char_length(v_city) not between 1 and 80
    or v_state is null
    or v_state !~ '^[A-Z]{2}$'
    or v_zip_code is null
    or v_zip_code !~ '^[0-9]{5}(-[0-9]{4})?$'
    or (v_line_2 is not null and char_length(v_line_2) > 60)
  then
    raise exception using errcode = '22023', message = 'invalid_profile_address';
  end if;

  v_location_id := app_private.save_address_location_v2(
    v_user_id,
    v_existing_location_id,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolution_source,
    p_user_confirmed_at
  );

  update public.customer_profiles
  set
    street_address = v_line_1,
    address_line_2 = v_line_2,
    city = v_city,
    state = v_state,
    zip_code = v_zip_code,
    address_location_id = v_location_id
  where user_id = v_user_id;

  return v_location_id;
end;
$$;

create function public.save_customer_profile_address_v2(
  p_line_1 text,
  p_line_2 text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select app_private.save_customer_profile_address_v2(
    p_line_1,
    p_line_2,
    p_city,
    p_state,
    p_zip_code,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolution_source,
    p_user_confirmed_at
  );
$$;

create function app_private.save_groomer_profile_address_v2(
  p_line_1 text,
  p_line_2 text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz
)
returns uuid
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
  v_line_1 text := btrim(p_line_1);
  v_line_2 text := nullif(btrim(p_line_2), '');
  v_city text := btrim(p_city);
  v_state text := upper(btrim(p_state));
  v_zip_code text := btrim(p_zip_code);
  v_existing_location_id uuid;
  v_location_id uuid;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using errcode = '28000', message = 'authenticated_user_required';
  end if;

  select groomer_profile.address_location_id
  into v_existing_location_id
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile on profile.id = groomer_profile.user_id
  where groomer_profile.user_id = v_user_id
    and profile.role = 'groomer'::public.user_role
  for update of groomer_profile;

  if not found then
    raise exception using errcode = 'P0001', message = 'groomer_profile_required';
  end if;

  if v_line_1 is null
    or char_length(v_line_1) not between 1 and 160
    or v_city is null
    or char_length(v_city) not between 1 and 100
    or v_state is null
    or v_state !~ '^[A-Z]{2}$'
    or v_zip_code is null
    or v_zip_code !~ '^[0-9]{5}(-[0-9]{4})?$'
    or (v_line_2 is not null and char_length(v_line_2) > 60)
  then
    raise exception using errcode = '22023', message = 'invalid_profile_address';
  end if;

  v_location_id := app_private.save_address_location_v2(
    v_user_id,
    v_existing_location_id,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolution_source,
    p_user_confirmed_at
  );

  update public.groomer_profiles
  set
    base_street_address = v_line_1,
    base_address_line_2 = v_line_2,
    base_city = v_city,
    base_state = v_state,
    base_zip_code = v_zip_code,
    address_location_id = v_location_id
  where user_id = v_user_id;

  return v_location_id;
end;
$$;

create function public.save_groomer_profile_address_v2(
  p_line_1 text,
  p_line_2 text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select app_private.save_groomer_profile_address_v2(
    p_line_1,
    p_line_2,
    p_city,
    p_state,
    p_zip_code,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolution_source,
    p_user_confirmed_at
  );
$$;

revoke all on function app_private.save_customer_profile_address_v2(
  text, text, text, text, text, text, text, text,
  double precision, double precision, text, timestamptz
) from public, anon, authenticated;
revoke all on function app_private.save_groomer_profile_address_v2(
  text, text, text, text, text, text, text, text,
  double precision, double precision, text, timestamptz
) from public, anon, authenticated;
grant execute on function app_private.save_customer_profile_address_v2(
  text, text, text, text, text, text, text, text,
  double precision, double precision, text, timestamptz
) to authenticated, service_role;
grant execute on function app_private.save_groomer_profile_address_v2(
  text, text, text, text, text, text, text, text,
  double precision, double precision, text, timestamptz
) to authenticated, service_role;

revoke all on function public.save_customer_profile_address_v2(
  text, text, text, text, text, text, text, text,
  double precision, double precision, text, timestamptz
) from public, anon, authenticated;
revoke all on function public.save_groomer_profile_address_v2(
  text, text, text, text, text, text, text, text,
  double precision, double precision, text, timestamptz
) from public, anon, authenticated;
grant execute on function public.save_customer_profile_address_v2(
  text, text, text, text, text, text, text, text,
  double precision, double precision, text, timestamptz
) to authenticated, service_role;
grant execute on function public.save_groomer_profile_address_v2(
  text, text, text, text, text, text, text, text,
  double precision, double precision, text, timestamptz
) to authenticated, service_role;

create function app_private.get_my_customer_profile_address_v2()
returns table (
  line_1 text,
  line_2 text,
  city text,
  state text,
  zip_code text,
  provider text,
  place_id text,
  country_code text,
  latitude double precision,
  longitude double precision,
  resolution_source text,
  user_confirmed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    customer_profile.street_address,
    customer_profile.address_line_2,
    customer_profile.city,
    customer_profile.state,
    customer_profile.zip_code,
    address_location.provider,
    address_location.place_id,
    address_location.country_code,
    address_location.latitude,
    address_location.longitude,
    address_location.resolution_source,
    address_location.user_confirmed_at
  from public.customer_profiles as customer_profile
  join public.profiles as profile
    on profile.id = customer_profile.user_id
   and profile.role = 'customer'::public.user_role
  join app_private.address_locations as address_location
    on address_location.id = customer_profile.address_location_id
   and address_location.owner_id = customer_profile.user_id
  where customer_profile.user_id = (select auth.uid())
    and (select auth.uid()) is not null
    and not coalesce(
      ((select auth.jwt()) ->> 'is_anonymous')::boolean,
      false
    );
$$;

create function public.get_my_customer_profile_address_v2()
returns table (
  line_1 text,
  line_2 text,
  city text,
  state text,
  zip_code text,
  provider text,
  place_id text,
  country_code text,
  latitude double precision,
  longitude double precision,
  resolution_source text,
  user_confirmed_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app_private.get_my_customer_profile_address_v2();
$$;

create function app_private.get_my_groomer_profile_address_v2()
returns table (
  line_1 text,
  line_2 text,
  city text,
  state text,
  zip_code text,
  provider text,
  place_id text,
  country_code text,
  latitude double precision,
  longitude double precision,
  resolution_source text,
  user_confirmed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    groomer_profile.base_street_address,
    groomer_profile.base_address_line_2,
    groomer_profile.base_city,
    groomer_profile.base_state,
    groomer_profile.base_zip_code,
    address_location.provider,
    address_location.place_id,
    address_location.country_code,
    address_location.latitude,
    address_location.longitude,
    address_location.resolution_source,
    address_location.user_confirmed_at
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile
    on profile.id = groomer_profile.user_id
   and profile.role = 'groomer'::public.user_role
  join app_private.address_locations as address_location
    on address_location.id = groomer_profile.address_location_id
   and address_location.owner_id = groomer_profile.user_id
  where groomer_profile.user_id = (select auth.uid())
    and (select auth.uid()) is not null
    and not coalesce(
      ((select auth.jwt()) ->> 'is_anonymous')::boolean,
      false
    );
$$;

create function public.get_my_groomer_profile_address_v2()
returns table (
  line_1 text,
  line_2 text,
  city text,
  state text,
  zip_code text,
  provider text,
  place_id text,
  country_code text,
  latitude double precision,
  longitude double precision,
  resolution_source text,
  user_confirmed_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app_private.get_my_groomer_profile_address_v2();
$$;

revoke all on function app_private.get_my_customer_profile_address_v2()
from public, anon, authenticated;
revoke all on function app_private.get_my_groomer_profile_address_v2()
from public, anon, authenticated;
grant execute on function app_private.get_my_customer_profile_address_v2()
to authenticated;
grant execute on function app_private.get_my_groomer_profile_address_v2()
to authenticated;

revoke all on function public.get_my_customer_profile_address_v2()
from public, anon, authenticated;
revoke all on function public.get_my_groomer_profile_address_v2()
from public, anon, authenticated;
grant execute on function public.get_my_customer_profile_address_v2()
to authenticated;
grant execute on function public.get_my_groomer_profile_address_v2()
to authenticated;

create function app_private.evaluate_request_location_fit(
  p_request_location extensions.geography,
  p_groomer_location extensions.geography,
  p_location_mode text,
  p_customer_travel_radius_miles integer,
  p_groomer_service_radius_miles integer,
  p_request_state text,
  p_request_city text,
  p_groomer_state text,
  p_groomer_city text
)
returns table (
  is_eligible boolean,
  location_score integer,
  location_reason text,
  distance_miles double precision,
  allowed_radius double precision,
  used_legacy_fallback boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with measured as (
    select
      case
        when p_request_location is not null
          and p_groomer_location is not null
        then extensions.st_distance(
          p_request_location,
          p_groomer_location
        ) / 1609.344
        else null
      end as distance_miles,
      case
        when p_location_mode = 'customer_comes_to_groomer'
        then p_customer_travel_radius_miles::double precision
        else p_groomer_service_radius_miles::double precision
      end as allowed_radius,
      p_request_location is null or p_groomer_location is null
        as used_legacy_fallback
  )
  select
    case
      when not measured.used_legacy_fallback
      then measured.allowed_radius is not null
        and measured.allowed_radius > 0
        and measured.distance_miles <= measured.allowed_radius
      else p_groomer_state = p_request_state
        or lower(p_groomer_city) = lower(p_request_city)
    end as is_eligible,
    case
      when not measured.used_legacy_fallback
        and measured.allowed_radius is not null
        and measured.allowed_radius > 0
      then round(
        80 - 20 * least(
          measured.distance_miles / measured.allowed_radius,
          1
        )
      )::integer
      when p_groomer_state = p_request_state
        and lower(p_groomer_city) = lower(p_request_city)
      then 80
      when p_groomer_state = p_request_state
      then 60
      else 50
    end as location_score,
    case
      when not measured.used_legacy_fallback
        and p_location_mode = 'customer_comes_to_groomer'
      then format(
        '%s miles away, within the customer''s %s-mile travel range',
        round(measured.distance_miles::numeric, 1),
        measured.allowed_radius::integer
      )
      when not measured.used_legacy_fallback
      then format(
        '%s miles away, within the groomer''s %s-mile service range',
        round(measured.distance_miles::numeric, 1),
        measured.allowed_radius::integer
      )
      else 'Legacy location fallback'
    end as location_reason,
    measured.distance_miles,
    measured.allowed_radius,
    measured.used_legacy_fallback
  from measured;
$$;

comment on function app_private.evaluate_request_location_fit(
  extensions.geography,
  extensions.geography,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text
) is
  'Evaluates coordinate distance with the direction-correct radius; falls back to state/city only when either legacy point is missing.';

revoke all on function app_private.evaluate_request_location_fit(
  extensions.geography,
  extensions.geography,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text
) from public, anon, authenticated;
grant execute on function app_private.evaluate_request_location_fit(
  extensions.geography,
  extensions.geography,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text
) to service_role;

-- Preserve T-155 pet-fit/time-capacity behavior while replacing only location
-- eligibility, score, and reason with coordinate distance when both points exist.

create or replace function app_private.create_request_matches_for_request(
  p_request_id uuid,
  p_only_groomer_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_match_count integer := 0;
begin
  if p_request_id is null then
    return 0;
  end if;

  with selected_request as materialized (
    select request.*
    from public.grooming_requests as request
    where request.id = p_request_id
      and request.status in ('open', 'has_offers')
      and request.expires_at > statement_timestamp()
    for update of request
  ),
  request_traits as materialized (
    select trait.trait_type, trait.trait_value
    from selected_request
    cross join lateral app_private.pet_fit_traits_from_snapshot(
      selected_request.pet_snapshot,
      selected_request.service_type,
      selected_request.preferred_start::date
    ) as trait
  ),
  eligible_groomers as (
    select
      selected_request.id as request_id,
      selected_request.customer_id,
      selected_request.service_type,
      selected_request.preferred_start,
      selected_request.preferred_end,
      groomer_profile.user_id,
      location_fit.location_score,
      location_fit.location_reason,
      case
        when app_private.groomer_is_available_for_range(
          groomer_profile.user_id,
          selected_request.preferred_start,
          selected_request.preferred_end
        )
        then 'Preferred time fits'
        else 'Can suggest another time on your preferred day'
      end as availability_reason
    from selected_request
    join public.groomer_profiles as groomer_profile
      on true
    join public.profiles as profile
      on profile.id = groomer_profile.user_id
    left join app_private.address_locations as request_location
      on request_location.id = selected_request.address_location_id
     and request_location.owner_id = selected_request.customer_id
    left join app_private.address_locations as groomer_location
      on groomer_location.id = groomer_profile.address_location_id
     and groomer_location.owner_id = groomer_profile.user_id
    cross join lateral app_private.evaluate_request_location_fit(
      request_location.location,
      groomer_location.location,
      selected_request.location_mode,
      selected_request.travel_radius_miles,
      groomer_profile.service_radius_miles,
      selected_request.state,
      selected_request.city,
      groomer_profile.base_state,
      groomer_profile.base_city
    ) as location_fit
    where profile.role = 'groomer'::public.user_role
      and groomer_profile.is_active
      and location_fit.is_eligible
      and (
        p_only_groomer_id is null
        or groomer_profile.user_id = p_only_groomer_id
      )
      and (
        groomer_profile.service_location_modes @>
          array[selected_request.location_mode]::text[]
        or (
          groomer_profile.service_location_modes is null
          and groomer_profile.service_location_mode = selected_request.location_mode
        )
      )
      and exists (
        select 1
        from public.groomer_services as groomer_service
        where groomer_service.groomer_id = groomer_profile.user_id
          and groomer_service.is_active
          and groomer_service.service_type = selected_request.service_type
      )
      and app_private.groomer_has_capacity_on_request_day(
        groomer_profile.user_id,
        selected_request.preferred_start
      )
  )
  insert into public.request_matches (
    request_id,
    groomer_id,
    customer_id,
    match_score,
    match_reason,
    status
  )
  select
    eligible_groomer.request_id,
    eligible_groomer.user_id,
    eligible_groomer.customer_id,
    greatest(
      0,
      least(
        100,
        eligible_groomer.location_score +
          coalesce(pet_fit.adjustment, 0) +
          case
            when coalesce(pet_fit.has_negative_evidence, false) then 0
            else coalesce(claim_tag_fit.adjustment, 0)
          end
      )
    )::numeric(5, 2),
    left(
      case
        when pet_fit.reason_text is null
          and (
            claim_tag_fit.reason_text is null
            or coalesce(pet_fit.has_negative_evidence, false)
          )
        then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '.'
        when pet_fit.reason_text is not null
          and claim_tag_fit.reason_text is not null
          and not coalesce(pet_fit.has_negative_evidence, false)
        then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
        when pet_fit.reason_text is not null then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '.'
        else
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
      end,
      500
    ),
    'visible'
  from eligible_groomers as eligible_groomer
  left join lateral (
    select
      greatest(
        -10,
        least(20, coalesce(sum(ranked_evidence.evidence_points), 0))
      )::integer as adjustment,
      coalesce(
        bool_or(ranked_evidence.evidence_points < 0),
        false
      ) as has_negative_evidence,
      string_agg(
        ranked_evidence.reason_label,
        ', '
        order by
          case
            when ranked_evidence.evidence_points < 0 then 0
            else 1
          end,
          case
            when ranked_evidence.evidence_points < 0
            then ranked_evidence.evidence_points
            else -ranked_evidence.evidence_points
          end,
          ranked_evidence.trait_sort,
          ranked_evidence.trait_value
      ) as reason_text
    from (
      select prioritized_evidence.*
      from (
        select
          evidence.*,
          row_number() over (
            order by
              case
                when evidence.evidence_points < 0 then 0
                else 1
              end,
              case
                when evidence.evidence_points < 0 then evidence.evidence_points
                else -evidence.evidence_points
              end,
              evidence.trait_sort,
              evidence.trait_value
          ) as fairness_rank
        from (
          select
            summary.trait_type,
            summary.trait_value,
            app_private.pet_fit_trait_sort(summary.trait_type) as trait_sort,
            case
              when summary.negative_review_outcome_count >
                summary.positive_review_outcome_count
              then -4
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
                and summary.confidence_tier = 'high'
              then 8
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
                and summary.confidence_tier = 'medium'
              then 6
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
              then 4
              when summary.positive_review_outcome_count =
                summary.negative_review_outcome_count
                and summary.positive_review_outcome_count > 0
              then 2
              when summary.completed_booking_count >= 2
              then 3
              when summary.completed_booking_count >= 1
              then 1
              else 0
            end as evidence_points,
            case
              when summary.negative_review_outcome_count >
                summary.positive_review_outcome_count
              then 'mixed feedback for ' ||
                app_private.pet_fit_trait_label(
                  summary.trait_type,
                  summary.trait_value
                )
              when summary.positive_review_outcome_count > 0
              then app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              ) || ' with positive reviews'
              when summary.completed_booking_count >= 2
              then app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              ) || ' from completed bookings'
              else app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              )
            end as reason_label
          from request_traits as request_trait
          join public.groomer_pet_fit_evidence_summary as summary
            on summary.groomer_id = eligible_groomer.user_id
           and summary.trait_type = request_trait.trait_type
           and summary.trait_value = request_trait.trait_value
          where summary.completed_booking_count > 0
            or summary.structured_review_outcome_count > 0
        ) as evidence
        where evidence.evidence_points <> 0
      ) as prioritized_evidence
      where prioritized_evidence.fairness_rank <= 3
      order by prioritized_evidence.fairness_rank
    ) as ranked_evidence
  ) as pet_fit
    on true
  left join lateral (
    select
      least(
        6,
        coalesce(sum(ranked_signal.signal_points), 0)
      )::integer as adjustment,
      string_agg(
        ranked_signal.reason_label,
        ', '
        order by
          ranked_signal.signal_points desc,
          ranked_signal.signal_sort,
          ranked_signal.trait_sort,
          ranked_signal.trait_value
      ) as reason_text
    from (
      select signal.*
      from (
        select
          request_trait.trait_type,
          request_trait.trait_value,
          1 as signal_sort,
          app_private.pet_fit_trait_sort(request_trait.trait_type) as trait_sort,
          2 as signal_points,
          'portfolio tag for ' ||
            app_private.pet_fit_trait_label(
              request_trait.trait_type,
              request_trait.trait_value
            ) as reason_label
        from request_traits as request_trait
        where exists (
          select 1
          from public.groomer_portfolio_fit_tags as portfolio_tag
          where portfolio_tag.groomer_id = eligible_groomer.user_id
            and portfolio_tag.trait_type = request_trait.trait_type
            and portfolio_tag.trait_value = request_trait.trait_value
        )

        union all

        select
          request_trait.trait_type,
          request_trait.trait_value,
          2 as signal_sort,
          app_private.pet_fit_trait_sort(request_trait.trait_type) as trait_sort,
          1 as signal_points,
          'self-claimed fit for ' ||
            app_private.pet_fit_trait_label(
              request_trait.trait_type,
              request_trait.trait_value
            ) as reason_label
        from request_traits as request_trait
        where exists (
          select 1
          from public.groomer_fit_claims as claim
          where claim.groomer_id = eligible_groomer.user_id
            and claim.trait_type = request_trait.trait_type
            and claim.trait_value = request_trait.trait_value
            and claim.is_active
        )
      ) as signal
      order by
        signal.signal_points desc,
        signal.signal_sort,
        signal.trait_sort,
        signal.trait_value
      limit 3
    ) as ranked_signal
  ) as claim_tag_fit
    on true
  on conflict on constraint request_matches_request_groomer_key do nothing;

  get diagnostics v_match_count = row_count;
  return v_match_count;
end;
$$;

comment on function app_private.create_request_matches_for_request(uuid, uuid) is
  'Creates missing eligible Groomer matches using PostGIS distance and the direction-correct radius when both locations are resolved; only incomplete legacy rows use state/city fallback.';

revoke all on function app_private.create_request_matches_for_request(uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.create_request_matches_for_request(uuid, uuid)
to service_role;
create function app_private.create_grooming_request_v2(
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
  p_address_line_2 text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz,
  p_travel_radius_miles integer
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
  v_address_line_2 text := nullif(btrim(p_address_line_2), '');
  v_travel_radius_miles integer := p_travel_radius_miles;
  v_open_request_count integer;
  v_request_id uuid;
  v_location_id uuid;
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

  if v_address_line_2 is not null
    and char_length(v_address_line_2) > 60
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_address_line_2';
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
    'coat_type', v_pet.coat_type,
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

  v_location_id := app_private.save_address_location_v2(
    v_user_id,
    null,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolution_source,
    p_user_confirmed_at
  );

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
    address_line_2,
    address_location_id,
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
    v_address_line_2,
    v_location_id,
    v_travel_radius_miles,
    'open',
    statement_timestamp() + interval '48 hours'
  )
  returning id into v_request_id;

  v_match_count := app_private.create_request_matches_for_request(
    v_request_id,
    null
  );

  return query
  select v_request_id, v_match_count;
end;
$$;

create function public.create_grooming_request_v2(
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
  p_address_line_2 text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz,
  p_travel_radius_miles integer
)
returns table (
  request_id uuid,
  match_count integer
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.create_grooming_request_v2(
    p_pet_id,
    p_service_type,
    p_service_notes,
    p_preferred_start,
    p_preferred_end,
    p_location_mode,
    p_street_address,
    p_city,
    p_state,
    p_zip_code,
    p_address_line_2,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolution_source,
    p_user_confirmed_at,
    p_travel_radius_miles
  );
$$;

comment on function public.create_grooming_request_v2(
  uuid, text, text, timestamptz, timestamptz, text, text, text, text, text,
  text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) is
  'Creates a coordinate-backed grooming request snapshot and inserts matches atomically through the private distance-aware matching helper.';

revoke all on function app_private.create_grooming_request_v2(
  uuid, text, text, timestamptz, timestamptz, text, text, text, text, text,
  text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) from public, anon, authenticated;
grant execute on function app_private.create_grooming_request_v2(
  uuid, text, text, timestamptz, timestamptz, text, text, text, text, text,
  text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) to authenticated, service_role;

revoke all on function public.create_grooming_request_v2(
  uuid, text, text, timestamptz, timestamptz, text, text, text, text, text,
  text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) from public, anon, authenticated;
grant execute on function public.create_grooming_request_v2(
  uuid, text, text, timestamptz, timestamptz, text, text, text, text, text,
  text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) to authenticated, service_role;
