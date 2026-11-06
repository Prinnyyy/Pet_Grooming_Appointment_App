-- T-466 runtime acceptance. Execute only with explicit remote-test authorization.
-- Entirely new, transaction-local actors/data; no existing accounts are modified.
-- This file always rolls back. An error also aborts the transaction on disconnect.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
create function pg_temp.check_that(ok boolean, label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'T466: %',label; end if; end $$;
create function pg_temp.expect_error(statement text, expected text) returns void language plpgsql as $$
begin
  begin execute statement;
  exception when others then
    if position(expected in sqlerrm)>0 then return; end if;
    raise exception 'T466 expected %, got %',expected,sqlerrm;
  end;
  raise exception 'T466 expected error %',expected;
end $$;
create function pg_temp.assume(actor uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub',actor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
end $$;
create function pg_temp.new_request(groomer uuid, start_at timestamptz, label text) returns uuid language plpgsql as $$
declare pet uuid; preview jsonb; result jsonb; input jsonb;
begin
  result:=public.save_my_pet_v3(null,jsonb_build_object('name',label,'species','Dog','breed','Unspecified',
    'weight_lbs',20,'coat_type','short_smooth','matting_confirmed',false,'temperament','Friendly','grooming_notes','TESTOPS:T466'),true,gen_random_uuid(),null);
  pet:=(result->>'pet_id')::uuid;
  input:=jsonb_build_object('pet_id',pet,'service_type','full_groom','service_notes','TESTOPS:T466',
    'preferred_start',start_at,'preferred_end',start_at+interval '2 hours','location_mode','groomer_comes_to_customer',
    'street_address','466 Testops Way','city','Key West','state','FL','zip_code','33040','provider','apple_maps','country_code','US',
    'latitude',24.5551,'longitude',-81.78,'resolution_source','manual_geocode','user_confirmed_at',now(),
    'preference_time_zone_identifier','America/New_York');
  preview:=public.prepare_request_discovery_v1(gen_random_uuid(),input);
  result:=public.publish_request_with_distribution_v1(gen_random_uuid(),(preview->>'session_id')::uuid,preview->>'input_digest',false,array[groomer]);
  return (result->>'request_id')::uuid;
end $$;
-- Historical service fixture uses the existing allocation validator and signed
-- reschedule provenance. No trigger, constraint or RLS is disabled.
create function pg_temp.move_to_history(booking uuid, days_ago integer default 30) returns public.bookings language plpgsql as $$
declare b public.bookings%rowtype; candidate jsonb; proposal uuid:=gen_random_uuid(); agreement jsonb;
  historical timestamptz:=timezone('America/New_York',(timezone('America/New_York',now())::date-days_ago)+time '10:00');
begin
  select * into strict b from public.bookings where id=booking;
  candidate:=app_private.validate_reschedule_candidate(b,historical,historical-interval '1 day');
  agreement:=b.agreement_snapshot||jsonb_build_object('scheduled_start',historical,'scheduled_end',(candidate->>'end')::timestamptz,'reschedule_id',proposal);
  insert into public.booking_reschedule_proposals(id,booking_id,base_revision,initiator_id,proposed_start,proposed_end,
    proposed_occupied_start,proposed_occupied_end,previous_agreement,proposed_agreement,status,created_at,expires_at,responded_by,responded_at)
    values(proposal,b.id,b.fulfillment_revision,b.customer_id,historical,(candidate->>'end')::timestamptz,
      (candidate->>'occupied_start')::timestamptz,(candidate->>'occupied_end')::timestamptz,b.agreement_snapshot,agreement,
      'accepted',historical-interval '1 day',historical-interval '5 minutes',b.groomer_id,historical-interval '1 hour');
  perform set_config('app.reschedule_proposal',proposal::text,true);
  perform set_config('app.fulfillment_write','1',true);
  update public.bookings set scheduled_start=historical,scheduled_end=(candidate->>'end')::timestamptz,
    occupied_start=(candidate->>'occupied_start')::timestamptz,occupied_end=(candidate->>'occupied_end')::timestamptz,
    agreement_snapshot=agreement,fulfillment_revision=gen_random_uuid() where id=b.id returning * into b;
  perform set_config('app.reschedule_proposal','',true); perform set_config('app.fulfillment_write','',true);
  update public.booking_reschedule_proposals set result_revision=b.fulfillment_revision where id=proposal;
  return b;
end $$;
do $$
declare customer uuid:=gen_random_uuid(); other_customer uuid:=gen_random_uuid(); groomer uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid();
  actor uuid; loc uuid; req_a uuid; req_b uuid; req_c uuid; offer_a uuid; offer_b uuid; offer_c uuid; old_offer uuid; revision uuid; conversation uuid;
  start_at timestamptz:=timezone('America/New_York',(timezone('America/New_York',now())::date+3)+time '10:00');
  result jsonb; schedule jsonb; contact jsonb; proposal uuid; operation uuid; previous_revision uuid;
  b public.bookings%rowtype; c public.bookings%rowtype; r public.grooming_requests%rowtype;
begin
  foreach actor in array array[customer,other_customer,groomer,stranger] loop
    insert into auth.users(id,email,raw_user_meta_data) values(actor,'t466-'||actor::text||'@example.invalid','{"fixture":"TESTOPS:T466"}');
    insert into public.profiles(id,role,display_name) values(actor,
      (case when actor=groomer then 'groomer' else 'customer' end)::public.user_role,'T466 temporary actor');
    if actor<>groomer then insert into public.customer_profiles(user_id) values(actor); end if;
  end loop;
  insert into app_private.address_locations(owner_id,provider,country_code,latitude,longitude,resolution_source,user_confirmed_at,time_zone_identifier)
    values(groomer,'apple_maps','US',24.5551,-81.78,'manual_geocode',now(),'America/New_York') returning id into loc;
  insert into public.groomer_profiles(user_id,business_name,address_location_id,is_active,is_verified,base_street_address,base_city,base_state,base_zip_code,
    service_location_mode,service_location_modes,service_radius_miles)
    values(groomer,'T466 temporary studio',loc,true,true,'466 Testops Way','Key West','FL','33040','groomer_comes_to_customer',array['groomer_comes_to_customer'],5);
  insert into public.groomer_services(groomer_id,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species)
    values(groomer,'T466 service','TESTOPS:T466',80,60,array['XS','S','M','L','XL','XXL','Giant'],true,'full_groom',array['dog']);
  perform pg_temp.assume(groomer);
  schedule:=public.get_groomer_availability();
  perform public.save_groomer_availability(schedule->>'revision',
    (select jsonb_agg(jsonb_build_object('weekday',day,'start_time','00:00','end_time','23:59','is_enabled',true,'timezone','America/New_York')) from generate_series(1,7) day),
    jsonb_build_object('max_appointments_per_day',8,'minimum_advance_notice_days',0,'auto_accept_bookings',false,
      'timing_buffers',jsonb_build_object('preparation_minutes',0,'cleanup_minutes',0,'inbound_travel_minutes',0,'outbound_travel_minutes',0)), '[]');
  perform pg_temp.assume(customer); req_a:=pg_temp.new_request(groomer,start_at,'T466 A');
  perform pg_temp.assume(other_customer); req_b:=pg_temp.new_request(groomer,start_at,'T466 B');
  perform pg_temp.assume(stranger);
  perform pg_temp.expect_error(format('select public.get_request_chat_contact(%L,%L)',req_a,groomer),'request_contact_unavailable');
  perform pg_temp.assume(customer);
  contact:=public.get_request_chat_contact(req_a,groomer);
  perform pg_temp.check_that((contact->>'can_message')::boolean=false,'invitation does not let inviter initiate before an offer');
  perform pg_temp.assume(groomer);
  contact:=public.get_request_chat_contact(req_a,groomer);
  perform pg_temp.check_that((contact->>'can_message')::boolean,'invited groomer can initiate');
  conversation:=public.open_request_conversation(req_a,groomer);
  perform set_config('role','none',true);
  update app_private.request_invitations set withdrawn_at=now() where request_id=req_a and groomer_id=groomer;
  perform pg_temp.assume(groomer);
  perform pg_temp.expect_error(format('insert into public.messages(conversation_id,sender_id,body) values(%L,%L,''TESTOPS:T466'')',conversation,groomer),'request_contact_unavailable');
  perform set_config('role','none',true);
  update app_private.request_invitations set withdrawn_at=null where request_id=req_a and groomer_id=groomer;
  select * into r from public.grooming_requests where id=req_a;
  perform pg_temp.check_that(app_private.request_street_name('466 Testops Way, Unit 12')='Testops Way','partial address strips number/unit');
  perform pg_temp.check_that(app_private.request_street_name('unrecognized private text') is null,'partial address fails closed');
  perform pg_temp.assume(groomer);
  -- Preferred window ends at 12:00. The groomer can propose 12:00-13:00.
  select offer_id into offer_a from public.create_groomer_offer_v3(req_a,r.terms_revision,start_at+interval '2 hours',start_at+interval '3 hours',95,'TESTOPS:T466','{}');
  perform set_config('role','none',true); select terms_revision into revision from public.grooming_requests where id=req_b;
  perform pg_temp.assume(groomer);
  select offer_id into offer_b from public.create_groomer_offer_v3(req_b,revision,start_at+interval '150 minutes',start_at+interval '210 minutes',80,null,'{}');
  perform pg_temp.check_that((select count(*)=2 from public.get_grooming_offers('waiting',20,0)),'waiting filter owns both offers');
  perform pg_temp.assume(customer); req_c:=pg_temp.new_request(groomer,start_at,'T466 C');
  perform set_config('role','none',true); select terms_revision into revision from public.grooming_requests where id=req_c;
  perform pg_temp.assume(groomer);
  perform pg_temp.expect_error(format('select public.create_groomer_offer_v3(%L,%L,%L,%L,10000,null,''{}'')',req_c,revision,start_at+interval '210 minutes',start_at+interval '270 minutes'),'invalid_price');
  select offer_id into old_offer from public.create_groomer_offer_v3(req_c,revision,start_at+interval '210 minutes',start_at+interval '270 minutes',90,null,'{}');
  perform public.withdraw_groomer_offer(old_offer);
  perform pg_temp.check_that(not exists(select 1 from public.get_grooming_offers('closed',20,0) where id=old_offer),'withdrawn offers are absent from Closed');
  select offer_id into offer_c from public.create_groomer_offer_v3(req_c,revision,start_at+interval '210 minutes',start_at+interval '270 minutes',85,null,'{}');
  perform pg_temp.check_that(offer_c<>old_offer,'new offer has independent identity on same request');
  perform pg_temp.assume(customer);
  perform pg_temp.check_that((public.get_request_chat_contact(req_a,groomer)->>'can_message')::boolean,'offer grants customer first contact');
  insert into public.messages(id,conversation_id,sender_id,body) values(gen_random_uuid(),conversation,customer,'TESTOPS:T466');
  perform set_config('role','none',true); select quote_revision into revision from public.groomer_offers where id=offer_b;
  perform pg_temp.assume(other_customer); perform public.accept_groomer_offer_v2(offer_b,revision);
  perform set_config('role','none',true);
  select * into strict b from public.bookings where offer_id=offer_b;
  perform pg_temp.check_that(app_private.evaluate_quote(offer_a,now())->>'reason'='time_slot_booked','overlap permanently closes pending offer');
  select quote_revision into revision from public.groomer_offers where id=offer_a;
  perform pg_temp.assume(customer);
  perform pg_temp.expect_error(format('select public.accept_groomer_offer_v2(%L,%L)',offer_a,revision),'offer');
  perform pg_temp.check_that((public.get_request_chat_contact(req_a,groomer)->>'can_message')::boolean,'established conversation survives expired basis');
  perform pg_temp.assume(groomer);
  perform pg_temp.check_that((select count(*)=1 from public.get_grooming_offers('accepted',20,0)),'accepted filter is independent');
  perform pg_temp.check_that((select count(*)=1 from public.get_grooming_offers('closed',20,0)),'conflicted offer belongs to closed');
  perform set_config('role','none',true); select quote_revision into revision from public.groomer_offers where id=offer_c;
  perform pg_temp.assume(customer); perform public.accept_groomer_offer_v2(offer_c,revision);
  perform set_config('role','none',true); select * into strict c from public.bookings where offer_id=offer_c;
  perform pg_temp.check_that(c.scheduled_start=b.scheduled_end,'adjacent bookings do not overlap');
  perform pg_temp.assume(groomer);
  perform pg_temp.expect_error(format('select public.mutate_booking_reschedule(%L,%L,%L,''propose'',gen_random_uuid(),%L)',b.id,b.fulfillment_revision,gen_random_uuid(),c.scheduled_start),'reschedule_resource_conflict');
  perform pg_temp.expect_error(format('select public.mutate_booking_fulfillment(%L,%L,%L,''complete'',null)',b.id,b.fulfillment_revision,gen_random_uuid()),'completion_too_early');
  perform pg_temp.expect_error(format('select public.mutate_booking_reschedule(%L,%L,%L,''propose'',gen_random_uuid(),%L)',b.id,b.fulfillment_revision,gen_random_uuid(),b.scheduled_start),'invalid_reschedule_time');
  result:=public.mutate_booking_reschedule(b.id,b.fulfillment_revision,gen_random_uuid(),'propose',gen_random_uuid(),b.scheduled_start+interval '3 hours');
  proposal:=(result->'proposal'->>'id')::uuid;
  perform pg_temp.assume(other_customer);
  result:=public.mutate_booking_reschedule(b.id,b.fulfillment_revision,gen_random_uuid(),'accept',proposal,null);
  result:=public.get_booking_reschedule(b.id);
  perform pg_temp.check_that(jsonb_array_length(result->'history')=2,'proposal/accept history survives state read');
  perform pg_temp.check_that(result->'history'->0->>'action'='propose' and result->'history'->1->>'action'='accept','history uses actual operation order');
  perform set_config('role','none',true);
  b:=pg_temp.move_to_history(b.id);
  perform pg_temp.check_that(app_private.grooming_finished_at(b) is null,'elapsed time alone never enables review');
  perform pg_temp.assume(other_customer);
  perform pg_temp.expect_error(format('select public.get_booking_review_context(%L)',b.id),'booking_not_completed');
  previous_revision:=b.fulfillment_revision; operation:=gen_random_uuid();
  result:=public.mutate_booking_fulfillment(b.id,previous_revision,operation,'complete',null);
  perform pg_temp.check_that(result->'booking'->>'status'='completed','customer can finish without groomer confirmation');
  result:=public.mutate_booking_fulfillment(b.id,previous_revision,operation,'complete',null);
  perform pg_temp.check_that((result->>'replayed')::boolean,'same completion operation safely replays');
  perform pg_temp.expect_error(format('select public.mutate_booking_fulfillment(%L,%L,%L,''cancel'',null)',b.id,previous_revision,operation),'fulfillment_operation_intent_changed');
  -- This entire fixture is one SQL command: statement_timestamp precedes the
  -- completion's clock_timestamp. Real HTTP review is a later command. Align
  -- only this synthetic completion timestamp to that command boundary.
  perform set_config('role','none',true);
  perform set_config('app.fulfillment_write','1',true);
  update public.bookings set completed_at=statement_timestamp() where id=b.id;
  perform set_config('app.fulfillment_write','',true);
  perform pg_temp.assume(other_customer);
  result:=public.get_booking_review_context(b.id);
  perform public.create_review_v2(b.id,(result->>'context_revision')::uuid,5,'TESTOPS:T466','[]');
  perform pg_temp.assume(stranger);
  perform pg_temp.expect_error(format('select public.get_booking_reschedule(%L)',b.id),'booking_not_found');
  perform pg_temp.expect_error(format('select public.get_conversation_send_permissions(array[%L]::uuid[])',conversation),'conversation_not_available');
  perform set_config('role','none',true);
  perform pg_temp.check_that(app_private.evaluate_quote(offer_a,now())->>'reason'='time_slot_booked','closed offer does not revive after schedule changes');
  perform pg_temp.check_that((select count(*)=1 from public.booking_fulfillment_events where booking_id=b.id and action='complete'),'exactly one completion receipt');
  perform pg_temp.check_that(not exists(select 1 from public.booking_fulfillment_events where booking_id=b.id and action='start'),'no synthetic start event');
  c:=pg_temp.move_to_history(c.id,31);
  perform pg_temp.assume(groomer);
  result:=public.mutate_booking_fulfillment(c.id,c.fulfillment_revision,gen_random_uuid(),'complete',null);
  perform pg_temp.check_that(result->'booking'->>'completed_by'=groomer::text,'groomer also finishes without counterpart confirmation');
  perform set_config('role','none',true);
end $$;
select 'T466 passed: proposal, consent/revocation, identity/privacy, overlap, filtered reads, reschedule history, completion, replay, review. Transaction rolled back.' as result;
rollback;
