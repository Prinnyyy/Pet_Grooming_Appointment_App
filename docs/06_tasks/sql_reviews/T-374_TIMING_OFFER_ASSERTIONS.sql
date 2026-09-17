-- Named fixture owners only; the runner rolls back every row and definition.
do $$
declare
  v_customer uuid;
  v_groomer uuid;
  v_pet uuid;
  v_request uuid := gen_random_uuid();
  v_match uuid := gen_random_uuid();
  v_offer uuid;
  v_start timestamptz := timezone('America/Los_Angeles',
    (timezone('America/Los_Angeles',statement_timestamp())::date+10)+time '08:00');
  v_case record;
  v_snapshot jsonb;
begin
  select id into strict v_customer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict v_groomer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict v_pet from public.pets where customer_id=v_customer order by id limit 1;
  perform set_config('app.availability_batch','1',true);
  insert into public.groomer_booking_preferences(groomer_id,timing_buffers)
  values(v_groomer,'{"preparation_minutes":15,"cleanup_minutes":10,"inbound_travel_minutes":30,"outbound_travel_minutes":20}')
  on conflict(groomer_id) do update set timing_buffers=excluded.timing_buffers;
  insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
  select v_groomer,d,'00:00'::time,'24:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
  on conflict(groomer_id,weekday) do update set timezone=excluded.timezone,
    start_time=excluded.start_time,end_time=excluded.end_time,is_enabled=true;
  insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,
    service_type,preferred_start,preferred_end,city,state,zip_code,street_address,
    location_mode,status,expires_at,preference_time_zone_identifier)
  values(v_request,v_customer,v_pet,'{}','[]','full_groom',v_start,v_start+interval '12 hours',
    'Fullerton','CA','92832','770 S Harbor Blvd','groomer_comes_to_customer','has_offers',
    statement_timestamp()+interval '1 day','America/Los_Angeles');
  insert into public.request_matches(id,request_id,groomer_id,customer_id,status)
  values(v_match,v_request,v_groomer,v_customer,'offered');
  update public.groomer_availability_windows set start_time='08:00' where groomer_id=v_groomer;
  begin
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
    values(v_request,v_match,v_customer,v_groomer,v_start,v_start+interval '1 hour',100,'pending',
      statement_timestamp()+interval '1 day');
    raise exception 'quote_preparation_outside_weekly_hours_accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'occupied_outside_weekly_hours' then raise; end if;
  end;
  update public.groomer_availability_windows set start_time='00:00' where groomer_id=v_groomer;
  for v_case in select * from (values
    (v_start-interval '1 minute',v_start+interval '1 hour'),
    (v_start+interval '11 hours',v_start+interval '12 hours 1 minute'),
    (v_start,v_start+interval '14 minutes'),
    (v_start,v_start+interval '15 minutes 1 second'),
    (v_start,'infinity'::timestamptz)
  ) as cases(starts,ends) loop
    begin
      insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
        proposed_start,proposed_end,price_estimate,status,expires_at)
      values(v_request,v_match,v_customer,v_groomer,v_case.starts,v_case.ends,100,'pending',
        statement_timestamp()+interval '1 day');
      raise exception 'invalid_offer_timing_accepted: %, %',v_case.starts,v_case.ends;
    exception when sqlstate '22023' then null;
    end;
  end loop;
  insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
    proposed_start,proposed_end,price_estimate,status,expires_at)
  values(v_request,v_match,v_customer,v_groomer,v_start,v_start+interval '12 hours',100,'pending',
    statement_timestamp()+interval '1 day') returning id into v_offer;
  begin
    update public.groomer_offers set proposed_end=proposed_end+interval '1 minute' where id=v_offer;
    raise exception 'offer_update_escaped_customer_window';
  exception when sqlstate '22023' then null;
  end;
  select jsonb_build_object('buffers',applied_timing_buffers,'start',occupied_start,'end',occupied_end,
    'service_zone',service_time_zone_identifier,'schedule_zone',schedule_time_zone_identifier)
    into v_snapshot from public.groomer_offers where id=v_offer;
  if v_snapshot->>'service_zone' is distinct from 'America/Los_Angeles'
    or v_snapshot->>'schedule_zone' is distinct from 'America/Los_Angeles'
    or (v_snapshot->>'start')::timestamptz is distinct from v_start-interval '45 minutes'
    or (v_snapshot->>'end')::timestamptz is distinct from v_start+interval '12 hours 30 minutes'
    or v_snapshot->'buffers' is distinct from
      '{"preparation_minutes":15,"cleanup_minutes":10,"inbound_travel_minutes":30,"outbound_travel_minutes":20}'::jsonb then
    raise exception 'offer_allocation_snapshot_mismatch';
  end if;
  update public.groomer_booking_preferences set timing_buffers=
    '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'
    where groomer_id=v_groomer;
  update public.groomer_offers set status='withdrawn_by_groomer',withdrawn_at=statement_timestamp()
    where id=v_offer;
  if not exists(select 1 from public.groomer_offers where id=v_offer and status='withdrawn_by_groomer'
      and proposed_end=v_start+interval '12 hours') then
    raise exception 'valid_offer_boundary_or_withdrawal_failed';
  end if;
  if (select jsonb_build_object('buffers',applied_timing_buffers,'start',occupied_start,'end',occupied_end,
      'service_zone',service_time_zone_identifier,'schedule_zone',schedule_time_zone_identifier)
      from public.groomer_offers where id=v_offer) is distinct from v_snapshot then
    raise exception 'settings_or_status_rewrote_offer_allocation';
  end if;
  begin
    update public.groomer_offers set occupied_start=occupied_start+interval '1 minute' where id=v_offer;
    raise exception 'offer_allocation_mutation_accepted';
  exception when sqlstate '23514' then null;
  end;
  update public.groomer_booking_preferences set timing_buffers=null where groomer_id=v_groomer;
  begin
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
    values(v_request,v_match,v_customer,v_groomer,v_start,v_start+interval '15 minutes',100,'pending',
      statement_timestamp()+interval '1 day');
    raise exception 'unknown_buffers_accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'timing_buffers_confirmation_required' then raise; end if;
  end;
  update public.groomer_booking_preferences set timing_buffers=
    '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'
    where groomer_id=v_groomer;
  insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
    proposed_start,proposed_end,price_estimate,status,expires_at,
    occupied_start,occupied_end,service_time_zone_identifier,applied_timing_buffers)
  values(v_request,v_match,v_customer,v_groomer,v_start,v_start+interval '15 minutes',100,'pending',
    statement_timestamp()+interval '1 day',v_start+interval '2 hours',v_start+interval '3 hours','UTC','{}')
    returning id into v_offer;
  if not exists(select 1 from public.groomer_offers where id=v_offer
      and occupied_start=v_start and occupied_end=v_start+interval '15 minutes'
      and service_time_zone_identifier='America/Los_Angeles') then
    raise exception 'caller_supplied_allocation_was_trusted';
  end if;
  if has_function_privilege('authenticated','app_private.snapshot_offer_timing()','execute')
    or has_function_privilege('anon','app_private.snapshot_offer_timing()','execute') then
    raise exception 'offer_snapshot_helper_exposed';
  end if;
end $$;
select 'T-374 offer consent and duration rollback passed' as result;

do $$
declare
  v_customer uuid;
  v_groomer uuid;
  v_pet uuid;
  v_location uuid;
  v_time_off uuid := gen_random_uuid();
  v_created record;
  v_accepted record;
  v_replayed record;
  v_request uuid := gen_random_uuid();
  v_match uuid := gen_random_uuid();
  v_offer uuid;
  v_case record;
begin
  select id into strict v_customer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict v_groomer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict v_pet from public.pets where customer_id=v_customer order by id limit 1;
  perform set_config('app.availability_batch','1',true);
  update public.groomer_booking_preferences set timing_buffers=
    '{"preparation_minutes":15,"cleanup_minutes":10,"inbound_travel_minutes":30,"outbound_travel_minutes":20}'
    where groomer_id=v_groomer;
  update public.groomer_availability_windows set timezone='America/New_York' where groomer_id=v_groomer;
  v_location := app_private.save_address_location_v2(v_groomer,null,'apple_maps',null,'US',
    33.83,-117.92,'manual_geocode',statement_timestamp());
  update public.groomer_profiles set address_location_id=v_location where user_id=v_groomer;
  insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,
    service_type,preferred_start,preferred_end,city,state,zip_code,street_address,
    location_mode,travel_radius_miles,status,expires_at,preference_time_zone_identifier)
  values(v_request,v_customer,v_pet,'{}','[]','full_groom','2026-11-01T02:00:00Z','2026-11-02T14:00:00Z',
    'Fullerton','CA','92832','770 S Harbor Blvd','customer_comes_to_groomer',5,'has_offers',
    statement_timestamp()+interval '1 day','America/New_York');
  insert into public.request_matches(id,request_id,groomer_id,customer_id,status)
  values(v_match,v_request,v_groomer,v_customer,'offered');
  begin
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
    values(v_request,v_match,v_customer,v_groomer,'2026-11-01T08:30:00Z','2026-11-01T10:30:00Z',100,'pending',
      statement_timestamp()+interval '1 day');
    raise exception 'unknown_destination_zone_accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'service_timezone_confirmation_required' then raise; end if;
  end;
  update app_private.address_locations set time_zone_identifier='America/Los_Angeles' where id=v_location;
  for v_case in select * from (values
    ('2026-11-01T08:30:00Z'::timestamptz,'2026-11-01T10:30:00Z'::timestamptz),
    ('2026-11-02T07:00:00Z'::timestamptz,'2026-11-02T08:00:00Z'::timestamptz)
  ) cases(starts,ends) loop
    if v_case.ends='2026-11-02T08:00:00Z'::timestamptz then
      -- Schedule is New York: midnight there is 05:00Z, so use the next
      -- NY midnight as a separate quote whose cleanup alone enters time off.
      insert into public.groomer_time_off_windows(id,groomer_id,title,start_date,end_date)
      values(v_time_off,v_groomer,'T-374 buffer boundary','2026-11-02','2026-11-02');
      begin
        insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
          proposed_start,proposed_end,price_estimate,status,expires_at)
        values(v_request,v_match,v_customer,v_groomer,'2026-11-02T04:00:00Z','2026-11-02T05:00:00Z',100,'pending',
          statement_timestamp()+interval '1 day');
        raise exception 'cleanup_entered_schedule_time_off';
      exception when sqlstate '22023' then
        if sqlerrm <> 'occupied_time_off_conflict' then raise; end if;
      end;
      delete from public.groomer_time_off_windows where id=v_time_off;
    end if;
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
    values(v_request,v_match,v_customer,v_groomer,v_case.starts,v_case.ends,100,'pending',
      statement_timestamp()+interval '1 day') returning id into v_offer;
    if not exists(select 1 from public.groomer_offers where id=v_offer
        and service_time_zone_identifier='America/Los_Angeles'
        and schedule_time_zone_identifier='America/New_York'
        and proposed_start=v_case.starts and proposed_end=v_case.ends
        and occupied_start=v_case.starts-interval '15 minutes'
        and occupied_end=v_case.ends+interval '10 minutes') then
      raise exception 'destination_zone_or_customer_travel_allocation_mismatch';
    end if;
    update public.groomer_offers set status='expired' where id=v_offer;
  end loop;
  begin
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
    values(v_request,v_match,v_customer,v_groomer,'2026-11-02T07:00:00Z','2026-11-02T08:15:00Z',100,'pending',
      statement_timestamp()+interval '1 day');
    raise exception 'service_crossing_destination_midnight_accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'service_crosses_local_day' then raise; end if;
  end;
  update public.request_matches set status='visible' where id=v_match;
  -- Model a pre-migration row only inside the outer rollback transaction.
  -- Restore the snapshot trigger before exercising any public operation.
  execute 'alter table public.groomer_offers disable trigger groomer_offers_snapshot_timing';
  insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
    proposed_start,proposed_end,price_estimate,status,expires_at)
  values(v_request,v_match,v_customer,v_groomer,'2026-11-02T04:00:00Z','2026-11-02T05:00:00Z',100,'pending',
    statement_timestamp()+interval '1 day') returning id into v_offer;
  execute 'alter table public.groomer_offers enable trigger groomer_offers_snapshot_timing';
  update public.request_matches set status='offered' where id=v_match;
  update public.grooming_requests set status='has_offers' where id=v_request;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  begin
    perform public.accept_groomer_offer(v_offer);
    raise exception 'legacy_quote_created_booking_without_snapshot';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'updated_timing_offer_required' then raise; end if;
  end;
  execute 'reset role';
  if exists(select 1 from public.bookings where offer_id=v_offer)
    or not exists(select 1 from public.groomer_offers where id=v_offer and status='pending'
      and applied_timing_buffers is null and occupied_start is null and occupied_end is null)
    or not exists(select 1 from public.grooming_requests where id=v_request and status='has_offers') then
    raise exception 'legacy_rejection_mutated_agreement_or_request';
  end if;
  begin
    -- Establish an already-accepted legacy fixture, then restore all guards before replay.
    execute 'alter table public.bookings disable trigger bookings_snapshot_timing';
    execute 'set local role authenticated';
    select * into strict v_accepted from public.accept_groomer_offer(v_offer);
    execute 'reset role';
    execute 'alter table public.bookings enable trigger bookings_snapshot_timing';
    if not exists(select 1 from public.bookings where id=v_accepted.booking_id
        and applied_timing_buffers is null and service_time_zone_identifier is null
        and schedule_time_zone_identifier is null and occupied_start is null and occupied_end is null
        and scheduled_start='2026-11-02T04:00:00Z'::timestamptz
        and scheduled_end='2026-11-02T05:00:00Z'::timestamptz) then
      raise exception 'accepted_legacy_fixture_did_not_preserve_unknown_timing';
    end if;
    -- Current settings cannot revoke or reinterpret an existing acceptance receipt.
    update public.groomer_booking_preferences set timing_buffers=null where groomer_id=v_groomer;
    execute 'set local role authenticated';
    select * into strict v_replayed from public.accept_groomer_offer(v_offer);
    if v_replayed.booking_id is distinct from v_accepted.booking_id
      or v_replayed.booking_status <> 'confirmed' then
      raise exception 'legacy_accepted_quote_failed_original_receipt_replay';
    end if;
    perform public.cancel_booking(v_accepted.booking_id);
    select * into strict v_replayed from public.accept_groomer_offer(v_offer);
    if v_replayed.booking_id is distinct from v_accepted.booking_id
      or v_replayed.booking_status <> 'cancelled_by_customer' then
      raise exception 'legacy_cancelled_quote_replay_reactivated_booking';
    end if;
    execute 'reset role';
    if not exists(select 1 from public.bookings where id=v_accepted.booking_id
        and applied_timing_buffers is null and service_time_zone_identifier is null
        and schedule_time_zone_identifier is null and occupied_start is null and occupied_end is null
        and scheduled_start='2026-11-02T04:00:00Z'::timestamptz
        and scheduled_end='2026-11-02T05:00:00Z'::timestamptz) then
      raise exception 'legacy_replay_or_cancellation_rewrote_timing';
    end if;
    raise exception using errcode='ZX374',message='legacy_receipt_fixture_complete';
  exception when sqlstate 'ZX374' then
    if sqlerrm <> 'legacy_receipt_fixture_complete' then raise; end if;
  end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_groomer,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  perform public.withdraw_groomer_offer(v_offer);
  execute 'reset role';
  if not exists(select 1 from public.groomer_offers where id=v_offer and status='withdrawn_by_groomer'
      and applied_timing_buffers is null and occupied_start is null and occupied_end is null) then
    raise exception 'legacy_withdrawal_rewrote_or_lost_original_offer';
  end if;
  execute 'set local role authenticated';
  select * into strict v_created from public.create_groomer_offer(v_request,
    '2026-11-02T04:00:00Z','2026-11-02T05:00:00Z',100,null);
  if v_created.offer_id=v_offer then raise exception 'replacement_reused_legacy_offer_identity'; end if;
  execute 'reset role';
  begin
    -- The quote remains pending, but newly added time off covers cleanup only.
    insert into public.groomer_time_off_windows(id,groomer_id,title,start_date,end_date)
      values(v_time_off,v_groomer,'T-374 after quote','2026-11-02','2026-11-02');
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
      'role','authenticated','is_anonymous',false)::text,true);
    execute 'set local role authenticated';
    perform public.accept_groomer_offer(v_created.offer_id);
    raise exception 'acceptance_ignored_time_off_added_after_quote';
  exception when sqlstate '22023' then
    if sqlerrm <> 'occupied_time_off_conflict' then raise; end if;
  end;
  if exists(select 1 from public.bookings where offer_id=v_created.offer_id)
    or not exists(select 1 from public.groomer_offers where id=v_created.offer_id and status='pending') then
    raise exception 'rejected_changed_schedule_acceptance_left_partial_state';
  end if;
  begin
    -- Service ends at midnight, but the retained cleanup ends ten minutes later.
    update public.groomer_availability_windows set start_time='00:10'
      where groomer_id=v_groomer;
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
      'role','authenticated','is_anonymous',false)::text,true);
    execute 'set local role authenticated';
    perform public.accept_groomer_offer(v_created.offer_id);
    raise exception 'acceptance_ignored_hours_changed_after_quote';
  exception when sqlstate '22023' then
    if sqlerrm <> 'occupied_outside_weekly_hours' then raise; end if;
  end;
  if exists(select 1 from public.bookings where offer_id=v_created.offer_id)
    or not exists(select 1 from public.groomer_offers where id=v_created.offer_id and status='pending')
    or not exists(select 1 from public.grooming_requests where id=v_request and status='has_offers') then
    raise exception 'rejected_changed_hours_acceptance_left_partial_state';
  end if;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
    'role','authenticated','is_anonymous',false)::text,true);
  select * into strict v_accepted from public.accept_groomer_offer(v_created.offer_id);
  select * into strict v_replayed from public.accept_groomer_offer(v_created.offer_id);
  if v_accepted.booking_id is distinct from v_replayed.booking_id then
    raise exception 'timed_acceptance_replay_changed_receipt';
  end if;
  execute 'reset role';
  if not exists(select 1 from public.bookings where id=v_accepted.booking_id
      and scheduled_end='2026-11-02T05:00:00Z'::timestamptz
      and occupied_start='2026-11-02T03:45:00Z'::timestamptz
      and occupied_end='2026-11-02T05:10:00Z'::timestamptz) then
    raise exception 'midnight_rpc_acceptance_lost_snapshot';
  end if;
  -- Later settings fixtures must not inherit this new accepted commitment.
  delete from public.grooming_requests where id=v_request;
end $$;
select 'T-374 customer travel, destination zone and midnight rollback passed' as result;

do $$
declare v_groomer uuid; v_time_off uuid; v_case record;
begin
  select id into strict v_groomer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  update public.groomer_availability_windows set timezone='America/Los_Angeles' where groomer_id=v_groomer;
  for v_case in select * from (values
    ('2026-03-08'::date,'2026-03-08T08:00:00Z'::timestamptz,'2026-03-09T07:00:00Z'::timestamptz),
    ('2026-11-01'::date,'2026-11-01T07:00:00Z'::timestamptz,'2026-11-02T08:00:00Z'::timestamptz)
  ) cases(day,starts,ends) loop
    insert into public.groomer_time_off_windows(groomer_id,title,start_date,end_date)
      values(v_groomer,'T-374 DST boundary',v_case.day,v_case.day) returning id into v_time_off;
    if not app_private.occupied_time_off_conflict(v_groomer,v_case.starts,v_case.starts+interval '1 microsecond')
      or not app_private.occupied_time_off_conflict(v_groomer,v_case.ends-interval '1 microsecond',v_case.ends)
      or app_private.occupied_time_off_conflict(v_groomer,v_case.starts-interval '1 hour',v_case.starts)
      or app_private.occupied_time_off_conflict(v_groomer,v_case.ends,v_case.ends+interval '1 hour') then
      raise exception 'time_off_dst_or_half_open_boundary_mismatch';
    end if;
    delete from public.groomer_time_off_windows where id=v_time_off;
  end loop;
end $$;
select 'T-374 DST time-off half-open boundaries passed' as result;
