-- T-399 / HD-01. Trusted private contexts share the deployed matching-v1 core.
-- The composite type is an internal value, never an inserted preview Request.
-- New helpers have no client execute grant; public reads authenticate their own scope.

create or replace function app_private.evaluate_context_constraints(p_context public.grooming_requests,p_groomer uuid,p_now timestamptz)
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype := p_context; g public.groomer_profiles%rowtype; species text;
begin
  if p_now is null or not isfinite(p_now) then
    return jsonb_build_object('state','excluded','reason','invalid_clock');
  end if;
  if r.customer_id is null or r.pet_id is null or r.expires_at<=p_now
    or r.preferred_start is null or r.preferred_end is null
    or not isfinite(r.preferred_start) or not isfinite(r.preferred_end)
    or r.preferred_start>=r.preferred_end
    or not exists(select 1 from public.profiles where id=r.customer_id and role='customer')
    or not exists(select 1 from public.pets where id=r.pet_id and customer_id=r.customer_id
      and is_active and deleted_at is null) then
    return jsonb_build_object('state','excluded','reason','request_unavailable');
  end if;
  species:=lower(btrim(r.pet_snapshot->>'species'));
  if species is null or species not in ('dog','cat') then
    return jsonb_build_object('state','excluded','reason','request_species_confirmation_required');
  end if;
  select * into g from public.groomer_profiles where user_id=p_groomer;
  if not found or not g.is_active
    or not exists(select 1 from public.profiles where id=p_groomer and role='groomer')
    or not coalesce(g.service_location_modes @> array[r.location_mode]::text[],
      g.service_location_mode=r.location_mode,false) then
    return jsonb_build_object('state','excluded','reason','groomer_unavailable');
  end if;
  if not exists(select 1 from app_private.address_locations a
    join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=p_groomer
    cross join lateral app_private.evaluate_request_location_fit(a.location,b.location,r.location_mode,
      r.travel_radius_miles,g.service_radius_miles,r.state,r.city,g.base_state,g.base_city) fit
    where a.id=r.address_location_id and a.owner_id=r.customer_id and fit.is_eligible) then
    return jsonb_build_object('state','excluded','reason','location_excluded');
  end if;
  if not exists(select 1 from public.groomer_services s where s.groomer_id=p_groomer
    and s.is_active and s.service_type=r.service_type) then
    return jsonb_build_object('state','excluded','reason','service_unavailable');
  end if;
  if not exists(select 1 from public.groomer_services s where s.groomer_id=p_groomer
    and s.is_active and s.service_type=r.service_type
    and (s.accepted_species is null or species=any(s.accepted_species))) then
    return jsonb_build_object('state','excluded','reason','pet_species_excluded');
  end if;
  if not exists(select 1 from public.groomer_services s where s.groomer_id=p_groomer
    and s.is_active and s.service_type=r.service_type
    and (s.accepted_species is null or species=any(s.accepted_species))
    and app_private.match_service_size(app_private.match_request_size(r.pet_snapshot),s.accepted_pet_sizes)<>'excluded') then
    return jsonb_build_object('state','excluded','reason','pet_size_excluded');
  end if;
  return jsonb_build_object('state','eligible','reason','explicit_constraints_met');
end $$;

CREATE OR REPLACE FUNCTION app_private.evaluate_context_eligibility(p_context public.grooming_requests, p_groomer uuid, p_now timestamp with time zone, p_valid_zones text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  r public.grooming_requests%rowtype := p_context; g public.groomer_profiles%rowtype;
  prefs public.groomer_booking_preferences%rowtype;
  zone text; service_zone text; valid_zones text[]; zones integer; windows integer;
  starts time[]; ends time[]; before_minutes integer := 0; after_minutes integer := 0;
  buffers_known boolean; earliest timestamptz; day date; day_end timestamptz;
  window_start timestamptz; window_end timestamptz; cursor_start timestamptz;
  available tstzmultirange; blocked tstzmultirange; allocation record; service record;
  pet_busy_until timestamptz; size_state text; duration integer; assessment jsonb;
  required text[]; assessment_species_unknown boolean; assessment_key_count integer;
  assessment_duration integer; assessment_id uuid;
begin
  assessment:=app_private.evaluate_context_constraints(p_context,p_groomer,p_now);
  if assessment->>'state'='excluded' then return assessment; end if;
  assessment:=null;
  select * into strict g from public.groomer_profiles where user_id=p_groomer;
  select min(timezone),count(distinct timezone),count(*),
    array_agg(case when is_enabled then start_time end order by weekday),
    array_agg(case when is_enabled then end_time end order by weekday)
    into zone,zones,windows,starts,ends from public.groomer_availability_windows where groomer_id=p_groomer;
  if zones<>1 or windows<>7 then
    return jsonb_build_object('state','excluded','reason','schedule_confirmation_required');
  end if;
  if r.location_mode='groomer_comes_to_customer' then service_zone:=r.preference_time_zone_identifier;
  else
    select time_zone_identifier into service_zone from app_private.address_locations
      where id=g.address_location_id and owner_id=p_groomer;
  end if;
  valid_zones:=p_valid_zones;
  if valid_zones is null then
    select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names where name in (zone,service_zone);
  end if;
  if not coalesce(zone=any(valid_zones),false) then
    return jsonb_build_object('state','excluded','reason','schedule_confirmation_required');
  end if;
  if not coalesce(service_zone=any(valid_zones),false) then
    return jsonb_build_object('state','excluded','reason','service_timezone_confirmation_required');
  end if;
  select * into prefs from public.groomer_booking_preferences where groomer_id=p_groomer;
  if not found then
    -- Optimistic notice only proves impossibility; missing preferences cannot
    -- produce estimated_fit because their buffers remain unconfirmed.
    prefs.minimum_advance_notice_days:=0;
  end if;
  buffers_known:=coalesce(app_private.valid_timing_buffers(prefs.timing_buffers),false);
  if buffers_known then
    before_minutes:=(prefs.timing_buffers->>'preparation_minutes')::integer;
    after_minutes:=(prefs.timing_buffers->>'cleanup_minutes')::integer;
    if r.location_mode='groomer_comes_to_customer' then
      before_minutes:=before_minutes+(prefs.timing_buffers->>'inbound_travel_minutes')::integer;
      after_minutes:=after_minutes+(prefs.timing_buffers->>'outbound_travel_minutes')::integer;
    end if;
  end if;
  earliest:=greatest(r.preferred_start,
    app_private.service_timing_earliest_start_validated(p_now,prefs.minimum_advance_notice_days,zone));
  select coalesce(range_agg(slot),'{}'::tstzmultirange) into blocked from (
    select tstzrange(coalesce(b.occupied_start,b.scheduled_start),app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)') slot
      from public.bookings b where b.groomer_id=p_groomer and b.status in ('confirmed','completed','unfulfilled')
    union all
    select tstzrange(timezone(zone,t.start_date::timestamp),timezone(zone,(t.end_date+1)::timestamp),'[)')
      from public.groomer_time_off_windows t where t.groomer_id=p_groomer
  ) occupied;
  day:=timezone(service_zone,earliest)::date;
  while timezone(service_zone,day::timestamp)<r.preferred_end loop
    day_end:=timezone(service_zone,(day+1)::timestamp);
    window_start:=greatest(earliest,timezone(service_zone,day::timestamp));
    window_end:=least(r.preferred_end,day_end);
    if window_start<window_end and not blocked @> tstzrange(window_start,window_end,'[)') then
      available:=app_private.match_weekly_ranges_validated(window_start-make_interval(mins=>before_minutes),
        window_end+make_interval(mins=>after_minutes),zone,starts,ends);
      if available is null then
        return jsonb_build_object('state','assessment_required','reason','schedule_evaluation_required');
      end if;
      for service in select * from public.groomer_services s where s.groomer_id=p_groomer
        and s.is_active and s.service_type=r.service_type order by s.duration_minutes,s.id loop
        size_state:=app_private.match_service_size(app_private.match_request_size(r.pet_snapshot),service.accepted_pet_sizes);
        if service.accepted_species is not null
          and not lower(btrim(r.pet_snapshot->>'species'))=any(service.accepted_species) then continue; end if;
        if size_state='excluded' then continue; end if;
        -- Unknown duration/buffers use optimistic lower bounds only to prove impossibility.
        duration:=case when r.service_type<>'custom_request' and service.duration_minutes between 15 and 720
          then service.duration_minutes else 15 end;
        cursor_start:=window_start;
        loop
          select * into allocation from app_private.match_service_interval(tstzrange(window_start,window_end,'[)'),
            available,blocked,duration,before_minutes,after_minutes,cursor_start);
          exit when not found;
          if (select count(*) from public.bookings b where b.groomer_id=p_groomer
              and b.status in ('confirmed','completed','unfulfilled')
              and timezone(zone,b.scheduled_start)::date=timezone(zone,allocation.service_start)::date)
              >=prefs.max_appointments_per_day then
            cursor_start:=timezone(zone,(timezone(zone,allocation.service_start)::date+1)::timestamp);
            continue;
          end if;
          select max(app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at)) into pet_busy_until from public.bookings b
            where b.pet_id=r.pet_id and b.status in ('confirmed','completed','unfulfilled')
              and b.scheduled_start<allocation.service_end and app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at)>allocation.service_start;
          if pet_busy_until is not null then cursor_start:=pet_busy_until; continue; end if;
          if size_state='eligible' and service.accepted_species is not null
            and cardinality(app_private.match_required_confirmations(r.pet_snapshot,r.service_type,
              service.accepted_species,service.accepted_pet_sizes))=0
            and buffers_known and r.service_type<>'custom_request'
            and service.duration_minutes between 15 and 720 then
            return jsonb_build_object('state','estimated_fit','reason','continuous_opening',
              'service_id',service.id,'service_start',allocation.service_start,'service_end',allocation.service_end,
              'occupied_start',allocation.occupied_start,'occupied_end',allocation.occupied_end);
          end if;
          required:=app_private.match_required_confirmations(r.pet_snapshot,r.service_type,
            service.accepted_species,service.accepted_pet_sizes);
          -- Later legacy configurations must not replace a usable confirmed scope.
          if assessment is null or
            row(service.accepted_species is null,cardinality(required),duration,service.id)
              < row(assessment_species_unknown,assessment_key_count,assessment_duration,assessment_id) then
            assessment:=jsonb_build_object('state','assessment_required','reason','service_details_unconfirmed',
              'service_id',service.id,'required_confirmations',to_jsonb(required),
              'service_start',allocation.service_start,'service_end',allocation.service_end,
              'occupied_start',allocation.occupied_start,'occupied_end',allocation.occupied_end);
            assessment_species_unknown:=service.accepted_species is null;
            assessment_key_count:=cardinality(required);
            assessment_duration:=duration; assessment_id:=service.id;
          end if;
          exit;
        end loop;
      end loop;
    end if;
    day:=day+1;
  end loop;
  return coalesce(assessment,jsonb_build_object('state','excluded','reason','no_continuous_opening'));
end $function$;

create function app_private.context_target_keys(p_context public.grooming_requests,p_groomer uuid,p_offer uuid,p_valid_zones text[])
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype := p_context; o public.groomer_offers%rowtype; zone text; first_keys jsonb; last_keys jsonb;
begin
  if p_offer is not null then
    select * into strict o from public.groomer_offers where id=p_offer and request_id=r.id and groomer_id=p_groomer;
    return app_private.review_allowed_keys(r.pet_snapshot,r.service_type,o.proposed_start,o.service_time_zone_identifier,p_valid_zones);
  end if;
  if r.location_mode='groomer_comes_to_customer' then zone:=r.preference_time_zone_identifier;
  else select a.time_zone_identifier into zone from public.groomer_profiles g
    join app_private.address_locations a on a.id=g.address_location_id and a.owner_id=g.user_id where g.user_id=p_groomer;
  end if;
  first_keys:=app_private.review_allowed_keys(r.pet_snapshot,r.service_type,r.preferred_start,zone,p_valid_zones);
  last_keys:=app_private.review_allowed_keys(r.pet_snapshot,r.service_type,r.preferred_end-interval '1 microsecond',zone,p_valid_zones);
  -- Only age categories stable across the whole window survive this intersection.
  return (select coalesce(jsonb_agg(value order by value->>'dimension',value->>'value'),'[]')
    from jsonb_array_elements(first_keys) where last_keys @> jsonb_build_array(value));
end $$;

create or replace function app_private.score_context_evidence(p_context public.grooming_requests,p_groomer_id uuid,p_score_as_of timestamptz,p_offer_id uuid,p_valid_zones text[])
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype := p_context; target jsonb; score jsonb; distance_miles double precision;
begin
  if p_score_as_of is null or not isfinite(p_score_as_of) then
    raise exception using errcode='22023',message='invalid_score_clock';
  end if;
  target:=app_private.context_target_keys(p_context,p_groomer_id,p_offer_id,p_valid_zones);
  select extensions.st_distance(a.location,b.location)/1609.344 into distance_miles
    from app_private.address_locations a join public.groomer_profiles g on g.user_id=p_groomer_id
    join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=g.user_id
    where a.id=r.address_location_id and a.owner_id=r.customer_id;

  with target_keys as (
    select value->>'dimension' dimension,value->>'value' value from jsonb_array_elements(target)
  ), shares as (
    select k.*,1.0/(select count(distinct dimension) from target_keys)/count(*) over(partition by dimension) share
    from target_keys k
  ), eligible_contexts as materialized (
    select c.*,b.customer_id from app_private.booking_review_contexts c
      join public.bookings b on b.id=c.booking_id
    where b.groomer_id=p_groomer_id and b.status='completed' and c.service_at<=p_score_as_of
      and isfinite(c.service_at)
  ), quality_rows as materialized (
    select review.id,review.customer_id,review.rating,c.service_at,
      case when extract(epoch from (p_score_as_of-c.service_at))<=15552000000.0
        then power(2.0::double precision,-extract(epoch from (p_score_as_of-c.service_at))::double precision/15552000.0)::numeric
        else power(2.0::numeric,-extract(epoch from (p_score_as_of-c.service_at))/15552000.0) end decay
    from public.reviews review join eligible_contexts c on c.booking_id=review.booking_id
    where review.groomer_id=p_groomer_id
  ), quality_weights as (
    select q.*,case when sum(decay) over(partition by customer_id)>0 then
      max(decay) over(partition by customer_id)*decay/sum(decay) over(partition by customer_id) else 0 end weight
    from quality_rows q
  ), related_contexts as materialized (
    select * from eligible_contexts where species=lower(r.pet_snapshot->>'species') and service_type=r.service_type
      and r.service_type<>'custom_request'
  ), fit_rows as materialized (
    select review.id,review.customer_id,c.service_at,
      case when extract(epoch from (p_score_as_of-c.service_at))<=15552000000.0
        then power(2.0::double precision,-extract(epoch from (p_score_as_of-c.service_at))::double precision/15552000.0)::numeric
        else power(2.0::numeric,-extract(epoch from (p_score_as_of-c.service_at))/15552000.0) end decay,
      coalesce(sum(s.share) filter(where e.outcome='positive'),0) positive,
      coalesce(sum(s.share) filter(where e.outcome='negative'),0) negative
    from related_contexts c join public.reviews review on review.booking_id=c.booking_id
      join app_private.review_evidence_projection e on e.review_id=review.id and e.is_valid
      join shares s on s.dimension=e.dimension and s.value=e.value
    group by review.id,review.customer_id,c.service_at
  ), fit_weights as (
    select f.*,case when sum(decay) over(partition by customer_id)>0 then
      max(decay) over(partition by customer_id)*decay/sum(decay) over(partition by customer_id) else 0 end weight
    from fit_rows f
  ), fit_totals as (
    select coalesce(sum(weight*positive),0) p,coalesce(sum(weight*negative),0) n,
      count(*) reviews,count(distinct customer_id) customers,max(service_at) latest from fit_weights
  ), quality_totals as (
    select 100*(2.5+coalesce(sum(weight*(rating-1)/4.0),0))/(5+coalesce(sum(weight),0)) q,
      count(*) reviews,count(distinct customer_id) customers from quality_weights
  ), key_coverage as (
    select s.dimension,s.value,
      (select count(*) from related_contexts c where c.allowed_keys @> jsonb_build_array(
        jsonb_build_object('dimension',s.dimension,'value',s.value))) completed,
      (select count(*) from related_contexts c join public.reviews review on review.booking_id=c.booking_id
        join app_private.review_evidence_projection e on e.review_id=review.id and e.is_valid
        where e.dimension=s.dimension and e.value=s.value and e.outcome='positive') positive,
      (select count(*) from related_contexts c join public.reviews review on review.booking_id=c.booking_id
        join app_private.review_evidence_projection e on e.review_id=review.id and e.is_valid
        where e.dimension=s.dimension and e.value=s.value and e.outcome='negative') negative
    from shares s
  )
  select jsonb_build_object('f',50+50*(f.p-f.n)/(f.p+f.n+5),'q',q.q,
    'd',case when distance_miles is null then null else 100/(1+distance_miles/5) end,
    'positive_weight',f.p,'negative_weight',f.n,'related_review_count',f.reviews,
    'f_customer_count',f.customers,'q_review_count',q.reviews,'q_customer_count',q.customers,
    'completed_count',(select count(*) from related_contexts),'latest_service_at',f.latest,
    'coverage',(select coalesce(jsonb_agg(jsonb_build_object('dimension',dimension,'value',value,
      'completed_count',completed,'positive_count',positive,'negative_count',negative,
      'unknown_count',greatest(0,completed-positive-negative)) order by dimension,value),'[]') from key_coverage),
    'algorithm_version','matching-v1','score_as_of',p_score_as_of,
    'state',case when f.reviews=0 then 'no_evidence' else 'available' end)
    into score from fit_totals f cross join quality_totals q;
  return score||jsonb_build_object('distance_miles',distance_miles,
    'b',0.70*(score->>'f')::numeric+0.30*(score->>'d')::numeric,
    's',0.60*(score->>'f')::numeric+0.25*(score->>'q')::numeric+0.15*(score->>'d')::numeric);
end $$;

revoke all on function app_private.evaluate_context_constraints(public.grooming_requests,uuid,timestamptz) from public,anon,authenticated,service_role;
revoke all on function app_private.evaluate_context_eligibility(public.grooming_requests,uuid,timestamptz,text[]) from public,anon,authenticated,service_role;
revoke all on function app_private.context_target_keys(public.grooming_requests,uuid,uuid,text[]) from public,anon,authenticated,service_role;
revoke all on function app_private.score_context_evidence(public.grooming_requests,uuid,timestamptz,uuid,text[]) from public,anon,authenticated,service_role;

create or replace function app_private.evaluate_match_constraints(p_request uuid,p_groomer uuid,p_now timestamptz)
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype;
begin
  if p_now is null or not isfinite(p_now) then
    return jsonb_build_object('state','excluded','reason','invalid_clock');
  end if;
  select * into r from public.grooming_requests where id=p_request;
  if not found or r.status not in ('open','has_offers') or r.expires_at<=p_now then
    return jsonb_build_object('state','excluded','reason','request_unavailable');
  end if;
  return app_private.evaluate_context_constraints(r,p_groomer,p_now);
end $$;

create or replace function app_private.evaluate_match_eligibility_with_zones(p_request uuid,p_groomer uuid,p_now timestamptz,p_valid_zones text[])
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype;
begin
  if p_now is null or not isfinite(p_now) then
    return jsonb_build_object('state','excluded','reason','invalid_clock');
  end if;
  select * into r from public.grooming_requests where id=p_request;
  if not found or r.status not in ('open','has_offers') or r.expires_at<=p_now then
    return jsonb_build_object('state','excluded','reason','request_unavailable');
  end if;
  return app_private.evaluate_context_eligibility(r,p_groomer,p_now,p_valid_zones);
end $$;

create or replace function app_private.match_target_keys(p_request uuid,p_groomer uuid,p_offer uuid,p_valid_zones text[])
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype;
begin
  select * into strict r from public.grooming_requests where id=p_request;
  return app_private.context_target_keys(r,p_groomer,p_offer,p_valid_zones);
end $$;

create or replace function app_private.score_match_evidence(p_request_id uuid,p_groomer_id uuid,p_score_as_of timestamptz,p_offer_id uuid,p_valid_zones text[])
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype;
begin
  if p_score_as_of is null or not isfinite(p_score_as_of) then
    raise exception using errcode='22023',message='invalid_score_clock';
  end if;
  select * into strict r from public.grooming_requests where id=p_request_id;
  return app_private.score_context_evidence(r,p_groomer_id,p_score_as_of,p_offer_id,p_valid_zones);
end $$;

alter table app_private.match_ranking_config
  add column discovery_enabled boolean not null default false,
  add column discovery_validation_actor_ids uuid[] not null default '{}';

create table app_private.request_discovery_sessions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  draft_id uuid not null,
  input_digest text not null,
  normalized_input jsonb not null,
  request_context jsonb not null,
  source_revision text not null,
  address_location_id uuid not null references app_private.address_locations(id),
  created_at timestamptz not null default statement_timestamp(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  check (jsonb_typeof(normalized_input)='object' and jsonb_typeof(request_context)='object'),
  check (octet_length(normalized_input::text)<=32768 and octet_length(request_context::text)<=65536),
  check (isfinite(expires_at) and expires_at>created_at and expires_at<=created_at+interval '30 minutes')
);
alter table app_private.request_discovery_sessions enable row level security;
revoke all on app_private.request_discovery_sessions from public,anon,authenticated,service_role;
create index request_discovery_owner_idx on app_private.request_discovery_sessions(customer_id,draft_id,expires_at);
create index request_discovery_expiry_idx on app_private.request_discovery_sessions(expires_at,id);

create function app_private.require_discovery_customer()
returns uuid language plpgsql stable set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles p join public.customer_profiles c on c.user_id=p.id
      where p.id=actor and p.role='customer') then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  if not exists(select 1 from app_private.match_ranking_config where singleton
    and (discovery_enabled or actor=any(discovery_validation_actor_ids))) then
    raise exception using errcode='P0001',message='discovery_unavailable';
  end if;
  return actor;
end $$;
revoke all on function app_private.require_discovery_customer() from public,anon,authenticated,service_role;

create function app_private.normalize_request_discovery_input(p_input jsonb)
returns jsonb language plpgsql stable set search_path = '' as $$
declare value jsonb; start_at timestamptz; end_at timestamptz; zone text;
begin
  if jsonb_typeof(p_input) is distinct from 'object' or octet_length(p_input::text)>32768
    or exists(select 1 from jsonb_object_keys(p_input) k where k<>all(array[
      'pet_id','service_type','service_notes','preferred_start','preferred_end','location_mode',
      'street_address','address_line_2','city','state','zip_code','travel_radius_miles',
      'provider','place_id','country_code','latitude','longitude','resolution_source','user_confirmed_at',
      'preference_time_zone_identifier','superseding_request_id','expected_request_revision'])) then
    raise exception using errcode='22023',message='invalid_discovery_input';
  end if;
  start_at:=(p_input->>'preferred_start')::timestamptz;
  end_at:=(p_input->>'preferred_end')::timestamptz;
  zone:=nullif(btrim(p_input->>'preference_time_zone_identifier'),'');
  value:=jsonb_build_object(
    'pet_id',(p_input->>'pet_id')::uuid,
    'service_type',lower(btrim(p_input->>'service_type')),
    'service_notes',nullif(btrim(p_input->>'service_notes'),''),
    'preferred_start',start_at,'preferred_end',end_at,
    'location_mode',lower(btrim(p_input->>'location_mode')),
    'street_address',btrim(p_input->>'street_address'),
    'address_line_2',nullif(btrim(p_input->>'address_line_2'),''),
    'city',btrim(p_input->>'city'),'state',upper(btrim(p_input->>'state')),
    'zip_code',btrim(p_input->>'zip_code'),
    'travel_radius_miles',case when lower(btrim(p_input->>'location_mode'))='customer_comes_to_groomer'
      then (p_input->>'travel_radius_miles')::integer else null end,
    'provider',lower(btrim(p_input->>'provider')),'place_id',nullif(btrim(p_input->>'place_id'),''),
    'country_code',upper(btrim(p_input->>'country_code')),
    'latitude',(p_input->>'latitude')::double precision,'longitude',(p_input->>'longitude')::double precision,
    'resolution_source',lower(btrim(p_input->>'resolution_source')),
    'user_confirmed_at',(p_input->>'user_confirmed_at')::timestamptz,
    'preference_time_zone_identifier',zone,
    'superseding_request_id',(p_input->>'superseding_request_id')::uuid,
    'expected_request_revision',(p_input->>'expected_request_revision')::uuid);
  if value->>'pet_id' is null
    or coalesce(value->>'service_type','')<>all(array['full_groom','bath_and_brush','haircut_only','nail_trim','de_shedding','custom_request'])
    or char_length(value->>'service_notes')>2000
    or start_at is null or end_at is null or not isfinite(start_at) or not isfinite(end_at)
    or start_at<=statement_timestamp() or end_at<=start_at or end_at<=statement_timestamp()+interval '5 minutes'
    or coalesce(value->>'location_mode','')<>all(array['groomer_comes_to_customer','customer_comes_to_groomer'])
    or char_length(coalesce(value->>'street_address','')) not between 1 and 160
    or char_length(coalesce(value->>'city','')) not between 1 and 100
    or coalesce(value->>'state','') !~ '^[A-Z]{2}$'
    or coalesce(value->>'zip_code','') !~ '^[0-9]{5}(-[0-9]{4})?$'
    or char_length(value->>'address_line_2')>60
    or (value->>'location_mode'='customer_comes_to_groomer'
      and coalesce((value->>'travel_radius_miles')::integer,0) not between 5 and 100)
    or zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=zone)
    or ((value->>'superseding_request_id' is null)<>(value->>'expected_request_revision' is null)) then
    raise exception using errcode='22023',message='invalid_discovery_input';
  end if;
  return value;
end $$;
revoke all on function app_private.normalize_request_discovery_input(jsonb) from public,anon,authenticated,service_role;

create function app_private.discovery_pet_source(p_customer uuid,p_pet uuid)
returns jsonb language plpgsql stable set search_path = '' as $$
declare pet public.pets%rowtype; photos jsonb; snapshot jsonb;
begin
  select * into pet from public.pets where id=p_pet and customer_id=p_customer and is_active and deleted_at is null;
  if not found then raise exception using errcode='P0001',message='pet_not_found'; end if;
  snapshot:=jsonb_build_object('id',pet.id,'name',pet.name,'species',pet.species,'breed',pet.breed,
    'coat_type',pet.coat_type,'coat_type_source',pet.coat_type_source,'matting_confirmed',pet.matting_confirmed,
    'facts_version',2,'size',pet.size,'weight_lbs',pet.weight_lbs,'birthday',pet.birthday,
    'temperament',pet.temperament,'medical_notes',pet.medical_notes,'grooming_notes',pet.grooming_notes);
  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'storage_bucket',p.storage_bucket,
    'storage_path',p.storage_path,'caption',p.caption,'sort_order',p.sort_order,'is_primary',p.is_primary,
    'created_at',p.created_at) order by p.is_primary desc,p.sort_order,p.created_at,p.id),'[]') into photos
    from (select * from public.pet_photos where customer_id=p_customer and pet_id=p_pet
      order by is_primary desc,sort_order,created_at,id limit 20) p;
  return jsonb_build_object('pet_snapshot',snapshot,'photo_snapshot',photos,
    'source_revision',encode(extensions.digest(convert_to(jsonb_build_array(snapshot,photos)::text,'UTF8'),'sha256'),'hex'));
end $$;
revoke all on function app_private.discovery_pet_source(uuid,uuid) from public,anon,authenticated,service_role;

create function app_private.prepare_request_discovery_v1(p_draft_id uuid,p_input jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=app_private.require_discovery_customer(); normalized jsonb; source jsonb;
  digest text; context jsonb; location_id uuid; existing app_private.request_discovery_sessions%rowtype;
begin
  if p_draft_id is null then raise exception using errcode='22023',message='invalid_discovery_input'; end if;
  normalized:=app_private.normalize_request_discovery_input(p_input);
  source:=app_private.discovery_pet_source(actor,(normalized->>'pet_id')::uuid);
  if normalized->>'superseding_request_id' is not null and not exists(
    select 1 from public.grooming_requests where id=(normalized->>'superseding_request_id')::uuid
      and customer_id=actor and terms_revision=(normalized->>'expected_request_revision')::uuid
      and status in ('open','has_offers') and expires_at>statement_timestamp()) then
    raise exception using errcode='PT409',message='request_changed';
  end if;
  digest:=encode(extensions.digest(convert_to(jsonb_build_array(normalized,source->>'source_revision')::text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended('request-discovery:'||actor::text,399));
  select * into existing from app_private.request_discovery_sessions
    where customer_id=actor and draft_id=p_draft_id and input_digest=digest
      and consumed_at is null and expires_at>statement_timestamp()
    order by created_at desc,id limit 1;
  if found then
    return jsonb_build_object('session_id',existing.id,'input_digest',existing.input_digest,
      'expires_at',existing.expires_at,'review',existing.normalized_input);
  end if;
  if (select count(*) from app_private.request_discovery_sessions where customer_id=actor
    and consumed_at is null and expires_at>statement_timestamp())>=4 then
    raise exception using errcode='P0001',message='discovery_session_limit_reached';
  end if;
  location_id:=app_private.save_address_location_v2(actor,null,normalized->>'provider',normalized->>'place_id',
    normalized->>'country_code',(normalized->>'latitude')::double precision,(normalized->>'longitude')::double precision,
    normalized->>'resolution_source',(normalized->>'user_confirmed_at')::timestamptz);
  update app_private.address_locations set time_zone_identifier=normalized->>'preference_time_zone_identifier'
    where id=location_id and owner_id=actor;
  context:=(normalized-array['provider','place_id','country_code','latitude','longitude','resolution_source',
    'user_confirmed_at','superseding_request_id','expected_request_revision'])||
    jsonb_build_object('customer_id',actor,'address_location_id',location_id,
      'pet_snapshot',(source->'pet_snapshot')||jsonb_build_object('snapshot_at',statement_timestamp()),
      'photo_snapshot',source->'photo_snapshot',
      'expires_at',least(statement_timestamp()+interval '48 hours',(normalized->>'preferred_end')::timestamptz-interval '5 minutes'));
  insert into app_private.request_discovery_sessions(customer_id,draft_id,input_digest,normalized_input,
    request_context,source_revision,address_location_id,expires_at)
    values(actor,p_draft_id,digest,normalized,context,source->>'source_revision',location_id,
      statement_timestamp()+interval '30 minutes') returning * into existing;
  return jsonb_build_object('session_id',existing.id,'input_digest',existing.input_digest,
    'expires_at',existing.expires_at,'review',existing.normalized_input);
end $$;
create function public.prepare_request_discovery_v1(p_draft_id uuid,p_input jsonb)
returns jsonb language sql volatile security invoker set search_path = '' as $$
  select app_private.prepare_request_discovery_v1(p_draft_id,p_input);
$$;
revoke all on function app_private.prepare_request_discovery_v1(uuid,jsonb),
  public.prepare_request_discovery_v1(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function app_private.prepare_request_discovery_v1(uuid,jsonb),
  public.prepare_request_discovery_v1(uuid,jsonb) to authenticated;

create function app_private.prune_request_discovery_sessions()
returns void language plpgsql security definer set search_path = '' as $$
declare locations uuid[];
begin
  with expired as (select id from app_private.request_discovery_sessions
    where expires_at<=statement_timestamp() order by expires_at,id limit 500 for update skip locked),
  removed as (delete from app_private.request_discovery_sessions where id in(select id from expired)
    returning address_location_id)
  select array_agg(address_location_id) into locations from removed;
  delete from app_private.address_locations a where a.id=any(locations)
    and not exists(select 1 from app_private.request_discovery_sessions where address_location_id=a.id)
    and not exists(select 1 from public.grooming_requests where address_location_id=a.id)
    and not exists(select 1 from public.customer_profiles where address_location_id=a.id)
    and not exists(select 1 from public.groomer_profiles where address_location_id=a.id);
end $$;
revoke all on function app_private.prune_request_discovery_sessions() from public,anon,authenticated,service_role;
select cron.schedule('beckon_prune_request_discovery_sessions','* * * * *','select app_private.prune_request_discovery_sessions();');

-- First publication remains owned by the existing durable operation receipt.
-- No FK to the short-lived preview: accepted operations outlive its retention.
alter table app_private.request_publish_operations
  add column protocol_version text not null default 'legacyV4'
    check(protocol_version in ('legacyV4','discoveryV1')),
  add column discovery_session_id uuid unique,
  add column discovery_draft_id uuid,
  add column canonical_hash text,
  add column distribution_receipt jsonb;

create function app_private.resolve_request_discovery_scope(p_scope jsonb)
returns jsonb language plpgsql stable set search_path = '' as $$
declare actor uuid:=app_private.require_discovery_customer(); preview app_private.request_discovery_sessions%rowtype;
  operation app_private.request_publish_operations%rowtype; r public.grooming_requests%rowtype;
  scope_id uuid; source jsonb; deadline timestamptz; tie_scope text; source_key text;
begin
  if jsonb_typeof(p_scope) is distinct from 'object'
    or coalesce(p_scope->>'kind','') not in ('preview','request')
    or (select count(*) from jsonb_object_keys(p_scope))<>3
    or not p_scope ?& array['kind','id']
    or not ((p_scope->>'kind'='preview' and p_scope ? 'input_digest')
      or (p_scope->>'kind'='request' and p_scope ? 'terms_revision')) then
    raise exception using errcode='22023',message='invalid_discovery_scope';
  end if;
  scope_id:=(p_scope->>'id')::uuid;
  if p_scope->>'kind'='preview' then
    select * into preview from app_private.request_discovery_sessions where id=scope_id and customer_id=actor;
    if not found or preview.expires_at<=statement_timestamp() then
      raise exception using errcode='PT409',message='discovery_expired';
    end if;
    if preview.input_digest is distinct from p_scope->>'input_digest' then
      raise exception using errcode='PT409',message='discovery_changed';
    end if;
    select * into operation from app_private.request_publish_operations
      where customer_id=actor and discovery_session_id=preview.id;
    if found then
      select * into r from public.grooming_requests where id=operation.request_id and customer_id=actor;
      if not found or r.status not in ('open','has_offers') or r.expires_at<=statement_timestamp()
        or r.terms_revision::text is distinct from operation.distribution_receipt->>'terms_revision' then
        raise exception using errcode='PT409',message='request_changed';
      end if;
    else
      r:=jsonb_populate_record(null::public.grooming_requests,preview.request_context);
      source:=app_private.discovery_pet_source(actor,r.pet_id);
      if source->>'source_revision' is distinct from preview.source_revision then
        raise exception using errcode='PT409',message='discovery_changed';
      end if;
      if r.expires_at<=statement_timestamp() then
        raise exception using errcode='PT409',message='discovery_expired';
      end if;
    end if;
    deadline:=least(preview.expires_at,(preview.request_context->>'expires_at')::timestamptz,r.expires_at);
    tie_scope:=preview.draft_id::text; source_key:=preview.input_digest;
  else
    select * into r from public.grooming_requests where id=scope_id and customer_id=actor;
    if not found then raise exception using errcode='42501',message='not_allowed'; end if;
    if r.terms_revision::text is distinct from p_scope->>'terms_revision'
      or r.status not in ('open','has_offers') or r.expires_at<=statement_timestamp() then
      raise exception using errcode='PT409',message='request_changed';
    end if;
    select * into operation from app_private.request_publish_operations
      where customer_id=actor and request_id=r.id and protocol_version='discoveryV1' limit 1;
    tie_scope:=coalesce(operation.discovery_draft_id,r.id)::text;
    deadline:=r.expires_at; source_key:=r.terms_revision::text;
  end if;
  return jsonb_build_object('context',to_jsonb(r),'valid_until',deadline,'tie_scope',tie_scope,
    'source_key',source_key,'browse_scope','groomer_discovery:'||p_scope::text);
end $$;
revoke all on function app_private.resolve_request_discovery_scope(jsonb) from public,anon,authenticated,service_role;

create function app_private.store_match_browse_snapshot(p_actor uuid,p_role text,p_scope text,
  p_mode text,p_result jsonb,p_soft jsonb)
returns uuid language plpgsql volatile set search_path = '' as $$
declare result uuid;
begin
  if p_soft is null or octet_length(p_soft::text)>262144 then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended('match-browse:'||p_actor::text,392));
  delete from app_private.match_browse_snapshots where viewer_id=p_actor and valid_until<=statement_timestamp();
  delete from app_private.match_browse_snapshots where id in (
    select id from app_private.match_browse_snapshots where viewer_id=p_actor
      order by captured_at desc,id offset 31);
  insert into app_private.match_browse_snapshots(viewer_id,viewer_role,scope,requested_mode,algorithm_version,
    privacy_revision,captured_at,valid_until,soft_evidence)
    values(p_actor,p_role,p_scope,p_mode,p_result->>'algorithm_version',(p_soft->>'privacy_revision')::uuid,
      (p_result->>'score_as_of')::timestamptz,(p_result->>'valid_until')::timestamptz,p_soft)
    returning id into result;
  return result;
end $$;
revoke all on function app_private.store_match_browse_snapshot(uuid,text,text,text,jsonb,jsonb)
  from public,anon,authenticated,service_role;

create function app_private.marketplace_groomer_summary(p_groomer uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id',g.user_id,'business_name',g.business_name,'bio',g.bio,
    'years_experience',g.years_experience,'city',g.base_city,'state',g.base_state,
    'rating_sum',g.rating_sum,'rating_count',g.rating_count,'is_verified',g.is_verified,'avatar_path',p.avatar_path)
  from public.groomer_profiles g join public.profiles p on p.id=g.user_id and p.role='groomer'
  where g.user_id=p_groomer and g.is_active
    and not exists(select 1 from public.account_deletion_requests where user_id=p_groomer and anonymized_at is not null);
$$;
revoke all on function app_private.marketplace_groomer_summary(uuid) from public,anon,authenticated,service_role;

-- Later feature migrations replace this overlay without changing ranking identity.
create function app_private.discovery_candidate_actions(p_customer uuid,p_request uuid,p_groomer uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('favorite_state',jsonb_build_object('is_favorite',false,'revision',null),
    'invitation_state','not_sent');
$$;
revoke all on function app_private.discovery_candidate_actions(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function app_private.request_groomer_candidates_page(p_scope jsonb,p_sort text,p_limit integer,
  p_cursor text,p_soft jsonb,p_profile uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=app_private.require_discovery_customer(); config app_private.match_ranking_config%rowtype;
  resolved jsonb; r public.grooming_requests%rowtype; g record; clock timestamptz:=statement_timestamp();
  as_of timestamptz:=clock; deadline timestamptz; cursor_data jsonb; last_key jsonb; valid_zones text[];
  evaluation jsonb; score jsonb; profile jsonb; reference_price jsonb; source jsonb; saved jsonb;
  distance_miles double precision; group_order integer; bucket numeric; tie text; primary_value numeric;
  rows jsonb:='[]'; page_rows jsonb; soft_items jsonb:='{}'; revision text; next_cursor text;
  pending integer:=0; assessment integer:=0; estimated integer:=0; effective text; scoring_failed boolean:=false;
  fact_deadline timestamptz; item jsonb; sort_key jsonb; evidence jsonb;
begin
  if p_sort is null or p_sort not in ('fit','distance') or p_limit is null or p_limit not between 1 and 50
    or (p_profile is not null and p_cursor is not null) then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  resolved:=app_private.resolve_request_discovery_scope(p_scope);
  r:=jsonb_populate_record(null::public.grooming_requests,resolved->'context');
  select * into strict config from app_private.match_ranking_config where singleton;
  config.enabled:=config.enabled or actor=any(config.validation_actor_ids);
  deadline:=least(clock+interval '5 minutes',(resolved->>'valid_until')::timestamptz);
  if p_cursor is not null then
    cursor_data:=app_private.match_cursor_decode(p_cursor,config.signing_key);
    if cursor_data->>'purpose' is distinct from 'groomer_discovery'
      or cursor_data->>'viewer' is distinct from actor::text or cursor_data->>'role' is distinct from 'customer'
      or cursor_data->>'scope' is distinct from resolved->>'browse_scope'
      or cursor_data->>'requested_mode' is distinct from p_sort
      or cursor_data->>'algorithm_version' is distinct from config.algorithm_version then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    as_of:=(cursor_data->>'score_as_of')::timestamptz;
    deadline:=least(deadline,(cursor_data->>'valid_until')::timestamptz);
    last_key:=cursor_data->'last_key';
    if as_of is null or deadline is null or not isfinite(as_of) or not isfinite(deadline)
      or as_of>clock or deadline>as_of+interval '5 minutes' or jsonb_typeof(last_key) is distinct from 'array'
      or jsonb_array_length(last_key)<>6 then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    if deadline<=clock then raise exception using errcode='PT409',message='list_changed'; end if;
  end if;
  if p_soft is not null then
    if (p_soft->>'enabled')::boolean is distinct from config.enabled
      or p_soft->>'privacy_revision' is distinct from config.privacy_revision::text then
      raise exception using errcode='PT409',message='list_changed';
    end if;
    scoring_failed:=coalesce((p_soft->>'scoring_failed')::boolean,false);
  end if;
  select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names;
  -- No ranked limit before eligibility: the 26th (or later) provider can lead the first page.
  for g in select gp.* from public.groomer_profiles gp
    where gp.is_active and (p_profile is null or gp.user_id=p_profile)
      and coalesce(gp.service_location_modes @> array[r.location_mode]::text[],gp.service_location_mode=r.location_mode,false)
      and exists(select 1 from public.groomer_services s where s.groomer_id=gp.user_id and s.is_active and s.service_type=r.service_type)
      and exists(select 1 from app_private.address_locations a
        join app_private.address_locations b on b.id=gp.address_location_id and b.owner_id=gp.user_id
        cross join lateral app_private.evaluate_request_location_fit(a.location,b.location,r.location_mode,
          r.travel_radius_miles,gp.service_radius_miles,r.state,r.city,gp.base_state,gp.base_city) fit
        where a.id=r.address_location_id and a.owner_id=actor and fit.is_eligible)
    order by gp.user_id
  loop
    profile:=app_private.marketplace_groomer_summary(g.user_id);
    if profile is null then continue; end if;
    evaluation:=app_private.evaluate_context_eligibility(r,g.user_id,clock,valid_zones);
    if evaluation->>'state'='excluded' then continue; end if;
    if evaluation->>'state' not in ('estimated_fit','assessment_required') then pending:=pending+1; continue; end if;
    group_order:=case evaluation->>'state' when 'estimated_fit' then 0 else 1 end;
    if group_order=0 then estimated:=estimated+1; else assessment:=assessment+1; end if;
    select extensions.st_distance(a.location,b.location)/1609.344 into distance_miles
      from app_private.address_locations a join app_private.address_locations b
        on b.id=g.address_location_id and b.owner_id=g.user_id
      where a.id=r.address_location_id and a.owner_id=actor;
    select jsonb_build_object('amount',s.base_price,'currency','USD','service_id',s.id,'reference_only',true)
      into reference_price from public.groomer_services s
      where s.id=(evaluation->>'service_id')::uuid and s.groomer_id=g.user_id
        and r.service_type<>'custom_request' and evaluation->>'state'='estimated_fit';
    score:=null;
    if p_soft is not null then
      saved:=p_soft->'items'->g.user_id::text;
      if saved is null then raise exception using errcode='PT409',message='list_changed'; end if;
      score:=saved->'score'; profile:=profile||(saved->'ratings');
    elsif config.enabled then
      begin
        score:=app_private.score_context_evidence(r,g.user_id,as_of,null,valid_zones);
      exception when numeric_value_out_of_range or division_by_zero then scoring_failed:=true;
      end;
    end if;
    soft_items:=soft_items||jsonb_build_object(g.user_id::text,jsonb_build_object('score',score,
      'ratings',jsonb_build_object('rating_sum',profile->'rating_sum','rating_count',profile->'rating_count')));
    select min(timezone(w.timezone,(timezone(w.timezone,clock)::date+1)::timestamp)) into fact_deadline
      from public.groomer_availability_windows w where w.groomer_id=g.user_id and w.timezone=any(valid_zones);
    if fact_deadline>clock then deadline:=least(deadline,fact_deadline); end if;
    -- Resource facts, not wall-clock witness timestamps, invalidate subsequent pages.
    source:=jsonb_build_object('profile',g.eligibility_revision,
      'location',(select a.updated_at from app_private.address_locations a where a.id=g.address_location_id and a.owner_id=g.user_id),
      'services',(select jsonb_agg(jsonb_build_array(s.id,s.eligibility_revision,s.base_price,
        s.duration_minutes,s.accepted_species,s.accepted_pet_sizes) order by s.id)
        from public.groomer_services s where s.groomer_id=g.user_id and s.is_active and s.service_type=r.service_type),
      'preferences',(select to_jsonb(p) from public.groomer_booking_preferences p where p.groomer_id=g.user_id),
      'windows',(select jsonb_agg(to_jsonb(w) order by w.weekday) from public.groomer_availability_windows w where w.groomer_id=g.user_id),
      'time_off',(select jsonb_agg(to_jsonb(t) order by t.id) from public.groomer_time_off_windows t where t.groomer_id=g.user_id),
      'bookings',(select jsonb_agg(jsonb_build_array(b.id,b.status,b.scheduled_start,b.scheduled_end,
        b.occupied_start,b.occupied_end,b.resource_release_at,b.pet_release_at) order by b.id)
        from public.bookings b where (b.groomer_id=g.user_id or b.pet_id=r.pet_id)
          and b.status in ('confirmed','completed','unfulfilled')
          and b.scheduled_start<r.preferred_end+interval '1 day'
          and greatest(app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),
            app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at))>r.preferred_start-interval '2 days'),
      'qualification',evaluation-array['service_start','service_end','occupied_start','occupied_end']);
    item:=jsonb_build_object('groomer_id',g.user_id,'safe_profile',profile,'eligibility',evaluation,
      'distance_miles',distance_miles,'reference_price',reference_price);
    rows:=rows||jsonb_build_array(jsonb_build_object('id',g.user_id,'group',group_order,
      'score',score,'source',source,'payload',item,'distance',distance_miles));
  end loop;
  effective:=case when p_sort='fit' and (not config.enabled or scoring_failed) then 'distance' else p_sort end;
  page_rows:='[]';
  for item in select value from jsonb_array_elements(rows) loop
    score:=item->'score';
    bucket:=case when not config.enabled or scoring_failed then 0 else coalesce(floor((score->>'s')::numeric/2),-1) end;
    primary_value:=case when effective='distance' then (item->>'distance')::numeric else 0 end;
    tie:=encode(extensions.hmac(convert_to(jsonb_build_array(actor,'groomer_discovery',resolved->>'tie_scope',
      p_sort,config.algorithm_version,item->>'id')::text,'UTF8'),config.signing_key,'sha256'),'hex');
    sort_key:=jsonb_build_array(item->'group',coalesce(primary_value,1e100),-bucket,tie,item->>'id',item->>'id');
    evidence:=case when config.enabled and not scoring_failed then app_private.public_matching_evidence(score)
      else jsonb_build_object('state','unavailable','algorithm_version',config.algorithm_version,'score_as_of',as_of,
        'related_review_count',0,'independent_customers',0,'completed_count',0,'latest_service_at',null,'coverage','[]'::jsonb) end;
    page_rows:=page_rows||jsonb_build_array(item||jsonb_build_object('sort_key',sort_key,
      'payload',(item->'payload')||jsonb_build_object('matching_evidence',evidence)));
  end loop;
  rows:=page_rows;
  select encode(extensions.digest(convert_to(jsonb_build_object('source',resolved->>'source_key',
    'mode',effective,'enabled',config.enabled,'privacy',config.privacy_revision,'pending',pending,'items',
    coalesce(jsonb_agg(jsonb_build_object('source',value->'source','key',value->'sort_key',
      'profile',value->'payload'->'safe_profile','price',value->'payload'->'reference_price') order by value->>'id'),'[]'))::text,'UTF8'),'sha256'),'hex')
    into revision from jsonb_array_elements(rows);
  if p_cursor is not null and (cursor_data->>'ranking_revision' is distinct from revision
    or cursor_data->>'effective_mode' is distinct from effective
    or deadline is distinct from (cursor_data->>'valid_until')::timestamptz) then
    raise exception using errcode='PT409',message='list_changed';
  end if;
  select coalesce(jsonb_agg(value order by value->'sort_key'),'[]') into page_rows from (
    select value from jsonb_array_elements(rows) where last_key is null or value->'sort_key'>last_key
      order by value->'sort_key' limit p_limit+1) selected;
  if jsonb_array_length(page_rows)>p_limit then
    next_cursor:=app_private.match_cursor_encode(jsonb_build_object('purpose','groomer_discovery',
      'viewer',actor,'role','customer','scope',resolved->>'browse_scope','requested_mode',p_sort,'effective_mode',effective,
      'algorithm_version',config.algorithm_version,'score_as_of',as_of,'valid_until',deadline,
      'ranking_revision',revision,'last_key',page_rows->(p_limit-1)->'sort_key'),config.signing_key);
    page_rows:=page_rows-p_limit;
  end if;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(
    jsonb_set(value->'payload','{matching_evidence,source_revision}',to_jsonb(revision))||
      app_private.discovery_candidate_actions(actor,r.id,(value->>'id')::uuid) order by value->'sort_key'),'[]')
    from jsonb_array_elements(page_rows)),
    'ranking_revision',revision,'score_as_of',as_of,'valid_until',deadline,'algorithm_version',config.algorithm_version,
    'requested_mode',p_sort,'effective_mode',effective,'pending_count',pending,'assessment_count',assessment,
    'estimated_fit_count',estimated,'next_cursor',next_cursor,'_soft_evidence',jsonb_build_object('items',soft_items,
      'enabled',config.enabled,'privacy_revision',config.privacy_revision,'scoring_failed',scoring_failed));
end $$;
revoke all on function app_private.request_groomer_candidates_page(jsonb,text,integer,text,jsonb,uuid)
  from public,anon,authenticated,service_role;

create function app_private.get_request_groomer_candidates_v1(p_scope jsonb,p_sort text,p_limit integer default 25,p_cursor text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=app_private.require_discovery_customer(); config app_private.match_ranking_config%rowtype;
  snapshot app_private.match_browse_snapshots%rowtype; cursor_data jsonb; result jsonb; soft jsonb;
  snapshot_id uuid; browse_scope text;
begin
  browse_scope:='groomer_discovery:'||p_scope::text;
  select * into strict config from app_private.match_ranking_config where singleton;
  if p_cursor is not null then
    cursor_data:=app_private.match_cursor_decode(p_cursor,config.signing_key);
    if cursor_data->>'purpose' is distinct from 'groomer_discovery'
      or cursor_data->>'viewer' is distinct from actor::text or cursor_data->>'role' is distinct from 'customer'
      or cursor_data->>'scope' is distinct from browse_scope or cursor_data->>'requested_mode' is distinct from p_sort then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    if cursor_data ? 'snapshot_id' then
      snapshot_id:=(cursor_data->>'snapshot_id')::uuid;
      select * into snapshot from app_private.match_browse_snapshots where id=snapshot_id and viewer_id=actor
        and viewer_role='customer' and scope=browse_scope and requested_mode=p_sort;
      if not found or snapshot.valid_until<=statement_timestamp()
        or snapshot.privacy_revision is distinct from config.privacy_revision
        or snapshot.algorithm_version is distinct from config.algorithm_version
        or snapshot.captured_at is distinct from (cursor_data->>'score_as_of')::timestamptz
        or snapshot.valid_until is distinct from (cursor_data->>'valid_until')::timestamptz then
        raise exception using errcode='PT409',message='list_changed';
      end if;
      soft:=snapshot.soft_evidence;
    end if;
  end if;
  result:=app_private.request_groomer_candidates_page(p_scope,p_sort,p_limit,p_cursor,soft);
  if result->>'next_cursor' is not null then
    if p_cursor is null then
      snapshot_id:=app_private.store_match_browse_snapshot(actor,'customer',browse_scope,p_sort,result,result->'_soft_evidence');
    end if;
    if snapshot_id is not null then
      cursor_data:=app_private.match_cursor_decode(result->>'next_cursor',config.signing_key);
      result:=jsonb_set(result,'{next_cursor}',to_jsonb(app_private.match_cursor_encode(
        cursor_data||jsonb_build_object('snapshot_id',snapshot_id),config.signing_key)));
    end if;
  end if;
  return result-'_soft_evidence';
end $$;
create function public.get_request_groomer_candidates_v1(p_scope jsonb,p_sort text,p_limit integer default 25,p_cursor text default null)
returns jsonb language sql volatile security invoker set search_path = '' as $$
  select app_private.get_request_groomer_candidates_v1(p_scope,p_sort,p_limit,p_cursor);
$$;
create function app_private.get_discovery_groomer_profile_v1(p_scope jsonb,p_groomer_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if p_groomer_id is null then raise exception using errcode='22023',message='invalid_groomer'; end if;
  result:=app_private.request_groomer_candidates_page(p_scope,'fit',1,null,null,p_groomer_id)->'items'->0;
  if result is null then raise exception using errcode='PT409',message='groomer_unavailable'; end if;
  return result;
end $$;
create function public.get_discovery_groomer_profile_v1(p_scope jsonb,p_groomer_id uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select app_private.get_discovery_groomer_profile_v1(p_scope,p_groomer_id);
$$;
revoke all on function app_private.get_request_groomer_candidates_v1(jsonb,text,integer,text),
  public.get_request_groomer_candidates_v1(jsonb,text,integer,text),
  app_private.get_discovery_groomer_profile_v1(jsonb,uuid),public.get_discovery_groomer_profile_v1(jsonb,uuid)
  from public,anon,authenticated,service_role;
grant execute on function app_private.get_request_groomer_candidates_v1(jsonb,text,integer,text),
  public.get_request_groomer_candidates_v1(jsonb,text,integer,text),
  app_private.get_discovery_groomer_profile_v1(jsonb,uuid),public.get_discovery_groomer_profile_v1(jsonb,uuid) to authenticated;

create or replace function app_private.ranked_marketplace_browse(p_role text,p_request uuid,p_sort text,p_limit integer,p_cursor text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); config app_private.match_ranking_config%rowtype;
  snapshot app_private.match_browse_snapshots%rowtype; cursor_data jsonb; result jsonb; soft_evidence jsonb;
  snapshot_id uuid; browse_scope text:=case when p_role='groomer' then 'matches' else p_request::text end;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles where id=actor and role::text=p_role)
    or (p_role='customer' and not exists(select 1 from public.grooming_requests where id=p_request and customer_id=actor)) then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  select * into strict config from app_private.match_ranking_config where singleton;
  if p_cursor is not null then
    cursor_data:=app_private.match_cursor_decode(p_cursor,config.signing_key);
    -- Legacy cursors and over-budget snapshots retain strict consistency, not truncated pools.
    if not cursor_data ? 'snapshot_id' then
      return app_private.ranked_marketplace_page(p_role,p_request,p_sort,p_limit,p_cursor);
    end if;
    if cursor_data->>'viewer' is distinct from actor::text or cursor_data->>'role' is distinct from p_role
      or cursor_data->>'scope' is distinct from browse_scope or cursor_data->>'requested_mode' is distinct from p_sort then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    snapshot_id:=(cursor_data->>'snapshot_id')::uuid;
    select * into snapshot from app_private.match_browse_snapshots where id=snapshot_id and viewer_id=actor
      and viewer_role=p_role and match_browse_snapshots.scope=browse_scope and requested_mode=p_sort;
    if not found or snapshot.valid_until<=statement_timestamp()
      or snapshot.privacy_revision is distinct from config.privacy_revision
      or snapshot.algorithm_version is distinct from config.algorithm_version
      or snapshot.captured_at is distinct from (cursor_data->>'score_as_of')::timestamptz
      or snapshot.valid_until is distinct from (cursor_data->>'valid_until')::timestamptz then
      raise exception using errcode='PT409',message='list_changed';
    end if;
    soft_evidence:=snapshot.soft_evidence;
  end if;

  -- This stable call uses one fresh statement snapshot for all hard facts and privacy checks.
  result:=app_private.ranked_marketplace_page_with_evidence(p_role,p_request,p_sort,p_limit,p_cursor,soft_evidence);
  if result->>'next_cursor' is not null then
    if p_cursor is null then
      snapshot_id:=app_private.store_match_browse_snapshot(actor,p_role,browse_scope,p_sort,result,result->'_soft_evidence');
      if snapshot_id is null then return result-'_soft_evidence'; end if;
    end if;
    cursor_data:=app_private.match_cursor_decode(result->>'next_cursor',config.signing_key);
    result:=jsonb_set(result,'{next_cursor}',to_jsonb(
      app_private.match_cursor_encode(cursor_data||jsonb_build_object('snapshot_id',snapshot_id),config.signing_key)));
  end if;
  return result-'_soft_evidence';
end $$;

notify pgrst,'reload schema';
