-- T-399: a legacy operation may replay only its original protocol receipt.
create or replace function app_private.create_grooming_request_v3(
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
    if exists(select 1 from app_private.request_publish_operations o
      where o.customer_id=v_user_id and o.operation_id=p_publish_operation_id and o.protocol_version<>'legacyV4') then
      raise exception using errcode='22023',message='publish_operation_intent_changed';
    end if;
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

create or replace function app_private.create_grooming_request_v4(
  p_publish_operation_id uuid,p_request jsonb,p_preference_time_zone_identifier text
)
returns table(request_id uuid,match_count integer)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_request uuid;
  v_count integer;
begin
  if v_user is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_publish_operation_id is null then
    raise exception using errcode='22023',message='invalid_publish_operation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_user::text || ':' || p_publish_operation_id::text,0));
  select o.request_id,o.match_count into v_request,v_count
    from app_private.request_publish_operations o
    where o.customer_id=v_user and o.operation_id=p_publish_operation_id;
  if found then
    if exists(select 1 from app_private.request_publish_operations o
      where o.customer_id=v_user and o.operation_id=p_publish_operation_id and o.protocol_version<>'legacyV4') then
      raise exception using errcode='22023',message='publish_operation_intent_changed';
    end if;
    return query select v_request,v_count;
    return;
  end if;
  if jsonb_typeof(p_request) is distinct from 'object'
     or p_preference_time_zone_identifier is null or not exists (
       select 1 from pg_catalog.pg_timezone_names where name=p_preference_time_zone_identifier
     ) then
    raise exception using errcode='22023',message='request_reference_time_zone_required';
  end if;
  select r.request_id,r.match_count into strict v_request,v_count
    from app_private.create_grooming_request_v3(p_publish_operation_id,
      (p_request->>'pet_id')::uuid,p_request->>'service_type',p_request->>'service_notes',
      (p_request->>'preferred_start')::timestamptz,(p_request->>'preferred_end')::timestamptz,
      p_request->>'location_mode',p_request->>'street_address',p_request->>'city',
      p_request->>'state',p_request->>'zip_code',p_request->>'address_line_2',
      p_request->>'provider',p_request->>'place_id',p_request->>'country_code',
      (p_request->>'latitude')::double precision,(p_request->>'longitude')::double precision,
      p_request->>'resolution_source',(p_request->>'user_confirmed_at')::timestamptz,
      (p_request->>'travel_radius_miles')::integer) r;
  update public.grooming_requests set preference_time_zone_identifier=p_preference_time_zone_identifier
    where id=v_request and customer_id=v_user;
  perform app_private.create_request_matches_for_request(v_request);
  select count(*)::integer into v_count from public.request_matches m
    where m.request_id=v_request and m.status in ('visible','viewed','offered');
  update app_private.request_publish_operations o set match_count=v_count
    where o.customer_id=v_user and o.operation_id=p_publish_operation_id;
  return query select v_request,v_count;
end $$;

create or replace function app_private.supersede_grooming_request(p_request_id uuid,p_expected_request_revision uuid,
  p_publish_operation_id uuid,p_request jsonb,p_preference_time_zone_identifier text)
returns table(request_id uuid,match_count integer)
language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); original public.grooming_requests%rowtype;
  replacement uuid; matches integer;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_publish_operation_id is null then raise exception using errcode='22023',message='invalid_publish_operation'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||':'||p_publish_operation_id::text,0));
  select o.request_id,o.match_count into replacement,matches from app_private.request_publish_operations o
    where o.customer_id=actor and o.operation_id=p_publish_operation_id;
  if found then
    if exists(select 1 from app_private.request_publish_operations o
      where o.customer_id=actor and o.operation_id=p_publish_operation_id and o.protocol_version<>'legacyV4') then
      raise exception using errcode='22023',message='publish_operation_intent_changed';
    end if;
    if not exists(select 1 from public.grooming_requests r where r.id=replacement and r.customer_id=actor
      and r.supersedes_request_id=p_request_id) then
      raise exception using errcode='22023',message='publish_operation_intent_changed';
    end if;
    return query select replacement,matches;
    return;
  end if;
  select * into original from public.grooming_requests r where r.id=p_request_id and r.customer_id=actor for update;
  if not found then raise exception using errcode='P0001',message='request_not_found'; end if;
  if original.terms_revision is distinct from p_expected_request_revision then
    raise exception using errcode='22023',message='request_revision_changed';
  end if;
  if original.status not in ('open','has_offers') or original.expires_at<=statement_timestamp() then
    raise exception using errcode='P0001',message='request_not_cancellable';
  end if;
  perform app_private.cancel_grooming_request(original.id);
  select created.request_id,created.match_count into strict replacement,matches
    from app_private.create_grooming_request_v4(p_publish_operation_id,p_request,p_preference_time_zone_identifier) created;
  update public.grooming_requests set supersedes_request_id=original.id where id=replacement and customer_id=actor;
  return query select replacement,matches;
end $$;

notify pgrst, 'reload schema';
