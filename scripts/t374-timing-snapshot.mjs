import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const snapshotSQL = `select
  (select md5(coalesce(jsonb_agg(to_jsonb(c) order by c.id),'[]'::jsonb)::text) from public.conversations c
    where c.customer_id=(select id from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001')) as conversations,
  (select md5(coalesce(jsonb_agg(to_jsonb(m) order by m.id),'[]'::jsonb)::text) from public.messages m
    join public.conversations c on c.id=m.conversation_id
    where c.customer_id=(select id from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001')) as messages,
  ${[
  "groomer_availability_windows", "groomer_booking_preferences", "groomer_time_off_windows", "request_matches", "bookings", "groomer_offers",
].map(table => `(select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb)::text)
  from public.${table} t where groomer_id=(select id from auth.users
    where raw_app_meta_data->>'beckon_seed_id'='BTG-001')) as ${table}`).join(",")},
  (select md5(string_agg(pg_get_functiondef(p.oid),'|' order by p.proname)) from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private'
    and p.proname in ('get_groomer_availability','save_groomer_availability')) as availability_functions,
  (select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.id),'[]'::jsonb)::text)
    from app_private.address_locations t where owner_id in (select id from auth.users
      where raw_app_meta_data->>'beckon_seed_id' in ('BTG-001','BTC-001','BTC-002'))) as address_locations,
  (select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.user_id),'[]'::jsonb)::text)
    from public.customer_profiles t where user_id in (select id from auth.users
      where raw_app_meta_data->>'beckon_seed_id' in ('BTC-001','BTC-002'))) as customer_profiles,
  (select count(*) from information_schema.columns where table_schema='app_private'
    and table_name='address_locations' and column_name='time_zone_identifier') as address_zone_columns,
  (select count(*) from pg_trigger where tgrelid='app_private.address_locations'::regclass
    and tgname='address_locations_guard_time_zone') as address_zone_triggers,
  to_regprocedure('app_private.guard_address_time_zone()')::text as address_zone_guard,
  (select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.user_id),'[]'::jsonb)::text)
    from public.groomer_profiles t where user_id=(select id from auth.users
      where raw_app_meta_data->>'beckon_seed_id'='BTG-001')) as groomer_profile,
  (select md5(coalesce(string_agg(pg_get_functiondef(p.oid),'|' order by n.nspname,p.proname),''))
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','app_private')
      and p.proname in ('get_my_profile_address_v3','save_my_profile_address_v3','create_grooming_request_v4')) as versioned_functions,
  (select count(*) from information_schema.columns where table_schema='public'
    and table_name='grooming_requests' and column_name='preference_time_zone_identifier') as preference_zone_columns,
  to_regprocedure('app_private.guard_request_timing_intent()')::text as request_timing_guard,
  to_regprocedure('app_private.guard_offer_timing_consent()')::text as offer_timing_guard,
  to_regprocedure('app_private.snapshot_offer_timing()')::text as offer_snapshot_function,
  to_regprocedure('app_private.snapshot_booking_timing()')::text as booking_snapshot_function,
  to_regprocedure('app_private.occupied_time_off_conflict(uuid,timestamptz,timestamptz)')::text as occupied_time_off_function,
  to_regprocedure('app_private.occupied_weekly_hours_covered(uuid,timestamptz,timestamptz)')::text as occupied_weekly_hours_function,
  to_regprocedure('app_private.weekly_hours_cover_interval(timestamptz,timestamptz,text,time[],time[])')::text as weekly_interval_function,
  to_regprocedure('app_private.validate_booked_coverage(uuid)')::text as booked_coverage_function,
  to_regprocedure('app_private.guard_changed_booked_coverage()')::text as changed_coverage_function,
  (select jsonb_agg(pg_get_triggerdef(oid) order by tgname) from pg_trigger
    where tgname in ('groomer_weekly_hours_preserve_booking_coverage',
      'groomer_time_off_preserve_booking_coverage')) as booked_coverage_triggers,
  to_regprocedure('app_private.groomer_can_admit_service(uuid,timestamptz,timestamptz,timestamptz)')::text as service_admission_function,
  (select md5(string_agg(pg_get_functiondef(p.oid),'|' order by p.proname)) from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private'
      and p.proname in ('create_groomer_offer','guard_booking_admission')) as admission_functions,
  (select count(*) from information_schema.columns where table_schema='public'
    and table_name='bookings' and column_name in ('applied_timing_buffers','service_time_zone_identifier',
      'schedule_time_zone_identifier','occupied_start','occupied_end')) as booking_snapshot_columns,
  (select count(*) from pg_trigger where tgrelid='public.bookings'::regclass
    and tgname='bookings_snapshot_timing') as booking_snapshot_triggers,
  (select count(*) from pg_constraint where conrelid='public.bookings'::regclass
    and conname='bookings_no_groomer_occupied_overlap') as booking_occupied_constraints,
  (select count(*) from information_schema.columns where table_schema='public'
    and table_name='groomer_offers' and column_name in ('applied_timing_buffers','service_time_zone_identifier',
      'schedule_time_zone_identifier','occupied_start','occupied_end')) as offer_snapshot_columns,
  (select count(*) from pg_trigger where tgrelid='public.groomer_offers'::regclass
    and tgname='groomer_offers_snapshot_timing') as offer_snapshot_triggers,
  (select count(*) from pg_trigger where tgrelid='public.groomer_offers'::regclass
    and tgname='groomer_offers_guard_timing_consent') as offer_timing_triggers,
  (select count(*) from pg_trigger where tgrelid='public.grooming_requests'::regclass
    and tgname='grooming_requests_guard_timing_intent') as request_timing_triggers,
  (select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.id),'[]'::jsonb)::text)
    from public.grooming_requests t where customer_id=(select id from auth.users
      where raw_app_meta_data->>'beckon_seed_id'='BTC-001')) as customer_requests,
  (select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.operation_id),'[]'::jsonb)::text)
    from app_private.request_publish_operations t where customer_id=(select id from auth.users
      where raw_app_meta_data->>'beckon_seed_id'='BTC-001')) as publish_operations,
  (select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.id),'[]'::jsonb)::text)
    from public.request_matches t where customer_id=(select id from auth.users
      where raw_app_meta_data->>'beckon_seed_id'='BTC-001')) as customer_matches;`;

export function captureT374TimingSnapshot() {
  assert.equal(readFileSync("supabase/.temp/project-ref", "utf8").trim(), "lqmasbuqzvcvtawonjlb");
  const result = spawnSync("supabase", ["db", "query", "--linked", "--output", "json", snapshotSQL], {
    encoding: "utf8", timeout: 120_000,
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  assert.equal(result.status, 0, "Read-only timing snapshot failed; restoration is unverified");
  const rows = JSON.parse(result.stdout).rows;
  assert.ok(Array.isArray(rows) && rows.length === 1, "Invalid timing snapshot response");
  return rows;
}
