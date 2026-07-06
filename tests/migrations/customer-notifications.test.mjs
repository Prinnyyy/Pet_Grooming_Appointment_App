import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationPath = join(
  process.cwd(),
  "supabase/migrations/20260706203710_t153_customer_notifications.sql",
);
const sql = readFileSync(migrationPath, "utf8");

test("T-153 migration defines customer notification table and ownership grants", () => {
  assert.match(sql, /create table public\.customer_notifications\s*\(/i);
  assert.match(sql, /customer_id uuid not null\s+references public\.customer_profiles/i);
  assert.match(sql, /kind text not null/i);
  assert.match(sql, /is_read boolean not null default false/i);
  assert.match(sql, /read_at timestamptz/i);
  assert.match(sql, /related_request_id uuid/i);
  assert.match(sql, /related_booking_id uuid/i);
  assert.match(sql, /related_offer_id uuid/i);
  assert.match(sql, /alter table public\.customer_notifications enable row level security/i);
  assert.match(sql, /grant select on table public\.customer_notifications to authenticated/i);
  assert.match(
    sql,
    /grant update \(is_read, read_at\) on table public\.customer_notifications to authenticated/i,
  );
  assert.doesNotMatch(
    sql,
    /grant insert on table public\.customer_notifications to authenticated/i,
  );
});

test("T-153 migration exposes controlled read-state RPCs", () => {
  assert.match(sql, /create or replace function public\.mark_customer_notification_read\(/i);
  assert.match(sql, /create or replace function public\.mark_all_customer_notifications_read\(\)/i);
  assert.match(sql, /revoke all on function public\.mark_customer_notification_read\(uuid\)/i);
  assert.match(sql, /grant execute on function public\.mark_customer_notification_read\(uuid\) to authenticated/i);
  assert.match(sql, /grant execute on function public\.mark_all_customer_notifications_read\(\) to authenticated/i);
});

test("T-153 migration creates notifications from the four v1 customer events", () => {
  for (const kind of [
    "request_published",
    "request_cancelled",
    "booking_confirmed",
    "booking_cancelled",
  ]) {
    assert.match(sql, new RegExp(`'${kind}'`, "i"));
  }

  assert.match(sql, /after insert on public\.grooming_requests/i);
  assert.match(sql, /after update of status on public\.grooming_requests/i);
  assert.match(sql, /after insert on public\.bookings/i);
  assert.match(sql, /after update of status on public\.bookings/i);
  assert.match(sql, /app_private\.create_customer_notification/i);
});
