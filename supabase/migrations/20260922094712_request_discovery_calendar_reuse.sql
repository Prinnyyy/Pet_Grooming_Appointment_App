-- Reuse exact calendar results only within one candidate page evaluation.
-- Every groomer still rechecks current permissions, resources, buffers and capacity.
CREATE FUNCTION app_private.evaluate_context_eligibility_cached(p_context public.grooming_requests, p_groomer uuid, p_now timestamp with time zone, p_valid_zones text[], INOUT p_weekly_cache jsonb, OUT evaluation jsonb)
 RETURNS record
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
  assessment_duration integer; assessment_id uuid; calendar_key text;
begin
  assessment:=app_private.evaluate_context_constraints(p_context,p_groomer,p_now);
  if assessment->>'state'='excluded' then evaluation:=assessment; return; end if;
  assessment:=null;
  select * into strict g from public.groomer_profiles where user_id=p_groomer;
  select min(timezone),count(distinct timezone),count(*),
    array_agg(case when is_enabled then start_time end order by weekday),
    array_agg(case when is_enabled then end_time end order by weekday)
    into zone,zones,windows,starts,ends from public.groomer_availability_windows where groomer_id=p_groomer;
  if zones<>1 or windows<>7 then
    evaluation:=jsonb_build_object('state','excluded','reason','schedule_confirmation_required'); return;
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
    evaluation:=jsonb_build_object('state','excluded','reason','schedule_confirmation_required'); return;
  end if;
  if not coalesce(service_zone=any(valid_zones),false) then
    evaluation:=jsonb_build_object('state','excluded','reason','service_timezone_confirmation_required'); return;
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
      calendar_key:=jsonb_build_array(window_start-make_interval(mins=>before_minutes),
        window_end+make_interval(mins=>after_minutes),zone,starts,ends)::text;
      if p_weekly_cache ? calendar_key then
        available:=(p_weekly_cache->>calendar_key)::tstzmultirange;
      else
        available:=app_private.match_weekly_ranges_validated(window_start-make_interval(mins=>before_minutes),
          window_end+make_interval(mins=>after_minutes),zone,starts,ends);
        p_weekly_cache:=coalesce(p_weekly_cache,'{}')||jsonb_build_object(calendar_key,available::text);
      end if;
      if available is null then
        evaluation:=jsonb_build_object('state','assessment_required','reason','schedule_evaluation_required'); return;
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
            evaluation:=jsonb_build_object('state','estimated_fit','reason','continuous_opening',
              'service_id',service.id,'service_start',allocation.service_start,'service_end',allocation.service_end,
              'occupied_start',allocation.occupied_start,'occupied_end',allocation.occupied_end); return;
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
  evaluation:=coalesce(assessment,jsonb_build_object('state','excluded','reason','no_continuous_opening')); return;
end $function$;

revoke all on function app_private.evaluate_context_eligibility_cached(public.grooming_requests,uuid,timestamptz,text[],jsonb)
  from public,anon,authenticated,service_role;

create or replace function app_private.evaluate_context_eligibility(p_context public.grooming_requests,
  p_groomer uuid,p_now timestamptz,p_valid_zones text[])
returns jsonb language sql stable set search_path = '' as $$
  select result.evaluation from app_private.evaluate_context_eligibility_cached(p_context,p_groomer,p_now,p_valid_zones,'{}') result;
$$;

create or replace function app_private.request_groomer_candidates_page(p_scope jsonb,p_sort text,p_limit integer,
  p_cursor text,p_soft jsonb,p_profile uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=app_private.require_discovery_customer(); config app_private.match_ranking_config%rowtype;
  resolved jsonb; r public.grooming_requests%rowtype; g record; clock timestamptz:=statement_timestamp();
  as_of timestamptz:=clock; deadline timestamptz; cursor_data jsonb; last_key jsonb; valid_zones text[];
  weekly_cache jsonb:='{}'; evaluation jsonb; score jsonb; profile jsonb; reference_price jsonb; source jsonb; saved jsonb;
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
    select result.evaluation,result.p_weekly_cache into evaluation,weekly_cache
      from app_private.evaluate_context_eligibility_cached(r,g.user_id,clock,valid_zones,weekly_cache) result;
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
