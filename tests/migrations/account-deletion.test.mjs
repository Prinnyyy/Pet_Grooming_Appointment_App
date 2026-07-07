import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t160_account_deletion.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-160 account deletion migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");

test("T-160 migration tracks account deletion without direct authenticated table writes", () => {
  assert.match(sql, /create table public\.account_deletion_requests\s*\(/i);
  assert.match(sql, /user_id uuid not null\s+references public\.profiles/i);
  assert.match(sql, /status text not null default 'pending_auth_soft_delete'/i);
  assert.match(sql, /alter table public\.account_deletion_requests enable row level security/i);
  assert.match(sql, /grant select on table public\.account_deletion_requests to authenticated/i);
  assert.match(sql, /grant select,\s*insert,\s*update,\s*delete\s+on table public\.account_deletion_requests\s+to service_role/i);
  assert.doesNotMatch(sql, /grant\s+(?:insert|update|delete)[^;]+account_deletion_requests[^;]+authenticated/i);
});

test("T-160 migration exposes only controlled request and service-role status RPCs", () => {
  assert.match(sql, /create or replace function public\.request_account_deletion\(\)/i);
  assert.match(sql, /security invoker/i);
  assert.match(sql, /create or replace function app_private\.request_account_deletion\(\)/i);
  assert.match(
    sql,
    /create or replace function public\.record_account_deletion_auth_soft_deleted\(\s*p_deletion_request_id uuid\s*\)/i,
  );
  assert.match(
    sql,
    /create or replace function public\.record_account_deletion_failure\(\s*p_deletion_request_id uuid,\s*p_error text\s*\)/i,
  );
  assert.match(
    sql,
    /grant execute on function public\.request_account_deletion\(\)\s+to authenticated/i,
  );
  assert.match(
    sql,
    /grant execute on function public\.record_account_deletion_auth_soft_deleted\(uuid\)\s+to service_role/i,
  );
  assert.match(
    sql,
    /grant execute on function public\.record_account_deletion_failure\(uuid,\s*text\)\s+to service_role/i,
  );
  assert.doesNotMatch(
    sql,
    /grant execute on function public\.record_account_deletion_auth_soft_deleted\(uuid\)\s+to authenticated/i,
  );
  assert.doesNotMatch(
    sql,
    /grant execute on function public\.record_account_deletion_failure\(uuid,\s*text\)\s+to authenticated/i,
  );
});

test("T-160 migration anonymizes customer-owned PII while preserving marketplace history", () => {
  for (const table of [
    "profiles",
    "customer_profiles",
    "pets",
    "grooming_requests",
    "messages",
    "reviews",
  ]) {
    assert.match(sql, new RegExp(`public\\.${table}`, "i"));
  }

  assert.match(sql, /delete from public\.customer_notifications/i);
  assert.match(sql, /delete from public\.customer_push_tokens/i);
  assert.match(sql, /delete from public\.customer_booking_handoff_acknowledgements/i);
  assert.match(sql, /delete from public\.pet_photos/i);
  assert.match(sql, /delete from public\.request_photos/i);
  assert.match(sql, /service_notes = null/i);
  assert.match(sql, /photo_snapshot = '\[\]'::jsonb/i);
  assert.match(sql, /body = 'Message removed because this account was deleted\.'/i);
  assert.doesNotMatch(sql, /delete from public\.grooming_requests/i);
  assert.doesNotMatch(sql, /delete from public\.bookings/i);
});

test("T-160 migration deactivates groomer marketplace data without deleting historical rows", () => {
  for (const table of [
    "groomer_profiles",
    "groomer_services",
    "groomer_portfolio_photos",
    "groomer_fit_claims",
    "groomer_offers",
    "messages",
  ]) {
    assert.match(sql, new RegExp(`public\\.${table}`, "i"));
  }

  assert.match(sql, /is_active = false/i);
  assert.match(sql, /business_name = 'Deleted groomer'/i);
  assert.match(sql, /message = null/i);
  assert.doesNotMatch(sql, /delete from public\.groomer_offers/i);
  assert.doesNotMatch(sql, /delete from public\.bookings/i);
});
