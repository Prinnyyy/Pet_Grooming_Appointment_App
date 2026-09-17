-- Installed-schema probe; only BTC-001/BTG-001 change, always inside rollback.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
create temporary table t385_samples(label text, calls integer, elapsed_ms numeric, matches integer, payload_bytes integer);
do $$
declare
  c uuid; g uuid; pet uuid; address uuid:=gen_random_uuid(); request uuid:=gen_random_uuid();
  starts timestamptz:=timezone('America/Los_Angeles',
    (timezone('America/Los_Angeles',statement_timestamp())::date+10)+time '09:00');
  started timestamptz; elapsed numeric; n integer; matches integer; bytes integer; result jsonb;
begin
  select id into strict c from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict g from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict pet from public.pets where customer_id=c and is_active and deleted_at is null order by id limit 1;
  if exists(select 1 from public.bookings where groomer_id=g and status in ('confirmed','completed')) then
    raise exception 'Release probe requires idle named groomer fixture';
  end if;
  perform set_config('app.availability_batch','1',true);
  update public.groomer_profiles set service_location_modes=array['groomer_comes_to_customer'] where user_id=g;
  insert into app_private.address_locations(id,owner_id,provider,country_code,latitude,longitude,
    resolution_source,user_confirmed_at,time_zone_identifier)
  select address,c,'apple_maps','US',a.latitude,a.longitude,'manual_geocode',statement_timestamp(),'America/Los_Angeles'
  from public.groomer_profiles p join app_private.address_locations a on a.id=p.address_location_id and a.owner_id=g
  where p.user_id=g;
  if not found then raise exception 'Missing owned coordinate-backed fixture'; end if;
  insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days,timing_buffers)
  values(g,4,0,'{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}')
  on conflict(groomer_id) do update set max_appointments_per_day=4,minimum_advance_notice_days=0,timing_buffers=excluded.timing_buffers;
  insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
  select g,d,'08:00'::time,'13:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
  on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,is_enabled=true,timezone=excluded.timezone;
  delete from public.groomer_time_off_windows where groomer_id=g;
  update public.groomer_services set accepted_pet_sizes=array['M'],duration_minutes=60,is_active=true
  where groomer_id=g and service_type='full_groom';
  if not found then raise exception 'Missing full-groom fixture'; end if;
  insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,service_type,
    preferred_start,preferred_end,city,state,zip_code,street_address,location_mode,status,expires_at,
    preference_time_zone_identifier,address_location_id)
  values(request,c,pet,jsonb_build_object('id',pet,'size','M','species','Dog'),'[]','full_groom',
    starts,starts+interval '3 hours','Fullerton','CA','92832','T385 rollback fixture',
    'groomer_comes_to_customer','open',statement_timestamp()+interval '1 day','America/Los_Angeles',address);
  result:=app_private.evaluate_match_eligibility(request,g,statement_timestamp());
  if result->>'state' is distinct from 'estimated_fit' then raise exception 'Known feasible fixture rejected: %',result; end if;
  started:=clock_timestamp();
  for n in 1..25 loop perform app_private.create_request_matches_for_request(request,g); end loop;
  elapsed:=extract(epoch from clock_timestamp()-started)*1000;
  if elapsed>3500 then raise exception 'G-10 open-window budget exceeded: % ms',elapsed; end if;
  insert into t385_samples values('open_window',25,elapsed,1,null);
  insert into public.groomer_time_off_windows(groomer_id,title,start_date,end_date)
  values(g,'T385 rollback blocked window',timezone('America/Los_Angeles',starts)::date,
    timezone('America/Los_Angeles',starts)::date);
  started:=clock_timestamp();
  for n in 1..25 loop
    if app_private.create_request_matches_for_request(request,g)<>0 then raise exception 'Occupied window matched'; end if;
  end loop;
  elapsed:=extract(epoch from clock_timestamp()-started)*1000;
  if elapsed>2000 then raise exception 'G-10 closed-window budget exceeded: % ms',elapsed; end if;
  insert into t385_samples values('closed_window',25,elapsed,0,null);
  delete from public.groomer_time_off_windows where groomer_id=g;
  started:=clock_timestamp();
  matches:=app_private.create_request_matches_for_request(request,null);
  elapsed:=extract(epoch from clock_timestamp()-started)*1000;
  select octet_length(coalesce(jsonb_agg(to_jsonb(m)),'[]'::jsonb)::text) into bytes
  from public.request_matches m where m.request_id=request;
  insert into t385_samples values('current_marketplace_pool',1,elapsed,matches,bytes);
end $$;
select * from t385_samples order by label;
rollback;
