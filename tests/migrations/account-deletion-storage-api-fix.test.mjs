import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t233_move_account_storage_cleanup_to_api.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-233 account Storage API fix migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");
const rollbackSql = readFileSync(
  join(
    process.cwd(),
    "docs/06_tasks/sql_reviews/T-233_ACCOUNT_DELETION_STORAGE_ROLLBACK.sql",
  ),
  "utf8",
);

test("T-233 removes forbidden direct Storage deletion from account deletion RPC", () => {
  assert.match(
    sql,
    /create or replace function app_private\.request_account_deletion\(\)/i,
  );
  assert.doesNotMatch(sql, /(?:delete|update|insert)\s+(?:from\s+|into\s+)?storage\.objects/i);
  assert.match(
    sql,
    /on conflict on constraint account_deletion_requests_user_key\s+do update/i,
  );
});

test("T-233 preserves account anonymization and the private RPC boundary", () => {
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

  assert.match(
    sql,
    /revoke all on function app_private\.request_account_deletion\(\)\s+from public, anon, authenticated, service_role/i,
  );
  assert.match(
    sql,
    /grant execute on function app_private\.request_account_deletion\(\)\s+to authenticated/i,
  );
});

test("T-233 includes rollback-only database anonymization validation", () => {
  assert.match(rollbackSql, /^begin;/im);
  assert.match(rollbackSql, /set local role authenticated/i);
  assert.match(rollbackSql, /from public\.request_account_deletion\(\)/i);
  assert.match(rollbackSql, /account_deletion_requests/i);
  assert.match(rollbackSql, /display_name = 'Deleted customer'/i);
  assert.match(rollbackSql, /^rollback;/im);
});
