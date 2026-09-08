-- Execute inside an explicitly authorized transaction and always ROLLBACK.
-- Only named TestOps accounts are used. This is not a concurrent-session test.
do $$
declare
  v_customer uuid;
  v_groomer uuid;
  v_other_groomer uuid;
  v_pet uuid;
  v_requests uuid[] := array[gen_random_uuid(),gen_random_uuid()];
  v_offers uuid[] := array[gen_random_uuid(),gen_random_uuid()];
  v_match uuid;
  v_g uuid;
  v_i integer;
  v_start timestamptz := '2099-01-05 18:00:00+00';
  v_first record;
  v_replay record;
  v_count integer;
  v_message_count integer;
begin
  select id into strict v_customer from auth.users
    where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict v_groomer from auth.users
    where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict v_other_groomer from auth.users
    where raw_app_meta_data->>'beckon_seed_id'='BTG-002';
  select id into strict v_pet from public.pets where customer_id=v_customer order by id limit 1;
  perform set_config('app.availability_batch','1',true);
  foreach v_g in array array[v_groomer,v_other_groomer] loop
    insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
    select v_g,d,'08:00'::time,'20:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
    on conflict(groomer_id,weekday) do update
      set start_time=excluded.start_time,end_time=excluded.end_time,is_enabled=true,timezone=excluded.timezone;
    insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days)
    values(v_g,12,0) on conflict(groomer_id) do update
      set max_appointments_per_day=12,minimum_advance_notice_days=0;
  end loop;
  perform set_config('app.availability_batch','',true);
  for v_i in 1..2 loop
    v_g := case when v_i=1 then v_groomer else v_other_groomer end;
    v_match := gen_random_uuid();
    insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,
      service_type,preferred_start,preferred_end,city,state,zip_code,street_address,
      location_mode,status,expires_at)
    values(v_requests[v_i],v_customer,v_pet,'{}','[]','full_groom',v_start,v_start+interval '1 hour',
      'Fullerton','CA','92832','770 S Harbor Blvd','groomer_comes_to_customer','has_offers',now()+interval '1 day');
    insert into public.request_matches(id,request_id,groomer_id,customer_id,status)
    values(v_match,v_requests[v_i],v_g,v_customer,'offered');
    insert into public.groomer_offers(id,request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
    values(v_offers[v_i],v_requests[v_i],v_match,v_customer,v_g,v_start,v_start+interval '1 hour',100,'pending',now()+interval '1 day');
  end loop;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  select * into strict v_first from public.accept_groomer_offer(v_offers[1]);
  if v_first.booking_status <> 'confirmed' then raise exception 'first acceptance failed'; end if;
  execute 'reset role';
  begin
    insert into public.bookings(request_id,offer_id,customer_id,groomer_id,
      scheduled_start,scheduled_end,price_estimate,status)
    values(v_requests[2],v_offers[2],v_customer,v_other_groomer,
      v_start,v_start+interval '1 hour',100,'confirmed');
    raise exception 'direct writer bypassed pet exclusion';
  exception when exclusion_violation then null;
  end;
  begin
    update public.bookings set scheduled_start=scheduled_start+interval '1 day',
      scheduled_end=scheduled_end+interval '1 day' where id=v_first.booking_id;
    raise exception 'direct writer changed an admitted allocation';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'booking_allocation_immutable' then raise; end if;
  end;
  execute 'set local role authenticated';
  begin
    update public.bookings set price_estimate=101 where id=v_first.booking_id;
    raise exception 'authenticated caller can bypass booking RPCs';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.accept_groomer_offer(v_offers[2]);
    raise exception 'same pet accepted with overlapping second groomer';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'booking_conflict' then raise; end if;
  end;
  select count(*) into v_message_count from public.messages where conversation_id=v_first.conversation_id;
  select * into strict v_replay from public.accept_groomer_offer(v_offers[1]);
  if v_replay.booking_id <> v_first.booking_id or v_replay.conversation_id <> v_first.conversation_id then
    raise exception 'replay changed receipt identity';
  end if;
  select count(*) into v_count from public.messages where conversation_id=v_first.conversation_id;
  if v_count <> v_message_count then raise exception 'replay duplicated messages'; end if;
  select count(*) into v_count from public.get_offer_acceptance(v_offers[2]);
  if v_count <> 0 then raise exception 'lookup created or invented acceptance'; end if;
  perform public.cancel_booking(v_first.booking_id);
  select * into strict v_replay from public.accept_groomer_offer(v_offers[1]);
  if v_replay.booking_id <> v_first.booking_id or v_replay.booking_status <> 'cancelled_by_customer' then
    raise exception 'replay resurrected cancelled booking';
  end if;
  select * into strict v_replay from public.get_offer_acceptance(v_offers[1]);
  if v_replay.booking_status <> 'cancelled_by_customer' then raise exception 'lookup returned stale state'; end if;
  select * into strict v_replay from public.accept_groomer_offer(v_offers[2]);
  if v_replay.booking_status <> 'confirmed' then raise exception 'cancellation did not release pet capacity'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_other_groomer,
    'role','authenticated','is_anonymous',false)::text,true);
  perform public.complete_booking(v_replay.booking_id);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
    'role','authenticated','is_anonymous',false)::text,true);
  select * into strict v_replay from public.accept_groomer_offer(v_offers[2]);
  if v_replay.booking_status <> 'completed' then raise exception 'replay resurrected completed booking'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
    'role','authenticated','is_anonymous',true)::text,true);
  begin
    perform public.get_offer_acceptance(v_offers[1]);
    raise exception 'anonymous account read acceptance';
  exception when sqlstate '28000' then null;
  end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_groomer,
    'role','authenticated','is_anonymous',false)::text,true);
  begin
    perform public.get_offer_acceptance(v_offers[1]);
    raise exception 'foreign owner read acceptance receipt';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'offer_not_found' then raise; end if;
  end;
  execute 'reset role';
end;
$$;
