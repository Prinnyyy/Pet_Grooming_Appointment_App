import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t232_fix_account_deletion_conflict.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-232 account deletion conflict fix migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");

test("T-232 removes the ambiguous account deletion conflict target", () => {
  assert.match(
    sql,
    /create or replace function app_private\.request_account_deletion\(\)/i,
  );
  assert.match(
    sql,
    /on conflict on constraint account_deletion_requests_user_key\s+do update/i,
  );
  assert.doesNotMatch(sql, /on conflict\s*\(\s*user_id\s*\)/i);
});

test("T-232 preserves the privileged function contract and deletion behavior", () => {
  assert.match(sql, /returns table\s*\(\s*deletion_request_id uuid,\s*user_id uuid,/i);
  assert.match(sql, /language plpgsql\s+security definer\s+set search_path = ''/i);

  for (const table of [
    "profiles",
    "customer_profiles",
    "pets",
    "grooming_requests",
    "messages",
    "reviews",
    "groomer_profiles",
    "groomer_services",
    "groomer_fit_claims",
    "groomer_offers",
  ]) {
    assert.match(sql, new RegExp(`public\\.${table}`, "i"));
  }

  assert.match(sql, /delete from storage\.objects/i);
  assert.match(sql, /delete from public\.customer_notifications/i);
  assert.match(sql, /delete from public\.customer_push_tokens/i);
  assert.match(sql, /delete from public\.request_photos/i);
  assert.match(sql, /delete from public\.pet_photos/i);
});

test("T-232 preserves the private RPC privilege boundary", () => {
  assert.match(
    sql,
    /comment on function app_private\.request_account_deletion\(\)/i,
  );
  assert.match(
    sql,
    /revoke all on function app_private\.request_account_deletion\(\)\s+from public, anon, authenticated, service_role/i,
  );
  assert.match(
    sql,
    /grant execute on function app_private\.request_account_deletion\(\)\s+to authenticated/i,
  );
});
