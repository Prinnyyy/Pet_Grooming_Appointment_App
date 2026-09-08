do $$
declare
  v_customer uuid;
  v_groomer uuid;
  v_pet uuid;
  v_request uuid;
  v_match uuid;
  v_offer uuid;
  v_booking uuid;
  v_first uuid;
  v_start timestamptz;
  v_index integer := 0;
  v_requests uuid[] := '{}';
  v_offers uuid[] := '{}';
  v_snapshot jsonb;
  v_windows jsonb;
begin
  select id into strict v_customer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict v_groomer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict v_pet from public.pets where customer_id=v_customer order by id limit 1;
  perform set_config('app.availability_batch','1',true);
  insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days,timing_buffers)
  values(v_groomer,12,0,'{"preparation_minutes":30,"cleanup_minutes":30,"inbound_travel_minutes":0,"outbound_travel_minutes":0}')
  on conflict(groomer_id) do update set max_appointments_per_day=12,minimum_advance_notice_days=0,
    timing_buffers=excluded.timing_buffers;
  insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
  select v_groomer,d,'08:00'::time,'20:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
  on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
    is_enabled=true,timezone=excluded.timezone;
  foreach v_start in array array['2099-01-05T18:00:00Z'::timestamptz,
    '2099-01-05T19:45:00Z'::timestamptz,'2099-01-05T20:00:00Z'::timestamptz] loop
    v_index := v_index+1;
    update public.groomer_booking_preferences set timing_buffers=
      '{"preparation_minutes":30,"cleanup_minutes":30,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'
      where groomer_id=v_groomer;
    v_request := gen_random_uuid(); v_match := gen_random_uuid();
    v_requests := array_append(v_requests,v_request);
    insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,
      service_type,preferred_start,preferred_end,city,state,zip_code,street_address,
      location_mode,status,expires_at,preference_time_zone_identifier)
    values(v_request,v_customer,v_pet,'{}','[]','full_groom',v_start,v_start+interval '1 hour',
      'Fullerton','CA','92832','770 S Harbor Blvd','groomer_comes_to_customer','has_offers',
      statement_timestamp()+interval '1 day','America/Los_Angeles');
    insert into public.request_matches(id,request_id,groomer_id,customer_id,status)
    values(v_match,v_request,v_groomer,v_customer,'offered');
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
    values(v_request,v_match,v_customer,v_groomer,v_start,v_start+interval '1 hour',100,'pending',
      statement_timestamp()+interval '1 day') returning id into v_offer;
    v_offers := array_append(v_offers,v_offer);
  end loop;
  -- Quotes precede bookings, so the second acceptance must detect a later conflict.
  update public.groomer_booking_preferences set timing_buffers=
    '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'
    where groomer_id=v_groomer;
  for v_index in 1..3 loop
    v_offer := v_offers[v_index];
    select request_id,proposed_start into strict v_request,v_start from public.groomer_offers where id=v_offer;
    begin
      insert into public.bookings(request_id,offer_id,customer_id,groomer_id,
        scheduled_start,scheduled_end,price_estimate,status)
      values(v_request,v_offer,v_customer,v_groomer,v_start,v_start+interval '1 hour',100,'confirmed')
        returning id into v_booking;
      if v_index=2 then raise exception 'buffer_only_booking_conflict_accepted'; end if;
    exception when exclusion_violation then
      if v_index<>2 then raise; end if;
    end;
    if v_index=1 then v_first := v_booking; end if;
  end loop;
  -- Only the new cleanup/preparation overlaps an existing allocation, not service itself.
  update public.groomer_booking_preferences set timing_buffers=
    '{"preparation_minutes":30,"cleanup_minutes":30,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'
    where groomer_id=v_groomer;
  foreach v_start in array array['2099-01-05T16:30:00Z'::timestamptz,
    '2099-01-05T21:45:00Z'::timestamptz] loop
  v_request := gen_random_uuid(); v_match := gen_random_uuid();
  v_requests := array_append(v_requests,v_request);
  insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,
    service_type,preferred_start,preferred_end,city,state,zip_code,street_address,
    location_mode,status,expires_at,preference_time_zone_identifier)
  values(v_request,v_customer,v_pet,'{}','[]','full_groom',v_start,v_start+interval '1 hour',
    'Fullerton','CA','92832','770 S Harbor Blvd','groomer_comes_to_customer','open',
    statement_timestamp()+interval '1 day','America/Los_Angeles');
  insert into public.request_matches(id,request_id,groomer_id,customer_id,status)
    values(v_match,v_request,v_groomer,v_customer,'visible');
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_groomer,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  begin
    perform public.create_groomer_offer(v_request,v_start,v_start+interval '1 hour',100,null);
    raise exception using errcode='ZX374',message='new_quote_buffer_collision_accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'groomer_unavailable' then raise; end if;
  end;
  execute 'reset role';
  begin
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
    values(v_request,v_match,v_customer,v_groomer,v_start,v_start+interval '1 hour',100,'pending',
      statement_timestamp()+interval '1 day');
    raise exception using errcode='ZX374',message='direct_quote_buffer_collision_accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'groomer_unavailable' then raise; end if;
  end;
  if exists(select 1 from public.groomer_offers where request_id=v_request)
    or (select status from public.request_matches where id=v_match) <> 'visible'
    or (select status from public.grooming_requests where id=v_request) <> 'open' then
    raise exception 'rejected_buffer_quote_left_partial_state';
  end if;
  end loop;
  update public.groomer_booking_preferences set timing_buffers=
    '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'
    where groomer_id=v_groomer;
  if app_private.groomer_can_admit_service(v_groomer,'2099-01-05T16:00:00Z','2099-01-05T16:15:00Z',
      '2099-01-05T15:55:01Z')
    or not app_private.groomer_can_admit_service(v_groomer,'2099-01-05T16:00:00Z','2099-01-05T16:15:00Z',
      '2099-01-05T15:55:00Z') then
    raise exception 'admission_five_minute_boundary_mismatch';
  end if;
  update public.groomer_booking_preferences set max_appointments_per_day=2 where groomer_id=v_groomer;
  if app_private.groomer_can_admit_service(v_groomer,'2099-01-05T22:00:00Z','2099-01-05T23:00:00Z') then
    raise exception 'admission_daily_quota_lost';
  end if;
  update public.groomer_booking_preferences set max_appointments_per_day=12,minimum_advance_notice_days=1
    where groomer_id=v_groomer;
  if app_private.groomer_can_admit_service(v_groomer,'2099-01-05T22:00:00Z','2099-01-05T23:00:00Z',
      '2099-01-05T16:00:00Z') then
    raise exception 'admission_calendar_notice_lost';
  end if;
  update public.groomer_booking_preferences set minimum_advance_notice_days=0 where groomer_id=v_groomer;
  if not exists(select 1 from public.bookings where id=v_first
      and occupied_start='2099-01-05T17:30:00Z'::timestamptz
      and occupied_end='2099-01-05T19:30:00Z'::timestamptz
      and service_time_zone_identifier='America/Los_Angeles'
      and schedule_time_zone_identifier='America/Los_Angeles') then
    raise exception 'booking_did_not_retain_offer_allocation';
  end if;
  begin
    update public.bookings set occupied_end=occupied_end-interval '15 minutes' where id=v_first;
    raise exception 'booking_allocation_snapshot_mutated';
  exception when sqlstate '23514' then null;
  end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_groomer,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  v_snapshot := public.get_groomer_availability();
  select jsonb_agg(w || jsonb_build_object('timezone','Asia/Dhaka','start_time','00:00','end_time','23:59'))
    into v_windows from jsonb_array_elements(v_snapshot->'windows') w;
  begin
    -- In Dhaka, service begins Jan 6 at midnight; preparation starts Jan 5.
    perform public.save_groomer_availability(v_snapshot->>'revision',v_windows,v_snapshot->'preferences',
      (v_snapshot->'time_off') || jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),
        'title','T-374 preparation conflict','start_date','2099-01-05','end_date','2099-01-05')));
    raise exception 'availability_save_overwrote_booked_preparation';
  exception when sqlstate '22023' then
    if sqlerrm <> 'time_off_conflicts_with_booking_occupancy' then raise; end if;
  end;
  if public.get_groomer_availability() is distinct from v_snapshot then
    raise exception 'rejected_time_off_save_partially_changed_availability';
  end if;
  select jsonb_agg(w || jsonb_build_object('start_time','10:00'))
    into v_windows from jsonb_array_elements(v_snapshot->'windows') w;
  begin
    perform public.save_groomer_availability(v_snapshot->>'revision',v_windows,
      v_snapshot->'preferences',v_snapshot->'time_off');
    raise exception 'weekly_hours_save_removed_booked_preparation';
  exception when sqlstate '22023' then
    if sqlerrm <> 'weekly_hours_conflict_with_booking_occupancy' then raise; end if;
  end;
  if public.get_groomer_availability() is distinct from v_snapshot then
    raise exception 'rejected_hours_save_partially_changed_availability';
  end if;
  execute 'reset role';
  begin
    update public.groomer_availability_windows set start_time='10:00' where groomer_id=v_groomer;
    set constraints all immediate;
    raise exception 'direct_hours_writer_removed_booked_preparation';
  exception when sqlstate '22023' then
    if sqlerrm <> 'weekly_hours_conflict_with_booking_occupancy' then raise; end if;
  end;
  begin
    update public.groomer_availability_windows set start_time='00:00',end_time='24:00',timezone='Asia/Dhaka'
      where groomer_id=v_groomer;
    insert into public.groomer_time_off_windows(groomer_id,title,start_date,end_date)
      values(v_groomer,'T-374 direct preparation conflict','2099-01-05','2099-01-05');
    set constraints all immediate;
    raise exception 'direct_time_off_writer_removed_booked_preparation';
  exception when sqlstate '22023' then
    if sqlerrm <> 'time_off_conflicts_with_booking_occupancy' then raise; end if;
  end;
  -- Deferred checks must allow an invalid intermediate state repaired in this transaction.
  update public.groomer_availability_windows set is_enabled=false where groomer_id=v_groomer;
  update public.groomer_availability_windows set is_enabled=true where groomer_id=v_groomer;
  set constraints all immediate;
  set constraints all deferred;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_groomer,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  perform set_config('app.t374_save_started',clock_timestamp()::text,true);
  for v_index in 1..3 loop
    v_snapshot := public.get_groomer_availability();
    perform public.save_groomer_availability(v_snapshot->>'revision',v_snapshot->'windows',
      v_snapshot->'preferences',v_snapshot->'time_off');
    if public.get_groomer_availability()->'windows' is distinct from v_snapshot->'windows' then
      raise exception 'unchanged_weekly_rows_rewritten_by_save';
    end if;
    set constraints all immediate;
    set constraints all deferred;
  end loop;
  perform set_config('app.t374_save_mean_ms',
    (extract(epoch from clock_timestamp()-current_setting('app.t374_save_started')::timestamptz)*1000/3)::text,true);
  execute 'reset role';
  -- Do not consume the publication fixture's open-request quota.
  if current_setting('app.t374_scale',true)='1' then
    for v_index in 1..54 loop
      v_start := '2099-02-01T18:00:00Z'::timestamptz + (v_index-1)*interval '1 day';
      if v_index=54 then v_start := v_start+interval '7 hours 30 minutes'; end if;
      v_request := gen_random_uuid(); v_match := gen_random_uuid();
      v_requests := array_append(v_requests,v_request);
      insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,
        service_type,preferred_start,preferred_end,city,state,zip_code,street_address,
        location_mode,status,expires_at,preference_time_zone_identifier)
      values(v_request,v_customer,v_pet,'{}','[]','full_groom',v_start,v_start+interval '1 hour',
        'Fullerton','CA','92832','770 S Harbor Blvd','groomer_comes_to_customer','has_offers',
        statement_timestamp()+interval '1 day','America/Los_Angeles');
      insert into public.request_matches(id,request_id,groomer_id,customer_id,status)
      values(v_match,v_request,v_groomer,v_customer,'offered');
      insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
        proposed_start,proposed_end,price_estimate,status,expires_at)
      values(v_request,v_match,v_customer,v_groomer,v_start,v_start+interval '1 hour',100,'pending',
        statement_timestamp()+interval '1 day') returning id into v_offer;
      insert into public.bookings(request_id,offer_id,customer_id,groomer_id,
        scheduled_start,scheduled_end,price_estimate,status)
      values(v_request,v_offer,v_customer,v_groomer,v_start,v_start+interval '1 hour',100,'confirmed');
    end loop;
    set constraints all immediate;
    set constraints all deferred;
    execute 'set local role authenticated';
    v_snapshot := public.get_groomer_availability();
    perform set_config('app.t374_scale_started',clock_timestamp()::text,true);
    perform public.save_groomer_availability(v_snapshot->>'revision',v_snapshot->'windows',
      v_snapshot->'preferences',v_snapshot->'time_off');
    set constraints all immediate;
    set constraints all deferred;
    perform set_config('app.t374_scale_save_ms',
      (extract(epoch from clock_timestamp()-current_setting('app.t374_scale_started')::timestamptz)*1000)::text,true);
    if public.get_groomer_availability() is distinct from v_snapshot then
      raise exception 'scale_unchanged_save_modified_snapshot';
    end if;
    -- The last booking is beyond the first client page, but must still block time off.
    begin
      perform public.save_groomer_availability(v_snapshot->>'revision',v_snapshot->'windows',
        v_snapshot->'preferences',v_snapshot->'time_off' || jsonb_build_array(jsonb_build_object(
          'id',gen_random_uuid(),'title','T-374 beyond-page conflict',
          'start_date',(v_start at time zone 'America/Los_Angeles')::date,
          'end_date',(v_start at time zone 'America/Los_Angeles')::date)));
      raise exception using errcode='ZX374',message='scale_last_booking_time_off_accepted';
    exception when sqlstate '22023' then
      if sqlerrm<>'time_off_conflicts_with_booking_occupancy' then raise; end if;
    end;
    if public.get_groomer_availability() is distinct from v_snapshot then
      raise exception 'scale_rejected_save_modified_snapshot';
    end if;
    select jsonb_agg(w || jsonb_build_object('end_time','19:00')) into v_windows
      from jsonb_array_elements(v_snapshot->'windows') w;
    begin
      perform public.save_groomer_availability(v_snapshot->>'revision',v_windows,
        v_snapshot->'preferences',v_snapshot->'time_off');
      raise exception using errcode='ZX374',message='scale_last_booking_hours_accepted';
    exception when sqlstate '22023' then
      if sqlerrm<>'weekly_hours_conflict_with_booking_occupancy' then raise; end if;
    end;
    if public.get_groomer_availability() is distinct from v_snapshot then
      raise exception 'scale_rejected_hours_modified_snapshot';
    end if;
    select jsonb_agg(w || jsonb_build_object('end_time','19:45')) into v_windows
      from jsonb_array_elements(v_snapshot->'windows') w;
    perform set_config('app.t374_scale_started',clock_timestamp()::text,true);
    perform public.save_groomer_availability(v_snapshot->>'revision',v_windows,
      v_snapshot->'preferences',v_snapshot->'time_off');
    set constraints all immediate;
    set constraints all deferred;
    perform set_config('app.t374_scale_changed_ms',
      (extract(epoch from clock_timestamp()-current_setting('app.t374_scale_started')::timestamptz)*1000)::text,true);
    if exists(select 1 from jsonb_array_elements(public.get_groomer_availability()->'windows') w
      where (w->>'end_time')::time<>'19:45'::time) then
      raise exception 'scale_valid_hours_not_saved';
    end if;
    execute 'reset role';
  end if;
  delete from public.grooming_requests where id=any(v_requests);
end $$;
select 'T-374 buffered booking conflict and adjacency rollback passed' as result,
  current_setting('app.t374_save_mean_ms')::numeric as mean_ms_per_save_with_two_buffered_bookings,
  current_setting('app.t374_scale_save_ms',true)::numeric as ms_per_save_with_54_additional_bookings,
  current_setting('app.t374_scale_changed_ms',true)::numeric as ms_per_changed_save_with_54_additional_bookings;
