import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationPath = join(
  process.cwd(),
  "supabase/migrations/20260706220736_t156_booking_handoff_read_state.sql",
);
const sql = readFileSync(migrationPath, "utf8");

test("T-156 migration stores customer-owned booking handoff acknowledgements", () => {
  assert.match(sql, /create table public\.customer_booking_handoff_acknowledgements\s*\(/i);
  assert.match(sql, /customer_id uuid not null\s+references public\.customer_profiles/i);
  assert.match(sql, /request_id uuid not null/i);
  assert.match(sql, /booking_id uuid not null/i);
  assert.match(sql, /acknowledged_at timestamptz not null default statement_timestamp\(\)/i);
  assert.match(sql, /constraint customer_booking_handoff_acknowledgements_request_key\s+unique \(customer_id, request_id\)/i);
  assert.match(
    sql,
    /foreign key \(request_id, customer_id\)\s+references public\.grooming_requests \(id, customer_id\)/i,
  );
  assert.match(sql, /alter table public\.customer_booking_handoff_acknowledgements\s+enable row level security/i);
  assert.match(sql, /grant select on table public\.customer_booking_handoff_acknowledgements\s+to authenticated/i);
  assert.match(
    sql,
    /grant insert \(customer_id, request_id, booking_id\)\s+on table public\.customer_booking_handoff_acknowledgements\s+to authenticated/i,
  );
  assert.match(sql, /create policy customer_booking_handoff_acknowledgements_insert_own_confirmed/i);
});

test("T-156 migration exposes controlled current-customer handoff read RPCs", () => {
  assert.match(sql, /create or replace function public\.get_acknowledged_booking_handoff_request_ids\(\)/i);
  assert.match(sql, /create or replace function public\.acknowledge_booking_handoff\(\s*p_request_id uuid,\s*p_booking_id uuid\s*\)/i);
  assert.match(sql, /security invoker/i);
  assert.match(sql, /set search_path = ''/i);
  assert.match(sql, /grant execute on function public\.get_acknowledged_booking_handoff_request_ids\(\)\s+to authenticated/i);
  assert.match(sql, /grant execute on function public\.acknowledge_booking_handoff\(uuid, uuid\)\s+to authenticated/i);
  assert.match(sql, /booking\.status = 'confirmed'/i);
  assert.match(sql, /on conflict on constraint\s+customer_booking_handoff_acknowledgements_request_key\s+do nothing/i);
  assert.match(sql, /acknowledgement\.booking_id = p_booking_id/i);
});
