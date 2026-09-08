do $$
declare
  v_customer uuid;
  v_pet uuid;
  v_operation uuid := gen_random_uuid();
  v_payload jsonb;
  v_first record;
  v_replay record;
  v_assignment text;
  v_before jsonb;
  v_legacy_operation uuid := gen_random_uuid();
  v_legacy record;
begin
  select id into strict v_customer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict v_pet from public.pets where customer_id=v_customer order by id limit 1;
  v_payload := jsonb_build_object('pet_id',v_pet,'service_type','full_groom',
    'preferred_start',statement_timestamp()+interval '2 days',
    'preferred_end',statement_timestamp()+interval '2 days 2 hours',
    'location_mode','groomer_comes_to_customer','street_address','770 S Harbor Blvd',
    'city','Fullerton','state','CA','zip_code','92832','provider','apple_maps','country_code','US',
    'latitude',33.87,'longitude',-117.92,'resolution_source','manual_geocode',
    'user_confirmed_at',statement_timestamp());
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  select * into strict v_first from public.create_grooming_request_v4(v_operation,v_payload,'America/Los_Angeles');
  select * into strict v_replay from public.create_grooming_request_v4(v_operation,'{}',null);
  if v_first.request_id is distinct from v_replay.request_id
     or v_first.match_count is distinct from v_replay.match_count then
    raise exception 'timing_publish_replay_changed';
  end if;
  begin
    perform public.create_grooming_request_v4(gen_random_uuid(),v_payload,'Invalid/Zone');
    raise exception 'invalid_reference_zone_accepted';
  exception when sqlstate '22023' then null;
  end;
  execute 'reset role';
  if not exists(select 1 from public.grooming_requests where id=v_first.request_id
      and preference_time_zone_identifier='America/Los_Angeles') then
    raise exception 'request_reference_zone_missing';
  end if;
  select to_jsonb(r) into v_before from public.grooming_requests r where id=v_first.request_id;
  foreach v_assignment in array array[
    'preferred_start=preferred_start+interval ''1 hour''',
    'preferred_end=preferred_end+interval ''1 hour''',
    'preference_time_zone_identifier=''America/New_York''',
    'preference_time_zone_identifier=null',
    'location_mode=''customer_comes_to_groomer'',travel_radius_miles=5'
  ] loop
    begin
      execute 'update public.grooming_requests set ' || v_assignment || ' where id=$1'
        using v_first.request_id;
      raise exception 'published_timing_mutation_allowed: %',v_assignment;
    exception when sqlstate '23514' then null;
    end;
    if (select to_jsonb(r) from public.grooming_requests r where id=v_first.request_id) is distinct from v_before then
      raise exception 'rejected_intent_change_mutated_request';
    end if;
  end loop;
  update public.grooming_requests set status='cancelled',service_notes=null
    where id=v_first.request_id;
  execute 'set local role authenticated';
  select * into strict v_legacy from public.create_grooming_request_v3(
    v_legacy_operation,v_pet,'full_groom',null,
    (v_payload->>'preferred_start')::timestamptz,(v_payload->>'preferred_end')::timestamptz,
    'groomer_comes_to_customer','770 S Harbor Blvd','Fullerton','CA','92832',null,
    'apple_maps',null,'US',33.87,-117.92,'manual_geocode',statement_timestamp(),null);
  select * into strict v_replay from public.create_grooming_request_v4(v_legacy_operation,'{}','America/New_York');
  if v_legacy.request_id is distinct from v_replay.request_id
     or v_legacy.match_count is distinct from v_replay.match_count then
    raise exception 'cross_version_receipt_changed';
  end if;
  execute 'reset role';
  if exists(select 1 from public.grooming_requests where id=v_legacy.request_id
      and preference_time_zone_identifier is not null) then
    raise exception 'legacy_receipt_relabelled_with_new_zone';
  end if;
end $$;
select 'T-374 versioned publication rollback passed' as result;
