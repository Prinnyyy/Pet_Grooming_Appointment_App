import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t157_customer_push_notifications.sql"))
  .sort()
  .at(-1);
const validationFixFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t157_fix_push_token_validation.sql"))
  .sort()
  .at(-1);
const registerConflictFixFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t157_fix_push_token_register_conflict.sql"))
  .sort()
  .at(-1);
const constraintFixFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t157_fix_push_token_constraint.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-157 customer push notification migration");
assert.ok(validationFixFile, "missing T-157 customer push token validation fix migration");
assert.ok(registerConflictFixFile, "missing T-157 customer push token register conflict fix migration");
assert.ok(constraintFixFile, "missing T-157 customer push token constraint fix migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");
const validationFixSql = readFileSync(join(migrationsDir, validationFixFile), "utf8");
const registerConflictFixSql = readFileSync(join(migrationsDir, registerConflictFixFile), "utf8");
const constraintFixSql = readFileSync(join(migrationsDir, constraintFixFile), "utf8");

test("T-157 migration adds customer-owned APNs token registrations without direct client table access", () => {
  assert.match(sql, /create table public\.customer_push_tokens\s*\(/i);
  assert.match(sql, /customer_id uuid not null\s+references public\.customer_profiles/i);
  assert.match(sql, /token text not null/i);
  assert.match(sql, /installation_id uuid not null/i);
  assert.match(sql, /environment text not null/i);
  assert.match(
    sql,
    /create unique index customer_push_tokens_customer_installation_environment_active_key\s+on public\.customer_push_tokens \(customer_id, installation_id, environment\)\s+where disabled_at is null/i,
  );
  assert.match(sql, /alter table public\.customer_push_tokens enable row level security/i);
  assert.match(sql, /grant select,\s*insert,\s*update,\s*delete\s+on table public\.customer_push_tokens\s+to service_role/i);
  assert.doesNotMatch(sql, /grant\s+(?:select|insert|update|delete)[^;]+customer_push_tokens[^;]+authenticated/i);
});

test("T-157 migration exposes controlled customer token RPCs", () => {
  assert.match(sql, /create or replace function public\.register_customer_push_token\(/i);
  assert.match(sql, /create or replace function public\.unregister_customer_push_token\(/i);
  assert.match(sql, /grant execute on function public\.register_customer_push_token\(text,\s*uuid,\s*text\) to authenticated/i);
  assert.match(sql, /grant execute on function public\.unregister_customer_push_token\(text,\s*uuid\) to authenticated/i);
  assert.doesNotMatch(sql, /grant execute on function public\.register_customer_push_token\(text,\s*uuid,\s*text\) to anon/i);
});

test("T-157 validation fix keeps APNs token checks within Postgres regex limits", () => {
  assert.match(validationFixSql, /create or replace function app_private\.register_customer_push_token\(/i);
  assert.match(validationFixSql, /create or replace function app_private\.unregister_customer_push_token\(/i);
  assert.match(validationFixSql, /length\(v_token\) not between 32 and 256/i);
  assert.match(validationFixSql, /v_token !~ '\^\[0-9a-f\]\+\$'/i);
  assert.doesNotMatch(validationFixSql, /\{32,256\}/);
});

test("T-157 register fix resolves conflict inference column names as columns", () => {
  assert.match(registerConflictFixSql, /create or replace function app_private\.register_customer_push_token\(/i);
  assert.match(registerConflictFixSql, /#variable_conflict use_column/i);
  assert.match(registerConflictFixSql, /on conflict \(customer_id,\s*installation_id,\s*environment\)/i);
});

test("T-157 constraint fix keeps table-level token checks within Postgres regex limits", () => {
  assert.match(constraintFixSql, /drop constraint if exists customer_push_tokens_token_check/i);
  assert.match(constraintFixSql, /length\(token\) between 32 and 256/i);
  assert.match(constraintFixSql, /token ~ '\^\[0-9a-f\]\+\$'/i);
  assert.doesNotMatch(constraintFixSql, /\{32,256\}/);
});

test("T-157 migration adds push delivery state and service-role dispatch RPCs", () => {
  for (const column of [
    "push_delivery_status",
    "push_attempt_count",
    "push_attempted_at",
    "push_delivered_at",
    "push_last_error",
  ]) {
    assert.match(sql, new RegExp(`add column ${column}`, "i"));
  }

  assert.match(sql, /create or replace function public\.claim_customer_push_notifications\(/i);
  assert.match(sql, /create or replace function public\.record_customer_push_delivery\(/i);
  assert.match(sql, /grant execute on function public\.claim_customer_push_notifications\(integer\) to service_role/i);
  assert.match(sql, /grant execute on function public\.record_customer_push_delivery\(uuid,\s*text,\s*text\) to service_role/i);
  assert.doesNotMatch(sql, /grant execute on function public\.claim_customer_push_notifications\(integer\) to authenticated/i);
});

test("T-157 migration extends customer notifications to new offer and groomer-message events", () => {
  for (const kind of ["new_offer", "new_message"]) {
    assert.match(sql, new RegExp(`'${kind}'`, "i"));
  }

  assert.match(sql, /after insert on public\.groomer_offers/i);
  assert.match(sql, /after insert on public\.messages/i);
  assert.match(sql, /app_private\.customer_notifications_after_offer_insert/i);
  assert.match(sql, /app_private\.customer_notifications_after_groomer_message_insert/i);
});
