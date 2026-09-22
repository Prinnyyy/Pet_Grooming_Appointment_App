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
  end loop;
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  select id into pet from public.save_my_pet_v2(null,jsonb_build_object('name','Discovery fixture','species','Dog',
    'breed','Unspecified','weight_lbs',20,'coat_type','short_smooth','matting_confirmed',false,
    'temperament','Friendly','grooming_notes',d->>'marker'),true);
  perform set_config('role','none',true);
  input:=jsonb_build_object('pet_id',pet,'service_type','full_groom','service_notes',d->>'marker',
    'preferred_start',start_at,'preferred_end',start_at+interval '6 hours','location_mode','groomer_comes_to_customer',
    'street_address','399 TestOps Synthetic Way','city','Key West','state','FL','zip_code','33040',
    'provider','apple_maps','country_code','US','latitude',24.5551,'longitude',-81.78,
    'resolution_source','manual_geocode','user_confirmed_at',now(),'preference_time_zone_identifier','America/New_York');
  perform set_config('role','authenticated',true);


  perform set_config('role','none',true);
  perform set_config('app.testops_live_result',jsonb_build_object('pet_id',pet,'input',input,
    'address_ids',(select jsonb_agg(g.address_location_id) from public.groomer_profiles g
      where g.user_id in(select value::uuid from jsonb_array_elements_text(d->'groomers'))))::text,true);
end $$;
select current_setting('app.testops_live_result')::jsonb result;
commit;
