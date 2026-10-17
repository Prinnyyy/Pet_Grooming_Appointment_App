import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const name = readdirSync("supabase/migrations").find(n => n.endsWith("_pet_profile_reliability.sql"));
const sql = name ? readFileSync(`supabase/migrations/${name}`, "utf8") : "";

test("pet creation has an owner-scoped durable receipt and serializes retries", () => {
  assert.match(sql, /create table app_private\.pet_create_operations/);
  assert.match(sql, /primary key\s*\(customer_id, operation_id\)/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /pet_operation_intent_changed/);
  assert.match(sql, /created_revision/);
  assert.match(sql, /require_request_customer\(\)/);
});

test("pet updates compare the owned row revision before reusing the fact writer", () => {
  assert.match(sql, /revision uuid not null default gen_random_uuid\(\)/);
  assert.match(sql, /for update/);
  assert.match(sql, /revision is distinct from p_expected_revision/);
  assert.match(sql, /errcode\s*=\s*'PT409',\s*message\s*=\s*'pet_revision_conflict'/);
  assert.ok(sql.indexOf("pet_revision_conflict") < sql.lastIndexOf("app_private.save_my_pet_v2("));
  assert.match(sql, /before update on public\.pets/);
});

test("old fact writers cannot bypass CAS while owner soft deletion remains available", () => {
  assert.match(sql, /pet_client_update_required/);
  assert.match(sql, /revoke all on function app_private\.save_my_pet_v2/);
  assert.match(sql, /revoke insert, update on table public\.pets/);
  assert.match(sql, /revoke insert \(%s\), update \(%s\) on public\.pets/);
  assert.match(sql, /grant update \(is_active, deleted_at\) on public\.pets to authenticated/);
  assert.match(sql, /pet_create_operations enable row level security/);
  assert.match(sql, /delete from app_private\.pet_create_operations where customer_id=new\.user_id/);
});
