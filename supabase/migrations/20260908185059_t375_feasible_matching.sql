-- T-375 / WP-04. Install with the refresh worker paused for linked contention acceptance.
alter table public.request_matches add column eligibility_evaluation jsonb;
create table app_private.match_refresh_queue (
  id bigint generated always as identity primary key,
  -- No business-row foreign-key locks in a producer holding another request lock.
  -- The private consumer discards events whose owners were subsequently deleted.
  request_id uuid not null,
  groomer_id uuid not null,
  requested_at timestamptz not null default clock_timestamp()
);
revoke all on app_private.match_refresh_queue from public,anon,authenticated,service_role;
revoke all on sequence app_private.match_refresh_queue_id_seq from public,anon,authenticated,service_role;
create index match_refresh_queue_order on app_private.match_refresh_queue(requested_at,request_id,groomer_id);
create index match_refresh_queue_pair on app_private.match_refresh_queue(request_id,groomer_id);

create function app_private.match_service_size(p_size text,p_accepted text[])
returns text language sql immutable set search_path = ''
as $$
  select case
    when p_size is null or lower(btrim(p_size)) not in ('xs','s','m','l','xl','xxl','giant')
      or coalesce(cardinality(p_accepted),0)=0 then 'assessment_required'
    when exists(select 1 from unnest(p_accepted) s where lower(btrim(s))=lower(btrim(p_size)))
      then 'eligible'
    else 'excluded'
  end;
$$;

create function app_private.match_service_interval(
  p_window tstzrange,p_available tstzmultirange,p_blocked tstzmultirange,
  p_duration integer,p_before integer,p_after integer,p_earliest timestamptz
)
returns table(service_start timestamptz,service_end timestamptz,
  occupied_start timestamptz,occupied_end timestamptz)
language sql immutable set search_path = ''
as $$
  -- Subtract occupied intervals before testing duration; separated gaps never add up.
  with gaps as (
    select slot from unnest(p_available-p_blocked) slot
    where p_duration between 15 and 720 and p_before between 0 and 300 and p_after between 0 and 300
      and p_window is not null and not isempty(p_window)
      and lower_inc(p_window) and not upper_inc(p_window)
      and isfinite(lower(p_window)) and isfinite(upper(p_window))
      and p_earliest is not null and isfinite(p_earliest)
      and lower_inc(slot) and not upper_inc(slot)
      and isfinite(lower(slot)) and isfinite(upper(slot))
  ), candidates as (
    select slot,greatest(lower(p_window),p_earliest,
      lower(slot)+make_interval(mins=>p_before)) as starts from gaps
  ), allocations as (
    select starts,starts+make_interval(mins=>p_duration) as ends,
      starts-make_interval(mins=>p_before) as occupied_starts,
      starts+make_interval(mins=>p_duration+p_after) as occupied_ends,slot
    from candidates
  )
  select starts,ends,occupied_starts,occupied_ends from allocations
  where ends<=upper(p_window) and occupied_ends<=upper(slot)
  order by starts,ends limit 1;
$$;

revoke all on function app_private.match_service_size(text,text[])
  from public,anon,authenticated,service_role;
revoke all on function app_private.match_service_interval(tstzrange,tstzmultirange,tstzmultirange,integer,integer,integer,timestamptz)
  from public,anon,authenticated,service_role;

create function app_private.match_weekly_ranges_validated(
  p_start timestamptz,p_end timestamptz,p_zone text,p_starts time[],p_ends time[]
)
returns tstzmultirange language plpgsql stable set search_path = ''
as $$
begin
  -- Caller processes longer preferences in bounded calendar batches; NULL is
  -- unevaluated, never an empty schedule or an exact-match exclusion.
  if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end)
    or p_start>=p_end or p_end-p_start>interval '3 days'
    or cardinality(p_starts) is distinct from 7 or cardinality(p_ends) is distinct from 7 then
    return null;
  end if;
  return (
    with wall as materialized (
      select t,timezone(p_zone,t) as local_time
      from generate_series(date_trunc('second',p_start),p_end,interval '1 second') t
      where t<p_end
    ), bounds as (
      select greatest(t,p_start,t+((local_time::date+p_starts[extract(isodow from local_time)::integer])-local_time)) a,
        least(t+interval '1 second',p_end,
          t+((local_time::date+p_ends[extract(isodow from local_time)::integer])-local_time)) b
      from wall
      where p_starts[extract(isodow from local_time)::integer] is not null
        and p_ends[extract(isodow from local_time)::integer] is not null
    )
    select coalesce(range_agg(case when a<b then tstzrange(a,b,'[)') end),'{}'::tstzmultirange)
      from bounds
  );
end $$;
revoke all on function app_private.match_weekly_ranges_validated(timestamptz,timestamptz,text,time[],time[])
  from public,anon,authenticated,service_role;

create function app_private.match_weekly_ranges(
  p_start timestamptz,p_end timestamptz,p_zone text,p_starts time[],p_ends time[]
)
returns tstzmultirange language plpgsql stable set search_path = ''
as $$
begin
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_zone) then return null; end if;
  return app_private.match_weekly_ranges_validated(p_start,p_end,p_zone,p_starts,p_ends);
end $$;
revoke all on function app_private.match_weekly_ranges(timestamptz,timestamptz,text,time[],time[])
  from public,anon,authenticated,service_role;

create function app_private.service_timing_earliest_start_validated(
  p_now timestamptz,p_notice_days integer,p_schedule_timezone text
)
returns timestamptz language plpgsql stable set search_path = ''
as $$
begin
  if p_now is null or not isfinite(p_now) or p_notice_days is null or p_notice_days not between 0 and 2 then
    raise exception using errcode='22023',message='invalid_advance_notice';
  end if;
  return greatest(p_now+interval '5 minutes',timezone(p_schedule_timezone,
    (timezone(p_schedule_timezone,p_now)::date+p_notice_days)::timestamp));
end $$;
revoke all on function app_private.service_timing_earliest_start_validated(timestamptz,integer,text)
  from public,anon,authenticated,service_role;

create or replace function app_private.service_timing_earliest_start(
  p_now timestamptz,p_notice_days integer,p_schedule_timezone text
)
returns timestamptz language plpgsql stable set search_path = ''
as $$
begin
  if p_now is null or not isfinite(p_now) or p_notice_days is null or p_notice_days not between 0 and 2 then
    raise exception using errcode='22023',message='invalid_advance_notice';
  end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_schedule_timezone) then
    raise exception using errcode='22023',message='invalid_schedule_timezone';
  end if;
  return app_private.service_timing_earliest_start_validated(p_now,p_notice_days,p_schedule_timezone);
end $$;

create function app_private.evaluate_match_constraints(p_request uuid,p_groomer uuid,p_now timestamptz)
returns jsonb language plpgsql stable set search_path = ''
as $$
declare r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype;
begin
  if p_now is null or not isfinite(p_now) then
    return jsonb_build_object('state','excluded','reason','invalid_clock');
  end if;
  select * into r from public.grooming_requests where id=p_request;
  if not found or r.status not in ('open','has_offers') or r.expires_at<=p_now
    or r.preferred_start is null or r.preferred_end is null
    or not isfinite(r.preferred_start) or not isfinite(r.preferred_end)
    or r.preferred_start>=r.preferred_end
    or not exists(select 1 from public.profiles where id=r.customer_id and role='customer')
    or not exists(select 1 from public.pets where id=r.pet_id and customer_id=r.customer_id
      and is_active and deleted_at is null) then
    return jsonb_build_object('state','excluded','reason','request_unavailable');
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
    and app_private.match_service_size(r.pet_snapshot->>'size',s.accepted_pet_sizes)<>'excluded') then
    return jsonb_build_object('state','excluded','reason','pet_size_excluded');
  end if;
  return jsonb_build_object('state','eligible','reason','explicit_constraints_met');
end $$;
revoke all on function app_private.evaluate_match_constraints(uuid,uuid,timestamptz)
  from public,anon,authenticated,service_role;

create function app_private.evaluate_match_eligibility_with_zones(
  p_request uuid,p_groomer uuid,p_now timestamptz,p_valid_zones text[]
)
returns jsonb language plpgsql stable set search_path = ''
as $$
declare
  r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype;
  prefs public.groomer_booking_preferences%rowtype;
  zone text; service_zone text; valid_zones text[]; zones integer; windows integer;
  starts time[]; ends time[]; before_minutes integer := 0; after_minutes integer := 0;
  buffers_known boolean; earliest timestamptz; day date; day_end timestamptz;
  window_start timestamptz; window_end timestamptz; cursor_start timestamptz;
  available tstzmultirange; blocked tstzmultirange; allocation record; service record;
  pet_busy_until timestamptz; size_state text; duration integer; assessment jsonb;
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
    select tstzrange(coalesce(b.occupied_start,b.scheduled_start),coalesce(b.occupied_end,b.scheduled_end),'[)') slot
      from public.bookings b where b.groomer_id=p_groomer and b.status in ('confirmed','completed')
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
        size_state:=app_private.match_service_size(r.pet_snapshot->>'size',service.accepted_pet_sizes);
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
              and b.status in ('confirmed','completed')
              and timezone(zone,b.scheduled_start)::date=timezone(zone,allocation.service_start)::date)
              >=prefs.max_appointments_per_day then
            cursor_start:=timezone(zone,(timezone(zone,allocation.service_start)::date+1)::timestamp);
            continue;
          end if;
          select max(b.scheduled_end) into pet_busy_until from public.bookings b
            where b.pet_id=r.pet_id and b.status in ('confirmed','completed')
              and b.scheduled_start<allocation.service_end and b.scheduled_end>allocation.service_start;
          if pet_busy_until is not null then cursor_start:=pet_busy_until; continue; end if;
          if size_state='eligible' and buffers_known and r.service_type<>'custom_request'
            and service.duration_minutes between 15 and 720 then
            return jsonb_build_object('state','estimated_fit','reason','continuous_opening',
              'service_id',service.id,'service_start',allocation.service_start,'service_end',allocation.service_end,
              'occupied_start',allocation.occupied_start,'occupied_end',allocation.occupied_end);
          end if;
          assessment:=jsonb_build_object('state','assessment_required','reason','service_details_unconfirmed');
          exit;
        end loop;
      end loop;
    end if;
    day:=day+1;
  end loop;
  return coalesce(assessment,jsonb_build_object('state','excluded','reason','no_continuous_opening'));
end $$;
revoke all on function app_private.evaluate_match_eligibility_with_zones(uuid,uuid,timestamptz,text[])
  from public,anon,authenticated,service_role;

create function app_private.evaluate_match_eligibility(p_request uuid,p_groomer uuid,p_now timestamptz)
returns jsonb language sql stable set search_path = ''
as $$ select app_private.evaluate_match_eligibility_with_zones(p_request,p_groomer,p_now,null); $$;
revoke all on function app_private.evaluate_match_eligibility(uuid,uuid,timestamptz)
  from public,anon,authenticated,service_role;

create or replace function app_private.create_request_matches_for_request(
  p_request_id uuid,
  p_only_groomer_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_match_count integer := 0;
begin
  if p_request_id is null then
    return 0;
  end if;

  with selected_request as materialized (
    select request.*
    from public.grooming_requests as request
    where request.id = p_request_id
      and request.status in ('open', 'has_offers')
      and request.expires_at > statement_timestamp()
    for update of request
  ),
  request_traits as materialized (
    select trait.trait_type, trait.trait_value
    from selected_request
    cross join lateral app_private.pet_fit_traits_from_snapshot(
      selected_request.pet_snapshot,
      selected_request.service_type,
      timezone(coalesce(selected_request.preference_time_zone_identifier,'UTC'),selected_request.preferred_start)::date
    ) as trait
  ),
  location_candidates as materialized (
    select
      selected_request.id as request_id,
      selected_request.customer_id,
      selected_request.service_type,
      selected_request.preferred_start,
      selected_request.preferred_end,
      groomer_profile.user_id,
      location_fit.location_score,
      location_fit.location_reason
    from selected_request
    join public.groomer_profiles as groomer_profile
      on true
    join public.profiles as profile
      on profile.id = groomer_profile.user_id
    left join app_private.address_locations as request_location
      on request_location.id = selected_request.address_location_id
     and request_location.owner_id = selected_request.customer_id
    left join app_private.address_locations as groomer_location
      on groomer_location.id = groomer_profile.address_location_id
     and groomer_location.owner_id = groomer_profile.user_id
    cross join lateral app_private.evaluate_request_location_fit(
      request_location.location,
      groomer_location.location,
      selected_request.location_mode,
      selected_request.travel_radius_miles,
      groomer_profile.service_radius_miles,
      selected_request.state,
      selected_request.city,
      groomer_profile.base_state,
      groomer_profile.base_city
    ) as location_fit
    where profile.role = 'groomer'::public.user_role
      and groomer_profile.is_active
      and location_fit.is_eligible
      and (
        p_only_groomer_id is null
        or groomer_profile.user_id = p_only_groomer_id
      )
      and (
        groomer_profile.service_location_modes @>
          array[selected_request.location_mode]::text[]
        or (
          groomer_profile.service_location_modes is null
          and groomer_profile.service_location_mode = selected_request.location_mode
        )
      )
      and exists (
        select 1
        from public.groomer_services as groomer_service
        where groomer_service.groomer_id = groomer_profile.user_id
          and groomer_service.is_active
          and groomer_service.service_type = selected_request.service_type
      )
  ),
  zone_registry as materialized (
    select array(select name from pg_catalog.pg_timezone_names) as names
    where exists(select 1 from location_candidates)
  ),
  evaluated_candidates as materialized (
    select candidate.*, app_private.evaluate_match_eligibility_with_zones(
      candidate.request_id,candidate.user_id,statement_timestamp(),zone_registry.names) as evaluation
    from location_candidates candidate cross join zone_registry
  ),
  eligible_groomers as (
    select candidate.*,
      case when evaluation->>'state'='estimated_fit'
        then 'Estimated opening within your preferred window; confirm in the offer'
        else 'Service details need assessment before a time can be confirmed'
      end as availability_reason
    from evaluated_candidates candidate
    where evaluation->>'state' in ('estimated_fit','assessment_required')
  )
  insert into public.request_matches (
    request_id,
    groomer_id,
    customer_id,
    match_score,
    match_reason,
    eligibility_evaluation,
    status
  )
  select
    eligible_groomer.request_id,
    eligible_groomer.user_id,
    eligible_groomer.customer_id,
    greatest(
      0,
      least(
        100,
        eligible_groomer.location_score +
          coalesce(pet_fit.adjustment, 0) +
          case
            when coalesce(pet_fit.has_negative_evidence, false) then 0
            else coalesce(claim_tag_fit.adjustment, 0)
          end
      )
    )::numeric(5, 2),
    left(
      case
        when pet_fit.reason_text is null
          and (
            claim_tag_fit.reason_text is null
            or coalesce(pet_fit.has_negative_evidence, false)
          )
        then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '.'
        when pet_fit.reason_text is not null
          and claim_tag_fit.reason_text is not null
          and not coalesce(pet_fit.has_negative_evidence, false)
        then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
        when pet_fit.reason_text is not null then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '.'
        else
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
      end,
      500
    ),
    eligible_groomer.evaluation || jsonb_build_object('evaluated_at',statement_timestamp()),
    'visible'
  from eligible_groomers as eligible_groomer
  left join lateral (
    select
      greatest(
        -10,
        least(20, coalesce(sum(ranked_evidence.evidence_points), 0))
      )::integer as adjustment,
      coalesce(
        bool_or(ranked_evidence.evidence_points < 0),
        false
      ) as has_negative_evidence,
      string_agg(
        ranked_evidence.reason_label,
        ', '
        order by
          case
            when ranked_evidence.evidence_points < 0 then 0
            else 1
          end,
          case
            when ranked_evidence.evidence_points < 0
            then ranked_evidence.evidence_points
            else -ranked_evidence.evidence_points
          end,
          ranked_evidence.trait_sort,
          ranked_evidence.trait_value
      ) as reason_text
    from (
      select prioritized_evidence.*
      from (
        select
          evidence.*,
          row_number() over (
            order by
              case
                when evidence.evidence_points < 0 then 0
                else 1
              end,
              case
                when evidence.evidence_points < 0 then evidence.evidence_points
                else -evidence.evidence_points
              end,
              evidence.trait_sort,
              evidence.trait_value
          ) as fairness_rank
        from (
          select
            summary.trait_type,
            summary.trait_value,
            app_private.pet_fit_trait_sort(summary.trait_type) as trait_sort,
            case
              when summary.negative_review_outcome_count >
                summary.positive_review_outcome_count
              then -4
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
                and summary.confidence_tier = 'high'
              then 8
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
                and summary.confidence_tier = 'medium'
              then 6
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
              then 4
              when summary.positive_review_outcome_count =
                summary.negative_review_outcome_count
                and summary.positive_review_outcome_count > 0
              then 2
              when summary.completed_booking_count >= 2
              then 3
              when summary.completed_booking_count >= 1
              then 1
              else 0
            end as evidence_points,
            case
              when summary.negative_review_outcome_count >
                summary.positive_review_outcome_count
              then 'mixed feedback for ' ||
                app_private.pet_fit_trait_label(
                  summary.trait_type,
                  summary.trait_value
                )
              when summary.positive_review_outcome_count > 0
              then app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              ) || ' with positive reviews'
              when summary.completed_booking_count >= 2
              then app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              ) || ' from completed bookings'
              else app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              )
            end as reason_label
          from request_traits as request_trait
          join public.groomer_pet_fit_evidence_summary as summary
            on summary.groomer_id = eligible_groomer.user_id
           and summary.trait_type = request_trait.trait_type
           and summary.trait_value = request_trait.trait_value
          where summary.completed_booking_count > 0
            or summary.structured_review_outcome_count > 0
        ) as evidence
        where evidence.evidence_points <> 0
      ) as prioritized_evidence
      where prioritized_evidence.fairness_rank <= 3
      order by prioritized_evidence.fairness_rank
    ) as ranked_evidence
  ) as pet_fit
    on true
  left join lateral (
    select
      least(
        6,
        coalesce(sum(ranked_signal.signal_points), 0)
      )::integer as adjustment,
      string_agg(
        ranked_signal.reason_label,
        ', '
        order by
          ranked_signal.signal_points desc,
          ranked_signal.signal_sort,
          ranked_signal.trait_sort,
          ranked_signal.trait_value
      ) as reason_text
    from (
      select signal.*
      from (
        select
          request_trait.trait_type,
          request_trait.trait_value,
          1 as signal_sort,
          app_private.pet_fit_trait_sort(request_trait.trait_type) as trait_sort,
          2 as signal_points,
          'portfolio tag for ' ||
            app_private.pet_fit_trait_label(
              request_trait.trait_type,
              request_trait.trait_value
            ) as reason_label
        from request_traits as request_trait
        where exists (
          select 1
          from public.groomer_portfolio_fit_tags as portfolio_tag
          where portfolio_tag.groomer_id = eligible_groomer.user_id
            and portfolio_tag.trait_type = request_trait.trait_type
            and portfolio_tag.trait_value = request_trait.trait_value
        )

        union all

        select
          request_trait.trait_type,
          request_trait.trait_value,
          2 as signal_sort,
          app_private.pet_fit_trait_sort(request_trait.trait_type) as trait_sort,
          1 as signal_points,
          'self-claimed fit for ' ||
            app_private.pet_fit_trait_label(
              request_trait.trait_type,
              request_trait.trait_value
            ) as reason_label
        from request_traits as request_trait
        where exists (
          select 1
          from public.groomer_fit_claims as claim
          where claim.groomer_id = eligible_groomer.user_id
            and claim.trait_type = request_trait.trait_type
            and claim.trait_value = request_trait.trait_value
            and claim.is_active
        )
      ) as signal
      order by
        signal.signal_points desc,
        signal.signal_sort,
        signal.trait_sort,
        signal.trait_value
      limit 3
    ) as ranked_signal
  ) as claim_tag_fit
    on true
  on conflict on constraint request_matches_request_groomer_key do update
    set match_score=excluded.match_score, match_reason=excluded.match_reason,
      eligibility_evaluation=excluded.eligibility_evaluation,
      status=case when public.request_matches.status='hidden' then 'visible'
        else public.request_matches.status end
    where public.request_matches.status in ('visible','viewed','offered')
      or (public.request_matches.status='hidden'
        and public.request_matches.eligibility_evaluation->>'state'='excluded');

  get diagnostics v_match_count = row_count;
  return v_match_count;
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

create function app_private.refresh_request_match(p_request uuid,p_groomer uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform 1 from public.grooming_requests where id=p_request for update;
  if not found then return; end if;
  result:=app_private.evaluate_match_eligibility(p_request,p_groomer,statement_timestamp());
  if result->>'state'='excluded' then
    update public.request_matches set
      status=case when status in ('visible','viewed') then 'hidden' else status end,
      eligibility_evaluation=result || jsonb_build_object('evaluated_at',statement_timestamp()),
      match_reason='Current service or availability no longer fits this request'
      where request_id=p_request and groomer_id=p_groomer and status in ('visible','viewed','offered');
  else
    perform app_private.create_request_matches_for_request(p_request,p_groomer);
  end if;
end $$;
revoke all on function app_private.refresh_request_match(uuid,uuid)
  from public,anon,authenticated,service_role;

create function app_private.drain_match_refresh_queue(p_limit integer default 25)
returns integer language plpgsql security definer set search_path = ''
as $$
declare item record; processed integer:=0; event_ids bigint[];
begin
  -- Producers only append. Capture exact visible events after the request lock;
  -- events arriving during evaluation remain for the next pass.
  delete from app_private.match_refresh_queue where id in (
    select q.id from app_private.match_refresh_queue q
      where not exists(select 1 from public.grooming_requests r where r.id=q.request_id)
        or not exists(select 1 from public.groomer_profiles g where g.user_id=q.groomer_id)
      order by q.requested_at,q.id limit least(greatest(coalesce(p_limit,25),1),250)
  );
  for item in
    select q.request_id,q.groomer_id from (
      select request_id,groomer_id,min(requested_at) requested_at
      from app_private.match_refresh_queue group by request_id,groomer_id
    ) q
      join public.grooming_requests r on r.id=q.request_id
      order by q.requested_at,q.request_id,q.groomer_id
      limit least(greatest(coalesce(p_limit,25),1),250)
      for update of r skip locked
  loop
    select array_agg(id) into event_ids from app_private.match_refresh_queue
      where request_id=item.request_id and groomer_id=item.groomer_id;
    perform app_private.refresh_request_match(item.request_id,item.groomer_id);
    delete from app_private.match_refresh_queue where id=any(event_ids);
    processed:=processed+1;
  end loop;
  return processed;
end $$;
revoke all on function app_private.drain_match_refresh_queue(integer)
  from public,anon,authenticated,service_role;

create function app_private.enqueue_match_refresh(
  p_groomer_id uuid,p_pet_id uuid default null
)
returns integer language plpgsql security definer set search_path = ''
as $$
declare enqueued integer;
begin
  -- The consumer is bounded; no affected request is dropped at enqueue time.
  insert into app_private.match_refresh_queue(request_id,groomer_id)
  select r.id,p_groomer_id from public.grooming_requests r
    join public.groomer_profiles g on g.user_id=p_groomer_id
    where r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
      and (p_pet_id is null or r.pet_id=p_pet_id)
      and not exists(select 1 from public.request_matches m
        where m.request_id=r.id and m.groomer_id=p_groomer_id and m.status='dismissed')
      and (exists(select 1 from public.request_matches m
        where m.request_id=r.id and m.groomer_id=p_groomer_id)
        or (g.is_active and coalesce(g.service_location_modes @> array[r.location_mode]::text[],
          g.service_location_mode=r.location_mode,false)
          and exists(select 1 from public.groomer_services s where s.groomer_id=p_groomer_id
            and s.is_active and s.service_type=r.service_type)
          and exists(select 1 from app_private.address_locations a
            join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=p_groomer_id
            cross join lateral app_private.evaluate_request_location_fit(a.location,b.location,r.location_mode,
              r.travel_radius_miles,g.service_radius_miles,r.state,r.city,g.base_state,g.base_city) fit
            where a.id=r.address_location_id and a.owner_id=r.customer_id and fit.is_eligible)))
  ;
  get diagnostics enqueued=row_count;
  return enqueued;
end $$;
revoke all on function app_private.enqueue_match_refresh(uuid,uuid)
  from public,anon,authenticated,service_role;

create or replace function app_private.backfill_request_matches_for_groomer(
  p_groomer_id uuid,p_batch_size integer default 250
)
returns integer language sql security definer set search_path = ''
as $$ select app_private.enqueue_match_refresh(p_groomer_id); $$;

create trigger groomer_services_refresh_matches
after insert or update or delete on public.groomer_services
for each row execute function app_private.backfill_matches_after_groomer_availability_change();

create function app_private.enqueue_profile_match_refresh()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform app_private.backfill_request_matches_for_groomer(new.user_id);
  return new;
end $$;
revoke all on function app_private.enqueue_profile_match_refresh()
  from public,anon,authenticated,service_role;
drop trigger groomer_profiles_backfill_matches_after_activation on public.groomer_profiles;
create trigger groomer_profiles_refresh_matches
after insert or update of is_active,address_location_id,service_location_mode,service_location_modes,service_radius_miles
on public.groomer_profiles for each row execute function app_private.enqueue_profile_match_refresh();

create function app_private.enqueue_address_match_refresh()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare owner uuid;
begin
  owner:=case when tg_op='DELETE' then old.owner_id else new.owner_id end;
  perform app_private.backfill_request_matches_for_groomer(owner);
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app_private.enqueue_address_match_refresh()
  from public,anon,authenticated,service_role;
create trigger address_locations_refresh_matches
after insert or update or delete on app_private.address_locations
for each row execute function app_private.enqueue_address_match_refresh();

create function app_private.enqueue_booking_match_refresh()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare groomer uuid; pet uuid; candidate record;
begin
  if tg_op='DELETE' then groomer:=old.groomer_id; pet:=old.pet_id;
  else groomer:=new.groomer_id; pet:=new.pet_id; end if;
  perform app_private.backfill_request_matches_for_groomer(groomer);
  -- Pet occupancy also affects requests sent to other groomers.
  for candidate in select distinct g.user_id from public.groomer_profiles g
    join public.grooming_requests r on r.pet_id=pet and r.status in ('open','has_offers')
      and r.expires_at>statement_timestamp()
    where g.user_id<>groomer and exists(select 1 from public.groomer_services s
      where s.groomer_id=g.user_id and s.service_type=r.service_type and s.is_active)
  loop
    perform app_private.enqueue_match_refresh(candidate.user_id,pet);
  end loop;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app_private.enqueue_booking_match_refresh()
  from public,anon,authenticated,service_role;
create trigger bookings_refresh_matches
after insert or delete or update of status,scheduled_start,scheduled_end,occupied_start,occupied_end
on public.bookings for each row execute function app_private.enqueue_booking_match_refresh();

-- Worker activation follows linked contention and fan-out acceptance.

create function app_private.guard_match_writer_constraints()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.groomer_id::text,71071));
  result:=app_private.evaluate_match_constraints(new.request_id,new.groomer_id,statement_timestamp());
  if result->>'state'='excluded' then
    raise exception using errcode='22023',message='match_constraints_changed',detail=result->>'reason';
  end if;
  -- Existing timing/admission triggers validate the actual agreed interval.
  -- The catalog's estimated duration must not replace the groomer's explicit quote.
  return new;
end $$;
revoke all on function app_private.guard_match_writer_constraints()
  from public,anon,authenticated,service_role;
create trigger groomer_offers_revalidate_match
before insert on public.groomer_offers
for each row execute function app_private.guard_match_writer_constraints();
create trigger bookings_revalidate_match
before insert on public.bookings
for each row execute function app_private.guard_match_writer_constraints();

create function app_private.lock_match_constraint_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare groomer uuid;
begin
  if tg_table_name='groomer_services' then
    groomer:=case when tg_op='DELETE' then old.groomer_id else new.groomer_id end;
  elsif tg_table_name='groomer_profiles' then
    groomer:=case when tg_op='DELETE' then old.user_id else new.user_id end;
  else
    groomer:=case when tg_op='DELETE' then old.owner_id else new.owner_id end;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(groomer::text,71071));
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app_private.lock_match_constraint_change()
  from public,anon,authenticated,service_role;
create trigger groomer_services_lock_match_change
before insert or update or delete on public.groomer_services
for each row execute function app_private.lock_match_constraint_change();
create trigger groomer_profiles_lock_match_change
before update of is_active,address_location_id,service_location_mode,service_location_modes,service_radius_miles
on public.groomer_profiles for each row execute function app_private.lock_match_constraint_change();
create trigger address_locations_lock_match_change
before update or delete on app_private.address_locations
for each row execute function app_private.lock_match_constraint_change();

create function app_private.get_my_matched_requests(p_groomer_id uuid,p_limit integer default 25,p_offset integer default 0)
returns setof public.request_matches language plpgsql stable security definer set search_path = ''
as $$
declare owner uuid:=(select auth.uid());
begin
  if owner is null or owner is distinct from p_groomer_id
    or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles where id=owner and role='groomer') then
    raise exception using errcode='42501',message='groomer_profile_required';
  end if;
  if p_limit is null or p_limit not between 1 and 100 or p_offset is null or p_offset<0 then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  return query
    select display.*
    from public.request_matches m join public.grooming_requests r on r.id=m.request_id
    cross join lateral jsonb_populate_record(null::public.request_matches,to_jsonb(m)||
      case when m.eligibility_evaluation is null or exists(
        select 1 from app_private.match_refresh_queue q where q.request_id=m.request_id and q.groomer_id=m.groomer_id
      ) then jsonb_build_object('match_reason','Service and availability are being checked.',
        'eligibility_evaluation',jsonb_build_object('state','pending','reason','refresh_pending'))
      else '{}'::jsonb end) display
    where m.groomer_id=owner and m.status in ('visible','viewed','offered')
      and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
    order by m.created_at desc,m.id desc limit p_limit offset p_offset;
end $$;
create function public.get_my_matched_requests(p_groomer_id uuid,p_limit integer default 25,p_offset integer default 0)
returns setof public.request_matches language sql stable security invoker set search_path = ''
as $$ select * from app_private.get_my_matched_requests(p_groomer_id,p_limit,p_offset); $$;
revoke all on function app_private.get_my_matched_requests(uuid,integer,integer),
  public.get_my_matched_requests(uuid,integer,integer) from public,anon,authenticated,service_role;
grant execute on function app_private.get_my_matched_requests(uuid,integer,integer),
  public.get_my_matched_requests(uuid,integer,integer) to authenticated;

do $$
declare groomer record; worker bigint;
begin
  for groomer in select user_id from public.groomer_profiles order by user_id loop
    perform app_private.enqueue_match_refresh(groomer.user_id);
  end loop;
  worker:=cron.schedule('beckon_refresh_request_matches','10 seconds',
    'select app_private.drain_match_refresh_queue(25);');
  perform cron.alter_job(worker,active:=false);
end $$;
notify pgrst,'reload schema';
