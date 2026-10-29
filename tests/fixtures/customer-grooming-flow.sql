-- T-421. Explicitly authorized seed accounts only. All setup and assertions roll back.
begin;
set local lock_timeout='5s';
set local statement_timeout='90s';
select set_config('app.t421',(/* INPUT_JSON */)::text,true);
create function pg_temp.expect_error(statement text, expected text) returns void language plpgsql as $$
begin
  begin execute statement;
  exception when others then
    if position(expected in sqlerrm)>0 then return; end if;
    raise;
  end;
  raise exception 'Expected error %',expected;
end $$;
do $$
declare d jsonb:=current_setting('app.t421')::jsonb;
  customer uuid:=(d->>'customer')::uuid; groomer uuid:=(d->>'groomer')::uuid; stranger uuid:=(d->>'stranger')::uuid;
  loc uuid; pet uuid; req uuid; offer uuid; revision uuid; proposal uuid;
  start_at timestamptz:=timezone('America/New_York',(timezone('America/New_York',now())::date+3)+time '10:00');
  historical timestamptz:=timezone('America/New_York',(timezone('America/New_York',now())::date-30)+time '10:00');
  schedule jsonb; result jsonb; input jsonb; preview jsonb; context jsonb; candidate jsonb; agreement jsonb;
  b public.bookings%rowtype; sample public.bookings%rowtype; confirmations text[];
begin
  if d->>'marker' !~ '^TESTOPS:T421-[A-Z0-9-]+$' then raise exception 'Invalid marker'; end if;
  perform 1 from public.profiles where id in (customer,groomer,stranger) order by id for update;
  if exists(select 1 from public.bookings where groomer_id=groomer and status='confirmed' and scheduled_end>now()) then
    raise exception 'Test identity has an active booking'; end if;
  insert into app_private.address_locations(owner_id,provider,country_code,latitude,longitude,resolution_source,user_confirmed_at,time_zone_identifier)
    values(groomer,'apple_maps','US',24.5551,-81.78,'manual_geocode',now(),'America/New_York') returning id into loc;
  update public.groomer_profiles set address_location_id=loc,is_active=true,
    base_street_address='421 TestOps Way',base_city='Key West',base_state='FL',base_zip_code='33040',
    service_location_mode='groomer_comes_to_customer',service_location_modes=array['groomer_comes_to_customer'],service_radius_miles=5
    where user_id=groomer;
  update public.groomer_services set is_active=false where groomer_id=groomer;
  insert into public.groomer_services(groomer_id,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species)
    values(groomer,'T421 service',d->>'marker',80,60,array['XS','S','M','L','XL','XXL','Giant'],true,'full_groom',array['dog']);
  perform set_config('request.jwt.claim.sub',groomer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',groomer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  schedule:=public.get_groomer_availability();
  perform public.save_groomer_availability(schedule->>'revision',
    (select jsonb_agg(jsonb_build_object('weekday',day,'start_time','09:00','end_time','18:00','is_enabled',true,'timezone','America/New_York')) from generate_series(1,7) day),
    jsonb_build_object('max_appointments_per_day',4,'minimum_advance_notice_days',0,'auto_accept_bookings',false,
      'timing_buffers',jsonb_build_object('preparation_minutes',0,'cleanup_minutes',0,'inbound_travel_minutes',0,'outbound_travel_minutes',0)), '[]');
  perform pg_temp.expect_error(format('select public.get_customer_groomer_profile_v1(%L)',groomer),'not_allowed');
  perform set_config('role','none',true);
  insert into public.groomer_time_off_windows(groomer_id,title,start_date,end_date)
    values(groomer,'T421 PRIVATE NOTE',current_date+50,current_date+51);
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',true)::text,true);
  perform set_config('role','authenticated',true);
  perform pg_temp.expect_error(format('select public.get_customer_groomer_profile_v1(%L)',groomer),'not_allowed');
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  result:=public.get_customer_groomer_profile_v1(groomer);
  if result->'profile' is null or jsonb_array_length(result->'services')<>1 or jsonb_array_length(result->'windows')<>7
    or result->'time_off'->>'title'<>'Unavailable' or result::text like '%T421 PRIVATE NOTE%'
    or result::text like '%421 TestOps Way%' or result ? 'auto_accept_bookings' then raise exception 'Unsafe/incomplete public profile'; end if;
  perform set_config('role','none',true);
  update public.groomer_profiles set is_active=false where user_id=groomer;
  perform set_config('role','authenticated',true);
  perform pg_temp.expect_error(format('select public.get_customer_groomer_profile_v1(%L)',groomer),'groomer_unavailable');
  perform pg_temp.expect_error(format('select public.get_customer_groomer_profile_v1(%L)',gen_random_uuid()),'groomer_unavailable');
  perform set_config('role','none',true);
  update public.groomer_profiles set is_active=true where user_id=groomer;
  perform set_config('role','authenticated',true);
  result:=public.save_my_pet_v3(null,jsonb_build_object('name','T421 fixture','species','Dog','breed','Unspecified',
    'weight_lbs',20,'coat_type','short_smooth','matting_confirmed',false,'temperament','Friendly','grooming_notes',d->>'marker'),true,gen_random_uuid(),null);
  pet:=(result->>'pet_id')::uuid;
  input:=jsonb_build_object('pet_id',pet,'service_type','full_groom','service_notes',d->>'marker',
    'preferred_start',start_at,'preferred_end',start_at+interval '6 hours','location_mode','groomer_comes_to_customer',
    'street_address','421 TestOps Way','city','Key West','state','FL','zip_code','33040','provider','apple_maps','country_code','US',
    'latitude',24.5551,'longitude',-81.78,'resolution_source','manual_geocode','user_confirmed_at',now(),
    'preference_time_zone_identifier','America/New_York');
  preview:=public.prepare_request_discovery_v1(gen_random_uuid(),input);
  result:=public.publish_request_with_distribution_v1(gen_random_uuid(),(preview->>'session_id')::uuid,preview->>'input_digest',false,array[groomer]);
  req:=(result->>'request_id')::uuid;
  perform set_config('role','none',true);
  select terms_revision into strict revision from public.grooming_requests where id=req;
  select app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes)
    into confirmations from public.grooming_requests r cross join lateral app_private.offer_service_configuration(req,groomer,null) s where r.id=req;
  perform set_config('request.jwt.claim.sub',groomer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',groomer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  select offer_id into offer from public.create_groomer_offer_v3(req,revision,start_at,start_at+interval '1 hour',80,d->>'marker',confirmations);
  perform set_config('role','none',true);
  select quote_revision into revision from public.groomer_offers where id=offer;
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  perform public.accept_groomer_offer_v2(offer,revision);
  perform set_config('role','none',true);
  select * into strict b from public.bookings where request_id=req;
  perform set_config('role','authenticated',true);
  perform pg_temp.expect_error(format('select public.get_booking_review_context(%L)',b.id),'booking_not_completed');
  perform set_config('role','none',true);
  -- Reuse the existing historical-fixture allocation contract; no trigger or RLS bypass.
  candidate:=app_private.validate_reschedule_candidate(b,historical,historical-interval '1 day');
  proposal:=gen_random_uuid();
  agreement:=b.agreement_snapshot||jsonb_build_object('scheduled_start',historical,'scheduled_end',(candidate->>'end')::timestamptz,'reschedule_id',proposal);
  insert into public.booking_reschedule_proposals(id,booking_id,base_revision,initiator_id,proposed_start,proposed_end,
    proposed_occupied_start,proposed_occupied_end,previous_agreement,proposed_agreement,status,created_at,expires_at,responded_by,responded_at)
    values(proposal,b.id,b.fulfillment_revision,customer,historical,(candidate->>'end')::timestamptz,
      (candidate->>'occupied_start')::timestamptz,(candidate->>'occupied_end')::timestamptz,b.agreement_snapshot,agreement,
      'accepted',historical-interval '1 day',historical-interval '5 minutes',groomer,historical-interval '1 hour');
  perform set_config('app.reschedule_proposal',proposal::text,true);
  perform set_config('app.fulfillment_write','1',true);
  update public.bookings set scheduled_start=historical,scheduled_end=(candidate->>'end')::timestamptz,
    occupied_start=(candidate->>'occupied_start')::timestamptz,occupied_end=(candidate->>'occupied_end')::timestamptz,
    agreement_snapshot=agreement,fulfillment_revision=gen_random_uuid() where id=b.id returning * into b;
  perform set_config('app.reschedule_proposal','',true);
  perform set_config('app.fulfillment_write','',true);
  update public.booking_reschedule_proposals set result_revision=b.fulfillment_revision where id=proposal;
  sample:=b;
  if app_private.grooming_finished_at(sample)>now() then raise exception 'Elapsed booking not finished'; end if;
  sample.fulfillment_phase:='outcome_reported';
  if app_private.grooming_finished_at(sample) is not null then raise exception 'Pending outcome finished'; end if;
  sample:=b; sample.agreement_snapshot:=sample.agreement_snapshot||'{"service_time_zone_identifier":"Invalid/Zone"}';
  if app_private.grooming_finished_at(sample) is not null then raise exception 'Invalid timezone accepted'; end if;
  perform set_config('request.jwt.claim.sub',stranger::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',stranger,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  perform pg_temp.expect_error(format('select public.get_booking_review_context(%L)',b.id),'booking_not_found');
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  context:=public.get_booking_review_context(b.id);
  if context->'allowed_keys'<>'[]'::jsonb or context->>'service_at' is not null then raise exception 'Elapsed service invented evidence'; end if;
  perform pg_temp.expect_error(format('select public.create_review_v2(%L,%L,5,null,%L::jsonb)',b.id,gen_random_uuid(),'[]'),'review_context_changed');
  perform pg_temp.expect_error(format('select public.create_review_v2(%L,%L,5,null,%L::jsonb)',b.id,context->>'context_revision',
    '[{"trait_type":"coat","trait_value":"short_smooth","outcome":"positive"}]'),'invalid_pet_fit_context');
  perform public.create_review_v2(b.id,(context->>'context_revision')::uuid,5,d->>'marker','[]');
  perform pg_temp.expect_error(format('select public.create_review_v2(%L,%L,5,null,%L::jsonb)',b.id,context->>'context_revision','[]'),'review_already_exists');
  perform set_config('role','none',true);
  if not exists(select 1 from public.bookings where id=b.id and status='confirmed' and completed_at is null)
    or not exists(select 1 from app_private.booking_review_contexts where booking_id=b.id and source_state='elapsed_unverified')
    or exists(select 1 from app_private.review_evidence_projection p join public.reviews r on r.id=p.review_id where r.booking_id=b.id)
    then raise exception 'Review changed fulfillment or fabricated evidence'; end if;
end $$;
select 'passed: safe profile, actor/inactive/privacy fields, new publish/quote/accept, elapsed review, ownership, revision, duplicate, no fake completion/evidence' as result;
rollback;
