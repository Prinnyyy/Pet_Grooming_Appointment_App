-- T-300 removes the temporary state/city matching fallback after the reviewed
-- backfill proved zero active Groomer and Request coordinate gaps.

do $$
begin
  if exists (
    select 1
    from public.groomer_profiles as groomer_profile
    left join app_private.address_locations as address_location
      on address_location.id = groomer_profile.address_location_id
     and address_location.owner_id = groomer_profile.user_id
    where groomer_profile.is_active
      and address_location.location is null
  ) then
    raise exception 'strict_coordinate_cutover_active_groomer_gap';
  end if;

  if exists (
    select 1
    from public.grooming_requests as grooming_request
    left join app_private.address_locations as address_location
      on address_location.id = grooming_request.address_location_id
     and address_location.owner_id = grooming_request.customer_id
    where grooming_request.status in ('open', 'has_offers')
      and grooming_request.expires_at > statement_timestamp()
      and address_location.location is null
  ) then
    raise exception 'strict_coordinate_cutover_active_request_gap';
  end if;
end;
$$;

create or replace function app_private.evaluate_request_location_fit(
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
      end as allowed_radius
  )
  select
    p_request_location is not null
      and p_groomer_location is not null
      and measured.allowed_radius is not null
      and measured.allowed_radius > 0
      and measured.distance_miles <= measured.allowed_radius
      as is_eligible,
    case
      when p_request_location is not null
        and p_groomer_location is not null
        and measured.allowed_radius is not null
        and measured.allowed_radius > 0
      then round(
        80 - 20 * least(
          measured.distance_miles / measured.allowed_radius,
          1
        )
      )::integer
      else 0
    end as location_score,
    case
      when p_request_location is not null
        and p_groomer_location is not null
        and measured.allowed_radius is not null
        and measured.allowed_radius > 0
        and p_location_mode = 'customer_comes_to_groomer'
      then format(
        '%s miles away, within the customer''s %s-mile travel range',
        round(measured.distance_miles::numeric, 1),
        measured.allowed_radius::integer
      )
      when p_request_location is not null
        and p_groomer_location is not null
        and measured.allowed_radius is not null
        and measured.allowed_radius > 0
      then format(
        '%s miles away, within the groomer''s %s-mile service range',
        round(measured.distance_miles::numeric, 1),
        measured.allowed_radius::integer
      )
      else null::text
    end as location_reason,
    measured.distance_miles,
    measured.allowed_radius,
    false as used_legacy_fallback
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
  'Evaluates strict coordinate distance with the direction-correct radius; missing coordinates are ineligible and text fields are retained only for signature compatibility.';

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

comment on function app_private.create_request_matches_for_request(uuid, uuid) is
  'Creates missing eligible Groomer matches using strict PostGIS distance and the direction-correct radius; rows with either coordinate missing are ineligible.';

-- Retire the pre-coordinate publishing endpoint. Existing released code and
-- TestOps use create_grooming_request_v2 before this strict cutover.
revoke all on function public.create_grooming_request(
  uuid, text, text, timestamptz, timestamptz, text, text, text, text, text, integer
) from public, anon, authenticated;
revoke all on function app_private.create_grooming_request(
  uuid, text, text, timestamptz, timestamptz, text, text, text, text, text, integer
) from public, anon, authenticated, service_role;
