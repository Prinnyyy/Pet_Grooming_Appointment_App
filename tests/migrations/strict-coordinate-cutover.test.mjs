import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDirectory = join(process.cwd(), "supabase/migrations");
const migrationName = readdirSync(migrationsDirectory).find((name) =>
  name.endsWith("_t300_strict_coordinate_matching.sql"),
);
const validationPath = join(
  process.cwd(),
  "docs/06_tasks/sql_reviews/T-300_STRICT_COORDINATE_ROLLBACK_VALIDATION.sql",
);

test("T-300 provides the strict coordinate cutover migration and rollback validation", () => {
  assert.ok(migrationName, "missing T-300 strict coordinate migration");
  assert.ok(existsSync(validationPath), "missing T-300 rollback-only validation");
});

test("T-300 rejects matching when either private coordinate is missing", () => {
  assert.ok(migrationName);
  const sql = readFileSync(join(migrationsDirectory, migrationName), "utf8");

  assert.match(
    sql,
    /p_request_location is not null\s+and p_groomer_location is not null\s+and measured\.allowed_radius is not null\s+and measured\.allowed_radius > 0\s+and measured\.distance_miles <= measured\.allowed_radius/i,
  );
  assert.doesNotMatch(sql, /Legacy location fallback/i);
  assert.doesNotMatch(
    sql,
    /else\s+p_groomer_state\s*=\s*p_request_state\s+or\s+lower\(p_groomer_city\)\s*=\s*lower\(p_request_city\)/i,
  );
});

test("T-300 retains direction-correct radius scoring without exposing the helper", () => {
  assert.ok(migrationName);
  const sql = readFileSync(join(migrationsDirectory, migrationName), "utf8");

  assert.match(
    sql,
    /when p_location_mode = 'customer_comes_to_groomer'\s+then p_customer_travel_radius_miles::double precision\s+else p_groomer_service_radius_miles::double precision/i,
  );
  assert.match(sql, /extensions\.st_distance\(\s*p_request_location,\s*p_groomer_location\s*\)\s*\/\s*1609\.344/i);
  assert.match(sql, /revoke all on function app_private\.evaluate_request_location_fit\([\s\S]*from public, anon, authenticated/i);
  assert.match(sql, /grant execute on function app_private\.evaluate_request_location_fit\([\s\S]*to service_role/i);
  assert.doesNotMatch(
    sql,
    /grant execute on function app_private\.evaluate_request_location_fit\([\s\S]*to (?:anon|authenticated)/i,
  );
  assert.match(
    sql,
    /revoke all on function public\.create_grooming_request\([\s\S]*from public, anon, authenticated/i,
  );
  assert.match(
    sql,
    /revoke all on function app_private\.create_grooming_request\([\s\S]*from public, anon, authenticated, service_role/i,
  );
});

test("T-300 rollback validation covers strict absence, radius boundaries, and privacy", () => {
  assert.ok(existsSync(validationPath));
  const validation = readFileSync(validationPath, "utf8");

  assert.match(validation, /^begin;/im);
  assert.match(validation, /rollback;\s*$/i);
  assert.match(validation, /missing request coordinate/i);
  assert.match(validation, /missing groomer coordinate/i);
  assert.match(validation, /same text address cannot bypass missing coordinates/i);
  assert.match(validation, /exact radius boundary/i);
  assert.match(validation, /outside radius/i);
  assert.match(validation, /has_table_privilege\(\s*'authenticated',[\s\S]*address_locations[\s\S]*<> false/i);
});
