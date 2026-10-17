begin;
set local lock_timeout='5s';
set local statement_timeout='150s';
select set_config('app.testops_discovery_input',(/* INPUT_JSON */)::text,true);
do $$
declare d jsonb:=current_setting('app.testops_discovery_input')::jsonb;
  customer uuid:=(d->'actors'->>'C1')::uuid; other uuid:=(d->'actors'->>'C2')::uuid;
  gid uuid; best uuid:=(d->'groomers'->>0)::uuid; loc uuid; pet uuid; req uuid;
  draft uuid:=gen_random_uuid(); start_at timestamptz; input jsonb; session jsonb; scope jsonb;
  schedule jsonb; cfg jsonb; first_page jsonb; second_page jsonb; fresh_page jsonb; detail jsonb;
  r public.grooming_requests%rowtype; score jsonb; zones text[]; evaluation jsonb;
  before_counts bigint[]; ids uuid[]; all_ids uuid[]; snap uuid; i integer; assertions integer:=0;
  op uuid:=gen_random_uuid(); receipt jsonb; newer jsonb; offer uuid; request_revision uuid; distribution_revision uuid;
begin
  if d->>'run_id' !~ '^TESTOPS-T399-[A-Z0-9-]+$' or jsonb_array_length(d->'groomers')<>26 then
    raise exception 'invalid fixture manifest';
  end if;
  start_at:=timezone('America/New_York',(timezone('America/New_York',now())::date+3)+time '10:00');
  select array_agg(name) into zones from pg_catalog.pg_timezone_names;
  for gid in select value::uuid from jsonb_array_elements_text(d->'groomers') with ordinality x(value,ordinal) where ordinal<=6 loop
    if exists(select 1 from public.bookings where groomer_id=gid and scheduled_end>now()) then
      raise exception 'Non-idle test groomer';
    end if;
    insert into app_private.address_locations(owner_id,provider,country_code,latitude,longitude,resolution_source,user_confirmed_at,time_zone_identifier)
      values(gid,'apple_maps','US',24.5551,-81.78,'manual_geocode',now(),'America/New_York') returning id into loc;
    update public.groomer_profiles set address_location_id=loc,is_active=true,
      base_street_address='399 TestOps Synthetic Way',base_city='Key West',base_state='FL',base_zip_code='33040',
      service_location_mode='groomer_comes_to_customer',service_location_modes=array['groomer_comes_to_customer'],service_radius_miles=5
      where user_id=gid;
    update public.groomer_services set is_active=false where groomer_id=gid and is_active;
    insert into public.groomer_services(groomer_id,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species)
      values(gid,'Discovery test',d->>'marker',80,60,array['XS','S','M','L','XL','XXL','Giant'],true,'full_groom',array['dog']);
    perform set_config('request.jwt.claim.sub',gid::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',gid,'role','authenticated','is_anonymous',false)::text,true);
    perform set_config('role','authenticated',true);
    schedule:=public.get_groomer_availability();
    cfg:=public.save_groomer_availability(schedule->>'revision',
      (select jsonb_agg(jsonb_build_object('weekday',day,'start_time','09:00','end_time','18:00',
        'is_enabled',true,'timezone','America/New_York')) from generate_series(1,7) day),
      jsonb_build_object('max_appointments_per_day',4,'minimum_advance_notice_days',0,'auto_accept_bookings',false,
        'timing_buffers',jsonb_build_object('preparation_minutes',0,'cleanup_minutes',0,'inbound_travel_minutes',0,'outbound_travel_minutes',0)), '[]');
    perform set_config('role','none',true);
  end loop;
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  select id into pet from public.save_my_pet_v2(null,jsonb_build_object('name','Discovery fixture','species','Dog',
    'breed','Unspecified','weight_lbs',20,'coat_type','short_smooth','matting_confirmed',false,
    'temperament','Friendly','grooming_notes',d->>'marker'),true);
  perform set_config('role','none',true);
  before_counts:=array[(select count(*) from public.grooming_requests),(select count(*) from public.request_matches),
    (select count(*) from public.groomer_notifications)];
  input:=jsonb_build_object('pet_id',pet,'service_type','full_groom','service_notes',d->>'marker',
    'preferred_start',start_at,'preferred_end',start_at+interval '6 hours','location_mode','groomer_comes_to_customer',
    'street_address','399 TestOps Synthetic Way','city','Key West','state','FL','zip_code','33040',
    'provider','apple_maps','country_code','US','latitude',24.5551,'longitude',-81.78,
    'resolution_source','manual_geocode','user_confirmed_at',now(),'preference_time_zone_identifier','America/New_York');
  perform set_config('role','authenticated',true);

  session:=public.prepare_request_discovery_v1(draft,input);
  receipt:=public.publish_request_with_distribution_v1(op,(session->>'session_id')::uuid,session->>'input_digest',false,array[best]);
  req:=(receipt->>'request_id')::uuid; request_revision:=(receipt->>'terms_revision')::uuid;
  distribution_revision:=(receipt->>'distribution_revision')::uuid;
  if receipt->>'pool_enabled'<>'false' or jsonb_array_length(receipt->'invited_groomer_ids')<>1 then
    raise exception 'explicit distribution receipt incorrect';end if;
  if public.publish_request_with_distribution_v1(op,(session->>'session_id')::uuid,session->>'input_digest',false,array[best])<>receipt then
    raise exception 'identical first-send retry changed receipt';end if;
  begin perform public.publish_request_with_distribution_v1(op,(session->>'session_id')::uuid,session->>'input_digest',true,array[best]);
    raise exception 'changed first intent accepted';exception when sqlstate 'PT409' then
    if sqlerrm<>'operation_intent_changed' then raise;end if;end;
  begin perform public.publish_request_with_distribution_v1(gen_random_uuid(),(session->>'session_id')::uuid,session->>'input_digest',false,array[best]);
    raise exception 'second operation published again';exception when sqlstate 'PT409' then
    if sqlerrm<>'already_published' then raise;end if;end;
  assertions:=assertions+4;
  perform set_config('role','none',true);
  if (select count(*) from public.request_matches where request_id=req)<>1
    or exists(select 1 from app_private.match_refresh_queue where request_id=req and groomer_id<>best)
    or exists(select 1 from app_private.request_distribution_operations where request_id=req)
    or (select count(*) from app_private.request_publish_operations where request_id=req)<>1 then
    raise exception 'private send broadcast or double-owned first receipt';end if;
  update app_private.request_discovery_sessions set created_at=now()-interval '31 minutes',expires_at=now()-interval '1 minute'
    where id=(session->>'session_id')::uuid;
  perform set_config('role','authenticated',true);
  if public.publish_request_with_distribution_v1(op,(session->>'session_id')::uuid,session->>'input_digest',false,array[best])<>receipt then
    raise exception 'accepted retry expired with preview';end if;
  assertions:=assertions+2;
  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',best::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',best,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  if exists(select 1 from public.grooming_requests where id=req) then raise exception 'raw address row leaked';end if;
  select x into detail from public.get_groomer_request_summaries_v1(array[req]) x;
  if detail is null or detail ?| array['street_address','zip_code','address_line_2','address_location_id']
    or detail->>'service_notes' is not null or detail->'pet_snapshot' ? 'grooming_notes' then
    raise exception 'unsafe summary projection';end if;
  detail:=public.get_groomer_request_detail_v1(req);
  if detail->>'service_notes'<>d->>'marker' or detail ? 'street_address' then raise exception 'detail access incorrect';end if;
  first_page:=public.get_ranked_matched_requests_v2('fit',25,null);
  if not exists(select 1 from jsonb_array_elements(first_page->'items') x where x->'request'->>'id'=req::text)
    or exists(select 1 from jsonb_array_elements(first_page->'items') x where x->'request' ? 'street_address') then
    raise exception 'ranked compatibility unsafe';end if;
  assertions:=assertions+4;
  -- A stale or invented match must not manufacture permission for an uninvited groomer.
  gid:=(d->'groomers'->>1)::uuid;
  perform set_config('role','none',true);
  insert into public.request_matches(request_id,groomer_id,customer_id,status) values(req,gid,customer,'visible');
  perform app_private.refresh_candidate_evaluation(req,gid,now(),0);
  if exists(select 1 from public.request_matches where request_id=req and groomer_id=gid)
    or exists(select 1 from app_private.match_candidate_evaluations where request_id=req and groomer_id=gid) then
    raise exception 'worker created unsolicited match';end if;
  perform set_config('request.jwt.claim.sub',gid::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gid,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  if exists(select 1 from public.get_groomer_request_summaries_v1(array[req]))
    or exists(select 1 from public.get_my_matched_request(gid,req)) then raise exception 'uninvited read allowed';end if;
  begin perform public.get_groomer_request_detail_v1(req);raise exception 'uninvited detail allowed';
    exception when insufficient_privilege then null;end;
  begin perform public.create_groomer_offer_v3(req,request_revision,start_at,start_at+interval '1 hour',80,d->>'marker','{}');
    raise exception 'uninvited quote allowed';exception when raise_exception then if sqlerrm<>'match_not_found' then raise;end if;end;
  assertions:=assertions+4;
  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  newer:=public.set_request_pool_v1(gen_random_uuid(),req,distribution_revision,true);
  if newer->>'terms_revision'<>receipt->>'terms_revision' or newer->>'distribution_revision'=distribution_revision::text then
    raise exception 'pool revision modified terms or failed to advance';end if;
  distribution_revision:=(newer->>'distribution_revision')::uuid;
  perform set_config('role','none',true);
  perform app_private.refresh_candidate_evaluation(req,gid,now(),0);
  delete from app_private.match_refresh_queue where request_id=req and groomer_id=gid;
  perform set_config('request.jwt.claim.sub',gid::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gid,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  detail:=public.get_groomer_request_detail_v1(req);
  select offer_id into offer from public.create_groomer_offer_v3(req,request_revision,start_at,start_at+interval '1 hour',80,d->>'marker','{}');
  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  newer:=public.set_request_pool_v1(gen_random_uuid(),req,distribution_revision,false);
  perform set_config('role','none',true);
  if app_private.evaluate_quote(offer)->>'selectable'<>'true'
    or app_private.request_distribution_allows_new_quote(req,gid) then raise exception 'pool close invalidated old offer or allowed new quote';end if;
  assertions:=assertions+3;
  perform set_config('request.jwt.claim.sub',gid::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gid,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  detail:=public.get_groomer_request_detail_v1(req);
  if detail is null then raise exception 'existing offer lost detail';end if;
  perform set_config('role','none',true);
  -- Five counterpart cap includes offers from invited groomers; duplicate targets are harmless.
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  select array_agg(value::uuid) into ids from jsonb_array_elements_text(d->'groomers') with ordinality x(value,ordinal) where ordinal between 2 and 5;
  newer:=public.invite_request_groomers_v1(gen_random_uuid(),req,request_revision,ids);
  if jsonb_array_length(newer->'invited_groomer_ids')<>5 then raise exception 'append failed';end if;
  begin perform public.invite_request_groomers_v1(gen_random_uuid(),req,request_revision,array[(d->'groomers'->>5)::uuid]);
    raise exception 'sixth invite allowed';exception when raise_exception then if sqlerrm<>'invitation_limit_reached' then raise;end if;end;
  newer:=public.invite_request_groomers_v1(gen_random_uuid(),req,request_revision,array[best,best]);
  if jsonb_array_length(newer->'invited_groomer_ids')<>5 then raise exception 'duplicate invite';end if;
  newer:=public.withdraw_request_invitation_v1(gen_random_uuid(),req,best);
  newer:=public.invite_request_groomers_v1(gen_random_uuid(),req,request_revision,array[best]);
  perform set_config('role','none',true);
  if app_private.request_invitation_state(req,best)<>'withdrawn' then raise exception 'withdrawn pair resent';end if;
  if (select count(*) from public.groomer_notifications where related_request_id=req and groomer_id=gid)<>1 then
    raise exception 'pool plus invite duplicated notification';end if;
  assertions:=assertions+6;
  perform set_config('request.jwt.claim.sub',other::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  begin perform public.get_customer_request_progress_v1(array[req]);raise exception 'foreign progress allowed';
    exception when insufficient_privilege then null;end;
  begin perform public.set_request_pool_v1(gen_random_uuid(),req,(newer->>'distribution_revision')::uuid,true);
    raise exception 'foreign pool write allowed';exception when insufficient_privilege then null;end;
  assertions:=assertions+2;
  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  select quote_revision into snap from public.groomer_offers where id=offer;
  perform set_config('role','authenticated',true);
  perform public.accept_groomer_offer_v2(offer,snap);
  select x into detail from public.get_booking_request_locations_v1(array[req]) x;
  if detail->>'street_address'<>'399 TestOps Synthetic Way' or not detail ?& array['service_type','pet_snapshot'] then
    raise exception 'booking location wire is incomplete';end if;
  perform set_config('role','none',true);
  if (select count(*) from public.bookings where request_id=req)<>1 then raise exception 'booking not unique';end if;
  assertions:=assertions+2;
  perform set_config('app.testops_distribution_result',jsonb_build_object('assertions',assertions,'request_id',req,'rollback',true)::text,true);
end $$;
select current_setting('app.testops_distribution_result')::jsonb result;
rollback;
