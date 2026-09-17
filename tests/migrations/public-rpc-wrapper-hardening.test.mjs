import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t158_public_rpc_wrapper_hardening.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-158 public RPC wrapper hardening migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");

const hardenedFunctions = [
  "accept_groomer_offer",
  "cancel_booking",
  "cancel_grooming_request",
  "complete_booking",
  "create_groomer_offer",
  "create_grooming_request",
  "create_review",
  "dismiss_request_match",
  "get_my_groomer_pet_fit_evidence_summary",
  "withdraw_groomer_offer",
];

test("T-158 migration moves advisor-flagged public definer RPCs into app_private", () => {
  for (const functionName of hardenedFunctions) {
    assert.match(
      sql,
      new RegExp(`alter function public\\.${functionName}\\([\\s\\S]*?\\) set schema app_private`, "i"),
      `${functionName} should be moved to app_private`,
    );
    assert.match(
      sql,
      new RegExp(`grant execute on function app_private\\.${functionName}\\([\\s\\S]*?\\) to authenticated`, "i"),
      `${functionName} private helper should remain callable through authenticated wrappers`,
    );
  }
});

test("T-158 migration recreates public RPCs as security-invoker wrappers", () => {
  for (const functionName of hardenedFunctions) {
    assert.match(
      sql,
      new RegExp(
        `create or replace function public\\.${functionName}\\([\\s\\S]*?language sql\\s+security invoker\\s+set search_path = ''[\\s\\S]*?app_private\\.${functionName}`,
        "i",
      ),
      `${functionName} should be a public security-invoker wrapper`,
    );
    assert.match(
      sql,
      new RegExp(`grant execute on function public\\.${functionName}\\([\\s\\S]*?\\) to authenticated`, "i"),
      `${functionName} public wrapper should be granted to authenticated`,
    );
  }
});

test("T-158 migration does not create new public security-definer RPCs", () => {
  assert.doesNotMatch(
    sql,
    /create or replace function public\.[\s\S]*?security definer/i,
  );
});
