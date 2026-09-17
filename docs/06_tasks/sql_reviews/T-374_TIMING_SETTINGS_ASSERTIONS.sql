-- Named TestOps owner only; the runner rolls back every schedule, match and setting write.
do $$
declare
  v_groomer uuid;
  v_time_off uuid := gen_random_uuid();
  v_new_time_off uuid := gen_random_uuid();
  v_snapshot jsonb;
  v_saved jsonb;
  v_windows jsonb;
  v_items jsonb;
  v_buffers jsonb := '{"preparation_minutes":0,"cleanup_minutes":15,"inbound_travel_minutes":30,"outbound_travel_minutes":0}';
begin
  select id into strict v_groomer from auth.users
    where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  insert into public.groomer_time_off_windows(id,groomer_id,title,start_date,end_date,created_at,updated_at)
    values(v_time_off,v_groomer,'T-374 retained time off','2099-02-01','2099-02-01',
      '2020-01-01T00:00:00Z','2020-01-01T00:00:00Z');
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_groomer,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  v_snapshot := public.get_groomer_availability();
  if v_snapshot->>'timing_version' is distinct from '1' then
    raise exception 'timing_capability_missing';
  end if;
  select jsonb_agg(jsonb_build_object('weekday',d,'start_time','08:00','end_time','20:00',
    'is_enabled',true,'timezone','America/Los_Angeles') order by d)
    into v_windows from generate_series(1,7) d;
  v_saved := public.save_groomer_availability(v_snapshot->>'revision',v_windows,
    (v_snapshot->'preferences') || jsonb_build_object('timing_buffers',v_buffers),v_snapshot->'time_off');
  if v_saved#>'{preferences,timing_buffers}' is distinct from v_buffers then
    raise exception 'explicit_buffer_values_not_saved';
  end if;
  if v_saved->'time_off' is distinct from v_snapshot->'time_off' then
    raise exception 'unchanged_time_off_rewritten_by_save';
  end if;
  v_snapshot := v_saved;
  begin
    perform public.save_groomer_availability(v_snapshot->>'revision',v_windows,
      (v_snapshot->'preferences') || jsonb_build_object('timing_buffers',v_buffers-'outbound_travel_minutes'),
      v_snapshot->'time_off');
    raise exception 'partial_buffers_accepted';
  exception when sqlstate '22023' then null;
  end;
  if public.get_groomer_availability() is distinct from v_snapshot then
    raise exception 'invalid_buffers_partially_changed_schedule';
  end if;
  begin
    perform public.save_groomer_availability('stale',v_windows,v_snapshot->'preferences',v_snapshot->'time_off');
    raise exception 'stale_revision_accepted';
  exception when sqlstate 'PT409' then null;
  end;
  v_saved := public.save_groomer_availability(v_snapshot->>'revision',v_windows,
    (v_snapshot->'preferences')-'timing_buffers',v_snapshot->'time_off');
  if v_saved#>'{preferences,timing_buffers}' is distinct from v_buffers then
    raise exception 'older_client_erased_confirmed_buffers';
  end if;
  begin
    perform public.save_groomer_availability(v_saved->>'revision',v_windows,v_saved->'preferences',
      (v_saved->'time_off') || jsonb_build_array(v_saved->'time_off'->0));
    raise exception 'duplicate_time_off_id_accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'invalid_time_off_entries' then raise; end if;
  end;
  if public.get_groomer_availability() is distinct from v_saved then
    raise exception 'duplicate_time_off_partially_changed_schedule';
  end if;
  begin
    perform public.save_groomer_availability(v_saved->>'revision',v_windows,v_saved->'preferences',
      (v_saved->'time_off') || jsonb_build_array(jsonb_build_object('title','Missing identity',
        'start_date','2099-04-01','end_date','2099-04-01')));
    raise exception 'missing_time_off_id_accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'invalid_time_off_entries' then raise; end if;
  end;
  if public.get_groomer_availability() is distinct from v_saved then
    raise exception 'missing_time_off_id_partially_changed_schedule';
  end if;
  v_saved := public.save_groomer_availability(v_saved->>'revision',v_windows,v_saved->'preferences',
    (v_saved->'time_off') || jsonb_build_array(jsonb_build_object('id',v_new_time_off,
      'title','T-374 new time off','start_date','2099-04-01','end_date','2099-04-02')));
  if not exists(select 1 from jsonb_array_elements(v_saved->'time_off') t
      where t->>'id'=v_new_time_off::text and t->>'title'='T-374 new time off'
        and t->>'start_date'='2099-04-01' and t->>'end_date'='2099-04-02') then
    raise exception 'new_time_off_not_saved';
  end if;
  select jsonb_agg(case when t->>'id'=v_time_off::text
    then t || jsonb_build_object('title','T-374 updated time off') else t end)
    into v_items from jsonb_array_elements(v_saved->'time_off') t;
  v_saved := public.save_groomer_availability(v_saved->>'revision',v_windows,v_saved->'preferences',v_items);
  if not exists(select 1 from jsonb_array_elements(v_saved->'time_off') t
      where t->>'id'=v_time_off::text and t->>'title'='T-374 updated time off'
        and (t->>'created_at')::timestamptz='2020-01-01T00:00:00Z'::timestamptz) then
    raise exception 'time_off_update_recreated_existing_record';
  end if;
  select jsonb_agg(case when t->>'id'=v_time_off::text
    then t || jsonb_build_object('title','Must roll back') else t end)
    into v_items from jsonb_array_elements(v_saved->'time_off') t;
  begin
    perform public.save_groomer_availability(v_saved->>'revision',v_windows,v_saved->'preferences',
      v_items || jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'title','Invalid dates',
        'start_date','2099-03-02','end_date','2099-03-01')));
    raise exception 'invalid_time_off_dates_accepted';
  exception when check_violation then null;
  end;
  if public.get_groomer_availability() is distinct from v_saved then
    raise exception 'invalid_time_off_insert_partially_changed_schedule';
  end if;
  select coalesce(jsonb_agg(t),'[]'::jsonb) into v_items
    from jsonb_array_elements(v_saved->'time_off') t
    where t->>'id' not in (v_time_off::text,v_new_time_off::text);
  v_saved := public.save_groomer_availability(v_saved->>'revision',v_windows,v_saved->'preferences',v_items);
  if exists(select 1 from jsonb_array_elements(v_saved->'time_off') t
      where t->>'id' in (v_time_off::text,v_new_time_off::text)) then
    raise exception 'removed_time_off_remained_saved';
  end if;
  begin
    update public.groomer_booking_preferences set timing_buffers=null where groomer_id=v_groomer;
    raise exception 'direct_buffer_write_allowed';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';
end $$;
select 'T-374 timing settings rollback passed' as result;
