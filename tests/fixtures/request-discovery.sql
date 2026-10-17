begin;
set local lock_timeout='5s';
set local statement_timeout='150s';
select set_config('app.testops_discovery_input',(/* INPUT_JSON */)::text,true);
do $$
declare d jsonb:=current_setting('app.testops_discovery_input')::jsonb;
  customer uuid:=(d->'actors'->>'C1')::uuid; other uuid:=(d->'actors'->>'C2')::uuid;
  gid uuid; best uuid:=(d->'groomers'->>25)::uuid; loc uuid; pet uuid; req uuid;
  draft uuid:=gen_random_uuid(); start_at timestamptz; input jsonb; session jsonb; scope jsonb;
  schedule jsonb; cfg jsonb; first_page jsonb; second_page jsonb; fresh_page jsonb; detail jsonb;
  r public.grooming_requests%rowtype; score jsonb; zones text[]; evaluation jsonb;
  before_counts bigint[]; ids uuid[]; all_ids uuid[]; snap uuid; i integer; assertions integer:=0;
begin
  if d->>'run_id' !~ '^TESTOPS-T399-[A-Z0-9-]+$' or jsonb_array_length(d->'groomers')<>26 then
    raise exception 'invalid fixture manifest';
  end if;
  start_at:=timezone('America/New_York',(timezone('America/New_York',now())::date+3)+time '10:00');
  select array_agg(name) into zones from pg_catalog.pg_timezone_names;
  for gid in select value::uuid from jsonb_array_elements_text(d->'groomers') loop
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
    if gid<>best then update public.groomer_booking_preferences set timing_buffers=null where groomer_id=gid; end if;
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
  if public.prepare_request_discovery_v1(draft,input)->>'session_id' is distinct from session->>'session_id' then
    raise exception 'same draft/input did not reuse preview';
  end if;
  scope:=jsonb_build_object('kind','preview','id',session->>'session_id','input_digest',session->>'input_digest');
  first_page:=public.get_request_groomer_candidates_v1(scope,'fit',25,null);
  second_page:=public.get_request_groomer_candidates_v1(scope,'fit',25,first_page->>'next_cursor');
  select array_agg((value->>'groomer_id')::uuid) into all_ids
    from jsonb_array_elements((first_page->'items')||(second_page->'items'));
  select array_agg(value::uuid) into ids from jsonb_array_elements_text(d->'groomers');
  if not all_ids @> ids or cardinality(all_ids)<>(select count(distinct x) from unnest(all_ids) x)
    or first_page->'items'->0->>'groomer_id' is distinct from best::text then
    raise exception 'complete pool or late candidate ranking failed';
  end if;
  assertions:=assertions+3;
  detail:=public.get_discovery_groomer_profile_v1(scope,best);
  if detail->>'groomer_id' is distinct from best::text or detail->'safe_profile' ?| array['street_address','latitude','longitude','email','phone']
    or detail->'matching_evidence' ?| array['s','f','q','d','positive_weight'] then
    raise exception 'unsafe or mismatched profile projection';
  end if;
  begin perform 1 from app_private.request_discovery_sessions;raise exception 'preview table exposed';
  exception when insufficient_privilege then assertions:=assertions+1;end;
  begin perform 1 from app_private.match_browse_snapshots;raise exception 'snapshot table exposed';
  exception when insufficient_privilege then assertions:=assertions+1;end;
  perform set_config('role','none',true);
  if before_counts is distinct from array[(select count(*) from public.grooming_requests),(select count(*) from public.request_matches),
      (select count(*) from public.groomer_notifications)] then raise exception 'preview published business rows';end if;
  assertions:=assertions+2;

  update public.groomer_profiles set rating_count=rating_count+1,rating_sum=coalesce(rating_sum,0)+5 where user_id=best;
  perform set_config('role','authenticated',true);
  second_page:=public.get_request_groomer_candidates_v1(scope,'fit',25,first_page->>'next_cursor');
  fresh_page:=public.get_request_groomer_candidates_v1(scope,'fit',25,null);
  if second_page->>'ranking_revision' is distinct from first_page->>'ranking_revision'
    or fresh_page->>'ranking_revision'=first_page->>'ranking_revision' then raise exception 'soft snapshot drift';end if;
  assertions:=assertions+1;
  perform set_config('role','none',true);
  begin
    update public.groomer_profiles set is_active=false where user_id=best;
    perform set_config('role','authenticated',true);
    perform public.get_request_groomer_candidates_v1(scope,'fit',25,first_page->>'next_cursor');
    raise exception 'hard removal did not invalidate';
  exception when sqlstate 'PT409' then if sqlerrm<>'list_changed' then raise;end if;assertions:=assertions+1;end;
  begin
    update public.pets set grooming_notes=(d->>'marker')||' changed' where id=pet and customer_id=customer;
    perform set_config('role','authenticated',true);
    perform public.get_request_groomer_candidates_v1(scope,'fit',25,null);
    raise exception 'changed source was accepted';
  exception when sqlstate 'PT409' then if sqlerrm<>'discovery_changed' then raise;end if;assertions:=assertions+1;end;
  begin
    update app_private.request_discovery_sessions set created_at=now()-interval '31 minutes',expires_at=now()-interval '1 minute'
      where id=(session->>'session_id')::uuid;
    perform set_config('role','authenticated',true);
    perform public.get_request_groomer_candidates_v1(scope,'fit',25,null);
    raise exception 'expired preview was accepted';
  exception when sqlstate 'PT409' then if sqlerrm<>'discovery_expired' then raise;end if;assertions:=assertions+1;end;
  perform set_config('role','authenticated',true);
  begin
    perform public.get_request_groomer_candidates_v1(scope,'distance',25,first_page->>'next_cursor');
    raise exception 'cross-sort cursor was accepted';
  exception when invalid_parameter_value then if sqlerrm<>'invalid_cursor' then raise;end if;assertions:=assertions+1;end;
  perform set_config('role','none',true);
  for i in 1..34 loop
    snap:=app_private.store_match_browse_snapshot(customer,'customer','TESTOPS:'||(d->>'run_id'),'fit',first_page,
      jsonb_build_object('privacy_revision',(select privacy_revision from app_private.match_ranking_config where singleton)));
  end loop;
  if (select count(*) from app_private.match_browse_snapshots where viewer_id=customer)>32 then raise exception 'snapshot budget exceeded';end if;
  assertions:=assertions+1;

  -- A fixed expected schedule accompanies adapter parity; two shared implementations alone are not an oracle.
  perform set_config('role','authenticated',true);
  select request_id into req from public.create_grooming_request_v4(gen_random_uuid(),input-'preference_time_zone_identifier','America/New_York');
  perform set_config('role','none',true);
  select * into r from public.grooming_requests where id=req;
  evaluation:=app_private.evaluate_context_eligibility(r,best,statement_timestamp(),zones);
  if evaluation->>'state'<>'estimated_fit' or (evaluation->>'service_start')::timestamptz<>start_at
    or (evaluation->>'service_end')::timestamptz<>start_at+interval '1 hour' then raise exception 'fixed schedule oracle failed';end if;
  if evaluation is distinct from app_private.evaluate_match_eligibility_with_zones(req,best,statement_timestamp(),zones)
    or app_private.evaluate_context_constraints(r,best,statement_timestamp()) is distinct from
      app_private.evaluate_match_constraints(req,best,statement_timestamp()) then raise exception 'qualification adapter drift';end if;
  score:=app_private.score_context_evidence(r,best,statement_timestamp(),null,zones);
  if score is distinct from app_private.score_match_evidence(req,best,statement_timestamp(),null,zones)
    or abs((score->>'d')::numeric-100)>0.000001
    or abs((score->>'s')::numeric-(0.60*(score->>'f')::numeric+0.25*(score->>'q')::numeric+0.15*(score->>'d')::numeric))>0.000001 then
    raise exception 'score adapter or independent formula oracle drift';end if;
  r.id:=null;r.status:=null;
  if app_private.evaluate_context_eligibility(r,best,statement_timestamp(),zones) is distinct from evaluation then
    raise exception 'private context requires public row';end if;
  r.pet_snapshot:=r.pet_snapshot-'size'-'weight_lbs';
  if app_private.evaluate_context_eligibility(r,best,statement_timestamp(),zones)->>'state'<>'assessment_required' then
    raise exception 'unknown pet facts guessed';end if;
  assertions:=assertions+5;
  perform set_config('app.testops_discovery_result',jsonb_build_object('assertions',assertions,
    'cohort_candidates',26,'last_candidate_first',true,'private_preview',true,'soft_freeze',true,
    'hard_invalidation',true,'source_invalidation',true,'fixed_schedule_oracle',true,'adapter_parity',true)::text,true);
end $$;
select current_setting('app.testops_discovery_result')::jsonb result;
rollback;
