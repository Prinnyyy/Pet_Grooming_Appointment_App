import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t159_private_rpc_lint_cleanup.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-159 private RPC lint cleanup migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");

const functionSql = (functionName) => {
  const match = sql.match(
    new RegExp(
      `create or replace function app_private\\.${functionName}\\([\\s\\S]*?\\n\\$\\$;`,
      "i",
    ),
  );

  assert.ok(match, `${functionName} helper should be rebuilt in app_private`);
  return match[0];
};

test("T-159 migration removes unread variables from private RPC helpers", () => {
  const acceptOfferSql = functionSql("accept_groomer_offer");
  assert.doesNotMatch(
    acceptOfferSql,
    /\bv_match_id\s+uuid\b/i,
    "accept_groomer_offer should no longer declare unread v_match_id",
  );
  assert.doesNotMatch(
    acceptOfferSql,
    /\binto[\s\S]*?\bv_match_id\b/i,
    "accept_groomer_offer should no longer write unread v_match_id",
  );

  const completeBookingSql = functionSql("complete_booking");
  assert.doesNotMatch(
    completeBookingSql,
    /\bv_groomer_id\s+uuid\b/i,
    "complete_booking should no longer declare unread v_groomer_id",
  );
  assert.doesNotMatch(
    completeBookingSql,
    /\binto[\s\S]*?\bv_groomer_id\b/i,
    "complete_booking should no longer write unread v_groomer_id",
  );
});
