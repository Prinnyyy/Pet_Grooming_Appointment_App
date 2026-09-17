-- T-390: bind a quote to one compatible configuration; duplicate service types are legal.
create function app_private.offer_service_configuration(p_request uuid,p_groomer uuid,p_revision uuid)
returns setof public.groomer_services language sql stable set search_path = '' as $$
  select s.* from public.groomer_services s join public.grooming_requests r on r.id=p_request
  where s.groomer_id=p_groomer and s.service_type=r.service_type and s.is_active
    and (p_revision is null or s.eligibility_revision=p_revision)
    and (s.accepted_species is null or lower(btrim(r.pet_snapshot->>'species'))=any(s.accepted_species))
    and app_private.match_service_size(app_private.match_request_size(r.pet_snapshot),s.accepted_pet_sizes)<>'excluded'
  order by (s.accepted_species is null),cardinality(app_private.match_required_confirmations(
    r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes)),s.duration_minutes,s.id limit 1;
$$;
revoke all on function app_private.offer_service_configuration(uuid,uuid,uuid) from public,anon,authenticated,service_role;


create function app_private.validate_offer_match_facts(p_request uuid,p_groomer uuid,p_confirmations text[],p_service_revision uuid)
returns void language plpgsql set search_path = '' as $$
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
    or coalesce(supplied,'{}') is distinct from array(select key from unnest(required) key order by key) then
    raise exception using errcode='22023',message='assessment_confirmation_required';
  end if;
end $$;

create or replace function app_private.validate_offer_match_facts(p_request uuid,p_groomer uuid,p_confirmations text[])
returns void language sql set search_path = '' as $$
  select app_private.validate_offer_match_facts(p_request,p_groomer,p_confirmations,null);
$$;
revoke all on function app_private.validate_offer_match_facts(uuid,uuid,text[],uuid) from public,anon,authenticated,service_role;


create or replace function app_private.snapshot_offer_agreement()
returns trigger language plpgsql security definer set search_path = '' as $$
declare r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype;
  a app_private.address_locations%rowtype; address jsonb; service_revision uuid;
begin
  if tg_op='UPDATE' then
    if row(new.quote_revision,new.agreement_snapshot,new.price_estimate,new.message,new.expires_at,
      new.request_id,new.match_id,new.customer_id,new.groomer_id)
      is distinct from row(old.quote_revision,old.agreement_snapshot,old.price_estimate,old.message,old.expires_at,
      old.request_id,old.match_id,old.customer_id,old.groomer_id) then
      raise exception using errcode='23514',message='quote_terms_are_immutable';
    end if;
    if old.terms_invalid_reason is not null and new.terms_invalid_reason is distinct from old.terms_invalid_reason then
      raise exception using errcode='23514',message='quote_invalidity_is_terminal';
    end if;
    return new;
  end if;
  select * into strict r from public.grooming_requests where id=new.request_id and customer_id=new.customer_id for update;
  select * into strict g from public.groomer_profiles where user_id=new.groomer_id;
  select eligibility_revision into strict service_revision from
    app_private.offer_service_configuration(new.request_id,new.groomer_id,null);
  if r.location_mode='groomer_comes_to_customer' then
    select * into strict a from app_private.address_locations where id=r.address_location_id and owner_id=r.customer_id;
    address:=jsonb_build_object('street_address',r.street_address,'address_line_2',r.address_line_2,
      'city',r.city,'state',r.state,'zip_code',r.zip_code);
  else
    select * into strict g from public.groomer_profiles where user_id=new.groomer_id;
    select * into strict a from app_private.address_locations where id=g.address_location_id and owner_id=g.user_id;
    address:=jsonb_build_object('street_address',g.base_street_address,'address_line_2',g.base_address_line_2,
      'city',g.base_city,'state',g.base_state,'zip_code',g.base_zip_code);
  end if;
  if nullif(btrim(address->>'street_address'),'') is null then
    raise exception using errcode='22023',message='agreement_address_required';
  end if;
  address:=address||jsonb_build_object('country_code',a.country_code,'latitude',a.latitude,'longitude',a.longitude,
    'source_location_id',a.id,'provider',a.provider,'confirmed_at',a.user_confirmed_at,'source_updated_at',a.updated_at);
  new.agreement_snapshot:=jsonb_build_object('schema_version',1,'request_revision',r.terms_revision,
    'quote_revision',new.quote_revision,'pet_id',r.pet_id,'pet_snapshot',r.pet_snapshot,
    'service_type',r.service_type,'service_notes',r.service_notes,'location_mode',r.location_mode,
    'address',address,'service_time_zone_identifier',new.service_time_zone_identifier,
    'scheduled_start',new.proposed_start,'scheduled_end',new.proposed_end,
    'price_estimate',new.price_estimate,'currency','USD','captured_at',statement_timestamp(),
    'source','quote_creation','groomer_eligibility_revision',g.eligibility_revision,
    'service_eligibility_revision',service_revision,
    'service_configuration_id',(select id from app_private.offer_service_configuration(new.request_id,new.groomer_id,service_revision)));
  return new;
end $$;

CREATE OR REPLACE FUNCTION app_private.evaluate_quote(p_offer_id uuid, p_now timestamp with time zone DEFAULT statement_timestamp())
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
      or not (o.assessment_confirmations @> required and o.assessment_confirmations <@ required) then
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
  if zone_count<>1 or window_count<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=zone
  ) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  earliest:=app_private.service_timing_earliest_start(p_now,notice,zone);
  if o.proposed_start<earliest then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason','expired');
  end if;
  if not app_private.groomer_can_admit_service(o.groomer_id,o.proposed_start,o.proposed_end,p_now)
    or exists(select 1 from public.bookings b where b.pet_id=r.pet_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(b.scheduled_start,app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at),'[)') && tstzrange(o.proposed_start,o.proposed_end,'[)'))
    or exists(select 1 from public.bookings b where b.groomer_id=o.groomer_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(coalesce(b.occupied_start,b.scheduled_start),app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)')
        && tstzrange(o.occupied_start,o.occupied_end,'[)'))
    or app_private.occupied_time_off_conflict(o.groomer_id,o.occupied_start,o.occupied_end)
    or not app_private.occupied_weekly_hours_covered(o.groomer_id,o.occupied_start,o.occupied_end) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  return jsonb_build_object('terms_valid',true,'selectable',true,'reason','available');
end $function$;

create or replace function app_private.guard_booking_match_facts()
returns trigger language plpgsql security definer set search_path = '' as $$
declare confirmations text[]; revision uuid;
begin
  select assessment_confirmations,(agreement_snapshot->>'service_eligibility_revision')::uuid into strict confirmations,revision from public.groomer_offers
    where id=new.offer_id and request_id=new.request_id
      and groomer_id=new.groomer_id and customer_id=new.customer_id;
  perform app_private.validate_offer_match_facts(new.request_id,new.groomer_id,confirmations,revision);
  return new;
end $$;
