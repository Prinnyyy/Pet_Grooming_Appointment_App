import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const directory = "supabase/migrations";
const file = readdirSync(directory).find(name => name.endsWith("_t374_service_timing.sql"));
const sql = file ? readFileSync(`${directory}/${file}`, "utf8") : "";

test("request timing guard freezes consent bounds without freezing cancellation or privacy fields", () => {
  const guard = sql.split("create function app_private.guard_request_timing_intent()")[1]?.split("create or replace function")[0];
  assert.ok(guard);
  for (const field of ["preferred_start", "preferred_end", "location_mode", "preference_time_zone_identifier"]) {
    assert.ok(guard.includes(`old.${field}`));
    assert.ok(guard.includes(`new.${field}`));
  }
  assert.match(guard, /published_request_timing_is_immutable/);
  assert.match(guard, /before insert or update on public.grooming_requests/);
  assert.doesNotMatch(guard, /old\.(status|service_notes|street_address|pet_snapshot)/);
});

test("versioned publication shares operation locking and replays before fresh timezone validation", () => {
  const body = sql.split("create function app_private.create_grooming_request_v4(")[1]?.split("create function public.create_grooming_request_v4(")[0];
  assert.ok(body);
  assert.match(body, /v_user::text \|\| ':' \|\| p_publish_operation_id::text,0/);
  assert.ok(body.indexOf("pg_advisory_xact_lock") < body.indexOf("from app_private.request_publish_operations"));
  assert.ok(body.indexOf("return query select v_request,v_count") < body.indexOf("request_reference_time_zone_required"));
  assert.match(body, /o.customer_id=v_user and o.operation_id=p_publish_operation_id/);
  assert.match(body, /set preference_time_zone_identifier=p_preference_time_zone_identifier/);
  assert.match(sql, /add column preference_time_zone_identifier text;/);
});

test("versioned address RPCs use authoritative role and attach timezone inside the location transaction", () => {
  const save = sql.split("create function app_private.save_my_profile_address_v3(p_address jsonb)")[1]?.split("create function app_private.get_my_profile_address_v3()")[0];
  assert.ok(save);
  assert.match(save, /select role into v_role from public.profiles where id=v_user/);
  assert.match(save, /authenticated_user_required/);
  assert.match(save, /confirmed_location_time_zone_required/);
  for (const role of ["customer", "groomer"]) {
    assert.ok(save.indexOf(`save_${role}_profile_address_v2`) < save.indexOf("set time_zone_identifier=v_zone"));
  }
  assert.match(save, /where id=v_location and owner_id=v_user/);
  assert.match(sql, /jsonb_build_object\('timing_version',1,'address'/);
  assert.match(sql, /public.get_my_profile_address_v3\(\) from public,anon,authenticated/);
  assert.match(sql, /public.get_my_profile_address_v3\(\) to authenticated/);
});

test("private address zones remain unknown until supplied and old location edits invalidate them", () => {
  assert.match(sql, /alter table app_private\.address_locations add column time_zone_identifier text;/);
  const guard = sql.split("create function app_private.guard_address_time_zone()")[1];
  assert.ok(guard);
  assert.match(guard, /is distinct from/);
  for (const field of ["owner_id", "provider", "place_id", "country_code", "latitude", "longitude", "resolution_source", "user_confirmed_at"]) {
    assert.ok(guard.includes(`new.${field}`));
    assert.ok(guard.includes(`old.${field}`));
  }
  assert.match(guard, /new.time_zone_identifier := null/);
  assert.match(guard, /pg_catalog.pg_timezone_names/);
  assert.match(guard, /before insert or update on app_private.address_locations/);
  assert.match(guard, /revoke all on function app_private.guard_address_time_zone\(\) from public,anon,authenticated/);
});

test("service timing preserves established duration bounds and explicit buffer bounds", () => {
  assert.match(sql, /p_duration_minutes is null or p_duration_minutes not between 15 and 720/);
  for (const field of ["preparation", "cleanup"]) {
    assert.ok(sql.includes(`p_${field} is null or p_${field} not between 0 and 120`));
  }
  for (const field of ["inbound_travel", "outbound_travel"]) {
    assert.ok(sql.includes(`p_${field} is null or p_${field} not between 0 and 180`));
  }
});

test("allocation uses elapsed minutes while notice uses an explicit local calendar date", () => {
  assert.match(sql, /make_interval\(mins => p_duration_minutes\)/);
  assert.match(sql, /timezone\(p_schedule_timezone,p_now\)::date \+ p_notice_days/);
  assert.match(sql, /greatest\(p_now \+ interval '5 minutes'/);
  assert.match(sql, /invalid_schedule_timezone/);
});

test("internal timing helpers revoke client execution and do not use security definer", () => {
  for (const name of ["service_timing_allocation", "service_timing_earliest_start", "remaining_service_window"]) {
    assert.match(sql, new RegExp(`revoke all on function app_private\\.${name}\\([^;]+from public, anon, authenticated;`));
    const body = sql.split(`create or replace function app_private.${name}(`)[1]?.split("create or replace function")[0];
    assert.ok(body, `${name} must be defined`);
    assert.doesNotMatch(body, /security definer/i);
  }
});

test("offer consent guard validates changed timing but preserves historical status transitions", () => {
  const guard = sql.split("create or replace function app_private.guard_offer_timing_consent()")[1];
  assert.ok(guard);
  assert.match(guard, /security definer set search_path = ''/);
  assert.match(guard, /v_seconds < 900 or v_seconds > 43200 or mod\(v_seconds,60\) <> 0/);
  assert.match(guard, /new.proposed_start < v_start or new.proposed_end > v_end/);
  assert.match(guard, /id=new.request_id and customer_id=new.customer_id/);
  assert.match(guard, /is not distinct from row\(old.request_id,old.customer_id,old.proposed_start,old.proposed_end\)/);
  assert.match(guard, /before insert or update on public.groomer_offers/);
  assert.match(guard, /revoke all on function app_private.guard_offer_timing_consent\(\) from public,anon,authenticated/);
});

test("new offer snapshots are authoritative, locked and immutable without inventing legacy values", () => {
  const body = sql.split("create or replace function app_private.snapshot_offer_timing()")[1];
  assert.ok(body);
  for (const field of ["applied_timing_buffers", "service_time_zone_identifier", "schedule_time_zone_identifier", "occupied_start", "occupied_end"]) {
    assert.match(sql, new RegExp(`add column ${field} (?:jsonb|text|timestamptz)[,;]`));
    assert.ok(body.includes(`new.${field}`));
    assert.ok(body.includes(`old.${field}`));
  }
  assert.ok(body.indexOf("pg_advisory_xact_lock") < body.indexOf("select timing_buffers"));
  assert.match(body, /timing_buffers_confirmation_required/);
  assert.match(body, /a.id=g.address_location_id and a.owner_id=g.user_id/);
  assert.match(body, /service_crosses_local_day/);
  assert.match(body, /offer_timing_snapshot_immutable/);
  assert.match(body, /before insert or update on public.groomer_offers/);
});

test("bookings consume offer snapshots and exclude buffered overlap with legacy service fallback", () => {
  const body = sql.split("create or replace function app_private.snapshot_booking_timing()")[1];
  assert.ok(body);
  assert.match(body, /new.scheduled_start is distinct from v_offer.proposed_start/);
  assert.match(body, /updated_timing_offer_required/);
  assert.match(body, /new.occupied_start := v_offer.occupied_start/);
  assert.match(body, /new.applied_timing_buffers := v_offer.applied_timing_buffers/);
  assert.match(body, /booking_timing_snapshot_immutable/);
  assert.match(body, /coalesce\(occupied_start,scheduled_start\),coalesce\(occupied_end,scheduled_end\),'\[\)'/);
  assert.match(body, /where \(status in \('confirmed','completed'\)\)/);
  assert.match(body, /revoke all on function app_private.snapshot_booking_timing\(\) from public,anon,authenticated/);
});

test("occupied time off uses full calendar dates and is rechecked for quotes and bookings", () => {
  const body = sql.split("create or replace function app_private.occupied_time_off_conflict(")[1]?.split("create or replace function")[0];
  assert.ok(body);
  assert.match(body, /pg_catalog.timezone\(v_zone,\(t.end_date\+1\)::timestamp\)/);
  assert.match(body, /&& tstzrange\(p_start,p_end,'\[\)'\)/);
  assert.equal(sql.match(/if app_private.occupied_time_off_conflict\(new.groomer_id,new.occupied_start,new.occupied_end\)/g)?.length, 2);
  assert.match(body, /from public,anon,authenticated/);
});

test("availability save protects booked occupancy before committing or backfilling", () => {
  const save = sql.split("create or replace function app_private.save_groomer_availability(")[1]?.split("alter table app_private.address_locations")[0];
  assert.ok(save);
  assert.ok(save.indexOf("perform app_private.validate_booked_coverage(v_user_id)") > save.indexOf("insert into public.groomer_time_off_windows"));
  assert.ok(save.indexOf("perform app_private.validate_booked_coverage(v_user_id)") < save.indexOf("backfill_request_matches_for_groomer"));
  const guard = sql.split("create or replace function app_private.validate_booked_coverage(")[1]?.split("create or replace function")[0];
  assert.ok(guard);
  assert.match(guard, /b.status in \('confirmed','completed'\)/);
  assert.match(guard, /coalesce\(b.occupied_end,b.scheduled_end\)>statement_timestamp\(\)/);
  assert.match(guard, /time_off_conflicts_with_booking_occupancy/);
  assert.match(guard, /pg_advisory_xact_lock/);
});

test("time off save rejects duplicate identities and mutates only owner-scoped differences", () => {
  const save = sql.split("create or replace function app_private.save_groomer_availability(")[1]?.split("alter table app_private.address_locations")[0];
  assert.ok(save);
  assert.match(save, /count\(distinct t.id\)/);
  assert.ok(save.indexOf("invalid_time_off_entries") < save.indexOf("delete from public.groomer_time_off_windows"));
  assert.match(save, /delete from public.groomer_time_off_windows existing where existing.groomer_id=v_user_id/);
  assert.match(save, /existing.groomer_id=v_user_id and existing.id=t.id/);
  assert.match(save, /row\(existing.title,existing.start_date,existing.end_date\)\s+is distinct from row\(t.title,t.start_date,t.end_date\)/);
});

test("direct availability writers validate final transaction state for both owners", () => {
  const guard = sql.split("create or replace function app_private.guard_changed_booked_coverage()")[1]?.split("create or replace function")[0];
  assert.ok(guard);
  assert.match(guard, /unnest\(array\[v_old,v_new\]\).*order by id/);
  assert.doesNotMatch(guard, /availability_batch/);
  for (const table of ["groomer_availability_windows", "groomer_time_off_windows"]) {
    assert.ok(guard.includes(`after insert or update or delete on public.${table}\ndeferrable initially deferred`));
  }
});

test("weekly coverage checks entire offset-stable segments in every writer path", () => {
  const body = sql.split("create or replace function app_private.weekly_hours_cover_interval(")[1]?.split("create or replace function")[0];
  const wrapper = sql.split("create or replace function app_private.occupied_weekly_hours_covered(")[1]?.split("create or replace function")[0];
  assert.ok(body);
  assert.match(body, /date_trunc\('second',p_start\)/);
  assert.match(body, /max\(starts\+elapsed\) as ends/);
  assert.match(body, /from wall group by starts::date/);
  assert.match(body, /d.ends>d.local_date\+v_ends\[/);
  assert.match(wrapper, /array_agg\(case when is_enabled then start_time end order by weekday\)/);
  assert.match(wrapper, /return app_private.weekly_hours_cover_interval\(p_start,p_end,v_zone,v_starts,v_ends\)/);
  assert.match(body, /wall as materialized/);
  assert.match(body, /from public,anon,authenticated/);
  assert.equal(sql.match(/if not app_private.occupied_weekly_hours_covered\(new.groomer_id,new.occupied_start,new.occupied_end\)/g)?.length, 2);
  assert.match(sql, /weekly_hours_conflict_with_booking_occupancy/);
});

test("writer prechecks preserve notice and quota without the old schedule-day restriction", () => {
  const gate = sql.split("create or replace function app_private.groomer_can_admit_service(")[1]?.split("CREATE OR REPLACE FUNCTION")[0];
  assert.ok(gate);
  assert.match(gate, /service_timing_earliest_start\(p_now,v_notice,v_zone\)/);
  assert.match(gate, /coalesce\(b.occupied_start,b.scheduled_start\)<p_end/);
  assert.match(gate, /pg_catalog.timezone\(v_zone,b.scheduled_start\)::date=pg_catalog.timezone\(v_zone,p_start\)::date/);
  assert.doesNotMatch(gate, /local_start::date = .*local_end::date/);
  assert.equal(sql.match(/if not app_private.groomer_can_admit_service\(/g)?.length, 2);
  assert.doesNotMatch(sql, /if not app_private.groomer_is_available_for_range\(/);
});

test("batch coverage validates the schedule once without dropping bookings after a page limit", () => {
  const body = sql.split("create or replace function app_private.validate_booked_coverage(")[1]?.split("create or replace function")[0];
  assert.ok(body);
  assert.match(body, /pg_advisory_xact_lock/);
  assert.equal(body.match(/from pg_catalog.pg_timezone_names/g)?.length, 1);
  assert.match(body, /app_private.weekly_hours_cover_interval\(/);
  assert.match(body, /t\.end_date\+1/);
  assert.doesNotMatch(body, /app_private\.occupied_(weekly_hours_covered|time_off_conflict)\(/);
  assert.doesNotMatch(body, /\blimit\s+\d+/i);
  assert.match(body, /coalesce\(b.occupied_end,b.scheduled_end\)>statement_timestamp\(\)/);
});

test("buffer settings are nullable until confirmed and participate in the atomic availability save", () => {
  assert.match(sql, /add column timing_buffers jsonb;/);
  assert.match(sql, /check \(timing_buffers is null or app_private\.valid_timing_buffers\(timing_buffers\)\)/);
  assert.match(sql, /'timing_version',1/);
  const save = sql.split("create or replace function app_private.save_groomer_availability(")[1];
  assert.ok(save);
  assert.ok(save.indexOf("pg_advisory_xact_lock") < save.indexOf("v_snapshot :="));
  assert.ok(save.indexOf("invalid_timing_buffers") < save.indexOf("insert into public.groomer_availability_windows"));
  assert.match(save, /on conflict\(groomer_id,weekday\) do update/);
  assert.match(save, /is distinct from row\(excluded.start_time,excluded.end_time,excluded.is_enabled,excluded.timezone\)/);
  assert.doesNotMatch(save, /delete from public.groomer_availability_windows/);
  assert.match(save, /nullif\(v_snapshot#>'\{preferences,timing_buffers\}','null'::jsonb\)/);
  assert.match(save, /timing_buffers=excluded\.timing_buffers/);
});
