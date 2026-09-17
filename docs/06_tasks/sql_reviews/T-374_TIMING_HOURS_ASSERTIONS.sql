do $$
declare v_groomer uuid; v_started timestamptz; v_i integer; v_case record; v_expected boolean;
begin
  select id into strict v_groomer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  perform set_config('app.availability_batch','1',true);
  insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
  select v_groomer,d,'08:00'::time,'20:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
  on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
    is_enabled=true,timezone=excluded.timezone;
  if not app_private.occupied_weekly_hours_covered(v_groomer,'2026-09-08T15:00:00Z','2026-09-09T03:00:00Z')
    or app_private.occupied_weekly_hours_covered(v_groomer,'2026-09-08T14:59:59.999999Z','2026-09-08T16:00:00Z')
    or app_private.occupied_weekly_hours_covered(v_groomer,'2026-09-09T02:00:00Z','2026-09-09T03:00:00.000001Z') then
    raise exception 'weekly_hours_exact_boundary_mismatch';
  end if;
  update public.groomer_availability_windows set start_time='01:15',end_time='01:45' where groomer_id=v_groomer;
  if not app_private.occupied_weekly_hours_covered(v_groomer,'2026-11-01T08:15:00Z','2026-11-01T08:45:00Z')
    or not app_private.occupied_weekly_hours_covered(v_groomer,'2026-11-01T09:15:00Z','2026-11-01T09:45:00Z')
    or app_private.occupied_weekly_hours_covered(v_groomer,'2026-11-01T08:30:00Z','2026-11-01T09:30:00Z') then
    raise exception 'repeated_hour_closed_gap_was_ignored';
  end if;
  update public.groomer_availability_windows set start_time='01:00',end_time='04:00' where groomer_id=v_groomer;
  if not app_private.occupied_weekly_hours_covered(v_groomer,'2026-03-08T09:30:00Z','2026-03-08T10:30:00Z') then
    raise exception 'spring_forward_elapsed_interval_rejected';
  end if;
  update public.groomer_availability_windows set start_time='00:00',end_time='24:00' where groomer_id=v_groomer;
  if not app_private.occupied_weekly_hours_covered(v_groomer,'2026-09-09T06:30:00Z','2026-09-09T07:30:00Z') then
    raise exception 'fully_covered_midnight_rejected';
  end if;
  update public.groomer_availability_windows set is_enabled=false where groomer_id=v_groomer and weekday=3;
  if app_private.occupied_weekly_hours_covered(v_groomer,'2026-09-09T06:30:00Z','2026-09-09T07:30:00Z') then
    raise exception 'closed_next_day_accepted';
  end if;
  for v_case in
    select z.*,w.* from (values
      ('America/Los_Angeles','2026-11-01T08:00:00Z'::timestamptz,'2026-11-01T11:00:00Z'::timestamptz),
      ('America/Los_Angeles','2026-03-08T09:00:00Z','2026-03-08T12:00:00Z'),
      ('America/New_York','2026-11-01T05:00:00Z','2026-11-01T08:00:00Z'),
      ('Australia/Lord_Howe','2026-04-04T14:00:00Z','2026-04-04T17:00:00Z'),
      ('Pacific/Apia','2011-12-30T09:00:00Z','2011-12-30T12:00:00Z'),
      ('Asia/Kathmandu','2026-09-08T17:00:00Z','2026-09-08T20:00:00Z'),
      ('UTC','2026-09-08T23:59:59.999999Z','2026-09-09T00:00:00.000001Z')
    ) z(zone,starts,ends) cross join (values
      ('00:00'::time,'24:00'::time,0),('01:15','01:45',0),('08:00','20:00',0),('00:00','24:00',7)
    ) w(opens,closes,closed_day)
  loop
    update public.groomer_availability_windows set timezone=v_case.zone,
      start_time=v_case.opens,end_time=v_case.closes,is_enabled=weekday<>v_case.closed_day
      where groomer_id=v_groomer;
    -- Retain the original per-segment predicate as an independent optimization oracle.
    with windows as materialized (
      select weekday,start_time,end_time from public.groomer_availability_windows
      where groomer_id=v_groomer and is_enabled
    ), segments as (
      select greatest(t,v_case.starts) as starts,least(t+interval '1 second',v_case.ends) as ends
      from generate_series(date_trunc('second',v_case.starts),v_case.ends,interval '1 second') t
      where t<v_case.ends
    ), wall as (
      select timezone(v_case.zone,starts) as starts,ends-starts as elapsed from segments
    )
    select not exists(select 1 from wall s where not exists(select 1 from windows w
      where w.weekday=extract(isodow from s.starts)::integer
        and s.starts>=s.starts::date+w.start_time
        and s.starts+s.elapsed<=s.starts::date+w.end_time)) into v_expected;
    if app_private.occupied_weekly_hours_covered(v_groomer,v_case.starts,v_case.ends)
      is distinct from v_expected then
      raise exception 'optimized_coverage_differs_from_original: %',v_case;
    end if;
  end loop;
  update public.groomer_availability_windows set timezone='America/Los_Angeles',
    start_time='00:00',end_time='24:00',is_enabled=weekday<>3 where groomer_id=v_groomer;
  v_started := clock_timestamp();
  for v_i in 1..10 loop
    if not app_private.occupied_weekly_hours_covered(v_groomer,'2026-09-08T16:00:00Z','2026-09-09T04:00:00Z') then
      raise exception 'hours_benchmark_fixture_not_covered';
    end if;
  end loop;
  perform set_config('app.t374_hours_mean_ms',(extract(epoch from clock_timestamp()-v_started)*100)::text,true);
end $$;
select 'T-374 exact weekly coverage vectors passed' as result,
  current_setting('app.t374_hours_mean_ms')::numeric as mean_ms_per_12_hour_check;
