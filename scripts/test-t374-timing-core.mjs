import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { captureT374TimingSnapshot as snapshot } from "./t374-timing-snapshot.mjs";

assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1", "Explicit rollback-test authorization required");
assert.equal(readFileSync("supabase/.temp/project-ref", "utf8").trim(), "lqmasbuqzvcvtawonjlb");
assert.ok(!process.argv.includes("--scale") || process.argv.includes("--bookings"),
  "--scale requires --bookings");
const migration = process.argv.includes("--against-deployed") ? "" :
  readFileSync("supabase/migrations/20260908052312_t374_service_timing.sql", "utf8");
const assertions = readFileSync("docs/06_tasks/sql_reviews/T-374_TIMING_CORE_ASSERTIONS.sql", "utf8") +
  (process.argv.includes("--hours") ?
    readFileSync("docs/06_tasks/sql_reviews/T-374_TIMING_HOURS_ASSERTIONS.sql", "utf8") : "") +
  (process.argv.includes("--bookings") ?
    readFileSync("docs/06_tasks/sql_reviews/T-374_TIMING_BOOKING_ASSERTIONS.sql", "utf8") : "") +
  (process.argv.includes("--offers") ?
    readFileSync("docs/06_tasks/sql_reviews/T-374_TIMING_OFFER_ASSERTIONS.sql", "utf8") : "") +
  (process.argv.includes("--settings") ?
    readFileSync("docs/06_tasks/sql_reviews/T-374_TIMING_SETTINGS_ASSERTIONS.sql", "utf8") : "") +
  (process.argv.includes("--addresses") ?
    readFileSync("docs/06_tasks/sql_reviews/T-374_TIMING_ADDRESS_ASSERTIONS.sql", "utf8") : "") +
  (process.argv.includes("--publish") ?
    readFileSync("docs/06_tasks/sql_reviews/T-374_TIMING_PUBLISH_ASSERTIONS.sql", "utf8") : "");
assert.doesNotMatch(migration + assertions, /\b(?:commit|rollback)\s*;/i,
  "The rehearsal inputs must not end the outer rollback transaction");
const env = { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" };
const baseline = ["--settings", "--addresses", "--publish", "--offers", "--bookings", "--hours"].some(flag => process.argv.includes(flag)) ? snapshot() : null;
const result = spawnSync("supabase", ["db", "query", "--linked", "--output", "json",
  `begin;\nset local app.t374_scale = '${process.argv.includes("--scale") ? "1" : "0"}';\n${migration}\n${assertions}\nset constraints all immediate;\nrollback;`], {
  encoding: "utf8", timeout: 120_000,
  env,
});
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.error) throw result.error;
if (baseline) {
  assert.deepEqual(snapshot(), baseline, "Rollback did not restore timing settings, addresses and schema definitions");
  process.stdout.write("Exact timing settings/address restoration: PASS\n");
}
process.exit(result.status ?? 1);
