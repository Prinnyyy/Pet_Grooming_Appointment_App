-- T-466: offers propose independent service terms; customer acceptance gives consent.
BEGIN;

CREATE OR REPLACE FUNCTION app_private.match_required_confirmations(p_snapshot jsonb, p_service_type text, p_species text[], p_sizes text[])
RETURNS text[] LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  SELECT CASE WHEN p_species IS NULL THEN ARRAY['service_species_configuration']::text[] ELSE '{}'::text[] END;
$function$;

CREATE OR REPLACE FUNCTION app_private.validate_offer_match_facts(p_request uuid, p_groomer uuid, p_confirmations text[], p_service_revision uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.grooming_requests%rowtype; s public.groomer_services%rowtype;
  required text[] := '{}'; supplied text[];
begin
  -- The request/admission writers and service-change triggers share this lock.
  -- Do not add source row locks after it: configuration UPDATE already owns its row.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_groomer::text,71071));
  select * into strict r from public.grooming_requests where id=p_request;
  if app_private.evaluate_match_constraints(p_request,p_groomer,statement_timestamp())->>'state' is distinct from 'eligible' then
    raise exception using errcode='22023',message='match_constraints_changed';
  end if;
  select * into s from app_private.offer_service_configuration(p_request,p_groomer,p_service_revision);
  if s.id is null then raise exception using errcode='22023',message='match_constraints_changed'; end if;
  if s.accepted_species is null then
    raise exception using errcode='22023',message='service_species_confirmation_required';
  end if;
  required:=app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes);
  if p_confirmations is null or array_ndims(p_confirmations)>1 then
    raise exception using errcode='22023',message='assessment_confirmation_required';
  end if;
  select array_agg(key order by key) into supplied from unnest(p_confirmations) key;
  if array_position(p_confirmations,null) is not null
    or cardinality(p_confirmations)<>(select count(distinct key) from unnest(p_confirmations) key)
    or not coalesce(supplied,'{}') <@ ARRAY['pet_size','custom_service','pet_coat','pet_matting']::text[] then
    raise exception using errcode='22023',message='assessment_confirmation_required';
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION app_private.evaluate_quote(p_offer_id uuid, p_now timestamp with time zone, p_valid_zones text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.groomer_offers%rowtype; r public.grooming_requests%rowtype;
  reason text; constraints jsonb; earliest timestamptz; notice integer; zone text;
  zone_count integer; window_count integer; required text[];
begin
  select * into o from public.groomer_offers where id=p_offer_id;
  if not found then return jsonb_build_object('terms_valid',false,'selectable',false,'reason','not_found'); end if;
  select * into strict r from public.grooming_requests where id=o.request_id;
  if o.terms_invalid_reason is not null then reason:=o.terms_invalid_reason;
  elsif o.status='withdrawn_by_groomer' then reason:='withdrawn';
  elsif o.status='expired' or least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')<=p_now then reason:='expired';
  elsif o.status<>'pending' or r.status not in ('open','has_offers') then reason:='superseded';
  elsif o.agreement_snapshot is null then reason:='legacy_unverified';
  elsif o.applied_timing_buffers is distinct from '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb
    or o.occupied_start is distinct from o.proposed_start or o.occupied_end is distinct from o.proposed_end
    then reason:='legacy_unverified'; -- Keep frozen quote facts; the existing replace-offer flow supplies new terms.

  elsif o.agreement_snapshot->>'request_revision' is distinct from r.terms_revision::text then reason:='superseded';
  elsif o.agreement_snapshot->>'groomer_eligibility_revision' is distinct from
    (select eligibility_revision::text from public.groomer_profiles where user_id=o.groomer_id)
    or o.agreement_snapshot->>'service_eligibility_revision' is distinct from
    (select eligibility_revision::text from app_private.offer_service_configuration(r.id,o.groomer_id,
      (o.agreement_snapshot->>'service_eligibility_revision')::uuid))
    or (o.agreement_snapshot->'address'->>'source_updated_at')::timestamptz is distinct from
    (select updated_at from app_private.address_locations where id=(o.agreement_snapshot->'address'->>'source_location_id')::uuid)
    then reason:='eligibility_revoked';
  else
    constraints:=app_private.evaluate_match_constraints(r.id,o.groomer_id,p_now);
    if constraints->>'state'='excluded' then reason:='eligibility_revoked'; end if;
  end if;
  if reason is null then
    select app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes)
      into required from app_private.offer_service_configuration(r.id,o.groomer_id,
        (o.agreement_snapshot->>'service_eligibility_revision')::uuid) s;
    if required is null or 'service_species_configuration'=any(required)
      or not (o.assessment_confirmations @> required and o.assessment_confirmations <@ ARRAY['pet_size','custom_service','pet_coat','pet_matting']::text[]) then
      reason:='assessment_confirmation_required';
    end if;
  end if;
  if reason is not null then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason',reason);
  end if;
  select coalesce((select minimum_advance_notice_days from public.groomer_booking_preferences
    where groomer_id=o.groomer_id),0) into notice;
  select min(timezone),count(distinct timezone),count(*) into zone,zone_count,window_count
    from public.groomer_availability_windows where groomer_id=o.groomer_id;
  if zone_count<>1 or window_count<>7 or not coalesce(zone=any(p_valid_zones),false) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  earliest:=app_private.service_timing_earliest_start_validated(p_now,notice,zone);
  if o.proposed_start<earliest then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason','expired');
  end if;
  if not app_private.groomer_can_admit_service(o.groomer_id,o.proposed_start,o.proposed_end,p_now,p_valid_zones)
    or exists(select 1 from public.bookings b where b.pet_id=r.pet_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(b.scheduled_start,app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at),'[)') && tstzrange(o.proposed_start,o.proposed_end,'[)'))
    or exists(select 1 from public.bookings b where b.groomer_id=o.groomer_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(b.scheduled_start,app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)')
        && tstzrange(o.occupied_start,o.occupied_end,'[)'))
    or app_private.occupied_time_off_conflict(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones)
    or not app_private.occupied_weekly_hours_covered(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  return jsonb_build_object('terms_valid',true,'selectable',true,'reason','available');
end $function$
;

CREATE OR REPLACE FUNCTION app_private.guard_offer_timing_consent()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_start timestamptz;
  v_end timestamptz;
  v_seconds numeric;
begin
  -- Historical status transitions do not renegotiate service times.
  if tg_op='UPDATE' then
    if row(new.request_id,new.customer_id,new.proposed_start,new.proposed_end)
       is not distinct from row(old.request_id,old.customer_id,old.proposed_start,old.proposed_end) then
      return new;
    end if;
  end if;
  if new.proposed_start is null or new.proposed_end is null
    or not pg_catalog.isfinite(new.proposed_start) or not pg_catalog.isfinite(new.proposed_end) then
    raise exception using errcode='22023',message='invalid_proposed_range';
  end if;
  v_seconds := extract(epoch from new.proposed_end-new.proposed_start);
  if v_seconds < 900 or v_seconds > 43200 or mod(v_seconds,60) <> 0 then
    raise exception using errcode='22023',message='invalid_service_duration';
  end if;
  -- Requested times remain a preference. The confirmed quote owns its exact interval;
  -- duration, advance notice, weekly hours and occupancy remain independently guarded.
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION app_private.snapshot_booking_timing()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_offer public.groomer_offers%rowtype;
begin
  if tg_op='UPDATE' then
    if app_private.authorized_reschedule_change(new,old) then return new; end if;
    if row(new.applied_timing_buffers,new.service_time_zone_identifier,new.schedule_time_zone_identifier,
        new.occupied_start,new.occupied_end) is distinct from
       row(old.applied_timing_buffers,old.service_time_zone_identifier,old.schedule_time_zone_identifier,
        old.occupied_start,old.occupied_end) then
      raise exception using errcode='23514',message='booking_timing_snapshot_immutable';
    end if;
    return new;
  end if;
  select * into v_offer from public.groomer_offers where id=new.offer_id and request_id=new.request_id
    and customer_id=new.customer_id and groomer_id=new.groomer_id;
  if not found or new.scheduled_start is distinct from v_offer.proposed_start
    or new.scheduled_end is distinct from v_offer.proposed_end then
    raise exception using errcode='23514',message='booking_offer_timing_mismatch';
  end if;
  if v_offer.occupied_start is null or v_offer.occupied_end is null
    or v_offer.service_time_zone_identifier is null or v_offer.schedule_time_zone_identifier is null
    or v_offer.applied_timing_buffers is distinct from '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb
    or v_offer.occupied_start is distinct from v_offer.proposed_start
    or v_offer.occupied_end is distinct from v_offer.proposed_end then
    raise exception using errcode='P0001',message='updated_timing_offer_required';
  end if;
  new.applied_timing_buffers := v_offer.applied_timing_buffers;
  new.service_time_zone_identifier := v_offer.service_time_zone_identifier;
  new.schedule_time_zone_identifier := v_offer.schedule_time_zone_identifier;
  new.occupied_start := v_offer.occupied_start;
  new.occupied_end := v_offer.occupied_end;
  if app_private.occupied_time_off_conflict(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_time_off_conflict';
  end if;
  if not app_private.occupied_weekly_hours_covered(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_outside_weekly_hours';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION app_private.snapshot_offer_timing()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_request public.grooming_requests%rowtype;
  v_buffers jsonb;
  v_zone text;
  v_schedule_zone text;
  v_zone_count integer;
  v_window_count integer;
  v_allocation record;
begin
  if tg_op='UPDATE' then
    if row(new.request_id,new.customer_id,new.groomer_id,new.proposed_start,new.proposed_end,
      new.applied_timing_buffers,new.service_time_zone_identifier,new.schedule_time_zone_identifier,
      new.occupied_start,new.occupied_end) is distinct from
      row(old.request_id,old.customer_id,old.groomer_id,old.proposed_start,old.proposed_end,
      old.applied_timing_buffers,old.service_time_zone_identifier,old.schedule_time_zone_identifier,
      old.occupied_start,old.occupied_end) then
      raise exception using errcode='23514',message='offer_timing_snapshot_immutable';
    end if;
    return new;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.groomer_id::text,71071));
  select * into strict v_request from public.grooming_requests
    where id=new.request_id and customer_id=new.customer_id;
  v_buffers := '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb;
  select min(timezone),count(distinct timezone),count(*) into v_schedule_zone,v_zone_count,v_window_count
    from public.groomer_availability_windows where groomer_id=new.groomer_id;
  if v_zone_count <> 1 or v_window_count <> 7 or not exists (
    select 1 from pg_catalog.pg_timezone_names where name=v_schedule_zone
  ) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required';
  end if;
  if v_request.location_mode='groomer_comes_to_customer' then
    v_zone := v_request.preference_time_zone_identifier;
  else
    select a.time_zone_identifier into v_zone from public.groomer_profiles g
      join app_private.address_locations a on a.id=g.address_location_id and a.owner_id=g.user_id
      where g.user_id=new.groomer_id;
  end if;
  if v_zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=v_zone) then
    raise exception using errcode='22023',message='service_timezone_confirmation_required';
  end if;

  select * into strict v_allocation from app_private.service_timing_allocation(new.proposed_start,
    (extract(epoch from new.proposed_end-new.proposed_start)/60)::integer,
    (v_buffers->>'preparation_minutes')::integer,(v_buffers->>'cleanup_minutes')::integer,
    (v_buffers->>'inbound_travel_minutes')::integer,(v_buffers->>'outbound_travel_minutes')::integer,
    v_request.location_mode);
  new.applied_timing_buffers := v_buffers;
  new.service_time_zone_identifier := v_zone;
  new.schedule_time_zone_identifier := v_schedule_zone;
  new.occupied_start := v_allocation.occupied_start;
  new.occupied_end := v_allocation.occupied_end;
  if exists(select 1 from public.bookings b where b.groomer_id=new.groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and b.scheduled_start<new.occupied_end
      and new.occupied_start<app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at)) then
    raise exception using errcode='P0001',message='groomer_unavailable';
  end if;
  if app_private.occupied_time_off_conflict(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_time_off_conflict';
  end if;
  if not app_private.occupied_weekly_hours_covered(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_outside_weekly_hours';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION app_private.create_groomer_offer(p_request_id uuid, p_proposed_start timestamp with time zone, p_proposed_end timestamp with time zone, p_price_estimate numeric, p_message text, p_assessment_confirmations text[])
 RETURNS TABLE(offer_id uuid, offer_status text, request_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_message text := nullif(
    regexp_replace(coalesce(p_message, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g'),
    ''
  );
  v_match_id uuid;
  v_match_status text;
  v_customer_id uuid;
  v_request_status text;
  v_request_expires_at timestamptz;
  v_offer_id uuid;
  v_offer_status text;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  perform 1
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile
    on profile.id = groomer_profile.user_id
  where groomer_profile.user_id = v_user_id
    and profile.role = 'groomer'::public.user_role;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_profile_required';
  end if;

  if p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_request';
  end if;

  if p_proposed_start is null
    or p_proposed_end is null
    or p_proposed_start <= statement_timestamp()
    or p_proposed_end <= p_proposed_start
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_proposed_range';
  end if;

  if p_price_estimate is null
    or p_price_estimate < 0
    or p_price_estimate > 9999.99
    or p_price_estimate <> round(p_price_estimate, 2)
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_price_estimate';
  end if;

  if v_message is not null
    and char_length(v_message) > 200
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_message';
  end if;

  perform 1 from public.grooming_requests as parent_request
  where parent_request.id = p_request_id and exists (
      select 1 from public.request_matches m
      where m.request_id=parent_request.id and m.groomer_id=v_user_id
    )
  for update of parent_request;
  if not found then
    raise exception using errcode='P0001', message='match_not_found';
  end if;

  select
    request_match.id,
    request_match.status,
    request_match.customer_id,
    grooming_request.status,
    grooming_request.expires_at
  into
    v_match_id,
    v_match_status,
    v_customer_id,
    v_request_status,
    v_request_expires_at
  from public.request_matches as request_match
  join public.grooming_requests as grooming_request
    on grooming_request.id = request_match.request_id
   and grooming_request.customer_id = request_match.customer_id
  where request_match.request_id = p_request_id
    and request_match.groomer_id = v_user_id
  for update of request_match, grooming_request;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_found';
  end if;

  if v_match_status not in ('visible', 'viewed') then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_offerable';
  end if;

  if v_request_status not in ('open', 'has_offers')
    or v_request_expires_at <= statement_timestamp()
  then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_open';
  end if;

  if exists (
    select 1
    from public.groomer_offers as existing_offer
    where existing_offer.request_id = p_request_id
      and existing_offer.groomer_id = v_user_id
      and existing_offer.status = 'pending'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'active_offer_exists';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 71071)
  );

  if not app_private.groomer_can_admit_service(
    v_user_id,
    p_proposed_start,
    p_proposed_end
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_unavailable';
  end if;

  insert into public.groomer_offers (
    request_id,
    match_id,
    customer_id,
    groomer_id,
    proposed_start,
    proposed_end,
    price_estimate,
    message,
    status,
    expires_at,
    assessment_confirmations
  )
  values (
    p_request_id,
    v_match_id,
    v_customer_id,
    v_user_id,
    p_proposed_start,
    p_proposed_end,
    p_price_estimate,
    v_message,
    'pending',
    v_request_expires_at,
    p_assessment_confirmations
  )
  returning id, status
  into v_offer_id, v_offer_status;

  update public.request_matches as request_match
  set
    status = 'offered',
    viewed_at = coalesce(request_match.viewed_at, statement_timestamp())
  where request_match.id = v_match_id;

  update public.grooming_requests as grooming_request
  set status = 'has_offers'
  where grooming_request.id = p_request_id
    and grooming_request.status = 'open'
  returning grooming_request.status
  into v_request_status;

  if v_request_status is null then
    v_request_status := 'has_offers';
  end if;

  return query
  select v_offer_id, v_offer_status, v_request_status;
end;
$function$
;

COMMIT;
