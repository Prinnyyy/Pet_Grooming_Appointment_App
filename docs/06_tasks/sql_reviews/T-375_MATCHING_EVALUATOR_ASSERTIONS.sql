-- Caller owns BEGIN/ROLLBACK. Only named TestOps owners are temporarily changed.
do $$
declare
  c uuid; g uuid; pet uuid; address uuid := gen_random_uuid(); request uuid := gen_random_uuid();
  off_id uuid := gen_random_uuid(); result jsonb; match uuid; offer uuid;
  operation uuid:=gen_random_uuid(); published uuid; published_count integer;
  replayed uuid; replay_count integer; payload jsonb;
  booking_request uuid; booking_match uuid; slot timestamptz; minutes integer; scenario integer; n integer;
  new_groomers uuid[]; new_groomer uuid; new_address uuid;
  drained integer;
  starts timestamptz := timezone('America/Los_Angeles',
    (timezone('America/Los_Angeles',statement_timestamp())::date+10)+time '09:00');
begin
  select id into strict c from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict g from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict pet from public.pets where customer_id=c and is_active and deleted_at is null order by id limit 1;
  if exists(select 1 from public.bookings where groomer_id=g and status in ('confirmed','completed')) then
    raise exception 'T-375 requires idle named groomer fixture';
  end if;
  perform set_config('app.availability_batch','1',true);
  update public.groomer_profiles set service_location_modes=array['groomer_comes_to_customer'] where user_id=g;
  insert into app_private.address_locations(id,owner_id,provider,country_code,latitude,longitude,
    resolution_source,user_confirmed_at,time_zone_identifier)
  select address,c,'apple_maps','US',a.latitude,a.longitude,'manual_geocode',statement_timestamp(),'America/Los_Angeles'
    from public.groomer_profiles p join app_private.address_locations a on a.id=p.address_location_id and a.owner_id=g
    where p.user_id=g;
  if not found then raise exception 'T-375 requires coordinate-backed groomer fixture'; end if;
  insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days,timing_buffers)
    values(g,4,0,'{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}')
    on conflict(groomer_id) do update set max_appointments_per_day=4,minimum_advance_notice_days=0,timing_buffers=excluded.timing_buffers;
  insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
    select g,d,'08:00'::time,'13:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
    on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
      is_enabled=true,timezone=excluded.timezone;
  delete from public.groomer_time_off_windows where groomer_id=g;
  update public.groomer_services set accepted_pet_sizes=array['M'],duration_minutes=60,is_active=true
    where groomer_id=g and service_type='full_groom';
  if not found then raise exception 'T-375 requires full-groom service fixture'; end if;
  insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,service_type,
    preferred_start,preferred_end,city,state,zip_code,street_address,location_mode,status,expires_at,
    preference_time_zone_identifier,address_location_id)
    values(request,c,pet,jsonb_build_object('id',pet,'size','M','species','Dog'),'[]','full_groom',
      starts,starts+interval '3 hours','Fullerton','CA','92832','T375 rollback fixture',
      'groomer_comes_to_customer','open',statement_timestamp()+interval '1 day','America/Los_Angeles',address);
  result := app_private.evaluate_match_eligibility(request,g,statement_timestamp());
  if result->>'state' is distinct from 'estimated_fit'
    or (result->>'service_start')::timestamptz is distinct from starts
    or (result->>'service_end')::timestamptz is distinct from starts+interval '1 hour' then
    raise exception 'T-375 known duration in broad preference: %',result;
  end if;
  perform app_private.create_request_matches_for_request(request,g);
  if not exists(select 1 from public.request_matches m where m.request_id=request and m.groomer_id=g
    and m.status='visible' and m.match_reason like '%Estimated opening within your preferred window%') then
    raise exception 'T-375 matcher did not use interval evaluation';
  end if;
  select id into strict match from public.request_matches where request_id=request and groomer_id=g;
  begin
    update public.groomer_services set accepted_pet_sizes=array['XS','S','M','L','XL','XXL','Giant']
      where groomer_id=g and service_type='full_groom';
    select jsonb_build_object('pet_id',pet,'service_type','full_groom',
      'preferred_start',starts,'preferred_end',starts+interval '3 hours',
      'location_mode','groomer_comes_to_customer','street_address','T375 authenticated rollback',
      'city','Fullerton','state','CA','zip_code','92832','provider','apple_maps','country_code','US',
      'latitude',latitude,'longitude',longitude,'resolution_source','manual_geocode',
      'user_confirmed_at',statement_timestamp()) into payload
      from app_private.address_locations where id=address and owner_id=c;
    perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
    execute 'set local role authenticated';
    select request_id,match_count into strict published,published_count
      from public.create_grooming_request_v4(operation,payload,'America/Los_Angeles');
    select request_id,match_count into strict replayed,replay_count
      from public.create_grooming_request_v4(operation,payload,'America/Los_Angeles');
    execute 'reset role';
    if published<>replayed or published_count<>replay_count or published_count<1
      or published_count<>(select count(*) from public.request_matches m where m.request_id=published
        and m.status in ('visible','viewed','offered'))
      or not exists(select 1 from public.request_matches m where m.request_id=published and m.groomer_id=g)
      or not exists(select 1 from app_private.request_publish_operations o where o.operation_id=operation
        and o.customer_id=c and o.match_count=published_count) then
      raise exception 'T-375 v4 matching count or original receipt was incoherent';
    end if;
    raise exception using errcode='Z3750',message='rollback successful publication fixture';
  exception when sqlstate 'Z3750' then null;
  end;
  insert into app_private.match_refresh_queue(request_id,groomer_id) values(request,g);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',g,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  select m.eligibility_evaluation into strict result from public.get_my_matched_requests(g,100,0) m where m.id=match;
  if result->>'state' is distinct from 'pending' then raise exception 'T-375 reader exposed stale fit'; end if;
  begin
    perform * from public.get_my_matched_requests(c,100,0);
    raise exception 'T-375 reader accepted another owner';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from app_private.match_refresh_queue;
    raise exception 'T-375 private queue exposed to authenticated client';
  exception when insufficient_privilege then null;
  end;
  begin
    perform app_private.evaluate_match_eligibility(request,g,statement_timestamp());
    raise exception 'T-375 internal evaluator exposed to authenticated client';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';
  delete from app_private.match_refresh_queue where request_id=request and groomer_id=g;
  begin
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
      values(request,match,c,g,starts,starts+interval '30 minutes',100,'pending',
        statement_timestamp()+interval '1 day') returning id into offer;
    update public.groomer_services set accepted_pet_sizes=array['S'] where groomer_id=g and service_type='full_groom';
    begin
      insert into public.bookings(request_id,offer_id,customer_id,groomer_id,
        scheduled_start,scheduled_end,price_estimate,status)
        values(request,offer,c,g,starts,starts+interval '30 minutes',100,'confirmed');
      raise exception 'T-375 stale explicit size accepted by booking writer';
    exception when sqlstate '22023' then
      if sqlerrm<>'match_constraints_changed' then raise; end if;
    end;
    raise exception using errcode='Z3750',message='rollback successful writer fixture';
  exception when sqlstate 'Z3750' then null;
  end;
  for scenario in 1..2 loop
    begin
      for n in 1..case when scenario=1 then 1 else 3 end loop
        booking_request:=gen_random_uuid();
        insert into public.grooming_requests
          select (jsonb_populate_record(null::public.grooming_requests,
            to_jsonb(r)||jsonb_build_object('id',booking_request))).*
            from public.grooming_requests r where r.id=request;
        perform app_private.create_request_matches_for_request(booking_request,g);
        select id into strict booking_match from public.request_matches where request_id=booking_request and groomer_id=g;
        slot:=starts+make_interval(hours=>n-1);
        minutes:=case when scenario=1 then 180 else 40 end;
        insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
          proposed_start,proposed_end,price_estimate,status,expires_at)
          values(booking_request,booking_match,c,g,slot,slot+make_interval(mins=>minutes),100,'pending',
            statement_timestamp()+interval '1 day') returning id into offer;
        insert into public.bookings(request_id,offer_id,customer_id,groomer_id,
          scheduled_start,scheduled_end,price_estimate,status)
          values(booking_request,offer,c,g,slot,slot+make_interval(mins=>minutes),100,'confirmed');
        update public.grooming_requests set status='booked' where id=booking_request;
      end loop;
      if (select count(*) from public.bookings where groomer_id=g and status='confirmed')>=4 then
        raise exception 'T-375 occupied fixture accidentally reached the quota';
      end if;
      result:=app_private.evaluate_match_eligibility(request,g,statement_timestamp());
      if result->>'state' is distinct from 'excluded' or result->>'reason' is distinct from 'no_continuous_opening' then
        raise exception 'T-375 occupied/fragmented booking scenario % falsely matched: %',scenario,result;
      end if;
      if to_regprocedure('app_private.t375_baseline_matcher(uuid,uuid)') is not null then
        delete from public.request_matches where request_id=request and groomer_id=g;
        drained:=app_private.t375_baseline_matcher(request,g);
        if drained<>1 then raise exception 'T-375 baseline did not reproduce occupied scenario %',scenario; end if;
        perform app_private.refresh_request_match(request,g);
        if exists(select 1 from public.request_matches m where m.request_id=request and m.groomer_id=g
          and m.status in ('visible','viewed')) then
          raise exception 'T-375 revised refresh retained the baseline false-positive';
        end if;
      end if;
      raise exception using errcode='Z3750',message='rollback successful occupied fixture';
    exception when sqlstate 'Z3750' then null;
    end;
  end loop;
  begin
    select array_agg(id order by raw_app_meta_data->>'beckon_seed_id') into new_groomers
      from auth.users where raw_app_meta_data->>'beckon_seed_id' in ('BTG-002','BTG-003');
    if cardinality(new_groomers) is distinct from 2 then raise exception 'T-375 new-groomer fixtures missing'; end if;
    foreach new_groomer in array new_groomers loop
      if exists(select 1 from public.bookings where groomer_id=new_groomer and status in ('confirmed','completed'))
        or exists(select 1 from public.groomer_pet_fit_evidence_summary where groomer_id=new_groomer
          and (completed_booking_count>0 or structured_review_outcome_count>0)) then
        raise exception 'T-375 exposure fixture is no longer an idle new groomer';
      end if;
      new_address:=gen_random_uuid();
      insert into app_private.address_locations(id,owner_id,provider,country_code,latitude,longitude,
        resolution_source,user_confirmed_at,time_zone_identifier)
        select new_address,new_groomer,'apple_maps','US',latitude,longitude,'manual_geocode',
          statement_timestamp(),'America/Los_Angeles' from app_private.address_locations where id=address;
      update public.groomer_profiles set is_active=true,address_location_id=new_address,service_radius_miles=12,
        service_location_modes=array['groomer_comes_to_customer'] where user_id=new_groomer;
      insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days,timing_buffers)
        values(new_groomer,4,0,'{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}')
        on conflict(groomer_id) do update set max_appointments_per_day=4,minimum_advance_notice_days=0,timing_buffers=excluded.timing_buffers;
      insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
        select new_groomer,d,'08:00'::time,'13:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
        on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
          is_enabled=true,timezone=excluded.timezone;
      delete from public.groomer_time_off_windows where groomer_id=new_groomer;
      update public.groomer_services set is_active=true,duration_minutes=60,accepted_pet_sizes=array['M']
        where groomer_id=new_groomer and service_type='full_groom';
      if not found then
        insert into public.groomer_services
          select (jsonb_populate_record(null::public.groomer_services,
            to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'groomer_id',new_groomer))).*
            from public.groomer_services s where s.groomer_id=g and s.service_type='full_groom' limit 1;
      end if;
      update public.groomer_fit_claims set is_active=false where groomer_id=new_groomer;
      delete from public.groomer_portfolio_fit_tags where groomer_id=new_groomer;
      perform app_private.create_request_matches_for_request(request,new_groomer);
    end loop;
    if (select count(*) from public.request_matches m where m.request_id=request and m.groomer_id=any(new_groomers)
      and m.status='visible' and m.eligibility_evaluation->>'state'='estimated_fit')<>2
      or (select count(distinct match_score) from public.request_matches m
        where m.request_id=request and m.groomer_id=any(new_groomers))<>1 then
      raise exception 'T-375 equal eligible new groomers did not receive equal-score exposure';
    end if;
    raise exception using errcode='Z3750',message='rollback successful exposure fixture';
  exception when sqlstate 'Z3750' then null;
  end;
  begin
    if exists(select 1 from public.groomer_services where groomer_id=g and service_type='custom_request') then
      update public.groomer_services set is_active=true,accepted_pet_sizes=array['M'],duration_minutes=60
        where groomer_id=g and service_type='custom_request';
    else
      insert into public.groomer_services
        select (jsonb_populate_record(null::public.groomer_services,
          to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'service_type','custom_request'))).*
          from public.groomer_services s where s.groomer_id=g and s.service_type='full_groom' limit 1;
    end if;
    update public.grooming_requests set service_type='custom_request',service_notes='T375 custom assessment'
      where id=request;
    result:=app_private.evaluate_match_eligibility(request,g,statement_timestamp());
    if result->>'state' is distinct from 'assessment_required' then
      raise exception 'T-375 custom duration was presented as known fit: %',result;
    end if;
    raise exception using errcode='Z3750',message='rollback successful custom fixture';
  exception when sqlstate 'Z3750' then null;
  end;
  begin
    delete from public.groomer_booking_preferences where groomer_id=g;
    result:=app_private.evaluate_match_eligibility(request,g,statement_timestamp());
    if result->>'state' is distinct from 'assessment_required' then
      raise exception 'T-375 missing preferences became confirmed fit or automatic rejection';
    end if;
    update public.groomer_availability_windows set is_enabled=false where groomer_id=g;
    result:=app_private.evaluate_match_eligibility(request,g,statement_timestamp());
    if result->>'state' is distinct from 'excluded' then
      raise exception 'T-375 unknown preferences overrode explicit closure';
    end if;
    raise exception using errcode='Z3750',message='rollback successful unknown preferences fixture';
  exception when sqlstate 'Z3750' then null;
  end;
  update public.request_matches set status='dismissed',dismissed_at=statement_timestamp()
    where request_id=request and groomer_id=g;
  perform app_private.create_request_matches_for_request(request,g);
  if not exists(select 1 from public.request_matches m where m.request_id=request and m.groomer_id=g
    and m.status='dismissed') then raise exception 'T-375 deliberate dismissal was overwritten'; end if;
  update public.groomer_services set accepted_pet_sizes=array['S'] where groomer_id=g and service_type='full_groom';
  result := app_private.evaluate_match_eligibility(request,g,statement_timestamp());
  if result->>'state' is distinct from 'excluded' or result->>'reason' is distinct from 'pet_size_excluded' then
    raise exception 'T-375 explicit size exclusion: %',result;
  end if;
  begin
    insert into public.groomer_offers(request_id,match_id,customer_id,groomer_id,
      proposed_start,proposed_end,price_estimate,status,expires_at)
      values(request,match,c,g,starts,starts+interval '30 minutes',100,'pending',
        statement_timestamp()+interval '1 day');
    raise exception 'T-375 stale explicit size accepted by offer writer';
  exception when sqlstate '22023' then
    if sqlerrm<>'match_constraints_changed' then raise; end if;
  end;
  perform app_private.refresh_request_match(request,g);
  if not exists(select 1 from public.request_matches m where m.request_id=request and m.groomer_id=g
    and m.status='dismissed') then raise exception 'T-375 exclusion lost deliberate dismissal'; end if;
  update public.request_matches set status='visible',dismissed_at=null where request_id=request and groomer_id=g;
  perform app_private.refresh_request_match(request,g);
  if not exists(select 1 from public.request_matches m where m.request_id=request and m.groomer_id=g
    and m.status='hidden' and m.eligibility_evaluation->>'reason'='pet_size_excluded') then
    raise exception 'T-375 existing excluded match remained visible';
  end if;
  update public.groomer_services set accepted_pet_sizes=array[]::text[] where groomer_id=g and service_type='full_groom';
  result := app_private.evaluate_match_eligibility(request,g,statement_timestamp());
  if result->>'state' is distinct from 'assessment_required' then raise exception 'T-375 legacy size: %',result; end if;
  insert into app_private.match_refresh_queue(request_id,groomer_id) values(request,g);
  -- This queue is newly created inside the caller's rollback-only migration.
  -- Do not drain unrelated requests enqueued by the temporary profile edits.
  delete from app_private.match_refresh_queue where request_id<>request or groomer_id<>g;
  perform app_private.drain_match_refresh_queue(250);
  if not exists(select 1 from public.request_matches m where m.request_id=request and m.groomer_id=g
    and m.status='visible' and m.eligibility_evaluation->>'state'='assessment_required')
    or exists(select 1 from app_private.match_refresh_queue where request_id=request and groomer_id=g) then
    raise exception 'T-375 queued refresh did not restore only eligibility-hidden match';
  end if;
  insert into public.groomer_time_off_windows(id,groomer_id,title,start_date,end_date)
    values(off_id,g,'T375 rollback',timezone('America/Los_Angeles',starts)::date,timezone('America/Los_Angeles',starts)::date);
  result := app_private.evaluate_match_eligibility(request,g,statement_timestamp());
  if result->>'state' is distinct from 'excluded' or result->>'reason' is distinct from 'no_continuous_opening' then
    raise exception 'T-375 full-day time off: %',result;
  end if;
  perform set_config('app.availability_batch','',true);
  update public.groomer_services set accepted_pet_sizes=array['M'] where groomer_id=g and service_type='full_groom';
  if not exists(select 1 from app_private.match_refresh_queue where request_id=request and groomer_id=g) then
    raise exception 'T-375 service edit failed to enqueue existing match';
  end if;
  delete from app_private.match_refresh_queue where request_id<>request or groomer_id<>g;
  perform app_private.drain_match_refresh_queue(1);
  if not exists(select 1 from public.request_matches m where m.request_id=request and m.groomer_id=g
    and m.status='hidden' and m.eligibility_evaluation->>'reason'='no_continuous_opening') then
    raise exception 'T-375 changed-service refresh retained occupied candidate';
  end if;
  result := app_private.evaluate_match_eligibility(gen_random_uuid(),g,statement_timestamp());
  if result->>'state' is distinct from 'excluded' then raise exception 'T-375 missing identity assessed'; end if;
  begin
    booking_request:=gen_random_uuid();
    insert into public.grooming_requests
      select (jsonb_populate_record(null::public.grooming_requests,
        to_jsonb(r)||jsonb_build_object('id',booking_request))).*
        from public.grooming_requests r where r.id=request;
    delete from app_private.match_refresh_queue;
    insert into app_private.match_refresh_queue(request_id,groomer_id)
      values(request,g),(request,g),(booking_request,g);
    drained:=app_private.drain_match_refresh_queue(1);
    if drained<>1
      or (select count(*) from app_private.match_refresh_queue)<>1 then
      raise exception 'T-375 bounded drain lost remaining work or failed to coalesce visible events';
    end if;
    drained:=app_private.drain_match_refresh_queue(1);
    if drained<>1
      or exists(select 1 from app_private.match_refresh_queue) then
      raise exception 'T-375 second batch failed to finish preserved work';
    end if;
    insert into app_private.match_refresh_queue(request_id,groomer_id) values(gen_random_uuid(),g);
    perform app_private.drain_match_refresh_queue(1);
    if exists(select 1 from app_private.match_refresh_queue) then raise exception 'T-375 orphan event did not expire'; end if;
    raise exception using errcode='Z3750',message='rollback successful batch fixture';
  exception when sqlstate 'Z3750' then null;
  end;
end $$;
