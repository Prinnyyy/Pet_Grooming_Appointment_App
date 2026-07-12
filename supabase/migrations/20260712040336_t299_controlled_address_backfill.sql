-- T-299 service-role-only controlled legacy address backfill.

create function app_private.list_address_backfill_targets()
returns table (
  source_kind text,
  source_id uuid,
  owner_id uuid,
  line_1 text,
  line_2 text,
  city text,
  state text,
  zip_code text
)
language sql
security definer
set search_path = ''
as $$
  select
    'groomer_profile'::text,
    groomer_profile.user_id,
    groomer_profile.user_id,
    groomer_profile.base_street_address,
    groomer_profile.base_address_line_2,
    groomer_profile.base_city,
    groomer_profile.base_state,
    groomer_profile.base_zip_code
  from public.groomer_profiles as groomer_profile
  where groomer_profile.address_location_id is null
    and nullif(btrim(groomer_profile.base_street_address), '') is not null
    and nullif(btrim(groomer_profile.base_city), '') is not null
    and nullif(btrim(groomer_profile.base_state), '') is not null
    and nullif(btrim(groomer_profile.base_zip_code), '') is not null

  union all

  select
    'customer_profile'::text,
    customer_profile.user_id,
    customer_profile.user_id,
    customer_profile.street_address,
    customer_profile.address_line_2,
    customer_profile.city,
    customer_profile.state,
    customer_profile.zip_code
  from public.customer_profiles as customer_profile
  where customer_profile.address_location_id is null
    and nullif(btrim(customer_profile.street_address), '') is not null
    and nullif(btrim(customer_profile.city), '') is not null
    and nullif(btrim(customer_profile.state), '') is not null
    and nullif(btrim(customer_profile.zip_code), '') is not null

  union all

  select
    'active_request'::text,
    grooming_request.id,
    grooming_request.customer_id,
    grooming_request.street_address,
    grooming_request.address_line_2,
    grooming_request.city,
    grooming_request.state,
    grooming_request.zip_code
  from public.grooming_requests as grooming_request
  where grooming_request.address_location_id is null
    and grooming_request.status in ('open', 'has_offers')
    and nullif(btrim(grooming_request.street_address), '') is not null
    and nullif(btrim(grooming_request.city), '') is not null
    and nullif(btrim(grooming_request.state), '') is not null
    and nullif(btrim(grooming_request.zip_code), '') is not null
  order by 1, 2;
$$;

create function public.list_address_backfill_targets()
returns table (
  source_kind text,
  source_id uuid,
  owner_id uuid,
  line_1 text,
  line_2 text,
  city text,
  state text,
  zip_code text
)
language sql
security invoker
set search_path = ''
as $$
  select * from app_private.list_address_backfill_targets();
$$;

create function app_private.backfill_address_location(
  p_source_kind text,
  p_source_id uuid,
  p_expected_line_1 text,
  p_expected_line_2 text,
  p_expected_city text,
  p_expected_state text,
  p_expected_zip_code text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolved_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_kind text := lower(btrim(p_source_kind));
  v_owner_id uuid;
  v_line_1 text;
  v_line_2 text;
  v_city text;
  v_state text;
  v_zip_code text;
  v_existing_location_id uuid;
  v_location_id uuid;
begin
  if v_source_kind = 'customer_profile' then
    select
      customer_profile.user_id,
      customer_profile.street_address,
      customer_profile.address_line_2,
      customer_profile.city,
      customer_profile.state,
      customer_profile.zip_code,
      customer_profile.address_location_id
    into
      v_owner_id, v_line_1, v_line_2, v_city, v_state, v_zip_code,
      v_existing_location_id
    from public.customer_profiles as customer_profile
    where customer_profile.user_id = p_source_id
    for update of customer_profile;
  elsif v_source_kind = 'groomer_profile' then
    select
      groomer_profile.user_id,
      groomer_profile.base_street_address,
      groomer_profile.base_address_line_2,
      groomer_profile.base_city,
      groomer_profile.base_state,
      groomer_profile.base_zip_code,
      groomer_profile.address_location_id
    into
      v_owner_id, v_line_1, v_line_2, v_city, v_state, v_zip_code,
      v_existing_location_id
    from public.groomer_profiles as groomer_profile
    where groomer_profile.user_id = p_source_id
    for update of groomer_profile;
  elsif v_source_kind = 'active_request' then
    select
      grooming_request.customer_id,
      grooming_request.street_address,
      grooming_request.address_line_2,
      grooming_request.city,
      grooming_request.state,
      grooming_request.zip_code,
      grooming_request.address_location_id
    into
      v_owner_id, v_line_1, v_line_2, v_city, v_state, v_zip_code,
      v_existing_location_id
    from public.grooming_requests as grooming_request
    where grooming_request.id = p_source_id
      and grooming_request.status in ('open', 'has_offers')
    for update of grooming_request;
  else
    raise exception using errcode = '22023', message = 'invalid_address_backfill_source';
  end if;

  if not found then
    raise exception using errcode = 'P0002', message = 'address_backfill_target_missing';
  end if;
  if v_existing_location_id is not null then
    raise exception using
      errcode = 'P0001',
      message = 'address_backfill_target_already_resolved';
  end if;
  if btrim(v_line_1) is distinct from btrim(p_expected_line_1)
    or nullif(btrim(v_line_2), '') is distinct from nullif(btrim(p_expected_line_2), '')
    or btrim(v_city) is distinct from btrim(p_expected_city)
    or upper(btrim(v_state)) is distinct from upper(btrim(p_expected_state))
    or btrim(v_zip_code) is distinct from btrim(p_expected_zip_code)
  then
    raise exception using errcode = '40001', message = 'address_backfill_target_changed';
  end if;

  v_location_id := app_private.save_address_location_v2(
    v_owner_id,
    null,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    'legacy_backfill',
    p_resolved_at
  );

  if v_source_kind = 'customer_profile' then
    update public.customer_profiles
    set address_location_id = v_location_id
    where user_id = p_source_id and address_location_id is null;
  elsif v_source_kind = 'groomer_profile' then
    update public.groomer_profiles
    set address_location_id = v_location_id
    where user_id = p_source_id and address_location_id is null;
  else
    update public.grooming_requests
    set address_location_id = v_location_id
    where id = p_source_id
      and status in ('open', 'has_offers')
      and address_location_id is null;
  end if;

  if not found then
    raise exception using errcode = '40001', message = 'address_backfill_target_changed';
  end if;
  return v_location_id;
end;
$$;

create function public.backfill_address_location(
  p_source_kind text,
  p_source_id uuid,
  p_expected_line_1 text,
  p_expected_line_2 text,
  p_expected_city text,
  p_expected_state text,
  p_expected_zip_code text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolved_at timestamptz
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select app_private.backfill_address_location(
    p_source_kind,
    p_source_id,
    p_expected_line_1,
    p_expected_line_2,
    p_expected_city,
    p_expected_state,
    p_expected_zip_code,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolved_at
  );
$$;

create function app_private.backfill_address_locations(p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_count integer := 0;
begin
  if jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) not between 1 and 500
  then
    raise exception using errcode = '22023', message = 'invalid_address_backfill_batch';
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    perform app_private.backfill_address_location(
      v_item ->> 'source_kind',
      (v_item ->> 'source_id')::uuid,
      v_item ->> 'expected_line_1',
      v_item ->> 'expected_line_2',
      v_item ->> 'expected_city',
      v_item ->> 'expected_state',
      v_item ->> 'expected_zip_code',
      v_item ->> 'provider',
      v_item ->> 'place_id',
      v_item ->> 'country_code',
      (v_item ->> 'latitude')::double precision,
      (v_item ->> 'longitude')::double precision,
      (v_item ->> 'resolved_at')::timestamptz
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create function public.backfill_address_locations(p_items jsonb)
returns integer
language sql
security invoker
set search_path = ''
as $$
  select app_private.backfill_address_locations(p_items);
$$;

create function app_private.get_address_backfill_summary()
returns table (
  customer_missing_count bigint,
  groomer_missing_count bigint,
  active_request_missing_count bigint,
  customer_incomplete_count bigint,
  groomer_incomplete_count bigint,
  active_request_incomplete_count bigint,
  orphan_legacy_location_count bigint
)
language sql
security definer
set search_path = ''
as $$
  select
    (
      select count(*) from public.customer_profiles as customer_profile
      where customer_profile.address_location_id is null
        and nullif(btrim(customer_profile.street_address), '') is not null
        and nullif(btrim(customer_profile.city), '') is not null
        and nullif(btrim(customer_profile.state), '') is not null
        and nullif(btrim(customer_profile.zip_code), '') is not null
    ),
    (
      select count(*) from public.groomer_profiles as groomer_profile
      where groomer_profile.address_location_id is null
        and nullif(btrim(groomer_profile.base_street_address), '') is not null
        and nullif(btrim(groomer_profile.base_city), '') is not null
        and nullif(btrim(groomer_profile.base_state), '') is not null
        and nullif(btrim(groomer_profile.base_zip_code), '') is not null
    ),
    (
      select count(*) from public.grooming_requests as grooming_request
      where grooming_request.address_location_id is null
        and grooming_request.status in ('open', 'has_offers')
        and nullif(btrim(grooming_request.street_address), '') is not null
        and nullif(btrim(grooming_request.city), '') is not null
        and nullif(btrim(grooming_request.state), '') is not null
        and nullif(btrim(grooming_request.zip_code), '') is not null
    ),
    (
      select count(*) from public.customer_profiles as customer_profile
      where customer_profile.address_location_id is null
        and (
          nullif(btrim(customer_profile.street_address), '') is null
          or nullif(btrim(customer_profile.city), '') is null
          or nullif(btrim(customer_profile.state), '') is null
          or nullif(btrim(customer_profile.zip_code), '') is null
        )
    ),
    (
      select count(*) from public.groomer_profiles as groomer_profile
      where groomer_profile.address_location_id is null
        and (
          nullif(btrim(groomer_profile.base_street_address), '') is null
          or nullif(btrim(groomer_profile.base_city), '') is null
          or nullif(btrim(groomer_profile.base_state), '') is null
          or nullif(btrim(groomer_profile.base_zip_code), '') is null
        )
    ),
    (
      select count(*) from public.grooming_requests as grooming_request
      where grooming_request.address_location_id is null
        and grooming_request.status in ('open', 'has_offers')
        and (
          nullif(btrim(grooming_request.street_address), '') is null
          or nullif(btrim(grooming_request.city), '') is null
          or nullif(btrim(grooming_request.state), '') is null
          or nullif(btrim(grooming_request.zip_code), '') is null
        )
    ),
    (
      select count(*) from app_private.address_locations as address_location
      where address_location.resolution_source = 'legacy_backfill'
        and not exists (
          select 1 from public.customer_profiles as customer_profile
          where customer_profile.address_location_id = address_location.id
        )
        and not exists (
          select 1 from public.groomer_profiles as groomer_profile
          where groomer_profile.address_location_id = address_location.id
        )
        and not exists (
          select 1 from public.grooming_requests as grooming_request
          where grooming_request.address_location_id = address_location.id
        )
    );
$$;

create function public.get_address_backfill_summary()
returns table (
  customer_missing_count bigint,
  groomer_missing_count bigint,
  active_request_missing_count bigint,
  customer_incomplete_count bigint,
  groomer_incomplete_count bigint,
  active_request_incomplete_count bigint,
  orphan_legacy_location_count bigint
)
language sql
security invoker
set search_path = ''
as $$
  select * from app_private.get_address_backfill_summary();
$$;

revoke all on function app_private.list_address_backfill_targets()
from public, anon, authenticated, service_role;
revoke all on function app_private.backfill_address_location(
  text, uuid, text, text, text, text, text, text, text, text,
  double precision, double precision, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function app_private.get_address_backfill_summary()
from public, anon, authenticated, service_role;
revoke all on function app_private.backfill_address_locations(jsonb)
from public, anon, authenticated, service_role;

grant execute on function app_private.list_address_backfill_targets()
to service_role;
grant execute on function app_private.backfill_address_location(
  text, uuid, text, text, text, text, text, text, text, text,
  double precision, double precision, timestamptz
) to service_role;
grant execute on function app_private.get_address_backfill_summary()
to service_role;
grant execute on function app_private.backfill_address_locations(jsonb)
to service_role;

revoke all on function public.list_address_backfill_targets()
from public, anon, authenticated, service_role;
revoke all on function public.backfill_address_location(
  text, uuid, text, text, text, text, text, text, text, text,
  double precision, double precision, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.get_address_backfill_summary()
from public, anon, authenticated, service_role;
revoke all on function public.backfill_address_locations(jsonb)
from public, anon, authenticated, service_role;

grant execute on function public.list_address_backfill_targets()
to service_role;
grant execute on function public.backfill_address_location(
  text, uuid, text, text, text, text, text, text, text, text,
  double precision, double precision, timestamptz
) to service_role;
grant execute on function public.get_address_backfill_summary()
to service_role;
grant execute on function public.backfill_address_locations(jsonb)
to service_role;

comment on function public.list_address_backfill_targets() is
  'Service-role-only complete display addresses that still require private coordinates.';
comment on function public.backfill_address_location(
  text, uuid, text, text, text, text, text, text, text, text,
  double precision, double precision, timestamptz
) is 'Service-role-only snapshot-checked Apple Maps legacy coordinate backfill.';
comment on function public.get_address_backfill_summary() is
  'Service-role-only gap and orphan summary for controlled address backfill.';
comment on function public.backfill_address_locations(jsonb) is
  'Service-role-only atomic batch wrapper for reviewed Apple Maps legacy backfill.';
