CREATE OR REPLACE FUNCTION app_private.evaluate_match_eligibility_with_zones(p_request uuid, p_groomer uuid, p_now timestamp with time zone, p_valid_zones text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype;
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
  assessment:=app_private.evaluate_match_constraints(p_request,p_groomer,p_now);
  if assessment->>'state'='excluded' then return assessment; end if;
  assessment:=null;
  select * into strict r from public.grooming_requests where id=p_request;
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
              'service_id',service.id,'required_confirmations',to_jsonb(required));
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

-- Invalidate only cached results that could have been masked by legacy scope.
insert into app_private.match_refresh_queue(request_id,groomer_id,reason)
select request_id,groomer_id,'hard_eligibility' from app_private.match_candidate_evaluations
where result->>'state'='assessment_required'
  and result->'required_confirmations' ? 'service_species_configuration';
