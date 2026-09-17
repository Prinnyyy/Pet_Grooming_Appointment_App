-- Use a new location owned by the named test account; the outer transaction rolls it back.
do $$
declare
  v_owner uuid;
  v_location uuid;
  v_zone text;
  v_payload jsonb;
  v_saved jsonb;
begin
  select id into strict v_owner from auth.users
    where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  v_location := app_private.save_address_location_v2(v_owner,null,'apple_maps',null,'US',
    33.83,-117.92,'manual_geocode',statement_timestamp());
  select time_zone_identifier into v_zone from app_private.address_locations where id=v_location;
  if v_zone is not null then raise exception 'legacy_zone_fabricated'; end if;
  update app_private.address_locations set time_zone_identifier='America/Los_Angeles' where id=v_location;
  update app_private.address_locations set updated_at=statement_timestamp() where id=v_location;
  select time_zone_identifier into v_zone from app_private.address_locations where id=v_location;
  if v_zone is distinct from 'America/Los_Angeles' then raise exception 'unchanged_location_lost_zone'; end if;
  perform app_private.save_address_location_v2(v_owner,v_location,'apple_maps',null,'US',
    40.71,-74.01,'manual_geocode',statement_timestamp());
  select time_zone_identifier into v_zone from app_private.address_locations where id=v_location;
  if v_zone is not null then raise exception 'old_writer_kept_stale_zone'; end if;
  begin
    update app_private.address_locations set time_zone_identifier='Not/A_Zone' where id=v_location;
    raise exception 'invalid_zone_accepted';
  exception when sqlstate '22023' then null;
  end;
  if has_table_privilege('authenticated','app_private.address_locations','UPDATE') then
    raise exception 'private_location_write_exposed';
  end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_owner,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  v_payload := jsonb_build_object('line_1','770 S Harbor Blvd','city','Anaheim','state','CA',
    'zip_code','92805','provider','apple_maps','country_code','US','latitude',33.83,
    'longitude',-117.92,'resolution_source','manual_geocode',
    'user_confirmed_at',statement_timestamp(),'time_zone_identifier','America/Los_Angeles');
  perform public.save_my_profile_address_v3(v_payload);
  v_saved := public.get_my_profile_address_v3();
  if v_saved->>'timing_version' is distinct from '1'
     or v_saved#>>'{address,time_zone_identifier}' is distinct from 'America/Los_Angeles'
     or v_saved#>>'{address,line_1}' is distinct from '770 S Harbor Blvd' then
    raise exception 'versioned_address_round_trip_failed';
  end if;
  begin
    perform public.save_my_profile_address_v3(v_payload-'time_zone_identifier');
    raise exception 'missing_zone_write_allowed';
  exception when sqlstate '22023' then null;
  end;
  if public.get_my_profile_address_v3() is distinct from v_saved then
    raise exception 'invalid_address_partially_saved';
  end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_owner,
    'role','authenticated','is_anonymous',true)::text,true);
  begin
    perform public.save_my_profile_address_v3(v_payload);
    raise exception 'anonymous_address_write_allowed';
  exception when sqlstate '28000' then null;
  end;
  begin
    perform public.get_my_profile_address_v3();
    raise exception 'anonymous_address_read_allowed';
  exception when sqlstate '28000' then null;
  end;
  execute 'reset role';
  if has_function_privilege('anon','public.save_my_profile_address_v3(jsonb)','EXECUTE')
     or has_function_privilege('anon','public.get_my_profile_address_v3()','EXECUTE') then
    raise exception 'anonymous_rpc_execute_granted';
  end if;
end $$;
do $$
declare
  v_customer uuid;
  v_other uuid;
  v_other_location uuid;
  v_before jsonb;
  v_after jsonb;
  v_result uuid;
  v_payload jsonb;
  v_saved jsonb;
begin
  select id into strict v_customer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict v_other from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-002';
  select to_jsonb(p),p.address_location_id into strict v_before,v_other_location
    from public.customer_profiles p where user_id=v_other;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,
    'role','authenticated','is_anonymous',false,'user_metadata',jsonb_build_object('role','groomer'))::text,true);
  execute 'set local role authenticated';
  v_payload := jsonb_build_object('line_1','123 Test Street','city','New York','state','NY',
    'zip_code','10001','provider','apple_maps','country_code','US','latitude',40.71,
    'longitude',-74.01,'resolution_source','manual_geocode','user_confirmed_at',statement_timestamp(),
    'time_zone_identifier','America/New_York','owner_id',v_other,'address_location_id',v_other_location);
  v_result := public.save_my_profile_address_v3(v_payload);
  v_saved := public.get_my_profile_address_v3();
  if v_saved#>>'{address,time_zone_identifier}' is distinct from 'America/New_York'
     or v_saved#>>'{address,line_1}' is distinct from '123 Test Street' then
    raise exception 'customer_address_round_trip_failed';
  end if;
  execute 'reset role';
  if not exists(select 1 from app_private.address_locations where id=v_result and owner_id=v_customer) then
    raise exception 'customer_address_ownership_wrong';
  end if;
  select to_jsonb(p) into v_after from public.customer_profiles p where user_id=v_other;
  if v_before is distinct from v_after then raise exception 'foreign_profile_modified'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_other,
    'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  if public.get_my_profile_address_v3() is not distinct from v_saved then
    raise exception 'foreign_address_returned';
  end if;
  execute 'reset role';
end $$;
select 'T-374 address timezone rollback passed' as result;
