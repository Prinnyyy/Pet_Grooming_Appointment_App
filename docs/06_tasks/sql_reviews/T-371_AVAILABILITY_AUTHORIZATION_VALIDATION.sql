-- Authorized T-371 test only. All writes roll back; uses named existing seeds.
-- Seed metadata identifies fixtures, never production authorization decisions.
begin;
set local statement_timeout = '30s';
do $$
declare
  g1 uuid;
  g2 uuid;
  c1 uuid;
  own_snapshot jsonb;
  other_snapshot jsonb;
  saved_snapshot jsonb;
  windows jsonb;
  table_name text;
  command text;
begin
  select id into strict g1 from auth.users where raw_app_meta_data->>'beckon_seed_id' = 'BTG-001';
  select id into strict g2 from auth.users where raw_app_meta_data->>'beckon_seed_id' = 'BTG-002';
  select id into strict c1 from auth.users where raw_app_meta_data->>'beckon_seed_id' = 'BTC-001';
  if g1 = g2 or g1 = c1 or g2 = c1 then raise exception 'Distinct fixtures required'; end if;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', jsonb_build_object('sub', g2,
    'role', 'authenticated', 'is_anonymous', false)::text, true);
  other_snapshot := public.get_groomer_availability();
  perform set_config('request.jwt.claims', jsonb_build_object('sub', g1,
    'role', 'authenticated', 'is_anonymous', false)::text, true);
  own_snapshot := public.get_groomer_availability();
  if (own_snapshot->'preferences'->>'groomer_id')::uuid <> g1
    or exists (select 1 from jsonb_array_elements(own_snapshot->'windows') w
      where (w->>'groomer_id')::uuid <> g1)
    or exists (select 1 from jsonb_array_elements(own_snapshot->'time_off') t
      where (t->>'groomer_id')::uuid <> g1) then
    raise exception 'Snapshot leaked another owner';
  end if;
  select jsonb_agg(jsonb_build_object('weekday', d, 'start_time', '09:00:00',
    'end_time', '17:00:00', 'is_enabled', false, 'timezone', 'America/Los_Angeles',
    'groomer_id', g2) order by d) into windows from generate_series(1, 7) d;
  begin
    perform public.save_groomer_availability(other_snapshot->>'revision', windows,
      own_snapshot->'preferences', '[]'::jsonb);
    raise exception 'Another owner revision was accepted';
  exception when sqlstate 'PT409' then null;
  end;
  if public.get_groomer_availability() <> own_snapshot then
    raise exception 'Rejected cross-owner revision changed caller state';
  end if;

  -- Unknown payload ownership fields cannot override the authenticated owner.
  saved_snapshot := public.save_groomer_availability(own_snapshot->>'revision', windows,
    (own_snapshot->'preferences') || jsonb_build_object('groomer_id', g2), '[]'::jsonb);
  if (saved_snapshot->'preferences'->>'groomer_id')::uuid <> g1
    or exists (select 1 from jsonb_array_elements(saved_snapshot->'windows') w
      where (w->>'groomer_id')::uuid <> g1) then
    raise exception 'Payload ownership overrode authenticated identity';
  end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', g2,
    'role', 'authenticated', 'is_anonymous', false)::text, true);
  if public.get_groomer_availability() <> other_snapshot then
    raise exception 'Spoofed payload changed another groomer';
  end if;

  -- Even harmless/no-op direct writes must fail at the grant boundary.
  foreach table_name in array array['groomer_availability_windows',
    'groomer_booking_preferences', 'groomer_time_off_windows'] loop
    foreach command in array array[
      format('insert into public.%I default values', table_name),
      format('update public.%I set groomer_id = groomer_id where false', table_name),
      format('delete from public.%I where false', table_name)
    ] loop
      begin
        execute command;
        raise exception 'Direct write unexpectedly permitted: %', command;
      exception when insufficient_privilege then null;
      end;
    end loop;
  end loop;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', c1,
    'role', 'authenticated', 'is_anonymous', false)::text, true);
  begin
    perform public.get_groomer_availability();
    raise exception 'Customer read groomer snapshot';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.save_groomer_availability(own_snapshot->>'revision', windows,
      own_snapshot->'preferences', '[]'::jsonb);
    raise exception 'Customer saved groomer availability';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;
