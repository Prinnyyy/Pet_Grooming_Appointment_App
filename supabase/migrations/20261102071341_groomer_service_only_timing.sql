-- T-435 / D-069: the appointment alone reserves time. Approved Handoff 4 D2.
-- Append-only replacement of installed definitions; locks, participant checks, grants,
-- receipt/revision handling, weekly hours, time off, daily capacity and notice are retained.
-- Historical offer/booking snapshots are never rewritten. Legacy padded pending quotes
-- use the existing legacy_unverified replacement flow before they can create a booking.

CREATE OR REPLACE FUNCTION app_private.service_timing_allocation(p_start timestamp with time zone, p_duration_minutes integer, p_preparation integer, p_cleanup integer, p_inbound_travel integer, p_outbound_travel integer, p_location_mode text)
 RETURNS TABLE(service_start timestamp with time zone, service_end timestamp with time zone, occupied_start timestamp with time zone, occupied_end timestamp with time zone)
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  v_end timestamptz;
begin
  if p_start is null or not pg_catalog.isfinite(p_start)
    or p_duration_minutes is null or p_duration_minutes not between 15 and 720 then
    raise exception using errcode='22023', message='invalid_service_duration';
  end if;
  if p_location_mode is null or p_location_mode not in
    ('groomer_comes_to_customer','customer_comes_to_groomer') then
    raise exception using errcode='22023', message='invalid_location_mode';
  end if;
  v_end := p_start + pg_catalog.make_interval(mins => p_duration_minutes);
  -- Deprecated buffer arguments remain wire-compatible; only the agreed service reserves time.
  return query select p_start, v_end, p_start, v_end;
end $function$;

CREATE OR REPLACE FUNCTION app_private.booking_resource_end(p_service_start timestamp with time zone, p_service_end timestamp with time zone, p_occupied_start timestamp with time zone, p_occupied_end timestamp with time zone, p_release timestamp with time zone)
 RETURNS timestamp with time zone
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select greatest(p_service_start,least(p_service_end,p_release));
$function$;

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
  if new.proposed_end > pg_catalog.timezone(v_zone,
      (pg_catalog.timezone(v_zone,new.proposed_start)::date+1)::timestamp) then
    raise exception using errcode='22023',message='service_crosses_local_day';
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
end $function$;

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
end $function$;

CREATE OR REPLACE FUNCTION app_private.evaluate_context_eligibility_cached(p_context grooming_requests, p_groomer uuid, p_now timestamp with time zone, p_valid_zones text[], INOUT p_weekly_cache jsonb, OUT evaluation jsonb)
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
  earliest timestamptz; day date; day_end timestamptz;
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
    -- Preserve existing defaults when preferences have not yet been saved.
    prefs.minimum_advance_notice_days:=0;
  end if;
  -- Missing or historical saved buffers do not downgrade a known service or enlarge its interval.
  earliest:=greatest(r.preferred_start,
    app_private.service_timing_earliest_start_validated(p_now,prefs.minimum_advance_notice_days,zone));
  select coalesce(range_agg(slot),'{}'::tstzmultirange) into blocked from (
    select tstzrange(b.scheduled_start,app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)') slot
      from public.bookings b where b.groomer_id=p_groomer and b.status in ('confirmed','completed','unfulfilled')
        and b.scheduled_start<r.preferred_end+make_interval(mins=>after_minutes)
        and b.scheduled_end>earliest-make_interval(mins=>before_minutes)
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
              and b.scheduled_start<allocation.service_end and b.scheduled_end>allocation.service_start
              and app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at)>allocation.service_start;
          if pet_busy_until is not null then cursor_start:=pet_busy_until; continue; end if;
          if size_state='eligible' and service.accepted_species is not null
            and cardinality(app_private.match_required_confirmations(r.pet_snapshot,r.service_type,
              service.accepted_species,service.accepted_pet_sizes))=0
            and r.service_type<>'custom_request'
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
      and b.status in ('confirmed','completed','unfulfilled') and b.scheduled_start<p_end
      and p_start<app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at))
    and (select count(*) from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and pg_catalog.timezone(v_zone,b.scheduled_start)::date=pg_catalog.timezone(v_zone,p_start)::date)<v_limit;
end $function$;

CREATE OR REPLACE FUNCTION app_private.validate_booked_coverage(p_groomer_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_zone text; v_zone_count integer; v_window_count integer; v_starts time[]; v_ends time[];
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_groomer_id::text,71071));
  if not exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at)>statement_timestamp()) then return; end if;
  -- Validate the shared schedule once, not once per future booking.
  select min(timezone),count(distinct timezone),count(*),
    array_agg(case when is_enabled then start_time end order by weekday),
    array_agg(case when is_enabled then end_time end order by weekday)
    into v_zone,v_zone_count,v_window_count,v_starts,v_ends
    from public.groomer_availability_windows where groomer_id=p_groomer_id;
  if v_zone_count<>1 or v_window_count<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=v_zone
  ) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required';
  end if;
  if exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at)>statement_timestamp()
      and exists(select 1 from public.groomer_time_off_windows t where t.groomer_id=p_groomer_id
        and tstzrange(pg_catalog.timezone(v_zone,t.start_date::timestamp),
          pg_catalog.timezone(v_zone,(t.end_date+1)::timestamp),'[)')
          && tstzrange(b.scheduled_start,
            app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)'))) then
    raise exception using errcode='22023',message='time_off_conflicts_with_booking_occupancy';
  end if;
  if exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at)>statement_timestamp()
      and not app_private.weekly_hours_cover_interval(
        b.scheduled_start,app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),
        v_zone,v_starts,v_ends)) then
    raise exception using errcode='22023',message='weekly_hours_conflict_with_booking_occupancy';
  end if;
end $function$;

CREATE OR REPLACE FUNCTION app_private.groomer_is_available_for_range(p_groomer_id uuid, p_scheduled_start timestamp with time zone, p_scheduled_end timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  with matching_window as (
    select
      availability_window.timezone,
      timezone(availability_window.timezone, p_scheduled_start) as local_start,
      timezone(availability_window.timezone, p_scheduled_end) as local_end,
      availability_window.start_time,
      availability_window.end_time
    from public.groomer_availability_windows as availability_window
    join pg_catalog.pg_timezone_names as timezone_name
      on timezone_name.name = availability_window.timezone
    where p_groomer_id is not null
      and p_scheduled_start is not null
      and p_scheduled_end is not null
      and p_scheduled_start > statement_timestamp()
      and p_scheduled_end > p_scheduled_start
      and availability_window.groomer_id = p_groomer_id
      and availability_window.is_enabled
      and availability_window.weekday =
        extract(isodow from timezone(availability_window.timezone, p_scheduled_start))::smallint
  ),
  feasible_window as (
    select
      matching_window.timezone,
      matching_window.local_start::date as local_date
    from matching_window
    where matching_window.local_start::date = matching_window.local_end::date
      and matching_window.local_start::time >= matching_window.start_time
      and matching_window.local_end::time <= matching_window.end_time
  ),
  booking_preferences as (
    select
      coalesce(preferences.max_appointments_per_day, 4) as max_appointments_per_day,
      coalesce(preferences.minimum_advance_notice_days, 0) as minimum_advance_notice_days
    from public.groomer_profiles as groomer_profile
    left join public.groomer_booking_preferences as preferences
      on preferences.groomer_id = groomer_profile.user_id
    where groomer_profile.user_id = p_groomer_id
  )
  select coalesce(
    (
      select true
      from feasible_window
      cross join booking_preferences
      where feasible_window.local_date >=
        (
          timezone(feasible_window.timezone, statement_timestamp())::date
          + booking_preferences.minimum_advance_notice_days
        )
        and not exists (
          select 1
          from public.groomer_time_off_windows as time_off
          where time_off.groomer_id = p_groomer_id
            and feasible_window.local_date between time_off.start_date and time_off.end_date
        )
        and not exists (
          select 1
          from public.bookings as existing_booking
          where existing_booking.groomer_id = p_groomer_id
            and existing_booking.status in ('confirmed','completed','unfulfilled')
            and existing_booking.scheduled_start < p_scheduled_end
            and p_scheduled_start < app_private.booking_resource_end(existing_booking.scheduled_start,existing_booking.scheduled_end,existing_booking.occupied_start,existing_booking.occupied_end,existing_booking.resource_release_at)
        )
        and (
          select count(*)::integer
          from public.bookings as daily_booking
          where daily_booking.groomer_id = p_groomer_id
            and daily_booking.status in ('confirmed','completed','unfulfilled')
            and timezone(feasible_window.timezone, daily_booking.scheduled_start)::date =
              feasible_window.local_date
        ) < booking_preferences.max_appointments_per_day
      limit 1
    ),
    false
  );
$function$;

CREATE OR REPLACE FUNCTION app_private.validate_reschedule_candidate(b bookings, p_start timestamp with time zone, p_now timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare ending timestamptz; v_occupied_start timestamptz; v_occupied_end timestamptz;
  zone text; zones integer; windows integer; daily_limit integer; notice integer;
begin
  if b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' or b.scheduled_start<=p_now then
    raise exception using errcode='22023',message='booking_not_reschedulable'; end if;
  if p_start is null or not pg_catalog.isfinite(p_start) or p_start=b.scheduled_start then
    raise exception using errcode='22023',message='invalid_reschedule_time'; end if;
  if b.agreement_snapshot is null or b.agreement_snapshot->>'schema_version' is distinct from '1'
    or b.pet_id is null or b.service_time_zone_identifier is null
    or app_private.valid_timing_buffers(b.applied_timing_buffers) is not true then
    raise exception using errcode='22023',message='reschedule_agreement_verification_required'; end if;
  ending:=p_start+(b.scheduled_end-b.scheduled_start);
  v_occupied_start:=p_start;
  v_occupied_end:=ending;
  select min(timezone),count(distinct timezone),count(*) into zone,zones,windows
    from public.groomer_availability_windows where groomer_id=b.groomer_id;
  if zones<>1 or windows<>7 or not exists(select 1 from pg_catalog.pg_timezone_names where name=zone) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required'; end if;
  select coalesce(p.max_appointments_per_day,4),coalesce(p.minimum_advance_notice_days,0) into daily_limit,notice
    from public.groomer_profiles g left join public.groomer_booking_preferences p on p.groomer_id=g.user_id
    where g.user_id=b.groomer_id;
  if not found or p_start<app_private.service_timing_earliest_start(p_now,notice,zone) then
    raise exception using errcode='22023',message='reschedule_notice_required'; end if;
  if app_private.occupied_time_off_conflict(b.groomer_id,v_occupied_start,v_occupied_end)
    or not app_private.occupied_weekly_hours_covered(b.groomer_id,v_occupied_start,v_occupied_end) then
    raise exception using errcode='22023',message='reschedule_outside_availability'; end if;
  if exists(select 1 from public.bookings other where other.id<>b.id
    and other.status in ('confirmed','completed','unfulfilled')
    and ((other.groomer_id=b.groomer_id and other.scheduled_start<v_occupied_end
      and v_occupied_start<app_private.booking_resource_end(other.scheduled_start,other.scheduled_end,
        other.occupied_start,other.occupied_end,other.resource_release_at))
      or (other.pet_id=b.pet_id and other.scheduled_start<ending
        and p_start<app_private.booking_pet_end(other.scheduled_start,other.scheduled_end,other.pet_release_at)))) then
    raise exception using errcode='PT409',message='reschedule_resource_conflict'; end if;
  if (select count(*) from public.bookings other where other.id<>b.id and other.groomer_id=b.groomer_id
    and other.status in ('confirmed','completed','unfulfilled')
    and timezone(zone,other.scheduled_start)::date=timezone(zone,p_start)::date)>=daily_limit then
    raise exception using errcode='PT409',message='reschedule_daily_limit'; end if;
  return jsonb_build_object('start',p_start,'end',ending,'occupied_start',v_occupied_start,'occupied_end',v_occupied_end);
end $function$;

CREATE OR REPLACE FUNCTION app_private.mutate_booking_fulfillment(p_booking_id uuid, p_expected_revision uuid, p_operation_id uuid, p_action text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype; event public.booking_fulfillment_events%rowtype;
  parent uuid; at_time timestamptz:=statement_timestamp(); note text:=nullif(btrim(p_note),'');
  receipt jsonb; event_id uuid:=gen_random_uuid(); conversation uuid; chat_text text;
  old_write text:=current_setting('app.fulfillment_write',true);
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_booking_id is null or p_expected_revision is null or p_operation_id is null
    or p_action is null or char_length(coalesce(note,''))>500 then
    raise exception using errcode='22023',message='invalid_fulfillment_operation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||p_operation_id::text,71377));
  select * into event from public.booking_fulfillment_events where actor_id=actor and operation_id=p_operation_id;
  if found then
    if row(event.booking_id,event.expected_revision,event.action,event.note)
      is distinct from row(p_booking_id,p_expected_revision,p_action,note) then
      raise exception using errcode='22023',message='fulfillment_operation_intent_changed';
    end if;
    return app_private.get_booking_fulfillment_operation(p_operation_id);
  end if;
  select r.id into parent from public.grooming_requests r join public.bookings booking on booking.request_id=r.id
    where booking.id=p_booking_id and (booking.customer_id=actor or booking.groomer_id=actor) for update of r;
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  select * into strict b from public.bookings where id=p_booking_id for update;
  if not exists(select 1 from public.profiles where id=actor
    and ((actor=b.customer_id and role='customer') or (actor=b.groomer_id and role='groomer'))) then
    raise exception using errcode='42501',message='booking_participant_required';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(b.groomer_id::text,71071));
  -- Evaluate boundaries after lock waits, not at the request's earlier arrival time.
  at_time:=clock_timestamp();
  if b.fulfillment_revision is distinct from p_expected_revision then
    raise exception using errcode='PT409',message='booking_revision_changed';
  end if;
  if p_action in ('report_interruption','report_no_show','close_elapsed','report_completion','record_objection')
    and note is null then raise exception using errcode='22023',message='fulfillment_note_required'; end if;
  case p_action
  when 'start' then
    if actor<>b.groomer_id or b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' then
      raise exception using errcode='P0001',message='service_not_startable'; end if;
    if at_time<b.scheduled_start or at_time>=b.scheduled_end then
      raise exception using errcode='22023',message='outside_service_start_window'; end if;
    b.fulfillment_phase:='in_service'; b.fulfillment_basis:='live'; b.actual_started_at:=at_time;
    chat_text:='Service has started.';
  when 'complete' then
    if actor<>b.groomer_id or b.status<>'confirmed' or b.fulfillment_phase<>'in_service'
      or b.actual_started_at is null then
      raise exception using errcode='P0001',message='service_not_completable'; end if;
    if at_time<b.actual_started_at+interval '1 minute' then
      raise exception using errcode='22023',message='completion_too_early'; end if;
    b.status:='completed'; b.fulfillment_phase:='completed'; b.actual_ended_at:=at_time;
    b.completed_at:=at_time; b.completed_by:=actor;
    b.pet_release_at:=greatest(b.scheduled_start,least(b.scheduled_end,at_time));
    b.resource_release_at:=greatest(b.scheduled_start,
      least(b.scheduled_end,at_time));
    chat_text:='Service is completed. The customer can leave a review.';
  when 'cancel' then
    if b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' or at_time>=b.scheduled_start then
      raise exception using errcode='P0001',message='use_service_outcome_report'; end if;
    b.status:=case when actor=b.customer_id then 'cancelled_by_customer' else 'cancelled_by_groomer' end;
    b.fulfillment_phase:='cancelled'; b.cancelled_at:=at_time; b.cancelled_by:=actor;
    chat_text:='This booking was cancelled before service. The original request remains closed.';
  when 'report_interruption','report_no_show' then
    if b.status<>'confirmed' or b.fulfillment_phase not in ('scheduled','in_service') or at_time<b.scheduled_start then
      raise exception using errcode='P0001',message='service_not_reportable'; end if;
    if p_action='report_no_show' and (b.actual_started_at is not null or at_time<b.scheduled_start+interval '15 minutes') then
      raise exception using errcode='22023',message='no_show_wait_required'; end if;
    b.report_previous_phase:=b.fulfillment_phase; b.fulfillment_phase:='outcome_reported';
    b.reported_outcome:=case p_action when 'report_no_show' then 'no_show' else 'interruption' end;
    b.reported_by:=actor; b.reported_at:=at_time; b.report_note:=note;
    chat_text:='A service issue was reported. Please confirm the service outcome. No fault has been assigned.';
  when 'confirm_stop' then
    if b.fulfillment_phase<>'outcome_reported' or b.reported_outcome not in ('interruption','no_show')
      or b.reported_by=actor then raise exception using errcode='P0001',message='other_participant_confirmation_required'; end if;
    b.status:='unfulfilled'; b.fulfillment_phase:='unfulfilled';
    if b.actual_started_at is not null then b.actual_ended_at:=at_time; end if;
    b.pet_release_at:=greatest(b.scheduled_start,least(b.scheduled_end,at_time));
    b.resource_release_at:=greatest(b.scheduled_start,
      least(b.scheduled_end,at_time));
    chat_text:='Both participants confirmed that service ended without completion. No fault has been assigned.';
  when 'withdraw_report' then
    if b.fulfillment_phase<>'outcome_reported' or b.reported_by<>actor then
      raise exception using errcode='P0001',message='report_not_withdrawable'; end if;
    b.fulfillment_phase:=b.report_previous_phase; b.reported_outcome:=null; b.reported_by:=null;
    b.reported_at:=null; b.report_previous_phase:=null; b.report_note:=null;
    chat_text:='The service outcome report was withdrawn. Previous observations remain recorded.';
  when 'close_elapsed' then
    if b.status<>'confirmed' or at_time<b.scheduled_end then
      raise exception using errcode='P0001',message='elapsed_closure_not_available'; end if;
    b.status:='unfulfilled'; b.fulfillment_phase:='unfulfilled';
    b.reported_outcome:='unresolved'; b.reported_by:=actor; b.reported_at:=at_time; b.report_note:=note;
    b.pet_release_at:=b.scheduled_end;
    b.resource_release_at:=least(b.scheduled_end,at_time);
    chat_text:='This elapsed booking was closed without confirmed completion. No fault has been assigned.';
  when 'report_completion' then
    if b.status not in ('confirmed','unfulfilled') or b.fulfillment_phase='outcome_reported' or at_time<b.scheduled_end then
      raise exception using errcode='P0001',message='retrospective_completion_not_available'; end if;
    b.report_previous_phase:=b.fulfillment_phase; b.fulfillment_phase:='outcome_reported';
    b.reported_outcome:='completion'; b.reported_by:=actor; b.reported_at:=at_time; b.report_note:=note;
    chat_text:='Service completion was reported retrospectively. The other participant must confirm it.';
  when 'confirm_completion' then
    if b.fulfillment_phase<>'outcome_reported' or b.reported_outcome<>'completion' or b.reported_by=actor then
      raise exception using errcode='P0001',message='other_participant_confirmation_required'; end if;
    b.status:='completed'; b.fulfillment_phase:='completed'; b.fulfillment_basis:='bilateral_retrospective';
    b.completed_at:=at_time; b.completed_by:=b.groomer_id;
    chat_text:='Both participants confirmed service completion. Unrecorded actual times remain unverified.';
  when 'record_objection' then
    if b.status='confirmed' or b.fulfillment_phase='outcome_reported' then
      raise exception using errcode='P0001',message='objection_requires_terminal_outcome'; end if;
    b.fulfillment_revision:=gen_random_uuid();
    chat_text:='An observation about the recorded service outcome was added. No automatic judgment has been made.';
  else raise exception using errcode='22023',message='invalid_fulfillment_action';
  end case;
  perform set_config('app.fulfillment_write','1',true);
  update public.bookings set status=b.status,fulfillment_phase=b.fulfillment_phase,fulfillment_basis=b.fulfillment_basis,
    fulfillment_revision=b.fulfillment_revision,actual_started_at=b.actual_started_at,actual_ended_at=b.actual_ended_at,
    pet_release_at=b.pet_release_at,resource_release_at=b.resource_release_at,reported_outcome=b.reported_outcome,
    reported_by=b.reported_by,reported_at=b.reported_at,report_previous_phase=b.report_previous_phase,report_note=b.report_note,
    cancelled_at=b.cancelled_at,cancelled_by=b.cancelled_by,completed_at=b.completed_at,completed_by=b.completed_by
    where id=b.id returning * into b;
  perform set_config('app.fulfillment_write',coalesce(old_write,''),true);
  receipt:=jsonb_build_object('id',event_id,'operation_id',p_operation_id,'booking_id',b.id,'action',p_action,
    'result_revision',b.fulfillment_revision,'recorded_at',at_time);
  insert into public.booking_fulfillment_events(id,booking_id,actor_id,operation_id,expected_revision,result_revision,action,note,receipt,recorded_at)
    values(event_id,b.id,actor,p_operation_id,p_expected_revision,b.fulfillment_revision,p_action,note,receipt,at_time);
  select id into conversation from public.conversations where customer_id=b.customer_id and groomer_id=b.groomer_id;
  if conversation is null then raise exception using errcode='P0001',message='conversation_not_found'; end if;
  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at)
    values(conversation,actor,'booking_card',b.id,at_time);
  insert into public.messages(conversation_id,sender_id,kind,body,created_at)
    values(conversation,actor,'text',chat_text,at_time+interval '1 microsecond');
  return jsonb_build_object('receipt',receipt,'booking',to_jsonb(b),'replayed',false);
end $function$;

CREATE OR REPLACE FUNCTION app_private.save_groomer_availability(p_expected_revision text, p_windows jsonb, p_preferences jsonb, p_time_off jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_snapshot jsonb;
  v_buffers jsonb;
  v_previous_batch text := current_setting('app.availability_batch',true);
begin
  if v_user_id is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='42501', message='authenticated_user_required';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user_id::text,71071));
  v_snapshot := app_private.get_groomer_availability();
  if p_expected_revision is null or p_expected_revision <> v_snapshot->>'revision' then
    raise exception using errcode='40001', message='availability_revision_conflict';
  end if;
  if jsonb_typeof(p_windows) is distinct from 'array'
    or jsonb_typeof(p_preferences) is distinct from 'object'
    or jsonb_typeof(p_time_off) is distinct from 'array' then
    raise exception using errcode='22023', message='invalid_availability_payload';
  end if;
  if jsonb_array_length(p_time_off) <> (select count(distinct t.id)
    from jsonb_to_recordset(p_time_off) as t(id uuid)) then
    raise exception using errcode='22023',message='invalid_time_off_entries';
  end if;
  if jsonb_array_length(p_windows) <> 7
    or (select count(distinct w.weekday) from jsonb_to_recordset(p_windows) as w(weekday integer)) <> 7
    or (select count(distinct w.timezone) from jsonb_to_recordset(p_windows) as w(timezone text)) <> 1
    or exists (select 1 from jsonb_to_recordset(p_windows) as w(timezone text)
      where not exists (select 1 from pg_catalog.pg_timezone_names n where n.name=w.timezone)) then
    raise exception using errcode='22023', message='invalid_availability_windows';
  end if;
  -- Compatibility key accepted, but cannot restore removed reservation padding.
  v_buffers := '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb;

  perform set_config('app.availability_batch','1',true);
  insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
    select v_user_id,w.weekday,w.start_time,w.end_time,w.is_enabled,w.timezone
    from jsonb_to_recordset(p_windows) as w(weekday smallint,start_time time,end_time time,is_enabled boolean,timezone text)
    on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
      is_enabled=excluded.is_enabled,timezone=excluded.timezone
    where row(groomer_availability_windows.start_time,groomer_availability_windows.end_time,
      groomer_availability_windows.is_enabled,groomer_availability_windows.timezone)
      is distinct from row(excluded.start_time,excluded.end_time,excluded.is_enabled,excluded.timezone);
  insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,
    minimum_advance_notice_days,auto_accept_bookings,timing_buffers)
    values(v_user_id,(p_preferences->>'max_appointments_per_day')::smallint,
      (p_preferences->>'minimum_advance_notice_days')::smallint,(p_preferences->>'auto_accept_bookings')::boolean,v_buffers)
    on conflict(groomer_id) do update set
      max_appointments_per_day=excluded.max_appointments_per_day,
      minimum_advance_notice_days=excluded.minimum_advance_notice_days,
      auto_accept_bookings=excluded.auto_accept_bookings,
      timing_buffers=excluded.timing_buffers;
  delete from public.groomer_time_off_windows existing where existing.groomer_id=v_user_id
    and not exists(select 1 from jsonb_to_recordset(p_time_off) as t(id uuid) where t.id=existing.id);
  update public.groomer_time_off_windows existing
    set title=t.title,start_date=t.start_date,end_date=t.end_date
    from jsonb_to_recordset(p_time_off) as t(id uuid,title text,start_date date,end_date date)
    where existing.groomer_id=v_user_id and existing.id=t.id
      and row(existing.title,existing.start_date,existing.end_date)
        is distinct from row(t.title,t.start_date,t.end_date);
  insert into public.groomer_time_off_windows(id,groomer_id,title,start_date,end_date)
    select t.id,v_user_id,t.title,t.start_date,t.end_date
    from jsonb_to_recordset(p_time_off) as t(id uuid,title text,start_date date,end_date date)
    where not exists(select 1 from public.groomer_time_off_windows existing
      where existing.groomer_id=v_user_id and existing.id=t.id);
  perform app_private.validate_booked_coverage(v_user_id);
  perform set_config('app.availability_batch',coalesce(v_previous_batch,''),true);
  perform app_private.backfill_request_matches_for_groomer(v_user_id,250);
  return app_private.get_groomer_availability();
end $function$;

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
      and tstzrange(b.scheduled_start,app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)')
        && tstzrange(o.occupied_start,o.occupied_end,'[)'))
    or app_private.occupied_time_off_conflict(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones)
    or not app_private.occupied_weekly_hours_covered(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  return jsonb_build_object('terms_valid',true,'selectable',true,'reason','available');
end $function$;

CREATE OR REPLACE FUNCTION app_private.get_groomer_availability()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_payload jsonb;
begin
  if v_user_id is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists (select 1 from public.profiles p join public.groomer_profiles g on g.user_id=p.id
      where p.id=v_user_id and p.role='groomer'::public.user_role) then
    raise exception using errcode='42501', message='groomer_profile_required';
  end if;
  select jsonb_build_object(
    'timing_version',1,
    'windows',coalesce((select jsonb_agg(to_jsonb(w) order by w.weekday)
      from public.groomer_availability_windows w where w.groomer_id=v_user_id),'[]'::jsonb),
    'preferences',coalesce((select to_jsonb(p) || jsonb_build_object('timing_buffers','{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb) from public.groomer_booking_preferences p
      where p.groomer_id=v_user_id),jsonb_build_object('groomer_id',v_user_id,
        'max_appointments_per_day',4,'minimum_advance_notice_days',0,'auto_accept_bookings',false,'timing_buffers','{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb)),
    'time_off',coalesce((select jsonb_agg(to_jsonb(t) order by t.start_date,t.id)
      from public.groomer_time_off_windows t where t.groomer_id=v_user_id),'[]'::jsonb)
  ) into v_payload;
  return v_payload || jsonb_build_object('revision',md5(v_payload::text));
end $function$;

alter table public.bookings drop constraint bookings_no_groomer_occupied_overlap;
alter table public.bookings add constraint bookings_no_groomer_occupied_overlap
  exclude using gist (groomer_id with =,
    tstzrange(scheduled_start,app_private.booking_resource_end(scheduled_start,scheduled_end,
      occupied_start,occupied_end,resource_release_at),'[)') with &&)
  where (status in ('confirmed','completed','unfulfilled'));

-- Preferences are mutable configuration, unlike frozen offers/agreements. Existing change triggers
-- retain revision checks, validate future coverage, and invalidate affected matching proofs.
update public.groomer_booking_preferences set timing_buffers = '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb
  where timing_buffers is distinct from '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb;

-- Also refresh configured groomers whose unsaved preferences formerly meant "unknown buffers".
do $refresh$
declare g record;
begin
  for g in select p.user_id from public.groomer_profiles p
    where not exists(select 1 from public.groomer_booking_preferences bp where bp.groomer_id=p.user_id)
  loop
    perform app_private.enqueue_match_refresh(g.user_id);
  end loop;
end $refresh$;
