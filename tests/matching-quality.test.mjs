import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";
import { scoreEvidence } from "./support/matching-rating-reference.mjs";

const quality = await import("../scripts/test-t391-matching-quality.mjs").catch(error => {
  if (error.code !== "ERR_MODULE_NOT_FOUND") throw error;
  return {};
});
const evaluate = (name, ...args) => {
  assert.equal(typeof quality[name], "function", `Missing ${name} implementation`);
  return quality[name](...args);
};
const hash = value => createHash("sha256").update(JSON.stringify(value)).digest("hex");
test("fixed paging schedule preserves both user cadences and five evenly spaced event phases", async () => {
  const fixture = await import("../scripts/test-t387-booking-fixture.mjs");
  assert.equal(typeof fixture.fixedPagingSchedule, "function");
  const rows = fixture.fixedPagingSchedule(10000);
  assert.equal(rows.length, 10);
  assert.deepEqual(rows.map(row => row.waitMS), [1000,1000,1000,1000,1000,5000,5000,5000,5000,5000]);
  assert.deepEqual(rows.map(row => row.phaseMS), [0,2000,4000,6000,8000,0,2000,4000,6000,8000]);
  assert.deepEqual(fixture.fixedPagingSchedule(60000).slice(0,5).map(row => row.phaseMS), [0,12000,24000,36000,48000]);
  assert.ok(fixture.fixedPagingSchedule(0).every(row => row.phaseMS === null));
  assert.throws(() => fixture.fixedPagingSchedule(500), /period/);
});
function dataset(count = 1, source = "synthetic") {
  const cases = Array.from({ length: count }, (_, index) => {
    const meta = { as_of: "2026-09-13T12:00:00Z", source_revision: `revision-${index}`, scoring_version: "matching-v1" };
    return { case_id: `case-${index}`, role: "customer", split: "holdout", source_kind: source,
      source_group: `customer-${index}`, leakage_keys: [`request-${index}`, `customer-${index}`],
      strata: ["dog", "fixed", "sparse"], intent: "recommended", ...meta,
      candidates: ["g1", "g2", "g3", "g4"].map((id, i) => ({ id, eligibility_group: 0,
        facts: { distance_miles: i, price: 100 + i, service_at: "2026-09-14T12:00:00Z",
          offer_id: `offer-${i}`, offer_status: "pending", selectable: true },
        eligibility: { state: "estimated_fit", source: "independent-test-facts" } })),
      rankings: { current: { ...meta, ids: ["g1", "g3", "g4", "g2"] },
        distance: { ...meta, ids: ["g1", "g2", "g3", "g4"] } } };
  });
  const snapshots = { schema_version: 1, frozen: true, seed: 391,
    primary_baselines: { customer: "distance", groomer: "distance" }, cases };
  const labels = { snapshot_hash: hash(snapshots), cases: cases.map(row => ({ case_id: row.case_id,
    reviews: [{ reviewer_id: "research-participant", role: "customer", origin: source === "real_redacted" ? "human" : "synthetic",
      values: Object.fromEntries(["g1", "g2", "g3", "g4"].map(id => [id,
        { rating: id === "g2" ? 0 : 2, reason: "test-only label" }])) }] })) };
  return { snapshots, labels };
}
function refreshHash(data) { data.labels.snapshot_hash = hash(data.snapshots); return data; }
const result = data => evaluate("evaluateDataset", data.snapshots, data.labels, "holdout");
const group = data => result(data).groups[0];

test("Top-3 matches independent hand calculations and never coerces unknown to zero", () => {
  assert.deepEqual(evaluate("evaluateTop3", ["a", "b", "c"], { a: 2, b: 0, c: 1 }),
    { status: "ok", k: 3, acceptableAt3: 2 / 3, hitAt3: 1 });
  assert.deepEqual(evaluate("evaluateTop3", ["a"], { a: 0 }),
    { status: "ok", k: 1, acceptableAt3: 0, hitAt3: 0 });
  assert.deepEqual(evaluate("evaluateTop3", ["a"], { a: null }), { status: "insufficient", reason: "unknown_label" });
  assert.deepEqual(evaluate("evaluateTop3", [], {}), { status: "insufficient", reason: "empty_pool" });
});
test("Top-3 rejects missing, duplicate and malformed labels", () => {
  for (const [ids, labels] of [[["a"], {}], [["a", "a"], { a: 1 }], [["a"], { a: "2" }], [["a"], { a: 3 }]]) {
    assert.throws(() => evaluate("evaluateTop3", ids, labels), /label|duplicate/i);
  }
});
test("paired metrics use equal source-group weights, not repeated requests as independent people", () => {
  const data = dataset(4);
  for (const row of data.snapshots.cases.slice(1)) row.source_group = "repeat-customer";
  for (const row of data.snapshots.cases.slice(1)) row.rankings.current.ids = ["g1", "g2", "g3", "g4"];
  const summary = group(refreshHash(data));
  assert.equal(summary.independentGroups, 2);
  assert.ok(Math.abs(summary.delta - 1 / 6) < 1e-12);
  assert.equal(summary.conclusion, "descriptive_only");
});
test("source kinds remain separate and synthetic data cannot establish recommendation superiority", () => {
  const summary = group(dataset(25));
  assert.equal(summary.conclusion, "descriptive_only");
  assert.equal(summary.confidenceInterval, null);
  const data = dataset(2);
  data.snapshots.cases[1].source_kind = "controlled_fixture";
  assert.equal(result(refreshHash(data)).groups.length, 2);
});
test("fixed-seed grouped intervals and 5pp decisions require held-out human evidence", () => {
  const data = dataset(20, "real_redacted");
  const first = group(data);
  assert.deepEqual(first, group(data));
  assert.equal(first.conclusion, "advantage");
  assert.ok(first.confidenceInterval[0] > 0);
  data.labels.cases[0].reviews[0].origin = "synthetic";
  assert.equal(group(data).conclusion, "insufficient");
});
test("unknown labels retain pair bounds, missingness denominators and no numeric false pass", () => {
  const data = dataset(20, "real_redacted");
  for (const row of data.labels.cases.slice(0, 3)) row.reviews[0].values.g1.rating = null;
  const summary = group(data);
  assert.equal(summary.unknownCases, 3);
  assert.equal(summary.missingRate, 0.15);
  assert.equal(summary.conclusion, "insufficient");
  assert.ok(summary.deltaBounds[0] <= summary.deltaBounds[1]);
});
test("an empty pool is supply coverage, never zero recommendation quality", () => {
  const data = dataset();
  data.snapshots.cases[0].candidates = [];
  for (const ranking of Object.values(data.snapshots.cases[0].rankings)) ranking.ids = [];
  data.labels.cases[0].reviews[0].values = {};
  const summary = group(refreshHash(data));
  assert.equal(summary.emptyPools, 1);
  assert.equal(summary.delta, null);
});
test("full-pool ranking metadata and frozen labels must match", () => {
  for (const mutate of [
    d => { d.snapshots.cases[0].rankings.distance.ids.pop(); },
    d => { d.snapshots.cases[0].rankings.distance.ids[3] = "outsider"; },
    d => { d.snapshots.cases[0].rankings.current.as_of = "2026-09-14T12:00:00Z"; },
    d => { d.snapshots.cases[0].rankings.current.source_revision = "other"; },
    d => { d.snapshots.cases[0].rankings.current.scoring_version = "unfrozen"; },
    d => { d.snapshots.cases[0].rankings.distance.ids = ["g4", "g3", "g2", "g1"]; },
    d => { d.snapshots.cases[0].candidates[0].facts.distance_miles = -1; },
  ]) {
    const data = dataset(); mutate(data);
    assert.throws(() => result(refreshHash(data)), /candidate|ranking|distance|metadata/i);
  }
  const data = dataset(); data.snapshots.seed += 1;
  assert.throws(() => result(data), /hash/);
});
test("shared requests, customers and near-clones cannot leak across development and holdout", () => {
  for (const key of ["source_group", "leakage_keys"]) {
    const data = dataset(2);
    data.snapshots.cases[0].split = "development";
    data.snapshots.cases[1][key] = data.snapshots.cases[0][key];
    assert.throws(() => result(refreshHash(data)), /leakage/);
  }
});
test("shared source keys cannot manufacture independent groups within the same split", () => {
  const data = dataset(20, "real_redacted");
  for (const row of data.snapshots.cases) row.leakage_keys.push("same-real-customer");
  assert.throws(() => result(refreshHash(data)), /source group/);
});
test("professional raters do not substitute for customer preference and need independent reviewers", () => {
  const data = dataset(20, "real_redacted");
  data.labels.cases[0].reviews[0].role = "groomer";
  assert.throws(() => result(data), /reviewer role/);
  for (const row of data.snapshots.cases) row.role = "groomer";
  for (const row of data.labels.cases) row.reviews[0].role = "groomer";
  assert.equal(group(refreshHash(data)).conclusion, "insufficient");
});
test("multiple raters are retained but do not inflate independent sample counts", () => {
  const data = dataset();
  const second = structuredClone(data.labels.cases[0].reviews[0]);
  second.reviewer_id = "second-rater"; second.values.g1.rating = 0;
  data.labels.cases[0].reviews.push(second);
  const report = result(data);
  assert.equal(report.groups[0].independentGroups, 1);
  assert.deepEqual(report.cases[0].disagreements, ["g1"]);
});
test("customer comparison rejects nonselectable or nonexistent quotes", () => {
  for (const mutate of [
    candidate => { candidate.facts.selectable = false; },
    candidate => { candidate.facts.offer_status = "withdrawn_by_groomer"; },
    candidate => { delete candidate.facts.offer_id; },
    candidate => { candidate.eligibility_group = 1; },
  ]) {
    const data = dataset(); mutate(data.snapshots.cases[0].candidates[0]);
    assert.throws(() => result(refreshHash(data)), /selectable|quote|offer/);
  }
});
test("explicit sorting is checked as a contract, not treated as evidence for composite ranking", () => {
  const data = dataset(20, "real_redacted");
  for (const row of data.snapshots.cases) {
    row.intent = "distance"; row.rankings.current.ids = row.rankings.distance.ids;
  }
  const summary = group(refreshHash(data));
  assert.equal(summary.explicitModeCases, 20);
  assert.equal(summary.delta, null);
  assert.notEqual(summary.conclusion, "non_inferior");
  data.snapshots.cases[0].rankings.current.ids = ["g4", "g3", "g2", "g1"];
  assert.throws(() => result(refreshHash(data)), /ranking/);
});
test("CLI defaults to development and refuses output overwrite", () => {
  assert.equal(typeof quality.evaluateTop3, "function", "Missing CLI implementation");
  const dir = mkdtempSync(join(tmpdir(), "matching-quality-"));
  try {
    const data = dataset();
    writeFileSync(join(dir, "input.json"), JSON.stringify(data.snapshots));
    writeFileSync(join(dir, "labels.json"), JSON.stringify(data.labels));
    const args = [resolve("scripts/test-t391-matching-quality.mjs"), "--input", join(dir, "input.json"),
      "--labels", join(dir, "labels.json"), "--out", join(dir, "result.json")];
    assert.equal(spawnSync(process.execPath, args, { encoding: "utf8" }).status, 0);
    const report = JSON.parse(readFileSync(join(dir, "result.json")));
    assert.equal(report.split, "development"); assert.equal(report.cases.length, 0);
    assert.notEqual(spawnSync(process.execPath, args, { encoding: "utf8" }).status, 0);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
test("sensitivity parameters preserve neutral priors and actual independent customer decay", () => {
  const target = { species: "dog", service: "full_groom", keys: ["service:full_groom"] };
  const review = { customer: "one", species: "dog", service: "full_groom", rating: 5, age: 180,
    answers: { "service:full_groom": "positive" } };
  for (const smoothing of [2.5, 5, 10]) {
    const empty = scoreEvidence(target, [], 5, { smoothing });
    assert.equal(empty.f, 50); assert.equal(empty.q, 50);
    const actual = scoreEvidence(target, [review], 5, { smoothing });
    assert.ok(Math.abs(actual.f - (50 + 25 / (0.5 + smoothing))) < 1e-12);
  }
  const faster = scoreEvidence(target, [review], 5, { halfLifeDays: 90 });
  assert.ok(Math.abs(faster.positive - 0.25) < 1e-12);
  assert.equal(scoreEvidence(target, [], 5, { distanceScaleMiles: 10 }).d, 100 / 1.5);
  const weighted = scoreEvidence(target, [review], 5, { groomerFitWeight: 0.8, customerFitWeight: 0.7 });
  assert.ok(Math.abs(weighted.b - (0.8 * weighted.f + 0.2 * weighted.d)) < 1e-12);
  assert.ok(Math.abs(weighted.s - (0.7 * weighted.f + 0.15 * weighted.q + 0.15 * weighted.d)) < 1e-12);
  assert.throws(() => scoreEvidence(target, [], 5, { halfLifeDays: 0 }), /parameter/);
  assert.throws(() => scoreEvidence(target, [], -1), /distance/);
});

test("T391 fixture identity and remote gate reject before reading credentials or connecting", async () => {
  const fixture = await import("../scripts/test-t387-booking-fixture.mjs");
  assert.equal(typeof fixture.isMatchingRun, "function", "Missing shared matching-run predicate");
  assert.equal(fixture.isMatchingRun("TESTOPS-T391-20260913-A"), true);
  assert.equal(fixture.isMatchingRun("TESTOPS-T390-20260912-F"), true);
  for (const id of ["TESTOPS-T391", "TESTOPS-T391-A'", "TESTOPS-T391-A trailing", "TESTOPS-T387-A"]) {
    assert.equal(fixture.isMatchingRun(id), false);
  }
  for (const [id, args, error] of [
    ["TESTOPS-T391-A", ["run"], /Explicit --execute/],
    ["TESTOPS-T391-A", ["run", "--execute"], /Explicit test-operation authorization/],
    ["TESTOPS-T391-A'", ["run", "--execute"], /match|run ID/i],
  ]) {
    const denied = spawnSync(process.execPath, ["scripts/test-t390-matching-scenarios.mjs", ...args],
      { encoding: "utf8", env: { PATH: process.env.PATH, TESTOPS_RUN_ID: id } });
    assert.notEqual(denied.status, 0); assert.match(denied.stderr, error);
    assert.doesNotMatch(denied.stderr, /supabase_environment_variables|ENOENT|fetch failed/);
  }
});
test("T391 enabled-ranking policy produces no configuration writes and guards restoration", async () => {
  const fixture = await import("../scripts/test-t387-booking-fixture.mjs");
  assert.equal(typeof fixture.rankingValidationPlan, "function", "Missing ranking validation policy");
  const actor = "11111111-1111-4111-8111-111111111111";
  const enabled = { enabled: true, validation_actor_ids: [] };
  const policy = fixture.rankingValidationPlan(enabled, [actor], "TESTOPS-T391-A");
  assert.equal(policy.activateSQL, null); assert.equal(policy.restoreSQL, null);
  assert.doesNotMatch(policy.verifySQL, /update |insert |delete /i);
  assert.match(policy.verifySQL, /Unexpected ranking config/);
  assert.deepEqual(enabled, { enabled: true, validation_actor_ids: [] });
  assert.throws(() => fixture.rankingValidationPlan({ ...enabled, enabled: false }, [actor], "TESTOPS-T391-A"), /enabled/);
  const legacy = fixture.rankingValidationPlan({ ...enabled, enabled: false }, [actor], "TESTOPS-T390-A");
  assert.match(legacy.activateSQL, /update app_private.match_ranking_config/);
  assert.match(legacy.restoreSQL, /update app_private.match_ranking_config/);
  assert.match(legacy.activateSQL, /Unexpected ranking config/);
});

test("synthetic marketplace replay requires an explicit bounded phase and rollback-only SQL", () => {
  const denied = spawnSync(process.execPath,
    ["scripts/test-t390-matching-scenarios.mjs", "marketplace-db", "--execute"],
    {encoding:"utf8",env:{PATH:process.env.PATH,TESTOPS_RUN_ID:"TESTOPS-T391-GATE",TESTOPS_REMOTE_WRITE_APPROVED:"1"}});
  assert.notEqual(denied.status,0);
  assert.match(denied.stderr,/Select one bounded marketplace phase/);
  assert.doesNotMatch(denied.stderr,/ENOENT|Initialising login|fetch failed/);
  const sql=readFileSync("tests/fixtures/matching-marketplace-replay.sql","utf8");
  assert.ok(sql.startsWith("begin;"));
  assert.ok(sql.trimEnd().endsWith("rollback;"));
  assert.doesNotMatch(sql,/\bcommit\s*;|disable trigger|update auth\.|insert into auth\./i);
  const runner=readFileSync("scripts/test-t390-matching-scenarios.mjs","utf8");
  assert.match(runner,/to_jsonb\(c\)-'signing_key'/);
});
