-- Run after the evaluator fixture, within its rollback-only transaction.
create temporary table t375_cost_samples(label text,iterations integer,elapsed_ms numeric) on commit drop;
do $$
declare r uuid; g uuid; started timestamptz; n integer;
begin
  select id into strict r from public.grooming_requests where street_address='T375 rollback fixture';
  select id into strict g from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  started:=clock_timestamp();
  for n in 1..25 loop
    perform app_private.evaluate_match_constraints(r,g,statement_timestamp()+make_interval(secs=>n));
  end loop;
  insert into t375_cost_samples values('explicit_constraints',25,extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();
  for n in 1..25 loop
    perform app_private.service_timing_earliest_start(statement_timestamp()+make_interval(secs=>n),0,'America/Los_Angeles');
  end loop;
  insert into t375_cost_samples values('earliest_start',25,extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();
  for n in 1..25 loop
    perform app_private.match_weekly_ranges('2026-09-18T16:00:00Z','2026-09-18T19:00:00Z',
      'America/Los_Angeles',array_fill('08:00'::time,array[7]),array_fill('13:00'::time,array[7]));
  end loop;
  insert into t375_cost_samples values('weekly_ranges',25,extract(epoch from clock_timestamp()-started)*1000);
  started:=clock_timestamp();
  for n in 1..25 loop
    perform app_private.evaluate_match_eligibility(r,g,statement_timestamp()+make_interval(secs=>n));
  end loop;
  insert into t375_cost_samples values('full_evaluator',25,extract(epoch from clock_timestamp()-started)*1000);
  if to_regprocedure('app_private.t375_baseline_matcher(uuid,uuid)') is not null then
    delete from public.request_matches where request_id=r and groomer_id=g;
    if app_private.t375_baseline_matcher(r,g)<>0 then
      raise exception 'T-375 baseline unexpectedly matched explicit time off';
    end if;
    started:=clock_timestamp();
    for n in 1..25 loop perform app_private.t375_baseline_matcher(r,g); end loop;
    insert into t375_cost_samples values('baseline_matcher',25,extract(epoch from clock_timestamp()-started)*1000);
    delete from public.request_matches where request_id=r and groomer_id=g;
    if app_private.create_request_matches_for_request(r,g)<>0 then
      raise exception 'T-375 revised matcher ignored explicit time off';
    end if;
    started:=clock_timestamp();
    for n in 1..25 loop perform app_private.create_request_matches_for_request(r,g); end loop;
    insert into t375_cost_samples values('revised_matcher',25,extract(epoch from clock_timestamp()-started)*1000);
    delete from public.groomer_time_off_windows where groomer_id=g;
    started:=clock_timestamp();
    for n in 1..25 loop perform app_private.t375_baseline_matcher(r,g); end loop;
    insert into t375_cost_samples values('baseline_open_window',25,extract(epoch from clock_timestamp()-started)*1000);
    started:=clock_timestamp();
    for n in 1..25 loop perform app_private.create_request_matches_for_request(r,g); end loop;
    insert into t375_cost_samples values('revised_open_window',25,extract(epoch from clock_timestamp()-started)*1000);
  end if;
end $$;
select * from t375_cost_samples order by label;
