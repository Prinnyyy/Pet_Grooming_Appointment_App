import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "../..");
const migrationName = "20260712040336_t299_controlled_address_backfill.sql";
const sql = fs.readFileSync(path.join(root, "supabase/migrations", migrationName), "utf8");
const cleanupSQL = fs.readFileSync(
  path.join(root, "supabase/migrations/20260712042846_t299_testops_address_cleanup.sql"),
  "utf8",
);

test("T-299 exposes service-role-only address backfill read and write RPCs", () => {
  for (const functionName of [
    "list_address_backfill_targets",
    "backfill_address_location",
    "backfill_address_locations",
    "get_address_backfill_summary",
  ]) {
    assert.match(sql, new RegExp(`create function public\\.${functionName}\\(`, "i"));
    assert.match(
      sql,
      new RegExp(`revoke all on function public\\.${functionName}\\([\\s\\S]*?from public, anon, authenticated`, "i"),
    );
    assert.match(
      sql,
      new RegExp(`grant execute on function public\\.${functionName}\\([\\s\\S]*?to service_role`, "i"),
    );
  }
  assert.doesNotMatch(
    sql,
    /grant execute on function public\.(?:list_address_backfill_targets|backfill_address_location|backfill_address_locations|get_address_backfill_summary)\([^;]*to (?:anon|authenticated)/i,
  );
});

test("T-299 lists only complete missing profile and active request locations", () => {
  assert.match(sql, /customer_profile\.address_location_id is null/i);
  assert.match(sql, /groomer_profile\.address_location_id is null/i);
  assert.match(sql, /grooming_request\.address_location_id is null/i);
  assert.match(sql, /grooming_request\.status in \('open', 'has_offers'\)/i);
  assert.match(sql, /nullif\(btrim\(customer_profile\.street_address\), ''\) is not null/i);
  assert.match(sql, /nullif\(btrim\(groomer_profile\.base_street_address\), ''\) is not null/i);
  assert.match(sql, /nullif\(btrim\(grooming_request\.street_address\), ''\) is not null/i);
});

test("T-299 backfill write locks and compares the full display-address snapshot", () => {
  assert.match(sql, /for update/i);
  assert.match(sql, /message = 'address_backfill_target_changed'/i);
  assert.match(sql, /message = 'address_backfill_target_already_resolved'/i);
  for (const parameter of [
    "p_expected_line_1",
    "p_expected_line_2",
    "p_expected_city",
    "p_expected_state",
    "p_expected_zip_code",
  ]) {
    assert.match(sql, new RegExp(parameter, "i"));
  }
  assert.match(sql, /'legacy_backfill'/i);
  assert.match(sql, /app_private\.save_address_location_v2/i);
  assert.match(sql, /jsonb_array_elements\(p_items\)/i);
  assert.match(sql, /jsonb_array_length\(p_items\) not between 1 and 500/i);
});

test("T-299 summary detects remaining gaps and orphaned legacy locations", () => {
  assert.match(sql, /customer_missing_count/i);
  assert.match(sql, /groomer_missing_count/i);
  assert.match(sql, /active_request_missing_count/i);
  assert.match(sql, /orphan_legacy_location_count/i);
  assert.match(sql, /resolution_source = 'legacy_backfill'/i);
});

test("T-299 TestOps cleanup is service-only and bound to the exact run tag", () => {
  assert.match(cleanupSQL, /create function public\.cleanup_testops_request_address_location\(/i);
  assert.match(cleanupSQL, /service_notes\s*=\s*'TESTOPS:'\s*\|\|\s*v_run_id/i);
  assert.match(cleanupSQL, /service_notes\s+like\s+'TESTOPS:'\s*\|\|\s*v_run_id\s*\|\|\s*' %'/i);
  assert.match(cleanupSQL, /delete from app_private\.address_locations/i);
  assert.match(cleanupSQL, /grant execute on function public\.cleanup_testops_request_address_location\([^;]*to service_role/i);
  assert.doesNotMatch(cleanupSQL, /grant execute on function public\.cleanup_testops_request_address_location\([^;]*to (?:anon|authenticated)/i);
});
