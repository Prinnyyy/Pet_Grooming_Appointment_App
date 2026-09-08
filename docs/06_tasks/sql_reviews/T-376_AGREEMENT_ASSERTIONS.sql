-- Caller owns BEGIN/ROLLBACK. No persistent fixtures or queue cleanup.
do $$
declare c uuid; pet uuid; request uuid:=gen_random_uuid();
begin
  select id into strict c from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict pet from public.pets where customer_id=c and is_active and deleted_at is null order by id limit 1;
  insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,service_type,
    preferred_start,preferred_end,city,state,zip_code,street_address,location_mode,status,expires_at,
    preference_time_zone_identifier)
  values(request,c,pet,jsonb_build_object('id',pet,'name','T376','species','Dog'),'[]','full_groom',
    statement_timestamp()+interval '10 days',statement_timestamp()+interval '10 days 3 hours',
    'Seattle','WA','98101','10 Original Street','groomer_comes_to_customer','open',
    statement_timestamp()+interval '1 day','America/Los_Angeles');
  begin
    update public.grooming_requests set service_type='nail_trim' where id=request;
    raise exception 'T-376 critical request terms changed in place';
  exception when check_violation then
    if sqlerrm<>'published_request_terms_are_immutable' then raise; end if;
  end;
  begin
    update public.grooming_requests set address_line_2='Unit 5' where id=request;
    raise exception 'T-376 agreed unit address changed in place';
  exception when check_violation then
    if sqlerrm<>'published_request_terms_are_immutable' then raise; end if;
  end;
end $$;

do $$
declare c uuid; g uuid; pet uuid; address uuid:=gen_random_uuid(); request uuid; offer uuid; booked uuid;
  direction text; starts timestamptz:=timezone('America/Los_Angeles',
    (timezone('America/Los_Angeles',statement_timestamp())::date+10)+time '09:00');
  snapshot jsonb; old_snapshot jsonb; evaluation jsonb; replacement uuid; operation uuid; payload jsonb; revision uuid;
begin
  select id into strict c from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict g from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict pet from public.pets where customer_id=c and is_active and deleted_at is null order by id limit 1;
  if exists(select 1 from public.bookings where groomer_id=g and status in ('confirmed','completed')) then
    raise exception 'T-376 requires idle named groomer';
  end if;
  perform set_config('app.availability_batch','1',true);
  update public.groomer_profiles set service_location_modes=array['groomer_comes_to_customer','customer_comes_to_groomer'],
    base_street_address='10 Original Street',base_address_line_2='Unit 4B' where user_id=g;
  update app_private.address_locations set time_zone_identifier='America/Los_Angeles'
    where id=(select address_location_id from public.groomer_profiles where user_id=g);
  insert into app_private.address_locations(id,owner_id,provider,country_code,latitude,longitude,
    resolution_source,user_confirmed_at,time_zone_identifier)
  select address,c,'apple_maps','US',a.latitude,a.longitude,'manual_geocode',statement_timestamp(),'America/Los_Angeles'
    from public.groomer_profiles p join app_private.address_locations a on a.id=p.address_location_id where p.user_id=g;
  insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days,timing_buffers)
    values(g,4,0,'{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}')
    on conflict(groomer_id) do update set max_appointments_per_day=4,minimum_advance_notice_days=0,timing_buffers=excluded.timing_buffers;
  insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
    select g,d,'08:00'::time,'18:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
    on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
      is_enabled=true,timezone=excluded.timezone;
  delete from public.groomer_time_off_windows where groomer_id=g;
  update public.groomer_services set accepted_pet_sizes='{}',duration_minutes=60,is_active=true
    where groomer_id=g and service_type='full_groom';
  foreach direction in array array['groomer_comes_to_customer','customer_comes_to_groomer'] loop
    request:=gen_random_uuid();
    insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,service_type,
      preferred_start,preferred_end,city,state,zip_code,street_address,address_line_2,location_mode,
      travel_radius_miles,status,expires_at,preference_time_zone_identifier,address_location_id)
    values(request,c,pet,jsonb_build_object('id',pet,'name','T376','species','Dog'),'[]','full_groom',
      starts,starts+interval '3 hours','Seattle','WA','98101','10 Original Street','Unit 4B',direction,
      case when direction='customer_comes_to_groomer' then 100 end,'open',
      statement_timestamp()+interval '1 day','America/Los_Angeles',address);
    perform app_private.create_request_matches_for_request(request,g);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',g,'role','authenticated','is_anonymous',false)::text,true);
    select terms_revision into strict revision from public.grooming_requests where id=request;
    execute 'set local role authenticated';
    select offer_id into strict offer from public.create_groomer_offer_v2(request,
      revision,starts,starts+interval '1 hour',125,null);
    if (select count(*) from public.get_quote_evaluations(array[offer]))<>1 then
      raise exception 'T-376 owned quote evaluation missing';
    end if;
    begin
      perform app_private.evaluate_quote(offer);
      raise exception 'T-376 private evaluator exposed';
    exception when insufficient_privilege then null;
    end;
    execute 'reset role';
    select agreement_snapshot into strict snapshot from public.groomer_offers where id=offer;
    evaluation:=app_private.evaluate_quote(offer,statement_timestamp());
    if evaluation->>'terms_valid' is distinct from 'true' or evaluation->>'selectable' is distinct from 'true' then
      raise exception 'T-376 new quote not selectable: %',evaluation;
    end if;
    evaluation:=app_private.evaluate_quote(offer,starts);
    if evaluation->>'terms_valid' is distinct from 'false' or evaluation->>'reason' is distinct from 'expired' then
      raise exception 'T-376 deadline depends on expiry worker: %',evaluation;
    end if;
    begin
      update public.groomer_booking_preferences set minimum_advance_notice_days=2 where groomer_id=g;
      update public.groomer_booking_preferences set minimum_advance_notice_days=0 where groomer_id=g;
      evaluation:=app_private.evaluate_quote(offer,statement_timestamp());
      if evaluation->>'terms_valid' is distinct from 'false' then
        raise exception 'T-376 changed notice policy revived old quote';
      end if;
      update public.groomer_profiles set eligibility_revision=(snapshot->>'groomer_eligibility_revision')::uuid
        where user_id=g;
      if (select eligibility_revision::text from public.groomer_profiles where user_id=g)
        =snapshot->>'groomer_eligibility_revision' then
        raise exception 'T-376 explicit revision assignment revived revoked consent';
      end if;
      raise exception using errcode='ZX001',message='restore notice policy subcase';
    exception when sqlstate 'ZX001' then null;
    end;
    begin
      delete from public.groomer_booking_preferences where groomer_id=g;
      evaluation:=app_private.evaluate_quote(offer,statement_timestamp());
      if evaluation->>'selectable' is distinct from 'true' then
        raise exception 'T-376 absent optional preferences do not use admission defaults';
      end if;
      delete from public.groomer_availability_windows where groomer_id=g;
      evaluation:=app_private.evaluate_quote(offer,statement_timestamp());
      if evaluation->>'selectable' is distinct from 'false' then
        raise exception 'T-376 incomplete schedule remained selectable';
      end if;
      raise exception using errcode='ZX001',message='restore missing schedule subcase';
    exception when sqlstate 'ZX001' then null;
    end;
    begin
      insert into public.groomer_time_off_windows(groomer_id,title,start_date,end_date)
        values(g,'T376 rollback',timezone('America/Los_Angeles',starts)::date,timezone('America/Los_Angeles',starts)::date);
      evaluation:=app_private.evaluate_quote(offer,statement_timestamp());
      if evaluation->>'terms_valid' is distinct from 'true' or evaluation->>'selectable' is distinct from 'false' then
        raise exception 'T-376 capacity collision destroyed terms: %',evaluation;
      end if;
      delete from public.groomer_time_off_windows where groomer_id=g;
      evaluation:=app_private.evaluate_quote(offer,statement_timestamp());
      if evaluation->>'selectable' is distinct from 'true' then raise exception 'T-376 slot did not recover'; end if;
      update public.groomer_services set is_active=false where groomer_id=g and service_type='full_groom';
      update public.groomer_services set is_active=true where groomer_id=g and service_type='full_groom';
      evaluation:=app_private.evaluate_quote(offer,statement_timestamp());
      if evaluation->>'terms_valid' is distinct from 'false' then raise exception 'T-376 revoked eligibility revived old consent'; end if;
      raise exception using errcode='ZX001',message='restore eligibility subcase';
    exception when sqlstate 'ZX001' then null;
    end;
    if snapshot->'address'->>'address_line_2' is distinct from 'Unit 4B'
      or snapshot->>'service_time_zone_identifier' is distinct from 'America/Los_Angeles'
      or snapshot->>'request_revision' is distinct from (select terms_revision::text from public.grooming_requests where id=request)
      or snapshot->>'source' is distinct from 'quote_creation' then
      raise exception 'T-376 incomplete quote snapshot';
    end if;
    begin
      update public.groomer_offers set price_estimate=126 where id=offer;
      raise exception 'T-376 quote price changed in place';
    exception when check_violation then
      if sqlerrm<>'quote_terms_are_immutable' then raise; end if;
    end;
    begin
      operation:=gen_random_uuid();
      select jsonb_build_object('pet_id',pet,'service_type','nail_trim','preferred_start',starts,
        'preferred_end',starts+interval '3 hours','location_mode',direction,
        'travel_radius_miles',case when direction='customer_comes_to_groomer' then 100 end,
        'street_address','20 Replacement Street','address_line_2','Unit 2','city','Seattle','state','WA','zip_code','98101',
        'provider','apple_maps','country_code','US','latitude',latitude,'longitude',longitude,
        'resolution_source','manual_geocode','user_confirmed_at',statement_timestamp()) into payload
        from app_private.address_locations where id=address;
      perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
      execute 'set local role authenticated';
      begin
        perform public.supersede_grooming_request(request,(snapshot->>'request_revision')::uuid,
          operation,payload || '{"service_type":"invalid_service"}'::jsonb,'America/Los_Angeles');
        raise exception 'T-376 invalid replacement succeeded';
      exception when invalid_parameter_value then
        if sqlerrm<>'invalid_service_type' then raise; end if;
      end;
      if (select status from public.grooming_requests where id=request) not in ('open','has_offers')
        or (select status from public.groomer_offers where id=offer)<>'pending'
        or exists(select 1 from public.grooming_requests where supersedes_request_id=request) then
        raise exception 'T-376 failed replacement altered original agreement';
      end if;
      select request_id into strict replacement from public.supersede_grooming_request(request,
        (snapshot->>'request_revision')::uuid,operation,payload,'America/Los_Angeles');
      if (select status from public.grooming_requests where id=request)<>'cancelled'
        or (select supersedes_request_id from public.grooming_requests where id=replacement) is distinct from request
        or (select status from public.groomer_offers where id=offer)<>'declined_by_customer' then
        raise exception 'T-376 supersession not atomic';
      end if;
      if (select request_id from public.supersede_grooming_request(request,
        (snapshot->>'request_revision')::uuid,operation,payload,'America/Los_Angeles')) is distinct from replacement then
        raise exception 'T-376 supersession replay duplicated publication';
      end if;
      begin
        perform public.accept_groomer_offer_v2(offer,(snapshot->>'quote_revision')::uuid);
        raise exception 'T-376 superseded quote accepted';
      exception when raise_exception then
        if sqlerrm<>'offer_not_pending' then raise; end if;
      end;
      execute 'reset role';
      raise exception using errcode='ZX001',message='restore supersession subcase';
    exception when sqlstate 'ZX001' then null;
    end;
    perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
    begin
      perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated','is_anonymous',false)::text,true);
      execute 'set local role authenticated';
      if (select count(*) from public.get_quote_evaluations(array[offer]))<>0 then
        raise exception 'T-376 quote evaluation leaked to unrelated actor';
      end if;
      begin
        perform public.accept_groomer_offer_v2(offer,(snapshot->>'quote_revision')::uuid);
        raise exception 'T-376 unrelated actor accepted quote';
      exception when raise_exception then if sqlerrm<>'offer_not_found' then raise; end if;
      end;
      raise exception using errcode='ZX001',message='restore actor';
    exception when sqlstate 'ZX001' then null;
    end;
    execute 'set local role authenticated';
    begin
      perform public.accept_groomer_offer_v2(offer,gen_random_uuid());
      raise exception 'T-376 stale displayed quote revision accepted';
    exception when invalid_parameter_value then
      if sqlerrm<>'quote_revision_changed' then raise; end if;
    end;
    select booking_id into strict booked from public.accept_groomer_offer_v2(offer,
      (snapshot->>'quote_revision')::uuid);
    execute 'reset role';
    select agreement_snapshot into strict old_snapshot from public.bookings where id=booked;
    if old_snapshot is distinct from snapshot then raise exception 'T-376 accepted terms changed'; end if;
    update public.groomer_profiles set base_street_address='99 Current Profile Street',base_address_line_2='Unit 9' where user_id=g;
    if (select agreement_snapshot from public.bookings where id=booked) is distinct from old_snapshot then
      raise exception 'T-376 profile edit rewrote historical agreement';
    end if;
    begin
      update public.bookings set price_estimate=126 where id=booked;
      raise exception 'T-376 booked price changed';
    exception when check_violation then
      if sqlerrm<>'booking_agreement_is_immutable' then raise; end if;
    end;
    update public.groomer_profiles set base_street_address='10 Original Street',base_address_line_2='Unit 4B' where user_id=g;
    starts:=starts+interval '1 day';
  end loop;
  delete from app_private.address_locations where id=address and owner_id=c;
  if (select agreement_snapshot from public.bookings where id=booked) is distinct from old_snapshot then
    raise exception 'T-376 source cleanup destroyed accepted snapshot';
  end if;
end $$;
