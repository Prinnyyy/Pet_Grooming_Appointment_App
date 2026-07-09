import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t203_groomer_notifications.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-203 groomer notifications migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");

test("T-203 migration defines groomer-owned notification table and Data API grants", () => {
  assert.match(sql, /create table public\.groomer_notifications\s*\(/i);
  assert.match(sql, /groomer_id uuid not null\s+references public\.groomer_profiles/i);
  assert.match(sql, /kind text not null/i);
  assert.match(sql, /is_read boolean not null default false/i);
  assert.match(sql, /read_at timestamptz/i);
  assert.match(sql, /related_request_id uuid/i);
  assert.match(sql, /related_booking_id uuid/i);
  assert.match(sql, /related_offer_id uuid/i);
  assert.match(sql, /alter table public\.groomer_notifications enable row level security/i);
  assert.match(sql, /grant select on table public\.groomer_notifications to authenticated/i);
  assert.match(
    sql,
    /grant update \(is_read, read_at\) on table public\.groomer_notifications to authenticated/i,
  );
  assert.doesNotMatch(
    sql,
    /grant insert on table public\.groomer_notifications to authenticated/i,
  );
});

test("T-203 migration exposes controlled groomer notification read-state RPCs", () => {
  assert.match(sql, /create or replace function public\.mark_groomer_notification_read\(/i);
  assert.match(sql, /create or replace function public\.mark_all_groomer_notifications_read\(\)/i);
  assert.match(sql, /revoke all on function public\.mark_groomer_notification_read\(uuid\)/i);
  assert.match(sql, /grant execute on function public\.mark_groomer_notification_read\(uuid\) to authenticated/i);
  assert.match(sql, /grant execute on function public\.mark_all_groomer_notifications_read\(\) to authenticated/i);
});

test("T-203 migration creates groomer notifications from four v1 events", () => {
  for (const kind of [
    "new_match",
    "offer_accepted",
    "booking_cancelled_by_customer",
    "new_message",
  ]) {
    assert.match(sql, new RegExp(`'${kind}'`, "i"));
  }

  assert.match(sql, /after insert on public\.request_matches/i);
  assert.match(sql, /after insert on public\.bookings/i);
  assert.match(sql, /after update of status on public\.bookings/i);
  assert.match(sql, /after insert on public\.messages/i);
  assert.match(sql, /app_private\.create_groomer_notification/i);
});

test("T-203 migration keeps groomer notifications private and participant-scoped", () => {
  assert.match(sql, /create policy groomer_notifications_select_own/i);
  assert.match(sql, /create policy groomer_notifications_update_own_read_state/i);
  assert.match(sql, /groomer_id = \(select auth\.uid\(\)\)/i);
  assert.match(sql, /from public\.groomer_profiles/i);
  assert.match(sql, /not coalesce\(\(\(select auth\.jwt\(\)\) ->> 'is_anonymous'\)::boolean, false\)/i);
  assert.match(sql, /revoke all on function app_private\.create_groomer_notification/i);
  assert.doesNotMatch(sql, /grant execute on function app_private\.create_groomer_notification[^;]+authenticated/i);
});
