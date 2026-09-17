-- T-392 / CA-14: share timezone names within one read; retain every live admission check.
-- Only owner-only overloads accept the server-loaded catalog. No persistent cache or client input.

CREATE OR REPLACE FUNCTION app_private.groomer_can_admit_service(p_groomer_id uuid, p_start timestamp with time zone, p_end timestamp with time zone, p_now timestamp with time zone, p_valid_zones text[])
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare v_zone text; v_zones integer; v_windows integer; v_limit integer; v_notice integer;
begin
  if p_start is null or p_end is null or p_now is null
    or not pg_catalog.isfinite(p_start) or not pg_catalog.isfinite(p_end)
    or not pg_catalog.isfinite(p_now) or p_start>=p_end then return false; end if;
  select min(timezone),count(distinct timezone),count(*) into v_zone,v_zones,v_windows
    from public.groomer_availability_windows where groomer_id=p_groomer_id;
  if v_zones<>1 or v_windows<>7 or not coalesce(v_zone=any(p_valid_zones),false) then return false; end if;
  select coalesce(p.max_appointments_per_day,4),coalesce(p.minimum_advance_notice_days,0)
    into v_limit,v_notice from public.groomer_profiles g
    left join public.groomer_booking_preferences p on p.groomer_id=g.user_id where g.user_id=p_groomer_id;
  if not found or p_start<app_private.service_timing_earliest_start_validated(p_now,v_notice,v_zone) then
    return false;
  end if;
  return not exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled') and coalesce(b.occupied_start,b.scheduled_start)<p_end
      and p_start<app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at))
    and (select count(*) from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and pg_catalog.timezone(v_zone,b.scheduled_start)::date=pg_catalog.timezone(v_zone,p_start)::date)<v_limit;
end $function$
;
revoke all on function app_private.groomer_can_admit_service(uuid,timestamp with time zone,timestamp with time zone,timestamp with time zone,text[]) from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION app_private.groomer_can_admit_service(p_groomer_id uuid, p_start timestamp with time zone, p_end timestamp with time zone, p_now timestamp with time zone DEFAULT statement_timestamp())
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select app_private.groomer_can_admit_service(p_groomer_id,p_start,p_end,p_now,
    (select array_agg(name) from pg_catalog.pg_timezone_names));
$function$;


CREATE OR REPLACE FUNCTION app_private.occupied_time_off_conflict(p_groomer_id uuid, p_start timestamp with time zone, p_end timestamp with time zone, p_valid_zones text[])
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare v_zone text; v_zone_count integer; v_window_count integer;
begin
  if p_start is null or p_end is null or not pg_catalog.isfinite(p_start)
    or not pg_catalog.isfinite(p_end) or p_start>=p_end then
    raise exception using errcode='22023',message='invalid_occupied_range';
  end if;
  select min(timezone),count(distinct timezone),count(*) into v_zone,v_zone_count,v_window_count
    from public.groomer_availability_windows where groomer_id=p_groomer_id;
  if v_zone_count<>1 or v_window_count<>7 or not coalesce(v_zone=any(p_valid_zones),false) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required';
  end if;
  return exists(select 1 from public.groomer_time_off_windows t where t.groomer_id=p_groomer_id
    and tstzrange(pg_catalog.timezone(v_zone,t.start_date::timestamp),
      pg_catalog.timezone(v_zone,(t.end_date+1)::timestamp),'[)') && tstzrange(p_start,p_end,'[)'));
end $function$
;
revoke all on function app_private.occupied_time_off_conflict(uuid,timestamp with time zone,timestamp with time zone,text[]) from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION app_private.occupied_time_off_conflict(p_groomer_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select app_private.occupied_time_off_conflict(p_groomer_id,p_start,p_end,
    (select array_agg(name) from pg_catalog.pg_timezone_names));
$function$;


CREATE OR REPLACE FUNCTION app_private.occupied_weekly_hours_covered(p_groomer_id uuid, p_start timestamp with time zone, p_end timestamp with time zone, p_valid_zones text[])
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare v_zone text; v_zone_count integer; v_window_count integer; v_starts time[]; v_ends time[];
begin
  if p_start is null or p_end is null or not pg_catalog.isfinite(p_start)
    or not pg_catalog.isfinite(p_end) or p_start>=p_end then
    raise exception using errcode='22023',message='invalid_occupied_range';
  end if;
  select min(timezone),count(distinct timezone),count(*),
    array_agg(case when is_enabled then start_time end order by weekday),
    array_agg(case when is_enabled then end_time end order by weekday)
    into v_zone,v_zone_count,v_window_count,v_starts,v_ends
    from public.groomer_availability_windows where groomer_id=p_groomer_id;
  if v_zone_count<>1 or v_window_count<>7 or not coalesce(v_zone=any(p_valid_zones),false) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required';
  end if;
  return app_private.weekly_hours_cover_interval(p_start,p_end,v_zone,v_starts,v_ends);
end $function$
;
revoke all on function app_private.occupied_weekly_hours_covered(uuid,timestamp with time zone,timestamp with time zone,text[]) from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION app_private.occupied_weekly_hours_covered(p_groomer_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select app_private.occupied_weekly_hours_covered(p_groomer_id,p_start,p_end,
    (select array_agg(name) from pg_catalog.pg_timezone_names));
$function$;


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
      and tstzrange(coalesce(b.occupied_start,b.scheduled_start),app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)')
        && tstzrange(o.occupied_start,o.occupied_end,'[)'))
    or app_private.occupied_time_off_conflict(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones)
    or not app_private.occupied_weekly_hours_covered(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  return jsonb_build_object('terms_valid',true,'selectable',true,'reason','available');
end $function$
;
revoke all on function app_private.evaluate_quote(uuid,timestamp with time zone,text[]) from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION app_private.evaluate_quote(p_offer_id uuid, p_now timestamp with time zone DEFAULT statement_timestamp())
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select app_private.evaluate_quote(p_offer_id,p_now,
    (select array_agg(name) from pg_catalog.pg_timezone_names));
$function$;


CREATE OR REPLACE FUNCTION app_private.get_quote_evaluations(p_offer_ids uuid[])
 RETURNS TABLE(offer_id uuid, evaluation jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=(select auth.uid()); valid_zones text[];
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_offer_ids is null or cardinality(p_offer_ids)>100 then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names;
  return query select o.id,app_private.evaluate_quote(o.id,statement_timestamp(),valid_zones) from public.groomer_offers o
    where o.id=any(p_offer_ids) and exists(select 1 from public.profiles p where p.id=actor
      and ((o.customer_id=actor and p.role='customer') or (o.groomer_id=actor and p.role='groomer')));
end $function$
;

CREATE OR REPLACE FUNCTION app_private.ranked_marketplace_page(p_role text, p_request uuid, p_sort text, p_limit integer, p_cursor text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=(select auth.uid()); config app_private.match_ranking_config%rowtype;
  clock timestamptz:=statement_timestamp(); as_of timestamptz; deadline timestamptz; scope text;
  cursor_data jsonb; last_key jsonb; candidates jsonb:='[]'; ranked jsonb; page_rows jsonb;
  fact record; score jsonb; evaluation jsonb; payload jsonb; evidence jsonb; source jsonb;
  candidate_id uuid; item_id uuid; request_id uuid; groomer_id uuid; offer_id uuid;
  group_order integer; primary_value numeric; bucket numeric; tie text; distance_miles double precision;
  revision text; effective text; next_cursor text; pending integer:=0; assessment integer:=0; pending_sources jsonb:='[]';
  score_cache jsonb:='{}'; score_key text;
  scoring_failed boolean:=false; fact_deadline timestamptz; valid_zones text[];
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or p_role not in ('groomer','customer')
    or not exists(select 1 from public.profiles where id=actor and role::text=p_role) then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  if p_role='customer' and not exists(select 1 from public.grooming_requests where id=p_request and customer_id=actor) then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  if p_limit is null or p_limit not between 1 and 50 or p_sort is null
    or (p_role='groomer' and (p_request is not null or p_sort not in ('fit','distance','newest')))
    or (p_role='customer' and p_sort not in ('balanced','distance','earliest','price')) then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  select * into strict config from app_private.match_ranking_config where singleton;
  config.enabled:=config.enabled or actor=any(config.validation_actor_ids);
  scope:=case when p_role='groomer' then 'matches' else p_request::text end;
  as_of:=clock; deadline:=clock+interval '5 minutes';
  if p_cursor is not null then
    cursor_data:=app_private.match_cursor_decode(p_cursor,config.signing_key);
    if cursor_data->>'viewer' is distinct from actor::text or cursor_data->>'role' is distinct from p_role
      or cursor_data->>'scope' is distinct from scope or cursor_data->>'requested_mode' is distinct from p_sort
      or cursor_data->>'algorithm_version' is distinct from config.algorithm_version then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    as_of:=(cursor_data->>'score_as_of')::timestamptz;
    deadline:=(cursor_data->>'valid_until')::timestamptz;
    last_key:=cursor_data->'last_key';
    if as_of is null or deadline is null or not isfinite(as_of) or not isfinite(deadline)
      or as_of>clock or deadline>as_of+interval '5 minutes' or jsonb_typeof(last_key) is distinct from 'array'
      or jsonb_array_length(last_key)<>6 then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    if deadline<=clock then raise exception using errcode='PT409',message='list_changed'; end if;
  end if;

  if config.enabled or p_role='customer' then select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names; end if;
  -- Both branches enumerate the entire authorized scope under this STABLE call's statement snapshot.
  for fact in
    select r.id request_id,actor groomer_id,null::uuid offer_id,m.id item_id,r.id candidate_id,
      jsonb_build_object('match',jsonb_build_object('id',m.id,'request_id',r.id,'groomer_id',actor,
        'customer_id',r.customer_id,'match_score',null,'match_reason',null,'dismiss_reason',m.dismiss_reason,
        'status',m.status,'viewed_at',m.viewed_at,'dismissed_at',m.dismissed_at,
        'created_at',m.created_at,'updated_at',m.updated_at),
        'request',jsonb_build_object('id',r.id,'customer_id',r.customer_id,'pet_id',r.pet_id,
        'pet_snapshot',r.pet_snapshot,'photo_snapshot',r.photo_snapshot,'service_type',r.service_type,
        'service_notes',r.service_notes,'preferred_start',r.preferred_start,'preferred_end',r.preferred_end,
        'preference_time_zone_identifier',r.preference_time_zone_identifier,'location_mode',r.location_mode,
        'street_address',r.street_address,'city',r.city,'state',r.state,'zip_code',r.zip_code,
        'travel_radius_miles',r.travel_radius_miles,'status',r.status,'expires_at',r.expires_at,
        'created_at',r.created_at,'updated_at',r.updated_at,'terms_revision',r.terms_revision)) payload,
      r.created_at newest,null::timestamptz earliest,null::numeric price,r.expires_at expiry,
      to_jsonb(c)-array['witness','evidence_revision','rating_revision','display_revision','ranking_revision'] source
    from public.request_matches m join public.grooming_requests r on r.id=m.request_id
      left join app_private.match_candidate_evaluations c on c.request_id=r.id and c.groomer_id=actor
    where p_role='groomer' and m.groomer_id=actor and m.status in ('visible','viewed')
      and r.status in ('open','has_offers') and r.expires_at>clock
      and not exists(select 1 from public.groomer_offers o where o.request_id=r.id and o.groomer_id=actor and o.status='pending')
    union all
    select r.id,o.groomer_id,o.id,o.id,o.groomer_id,
      jsonb_build_object('offer',jsonb_build_object('id',o.id,'request_id',o.request_id,'match_id',o.match_id,
        'customer_id',o.customer_id,'groomer_id',o.groomer_id,'proposed_start',o.proposed_start,'proposed_end',o.proposed_end,
        'price_estimate',o.price_estimate,'message',o.message,'status',o.status,'expires_at',o.expires_at,
        'withdrawn_at',o.withdrawn_at,'created_at',o.created_at,'updated_at',o.updated_at,
        'applied_timing_buffers',o.applied_timing_buffers,'service_time_zone_identifier',o.service_time_zone_identifier,
        'schedule_time_zone_identifier',o.schedule_time_zone_identifier,'occupied_start',o.occupied_start,
        'occupied_end',o.occupied_end,'agreement_snapshot',o.agreement_snapshot),
        'groomer_profile',case when g.user_id is null then null else jsonb_build_object('user_id',g.user_id,
        'business_name',g.business_name,'bio',g.bio,'years_experience',g.years_experience,'base_city',g.base_city,
        'base_state',g.base_state,'service_radius_miles',g.service_radius_miles,'service_location_mode',g.service_location_mode,
        'rating_avg',g.rating_avg,'rating_count',g.rating_count,'rating_sum',g.rating_sum,
        'is_active',g.is_active,'is_verified',g.is_verified) end),
      o.created_at,o.proposed_start,o.price_estimate,least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes'),
      jsonb_build_object('request_revision',r.terms_revision,'profile_revision',g.eligibility_revision,
        'quote',to_jsonb(o),'cache',to_jsonb(c)-array['witness','evidence_revision','rating_revision','display_revision','ranking_revision'])
    from public.groomer_offers o join public.grooming_requests r on r.id=o.request_id
      left join public.groomer_profiles g on g.user_id=o.groomer_id
      left join app_private.match_candidate_evaluations c on c.request_id=r.id and c.groomer_id=o.groomer_id
    where p_role='customer' and r.id=p_request and r.customer_id=actor and o.customer_id=actor
  loop
    request_id:=fact.request_id; groomer_id:=fact.groomer_id; offer_id:=fact.offer_id;
    candidate_id:=fact.candidate_id; item_id:=fact.item_id; payload:=fact.payload;
    if p_role='groomer' then
      evaluation:=app_private.read_candidate_evaluation(request_id,groomer_id,clock);
      if evaluation->>'state'='excluded' then continue; end if;
      group_order:=case evaluation->>'state' when 'estimated_fit' then 0 when 'assessment_required' then 1 else 2 end;
      if group_order=2 then pending:=pending+1; end if;
      if group_order=1 then assessment:=assessment+1; end if;
      payload:=jsonb_set(payload,'{match,eligibility_evaluation}',evaluation);
      fact_deadline:=(evaluation->>'valid_until')::timestamptz;
    else
      evaluation:=app_private.evaluate_quote(offer_id,clock,valid_zones);
      group_order:=case when (evaluation->>'selectable')::boolean then 0 else 1 end;
      payload:=payload||jsonb_build_object('quote_evaluation',evaluation);
      -- Daily advance-notice boundaries can change a quote without source writes.
      select min(timezone(w.timezone,(timezone(w.timezone,clock)::date+1)::timestamp)) into fact_deadline
        from public.groomer_availability_windows w where w.groomer_id=fact.groomer_id
          and w.timezone=any(valid_zones);
    end if;
    if fact.expiry>clock then deadline:=least(deadline,fact.expiry); end if;
    if fact_deadline>clock then deadline:=least(deadline,fact_deadline); end if;
    source:=jsonb_build_object('facts',fact.source,'evaluation',evaluation,'events',
      (select coalesce(jsonb_agg(q.id order by q.id),'[]') from app_private.match_refresh_queue q
        where q.request_id=fact.request_id and q.groomer_id=fact.groomer_id and q.reason='hard_eligibility'));
    select extensions.st_distance(a.location,b.location)/1609.344 into distance_miles
      from public.grooming_requests r join app_private.address_locations a on a.id=r.address_location_id and a.owner_id=r.customer_id
      join public.groomer_profiles g on g.user_id=fact.groomer_id
      join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=g.user_id where r.id=fact.request_id;
    score:=null;
    if config.enabled then
      begin
        select jsonb_build_array(groomer_id,lower(r.pet_snapshot->>'species'),r.service_type,
          app_private.match_target_keys(request_id,groomer_id,offer_id,valid_zones),distance_miles,as_of)::text
          into score_key from public.grooming_requests r where r.id=request_id;
        score:=score_cache->score_key;
        if score is null then
          score:=app_private.score_match_evidence(request_id,groomer_id,as_of,offer_id,valid_zones);
          score_cache:=score_cache||jsonb_build_object(score_key,score);
        end if;
      exception when numeric_value_out_of_range or division_by_zero then scoring_failed:=true;
      end;
    end if;
    candidates:=candidates||jsonb_build_array(jsonb_build_object('candidate',candidate_id,'item',item_id,
      'payload',payload,'source',source,'score',score,'group',group_order,'distance',distance_miles,
      'newest',-extract(epoch from fact.newest),'earliest',extract(epoch from fact.earliest),'price',fact.price));
  end loop;

  if p_role='groomer' then
    -- Coarse candidates without an authorized match expose only a count, never request details.
    with coarse as (
      select c.request_id from app_private.match_candidate_evaluations c where c.groomer_id=actor
      union select q.request_id from app_private.match_refresh_queue q where q.groomer_id=actor and q.reason='hard_eligibility'
    )
    select coalesce(jsonb_agg(jsonb_build_object('request',c.request_id,'events',
      (select jsonb_agg(q.id order by q.id) from app_private.match_refresh_queue q
        where q.request_id=c.request_id and q.groomer_id=actor and q.reason='hard_eligibility')) order by c.request_id),'[]') into pending_sources
      from coarse c join public.grooming_requests r on r.id=c.request_id
      where r.status in ('open','has_offers') and r.expires_at>clock
        and not exists(select 1 from public.request_matches m where m.request_id=c.request_id and m.groomer_id=actor)
        and app_private.read_candidate_evaluation(c.request_id,actor,clock)->>'state'='pending';
    pending:=pending+jsonb_array_length(pending_sources);
  end if;
  effective:=case when (not config.enabled or scoring_failed) and p_sort in ('fit','balanced') then 'time_fallback' else p_sort end;
  ranked:='[]';
  for fact in select value data from jsonb_array_elements(candidates) loop
    score:=fact.data->'score';
    bucket:=case when not config.enabled or scoring_failed then 0
      else coalesce(floor((score->>case when p_role='groomer' then 'b' else 's' end)::numeric/2),-1) end;
    primary_value:=case effective when 'distance' then (fact.data->>'distance')::numeric
      when 'newest' then (fact.data->>'newest')::numeric when 'price' then (fact.data->>'price')::numeric
      when 'earliest' then (fact.data->>'earliest')::numeric
      when 'time_fallback' then (fact.data->>case when p_role='groomer' then 'newest' else 'earliest' end)::numeric else 0 end;
    tie:=encode(extensions.hmac(convert_to(jsonb_build_array(actor,p_role,scope,p_sort,config.algorithm_version,
      fact.data->>'candidate')::text,'UTF8'),config.signing_key,'sha256'),'hex');
    evidence:=case when config.enabled and not scoring_failed then app_private.public_matching_evidence(score)
      else jsonb_build_object('state','unavailable','algorithm_version',config.algorithm_version,'score_as_of',as_of,
        'related_review_count',0,'independent_customers',0,'completed_count',0,'latest_service_at',null,'coverage','[]'::jsonb) end;
    ranked:=ranked||jsonb_build_array(fact.data||jsonb_build_object('sort_key',jsonb_build_array(
      fact.data->'group',coalesce(primary_value,1e100),-bucket,tie,fact.data->>'candidate',fact.data->>'item'),
      'payload',(fact.data->'payload')||jsonb_build_object('evidence',evidence)));
  end loop;
  select encode(extensions.digest(convert_to(jsonb_build_object('mode',effective,'enabled',config.enabled,
    'pending',pending_sources,'assessment',assessment,'sources',coalesce(jsonb_agg(value-'score' order by value->>'item'),'[]'))::text,'UTF8'),'sha256'),'hex')
    into revision from jsonb_array_elements(ranked);
  if p_cursor is not null and (cursor_data->>'ranking_revision' is distinct from revision
    or cursor_data->>'effective_mode' is distinct from effective
    or deadline is distinct from (cursor_data->>'valid_until')::timestamptz) then
    raise exception using errcode='PT409',message='list_changed';
  end if;
  select coalesce(jsonb_agg(value order by value->'sort_key'),'[]') into page_rows from (
    select value from jsonb_array_elements(ranked)
      where last_key is null or value->'sort_key'>last_key
      order by value->'sort_key' limit p_limit+1
  ) page;
  if jsonb_array_length(page_rows)>p_limit then
    next_cursor:=app_private.match_cursor_encode(jsonb_build_object('viewer',actor,'role',p_role,'scope',scope,
      'requested_mode',p_sort,'effective_mode',effective,'algorithm_version',config.algorithm_version,
      'score_as_of',as_of,'valid_until',deadline,'ranking_revision',revision,
      'last_key',page_rows->(p_limit-1)->'sort_key'),config.signing_key);
    page_rows:=page_rows-p_limit;
  end if;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(
    jsonb_set(value->'payload','{evidence,source_revision}',to_jsonb(revision)) order by value->'sort_key'),'[]')
    from jsonb_array_elements(page_rows)),
    'ranking_revision',revision,'score_as_of',as_of,'valid_until',deadline,'algorithm_version',config.algorithm_version,
    'requested_mode',p_sort,'effective_mode',effective,'pending_count',pending,'assessment_count',assessment,'next_cursor',next_cursor);
end $function$
;

CREATE OR REPLACE FUNCTION app_private.ranked_marketplace_page_with_evidence(p_role text, p_request uuid, p_sort text, p_limit integer, p_cursor text, p_soft jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=(select auth.uid()); config app_private.match_ranking_config%rowtype;
  clock timestamptz:=statement_timestamp(); as_of timestamptz; deadline timestamptz; scope text;
  cursor_data jsonb; last_key jsonb; candidates jsonb:='[]'; ranked jsonb; page_rows jsonb;
  fact record; score jsonb; evaluation jsonb; payload jsonb; evidence jsonb; source jsonb;
  candidate_id uuid; item_id uuid; request_id uuid; groomer_id uuid; offer_id uuid;
  group_order integer; primary_value numeric; bucket numeric; tie text; distance_miles double precision;
  revision text; effective text; next_cursor text; pending integer:=0; assessment integer:=0; pending_sources jsonb:='[]';
  score_cache jsonb:='{}'; score_key text;
  scoring_failed boolean:=coalesce((p_soft->>'scoring_failed')::boolean,false); fact_deadline timestamptz; valid_zones text[];
  saved jsonb; soft_items jsonb:='{}';
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or p_role not in ('groomer','customer')
    or not exists(select 1 from public.profiles where id=actor and role::text=p_role) then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  if p_role='customer' and not exists(select 1 from public.grooming_requests where id=p_request and customer_id=actor) then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  if p_limit is null or p_limit not between 1 and 50 or p_sort is null
    or (p_role='groomer' and (p_request is not null or p_sort not in ('fit','distance','newest')))
    or (p_role='customer' and p_sort not in ('balanced','distance','earliest','price')) then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  select * into strict config from app_private.match_ranking_config where singleton;
  config.enabled:=config.enabled or actor=any(config.validation_actor_ids);
  if p_soft is not null and ((p_soft->>'enabled')::boolean is distinct from config.enabled
    or p_soft->>'privacy_revision' is distinct from config.privacy_revision::text) then
    raise exception using errcode='PT409',message='list_changed';
  end if;
  scope:=case when p_role='groomer' then 'matches' else p_request::text end;
  as_of:=clock; deadline:=clock+interval '5 minutes';
  if p_cursor is not null then
    cursor_data:=app_private.match_cursor_decode(p_cursor,config.signing_key);
    if cursor_data->>'viewer' is distinct from actor::text or cursor_data->>'role' is distinct from p_role
      or cursor_data->>'scope' is distinct from scope or cursor_data->>'requested_mode' is distinct from p_sort
      or cursor_data->>'algorithm_version' is distinct from config.algorithm_version then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    as_of:=(cursor_data->>'score_as_of')::timestamptz;
    deadline:=(cursor_data->>'valid_until')::timestamptz;
    last_key:=cursor_data->'last_key';
    if as_of is null or deadline is null or not isfinite(as_of) or not isfinite(deadline)
      or as_of>clock or deadline>as_of+interval '5 minutes' or jsonb_typeof(last_key) is distinct from 'array'
      or jsonb_array_length(last_key)<>6 then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    if deadline<=clock then raise exception using errcode='PT409',message='list_changed'; end if;
  end if;

  if config.enabled or p_role='customer' then select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names; end if;
  -- Both branches enumerate the entire authorized scope under this STABLE call's statement snapshot.
  for fact in
    select r.id request_id,actor groomer_id,null::uuid offer_id,m.id item_id,r.id candidate_id,
      jsonb_build_object('match',jsonb_build_object('id',m.id,'request_id',r.id,'groomer_id',actor,
        'customer_id',r.customer_id,'match_score',null,'match_reason',null,'dismiss_reason',m.dismiss_reason,
        'status',m.status,'viewed_at',m.viewed_at,'dismissed_at',m.dismissed_at,
        'created_at',m.created_at,'updated_at',m.updated_at),
        'request',jsonb_build_object('id',r.id,'customer_id',r.customer_id,'pet_id',r.pet_id,
        'pet_snapshot',r.pet_snapshot,'photo_snapshot',r.photo_snapshot,'service_type',r.service_type,
        'service_notes',r.service_notes,'preferred_start',r.preferred_start,'preferred_end',r.preferred_end,
        'preference_time_zone_identifier',r.preference_time_zone_identifier,'location_mode',r.location_mode,
        'street_address',r.street_address,'city',r.city,'state',r.state,'zip_code',r.zip_code,
        'travel_radius_miles',r.travel_radius_miles,'status',r.status,'expires_at',r.expires_at,
        'created_at',r.created_at,'updated_at',r.updated_at,'terms_revision',r.terms_revision)) payload,
      r.created_at newest,null::timestamptz earliest,null::numeric price,r.expires_at expiry,
      to_jsonb(c)-array['witness','evidence_revision','rating_revision','display_revision','ranking_revision'] source
    from public.request_matches m join public.grooming_requests r on r.id=m.request_id
      left join app_private.match_candidate_evaluations c on c.request_id=r.id and c.groomer_id=actor
    where p_role='groomer' and m.groomer_id=actor and m.status in ('visible','viewed')
      and r.status in ('open','has_offers') and r.expires_at>clock
      and not exists(select 1 from public.groomer_offers o where o.request_id=r.id and o.groomer_id=actor and o.status='pending')
    union all
    select r.id,o.groomer_id,o.id,o.id,o.groomer_id,
      jsonb_build_object('offer',jsonb_build_object('id',o.id,'request_id',o.request_id,'match_id',o.match_id,
        'customer_id',o.customer_id,'groomer_id',o.groomer_id,'proposed_start',o.proposed_start,'proposed_end',o.proposed_end,
        'price_estimate',o.price_estimate,'message',o.message,'status',o.status,'expires_at',o.expires_at,
        'withdrawn_at',o.withdrawn_at,'created_at',o.created_at,'updated_at',o.updated_at,
        'applied_timing_buffers',o.applied_timing_buffers,'service_time_zone_identifier',o.service_time_zone_identifier,
        'schedule_time_zone_identifier',o.schedule_time_zone_identifier,'occupied_start',o.occupied_start,
        'occupied_end',o.occupied_end,'agreement_snapshot',o.agreement_snapshot),
        'groomer_profile',case when g.user_id is null then null else jsonb_build_object('user_id',g.user_id,
        'business_name',g.business_name,'bio',g.bio,'years_experience',g.years_experience,'base_city',g.base_city,
        'base_state',g.base_state,'service_radius_miles',g.service_radius_miles,'service_location_mode',g.service_location_mode,
        'rating_avg',g.rating_avg,'rating_count',g.rating_count,'rating_sum',g.rating_sum,
        'is_active',g.is_active,'is_verified',g.is_verified) end),
      o.created_at,o.proposed_start,o.price_estimate,least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes'),
      jsonb_build_object('request_revision',r.terms_revision,'profile_revision',g.eligibility_revision,
        'quote',to_jsonb(o),'cache',to_jsonb(c)-array['witness','evidence_revision','rating_revision','display_revision','ranking_revision'])
    from public.groomer_offers o join public.grooming_requests r on r.id=o.request_id
      left join public.groomer_profiles g on g.user_id=o.groomer_id
      left join app_private.match_candidate_evaluations c on c.request_id=r.id and c.groomer_id=o.groomer_id
    where p_role='customer' and r.id=p_request and r.customer_id=actor and o.customer_id=actor
  loop
    request_id:=fact.request_id; groomer_id:=fact.groomer_id; offer_id:=fact.offer_id;
    candidate_id:=fact.candidate_id; item_id:=fact.item_id; payload:=fact.payload;
    if p_role='groomer' then
      evaluation:=app_private.read_candidate_evaluation(request_id,groomer_id,clock);
      if evaluation->>'state'='excluded' then continue; end if;
      group_order:=case evaluation->>'state' when 'estimated_fit' then 0 when 'assessment_required' then 1 else 2 end;
      if group_order=2 then pending:=pending+1; end if;
      if group_order=1 then assessment:=assessment+1; end if;
      payload:=jsonb_set(payload,'{match,eligibility_evaluation}',evaluation);
      fact_deadline:=(evaluation->>'valid_until')::timestamptz;
    else
      evaluation:=app_private.evaluate_quote(offer_id,clock,valid_zones);
      group_order:=case when (evaluation->>'selectable')::boolean then 0 else 1 end;
      payload:=payload||jsonb_build_object('quote_evaluation',evaluation);
      -- Daily advance-notice boundaries can change a quote without source writes.
      select min(timezone(w.timezone,(timezone(w.timezone,clock)::date+1)::timestamp)) into fact_deadline
        from public.groomer_availability_windows w where w.groomer_id=fact.groomer_id
          and w.timezone=any(valid_zones);
    end if;
    if fact.expiry>clock then deadline:=least(deadline,fact.expiry); end if;
    if fact_deadline>clock then deadline:=least(deadline,fact_deadline); end if;
    source:=jsonb_build_object('facts',fact.source,'evaluation',evaluation,'events',
      (select coalesce(jsonb_agg(q.id order by q.id),'[]') from app_private.match_refresh_queue q
        where q.request_id=fact.request_id and q.groomer_id=fact.groomer_id and q.reason='hard_eligibility'));
    select extensions.st_distance(a.location,b.location)/1609.344 into distance_miles
      from public.grooming_requests r join app_private.address_locations a on a.id=r.address_location_id and a.owner_id=r.customer_id
      join public.groomer_profiles g on g.user_id=fact.groomer_id
      join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=g.user_id where r.id=fact.request_id;
    score:=null;
    if p_soft is not null then
      saved:=p_soft->'items'->item_id::text;
      if saved is null then raise exception using errcode='PT409',message='list_changed'; end if;
      score:=saved->'score';
      if p_role='customer' and jsonb_typeof(payload->'groomer_profile')='object' then
        payload:=jsonb_set(payload,'{groomer_profile}',(payload->'groomer_profile')||(saved->'ratings'));
      end if;
    elsif config.enabled then
      begin
        select jsonb_build_array(groomer_id,lower(r.pet_snapshot->>'species'),r.service_type,
          app_private.match_target_keys(request_id,groomer_id,offer_id,valid_zones),distance_miles,as_of)::text
          into score_key from public.grooming_requests r where r.id=request_id;
        score:=score_cache->score_key;
        if score is null then
          score:=app_private.score_match_evidence(request_id,groomer_id,as_of,offer_id,valid_zones);
          score_cache:=score_cache||jsonb_build_object(score_key,score);
        end if;
      exception when numeric_value_out_of_range or division_by_zero then scoring_failed:=true;
      end;
    end if;
    soft_items:=soft_items||jsonb_build_object(item_id::text,jsonb_build_object('score',score,'ratings',
      case when p_role='customer' then jsonb_build_object('rating_avg',payload->'groomer_profile'->'rating_avg',
        'rating_count',payload->'groomer_profile'->'rating_count','rating_sum',payload->'groomer_profile'->'rating_sum') else '{}'::jsonb end));
    candidates:=candidates||jsonb_build_array(jsonb_build_object('candidate',candidate_id,'item',item_id,
      'payload',payload,'source',source,'score',score,'group',group_order,'distance',distance_miles,
      'newest',-extract(epoch from fact.newest),'earliest',extract(epoch from fact.earliest),'price',fact.price));
  end loop;

  if p_role='groomer' then
    -- Coarse candidates without an authorized match expose only a count, never request details.
    with coarse as (
      select c.request_id from app_private.match_candidate_evaluations c where c.groomer_id=actor
      union select q.request_id from app_private.match_refresh_queue q where q.groomer_id=actor and q.reason='hard_eligibility'
    )
    select coalesce(jsonb_agg(jsonb_build_object('request',c.request_id,'events',
      (select jsonb_agg(q.id order by q.id) from app_private.match_refresh_queue q
        where q.request_id=c.request_id and q.groomer_id=actor and q.reason='hard_eligibility')) order by c.request_id),'[]') into pending_sources
      from coarse c join public.grooming_requests r on r.id=c.request_id
      where r.status in ('open','has_offers') and r.expires_at>clock
        and not exists(select 1 from public.request_matches m where m.request_id=c.request_id and m.groomer_id=actor)
        and app_private.read_candidate_evaluation(c.request_id,actor,clock)->>'state'='pending';
    pending:=pending+jsonb_array_length(pending_sources);
  end if;
  effective:=case when (not config.enabled or scoring_failed) and p_sort in ('fit','balanced') then 'time_fallback' else p_sort end;
  ranked:='[]';
  for fact in select value data from jsonb_array_elements(candidates) loop
    score:=fact.data->'score';
    bucket:=case when not config.enabled or scoring_failed then 0
      else coalesce(floor((score->>case when p_role='groomer' then 'b' else 's' end)::numeric/2),-1) end;
    primary_value:=case effective when 'distance' then (fact.data->>'distance')::numeric
      when 'newest' then (fact.data->>'newest')::numeric when 'price' then (fact.data->>'price')::numeric
      when 'earliest' then (fact.data->>'earliest')::numeric
      when 'time_fallback' then (fact.data->>case when p_role='groomer' then 'newest' else 'earliest' end)::numeric else 0 end;
    tie:=encode(extensions.hmac(convert_to(jsonb_build_array(actor,p_role,scope,p_sort,config.algorithm_version,
      fact.data->>'candidate')::text,'UTF8'),config.signing_key,'sha256'),'hex');
    evidence:=case when config.enabled and not scoring_failed then app_private.public_matching_evidence(score)
      else jsonb_build_object('state','unavailable','algorithm_version',config.algorithm_version,'score_as_of',as_of,
        'related_review_count',0,'independent_customers',0,'completed_count',0,'latest_service_at',null,'coverage','[]'::jsonb) end;
    ranked:=ranked||jsonb_build_array(fact.data||jsonb_build_object('sort_key',jsonb_build_array(
      fact.data->'group',coalesce(primary_value,1e100),-bucket,tie,fact.data->>'candidate',fact.data->>'item'),
      'payload',(fact.data->'payload')||jsonb_build_object('evidence',evidence)));
  end loop;
  select encode(extensions.digest(convert_to(jsonb_build_object('mode',effective,'enabled',config.enabled,
    'pending',pending_sources,'assessment',assessment,'sources',coalesce(jsonb_agg(value-'score' order by value->>'item'),'[]'))::text,'UTF8'),'sha256'),'hex')
    into revision from jsonb_array_elements(ranked);
  if p_cursor is not null and (cursor_data->>'ranking_revision' is distinct from revision
    or cursor_data->>'effective_mode' is distinct from effective
    or deadline is distinct from (cursor_data->>'valid_until')::timestamptz) then
    raise exception using errcode='PT409',message='list_changed';
  end if;
  select coalesce(jsonb_agg(value order by value->'sort_key'),'[]') into page_rows from (
    select value from jsonb_array_elements(ranked)
      where last_key is null or value->'sort_key'>last_key
      order by value->'sort_key' limit p_limit+1
  ) page;
  if jsonb_array_length(page_rows)>p_limit then
    next_cursor:=app_private.match_cursor_encode(jsonb_build_object('viewer',actor,'role',p_role,'scope',scope,
      'requested_mode',p_sort,'effective_mode',effective,'algorithm_version',config.algorithm_version,
      'score_as_of',as_of,'valid_until',deadline,'ranking_revision',revision,
      'last_key',page_rows->(p_limit-1)->'sort_key'),config.signing_key);
    page_rows:=page_rows-p_limit;
  end if;
  return jsonb_build_object('_soft_evidence',jsonb_build_object('items',soft_items,'enabled',config.enabled,
    'scoring_failed',scoring_failed,'privacy_revision',config.privacy_revision),'items',(select coalesce(jsonb_agg(
    jsonb_set(value->'payload','{evidence,source_revision}',to_jsonb(revision)) order by value->'sort_key'),'[]')
    from jsonb_array_elements(page_rows)),
    'ranking_revision',revision,'score_as_of',as_of,'valid_until',deadline,'algorithm_version',config.algorithm_version,
    'requested_mode',p_sort,'effective_mode',effective,'pending_count',pending,'assessment_count',assessment,'next_cursor',next_cursor);
end $function$
;
