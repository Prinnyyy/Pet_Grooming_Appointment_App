import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

// Static migration guards; role/API and transaction acceptance are separate.
const migration = readdirSync("supabase/migrations")
  .find(name => name.endsWith("_t390_match_input_contracts.sql"));
const sql = migration ? readFileSync(`supabase/migrations/${migration}`, "utf8") : "";

test("weight persistence removes legacy slider limits and pre-validation rounding", () => {
  assert.match(sql, /drop constraint pets_weight_lbs_range_check/);
  assert.match(sql, /alter column weight_lbs type numeric;/);
  assert.match(sql, /weight_lbs>0 and weight_lbs::text not in \('NaN','Infinity','-Infinity'\)/);
  assert.doesNotMatch(sql, /new\.weight_lbs>1000/);
});

test("service species stays nullable for legacy rows rather than accepting every species", () => {
  assert.match(sql, /add column accepted_species text\[\]/i);
  assert.doesNotMatch(sql, /accepted_species text\[\]\s+(?:not null|default)/i);
  assert.match(sql, /array_position\(accepted_species, null\) is null/);
});

test("new service writes reject unconfirmed active scope and duplicate species", () => {
  assert.match(sql, /service_species_confirmation_required/);
  assert.match(sql, /invalid_accepted_species/);
  assert.match(sql, /before insert or update on public\.groomer_services/i);
  assert.match(sql, /count\(distinct species\)/);
});

test("species changes participate in the existing quote eligibility revision", () => {
  assert.match(sql, /new\.accepted_species[\s\S]*old\.accepted_species/);
  assert.match(sql, /new\.eligibility_revision\s*:=\s*gen_random_uuid\(\)/);
  assert.match(sql, /revoke all on function app_private\.guard_service_species\(\)/i);
});

test("hard constraints require request species and reject explicit service species mismatch", () => {
  assert.match(sql, /request_species_confirmation_required/);
  assert.match(sql, /pet_species_excluded/);
  assert.match(sql, /create or replace function app_private\.evaluate_match_constraints/i);
  assert.match(sql, /species=any\(s\.accepted_species\)/);
  assert.match(sql, /evaluate_request_location_fit/);
});

test("legacy size conflict is assessed rather than taking the more favorable size", () => {
  assert.match(sql, /create function app_private\.match_request_size/i);
  assert.match(sql, /pet_size_code_for_weight_lbs/);
  assert.match(sql, /weight_size is distinct from normalized_size then return null/);
});

test("estimated timing fit cannot bypass species confirmation or use conflicting snapshot size", () => {
  const body = sql.split(/CREATE OR REPLACE FUNCTION app_private\.evaluate_match_eligibility_with_zones/)[1] ?? "";
  assert.match(body, /service\.accepted_species is not null/);
  assert.match(body, /match_request_size\(r\.pet_snapshot\)/);
  assert.match(body, /required_confirmations/);
  assert.match(body, /booking_resource_end/);
  assert.match(body, /booking_pet_end/);
});

test("quote and final booking validate confirmed scope under the existing admission lock", () => {
  assert.match(sql, /create function app_private\.validate_offer_match_facts/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.doesNotMatch(sql, /for share/i);
  assert.match(sql, /assessment_confirmation_required/);
  assert.match(sql, /bookings_aab_match_facts before insert on public\.bookings/);
  assert.match(sql, /groomer_offers_z_match_facts before insert or update/);
  assert.match(sql, /public\.create_groomer_offer_v3/);
});

test("pet facts are owner-written with protected provenance and frozen from one captured pet row", () => {
  assert.match(sql, /public\.save_my_pet_v2/);
  assert.match(sql, /coat_type_source/);
  assert.match(sql, /matting_confirmed/);
  assert.match(sql, /'coat_type_source', v_pet\.coat_type_source/);
  assert.match(sql, /'matting_confirmed', v_pet\.matting_confirmed/);
  assert.match(sql, /pet_not_found/);
  assert.match(sql, /invalid_pet_weight/);
});

test("hair-service assessments use the same unknown-fact requirements as quote admission", () => {
  assert.match(sql, /create function app_private\.match_required_confirmations/);
  assert.match(sql, /'pet_coat'/);
  assert.match(sql, /'pet_matting'/);
  assert.ok(sql.split("app_private.match_required_confirmations(").length >= 5);
});
test("unknown facts remove non-null and default weight inference", () => {
  const correction = readFileSync("supabase/migrations/20260911114329_t390_unknown_pet_facts.sql", "utf8");
  for (const column of ["weight_lbs", "size"]) {
    assert.ok(correction.includes(`alter column ${column} drop not null`));
    assert.ok(correction.includes(`alter column ${column} drop default`));
  }
});

test("quote configuration is selected deterministically and pinned for acceptance", () => {
  const correction = readFileSync("supabase/migrations/20260911114454_t390_bind_quote_service_configuration.sql", "utf8");
  assert.match(correction, /s\.eligibility_revision=p_revision/);
  assert.match(correction, /s\.duration_minutes,s\.id limit 1/);
  assert.match(correction, /'service_configuration_id'/);
  assert.match(correction, /new\.groomer_id,confirmations,revision/);
  assert.doesNotMatch(correction, /select eligibility_revision::text from public\.groomer_services where groomer_id=o\.groomer_id and service_type=r\.service_type\)/);
});
test("service species writer receives only the new column privileges", () => {
  const correction = readFileSync("supabase/migrations/20260911123541_t390_service_species_column_grants.sql", "utf8");
  assert.match(correction, /grant insert \(accepted_species\), update \(accepted_species\)/);
  assert.match(correction, /on public\.groomer_services to authenticated/);
  assert.doesNotMatch(correction, /grant all|disable row level security|drop policy/i);
});
test("legacy assessment cannot overwrite a confirmed usable service", () => {
  const correction = readFileSync("supabase/migrations/20260911124215_t390_prefer_actionable_assessment.sql", "utf8");
  assert.match(correction, /row\(service\.accepted_species is null,cardinality\(required\),duration,service\.id\)/);
  assert.match(correction, /< row\(assessment_species_unknown,assessment_key_count,assessment_duration,assessment_id\)/);
  assert.match(correction, /'service_id',service\.id,'required_confirmations',to_jsonb\(required\)/);
});
