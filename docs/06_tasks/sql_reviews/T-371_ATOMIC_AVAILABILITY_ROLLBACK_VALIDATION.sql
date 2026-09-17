-- Requires explicit approval for rollback-only remote writes.
-- T-371 first executed 2026-09-07 in a rolled-back migration rehearsal.
-- Run after the T-371 migration in an approved test environment. The operator
-- must set test.groomer_id to a dedicated, authorized existing groomer UUID.
-- Fixture must already contain weekly windows, saved preferences, and time off;
-- empty baselines cannot prove that failed replacements restore deleted rows.
-- No arbitrary existing user is selected. Separate-session race tests are also
-- required; this script alone does not establish concurrency correctness.
begin;
do $$
declare
  v_groomer_id uuid := nullif(current_setting('test.groomer_id', true), '')::uuid;
  v_before jsonb;
  v_after jsonb;
  v_windows jsonb;
  v_preferences jsonb;
  v_bookings_before text;
  v_matches_before text;
  v_table text;
  v_case record;
  v_state text;
begin
  if v_groomer_id is null then
    raise exception 'Set test.groomer_id to an explicitly authorized test groomer before running';
  end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', v_groomer_id,
    'role', 'authenticated', 'is_anonymous', false)::text, true);
  execute 'set local role authenticated';
  v_before := public.get_groomer_availability();
  if jsonb_array_length(v_before->'windows') = 0
    or jsonb_array_length(v_before->'time_off') = 0
    or not exists (select 1 from public.groomer_booking_preferences
      where groomer_id = v_groomer_id) then
    raise exception 'Test fixture requires existing windows, preferences, and time off';
  end if;
  select md5(coalesce(jsonb_agg(to_jsonb(b) order by b.id)::text, '[]'))
    into v_bookings_before from public.bookings b where b.groomer_id = v_groomer_id;
  select md5(coalesce(jsonb_agg(to_jsonb(m) order by m.id)::text, '[]'))
    into v_matches_before from public.request_matches m where m.groomer_id = v_groomer_id;
  select jsonb_agg(jsonb_build_object('weekday', d, 'start_time', '09:00:00',
    'end_time', '17:00:00', 'is_enabled', false, 'timezone', 'America/Los_Angeles') order by d)
    into v_windows from generate_series(1, 7) d;
  v_preferences := jsonb_build_object('max_appointments_per_day', 4,
    'minimum_advance_notice_days', 0, 'auto_accept_bookings', false);

  -- Each constraint fails after its corresponding preceding writes have begun.
  -- Catch only the expected constraint error, never a test assertion or auth error.
  for v_case in
    select * from (values
      ('weekly insert', jsonb_set(v_windows, '{0,end_time}', '"08:00:00"'::jsonb),
        v_preferences, '[]'::jsonb, '23514'),
      ('preferences upsert', v_windows,
        jsonb_set(v_preferences, '{max_appointments_per_day}', '0'::jsonb), '[]'::jsonb, '23514'),
      ('time-off insert', v_windows, v_preferences,
        '[{"id":null,"title":"Invalid","start_date":"2099-01-01","end_date":"2099-01-02"}]'::jsonb, '23502')
    ) as cases(label, windows, preferences, time_off, expected_state)
  loop
    v_state := null;
    begin
      perform public.save_groomer_availability(v_before->>'revision', v_case.windows,
        v_case.preferences, v_case.time_off);
    exception when check_violation or not_null_violation then
      get stacked diagnostics v_state = returned_sqlstate;
    end;
    if v_state is distinct from v_case.expected_state then
      raise exception '%: expected SQLSTATE %, got %',
        v_case.label, v_case.expected_state, coalesce(v_state, 'successful save');
    end if;
    if public.get_groomer_availability() <> v_before then
      raise exception '%: partial availability save survived failure', v_case.label;
    end if;
    if current_setting('app.availability_batch', true) = '1' then
      raise exception '%: batch suppression leaked after failure', v_case.label;
    end if;
    if (select md5(coalesce(jsonb_agg(to_jsonb(m) order by m.id)::text, '[]'))
        from public.request_matches m where m.groomer_id = v_groomer_id) <> v_matches_before then
      raise exception '%: failed save changed request matches', v_case.label;
    end if;
    if (select md5(coalesce(jsonb_agg(to_jsonb(b) order by b.id)::text, '[]'))
        from public.bookings b where b.groomer_id = v_groomer_id) <> v_bookings_before then
      raise exception '%: failed save changed existing bookings', v_case.label;
    end if;
  end loop;

  v_after := public.save_groomer_availability(v_before->>'revision', v_windows,
    v_preferences, '[]'::jsonb);
  if v_after <> public.get_groomer_availability()
    or v_after->>'revision' = v_before->>'revision'
    or jsonb_array_length(v_after->'windows') <> 7 then
    raise exception 'Save did not return the authoritative new snapshot';
  end if;
  begin
    perform public.save_groomer_availability(v_before->>'revision', v_windows,
      v_preferences, '[]'::jsonb);
    raise exception 'Stale revision was accepted';
  exception when sqlstate 'PT409' then null;
  end;
  if public.get_groomer_availability() <> v_after then
    raise exception 'Stale revision changed saved availability';
  end if;
  if (select md5(coalesce(jsonb_agg(to_jsonb(b) order by b.id)::text, '[]'))
      from public.bookings b where b.groomer_id = v_groomer_id) <> v_bookings_before then
    raise exception 'Availability save changed existing bookings';
  end if;

  foreach v_table in array array['groomer_availability_windows',
    'groomer_booking_preferences', 'groomer_time_off_windows'] loop
    if has_table_privilege('authenticated', 'public.' || v_table, 'INSERT')
      or has_table_privilege('authenticated', 'public.' || v_table, 'UPDATE')
      or has_table_privilege('authenticated', 'public.' || v_table, 'DELETE') then
      raise exception 'Authenticated callers still have a partial-write path';
    end if;
  end loop;
  perform set_config('request.jwt.claims', '{}', true);
  begin
    perform public.get_groomer_availability();
    raise exception 'Unauthenticated read was accepted';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', v_groomer_id,
    'role', 'authenticated', 'is_anonymous', true)::text, true);
  begin
    perform public.save_groomer_availability(v_after->>'revision', v_windows,
      v_preferences, '[]'::jsonb);
    raise exception 'Anonymous save was accepted';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;
