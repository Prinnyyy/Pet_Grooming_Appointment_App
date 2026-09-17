import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const directory = "supabase/migrations";
const file = readdirSync(directory).find(name => name.endsWith("_t371_atomic_groomer_availability.sql"));
const sql = readFileSync(`${directory}/${file}`, "utf8");

test("availability API maps permanent revision conflicts to non-retryable HTTP 409", () => {
  const patch = readdirSync(directory).find(name => name.endsWith("_t371_availability_conflict_http_status.sql"));
  const wrapper = readFileSync(`${directory}/${patch}`, "utf8");
  assert.match(wrapper, /exception when serialization_failure/);
  assert.match(wrapper, /v_message = 'availability_revision_conflict'/);
  assert.match(wrapper, /errcode = 'PT409'/);
  assert.match(wrapper, /security invoker/);
  assert.match(wrapper, /end if;\s+raise;/);
});

test("availability save checks an owned snapshot under the acceptance lock before writes", () => {
  const save = sql.split("create function app_private.save_groomer_availability(")[1];
  assert.ok(save);
  assert.match(save, /auth\.uid\(\)/);
  assert.match(save, /is_anonymous/);
  assert.match(save, /71071/);
  assert.ok(save.indexOf("pg_advisory_xact_lock") < save.indexOf("availability_revision_conflict"));
  assert.ok(save.indexOf("availability_revision_conflict") < save.indexOf("delete from public.groomer_availability_windows"));
  assert.doesNotMatch(save, /(?:insert into|update|delete from) public\.bookings/i);
});

test("availability batch suppresses intermediate backfill and restores normal triggers", () => {
  assert.match(sql, /current_setting\('app\.availability_batch', true\)/);
  assert.match(sql, /set_config\('app\.availability_batch', '1', true\)/);
  assert.match(sql, /set_config\('app\.availability_batch', coalesce\(v_previous_batch, ''\), true\)/);
  assert.match(sql, /perform app_private\.backfill_request_matches_for_groomer\(v_user_id, 250\)/);
});

test("availability callers cannot fall back to partial table writes", () => {
  assert.match(sql, /revoke insert, update, delete on table[\s\S]*groomer_availability_windows[\s\S]*groomer_booking_preferences[\s\S]*groomer_time_off_windows[\s\S]*from public, anon, authenticated/);
  assert.match(sql, /revoke all on function app_private\.save_groomer_availability[\s\S]*from public, anon, authenticated/);
  assert.match(sql, /create function public\.save_groomer_availability/);
  assert.match(sql, /jsonb_typeof\(p_windows\)/);
  assert.match(sql, /pg_catalog\.pg_timezone_names/);
});
