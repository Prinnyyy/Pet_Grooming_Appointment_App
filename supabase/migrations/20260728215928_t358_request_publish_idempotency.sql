create table app_private.request_publish_operations (
  customer_id uuid not null references public.profiles (id) on delete cascade,
  operation_id uuid not null,
  request_id uuid not null references public.grooming_requests (id) on delete cascade,
  match_count integer not null check (match_count >= 0),
  created_at timestamptz not null default statement_timestamp(),
  primary key (customer_id, operation_id)
);

create index request_publish_operations_request_idx
on app_private.request_publish_operations (request_id);

alter table app_private.request_publish_operations enable row level security;

revoke all on table app_private.request_publish_operations
from public, anon, authenticated;

comment on table app_private.request_publish_operations is
  'Private replay record for one Customer Request publish operation. Clients receive results only through create_grooming_request_v3.';

create function app_private.create_grooming_request_v3(
  p_publish_operation_id uuid,
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
  v_existing_request_id uuid;
  v_existing_match_count integer;
  v_request_id uuid;
  v_match_count integer;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_publish_operation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_publish_operation';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_user_id::text || ':' || p_publish_operation_id::text,
      0
    )
  );

  select
    publish_operation.request_id,
    publish_operation.match_count
  into
    v_existing_request_id,
    v_existing_match_count
  from app_private.request_publish_operations as publish_operation
  where publish_operation.customer_id = v_user_id
    and publish_operation.operation_id = p_publish_operation_id;

  if found then
    return query
    select v_existing_request_id, v_existing_match_count;
    return;
  end if;

  select
    created_request.request_id,
    created_request.match_count
  into
    v_request_id,
    v_match_count
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
  ) as created_request;

  if v_request_id is null or v_match_count is null then
    raise exception using
      errcode = 'P0001',
      message = 'request_publish_result_missing';
  end if;

  insert into app_private.request_publish_operations (
    customer_id,
    operation_id,
    request_id,
    match_count
  )
  values (
    v_user_id,
    p_publish_operation_id,
    v_request_id,
    v_match_count
  );

  return query
  select v_request_id, v_match_count;
end;
$$;

create function public.create_grooming_request_v3(
  p_publish_operation_id uuid,
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
  from app_private.create_grooming_request_v3(
    p_publish_operation_id,
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

comment on function public.create_grooming_request_v3(
  uuid, uuid, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) is
  'Creates one coordinate-backed Request per Customer publish operation and replays its original result on retry.';

revoke all on function app_private.create_grooming_request_v3(
  uuid, uuid, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) from public, anon, authenticated;
grant execute on function app_private.create_grooming_request_v3(
  uuid, uuid, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) to authenticated, service_role;

revoke all on function public.create_grooming_request_v3(
  uuid, uuid, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) from public, anon, authenticated;
grant execute on function public.create_grooming_request_v3(
  uuid, uuid, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, text, text, double precision, double precision, text,
  timestamptz, integer
) to authenticated, service_role;
