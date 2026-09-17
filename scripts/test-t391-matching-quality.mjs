import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

const mean = values => values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : null;
const hash = value => createHash("sha256").update(JSON.stringify(value)).digest("hex");
const text = (value, field) => assert.ok(typeof value === "string" && value.trim(), `Missing ${field}`);
function unique(values, field) {
  assert.ok(Array.isArray(values), `Invalid ${field}`);
  values.forEach(value => text(value, field));
  assert.equal(new Set(values).size, values.length, `Duplicate ${field}`);
}
export function evaluateTop3(orderedIDs, labels) {
  unique(orderedIDs, "candidate ID");
  const ids = orderedIDs.slice(0, 3);
  if (!ids.length) return { status: "insufficient", reason: "empty_pool" };
  for (const id of ids) {
    assert.ok(Object.hasOwn(labels, id), `Missing label: ${id}`);
    assert.ok([0, 1, 2, null].includes(labels[id]), `Invalid label: ${id}`);
  }
  if (ids.some(id => labels[id] === null)) return { status: "insufficient", reason: "unknown_label" };
  const accepted = ids.filter(id => labels[id] >= 1).length;
  return { status: "ok", k: ids.length, acceptableAt3: accepted / ids.length, hitAt3: accepted ? 1 : 0 };
}
function bounds(ids, labels) {
  const top = ids.slice(0, 3);
  return [mean(top.map(id => labels[id] >= 1 ? 1 : 0)),
    mean(top.map(id => labels[id] === null || labels[id] >= 1 ? 1 : 0))];
}
function validateSnapshots(snapshots) {
  assert.equal(snapshots.schema_version, 1, "Unsupported snapshot schema");
  assert.equal(snapshots.frozen, true, "Freeze inputs and primary baselines before comparison");
  assert.ok(Number.isSafeInteger(snapshots.seed), "Invalid fixed seed");
  for (const [role, modes] of Object.entries({ customer: ["distance", "price", "earliest"], groomer: ["distance", "newest"] })) {
    assert.ok(modes.includes(snapshots.primary_baselines?.[role]), "Invalid primary baseline");
  }
  unique(snapshots.cases.map(row => row.case_id), "case ID");
  const splits = new Map(), sourceGroups = new Map();
  for (const row of snapshots.cases) {
    assert.ok(["customer", "groomer"].includes(row.role), "Invalid role");
    assert.ok(["development", "holdout"].includes(row.split), "Invalid split");
    assert.ok(["real_redacted", "controlled_fixture", "synthetic"].includes(row.source_kind), "Invalid source kind");
    text(row.source_group, "source group"); unique(row.leakage_keys, "leakage key");
    assert.ok(row.leakage_keys.length, "Missing request/customer/clone leakage keys");
    for (const key of [`group:${row.role}:${row.source_group}`, ...row.leakage_keys.map(key => `source:${key}`)]) {
      assert.ok(!splits.has(key) || splits.get(key) === row.split, `Cross-split leakage: ${key}`);
      splits.set(key, row.split);
      if (key.startsWith("source:")) {
        const scoped = JSON.stringify([row.role, key]);
        assert.ok(!sourceGroups.has(scoped) || sourceGroups.get(scoped) === row.source_group,
          `Inconsistent source group for shared provenance: ${key}`);
        sourceGroups.set(scoped, row.source_group);
      }
    }
    text(row.source_revision, "source revision"); text(row.scoring_version, "scoring version");
    assert.ok(Number.isFinite(Date.parse(row.as_of)), "Invalid as_of metadata");
    unique(row.strata, "stratum");
    assert.ok((row.role === "customer" ? ["recommended", "distance", "price", "earliest"]
      : ["recommended", "distance", "newest"]).includes(row.intent), "Invalid explicit intent");
    const ids = row.candidates.map(candidate => candidate.id);
    unique(ids, "candidate ID");
    const candidates = new Map(row.candidates.map(candidate => [candidate.id, candidate]));
    for (const candidate of row.candidates) {
      assert.ok([0, 1].includes(candidate.eligibility_group), "Invalid candidate eligibility group");
      assert.ok(["estimated_fit", "assessment_required"].includes(candidate.eligibility?.state), "Invalid candidate eligibility");
      text(candidate.eligibility.source, "independent candidate eligibility source");
      assert.ok(candidate.facts && Object.keys(candidate.facts).length, "Missing candidate facts");
      if (row.role === "customer") {
        text(candidate.facts.offer_id, "quote offer ID");
        assert.ok(candidate.facts.offer_status === "pending" && candidate.facts.selectable === true
          && candidate.eligibility_group === 0, "Customer pool requires currently selectable quotes");
      } else assert.equal(candidate.eligibility_group, candidate.eligibility.state === "estimated_fit" ? 0 : 1,
        "Candidate eligibility group mismatch");
      const distance = candidate.facts.distance_miles;
      assert.ok(Number.isFinite(distance) && distance >= 0, "Invalid candidate distance");
    }
    assert.ok(row.rankings.current && row.rankings[snapshots.primary_baselines[row.role]], "Missing primary ranking");
    for (const [mode, ranking] of Object.entries(row.rankings)) {
      for (const key of ["as_of", "source_revision", "scoring_version"]) assert.equal(ranking[key], row[key], `Ranking metadata mismatch: ${key}`);
      unique(ranking.ids, "ranking candidate ID");
      assert.deepEqual([...ranking.ids].sort(), [...ids].sort(), "Ranking candidate set mismatch");
      for (let i = 1; i < ranking.ids.length; i++) {
        const before = candidates.get(ranking.ids[i - 1]), after = candidates.get(ranking.ids[i]);
        assert.ok(before.eligibility_group <= after.eligibility_group, "Ranking crossed eligibility groups");
        if (before.eligibility_group !== after.eligibility_group) continue;
        const primaryMode = mode === "current" && row.intent !== "recommended" ? row.intent : mode;
        const value = candidate => {
          if (primaryMode === "distance") return candidate.facts.distance_miles;
          if (primaryMode === "price") return candidate.facts.price;
          if (primaryMode === "earliest") return Date.parse(candidate.facts.service_at);
          if (primaryMode === "newest") return -Date.parse(candidate.facts.created_at);
          return null;
        };
        const a = value(before), b = value(after);
        if (a !== null) assert.ok(Number.isFinite(a) && Number.isFinite(b) && a <= b, `Invalid ${primaryMode} baseline ranking`);
      }
    }
  }
}
function evaluateCase(row, labelRow, baseline) {
  const reviews = labelRow?.reviews ?? [];
  unique(reviews.map(review => review.reviewer_id), "reviewer ID");
  const known = new Set(row.candidates.map(candidate => candidate.id));
  const ratings = reviews.map(review => {
    assert.equal(review.role, row.role, "Wrong reviewer role");
    assert.ok(["human", "synthetic"].includes(review.origin), "Invalid reviewer provenance");
    const values = {};
    for (const [id, value] of Object.entries(review.values)) {
      assert.ok(known.has(id), "Label candidate outside snapshot");
      assert.ok([null, 0, 1, 2].includes(value.rating), "Invalid label rating");
      text(value.reason, "label reason"); values[id] = value.rating;
    }
    const metrics = Object.fromEntries(Object.entries(row.rankings).map(([mode, ranking]) => [mode, evaluateTop3(ranking.ids, values)]));
    const currentBounds = bounds(row.rankings.current.ids, values), baseBounds = bounds(row.rankings[baseline].ids, values);
    return { values, metrics, deltaBounds: [currentBounds[0] - baseBounds[1], currentBounds[1] - baseBounds[0]] };
  });
  const empty = !row.candidates.length;
  const explicitMode = row.intent !== "recommended";
  const complete = !explicitMode && !empty && ratings.length > 0 && ratings.every(rating =>
    rating.metrics.current.status === "ok" && rating.metrics[baseline].status === "ok");
  const metric = (mode, name) => complete ? mean(ratings.map(rating => rating.metrics[mode][name])) : null;
  const current = metric("current", "acceptableAt3"), reference = metric(baseline, "acceptableAt3");
  return { case_id: row.case_id, role: row.role, split: row.split, source_kind: row.source_kind,
    source_group: row.source_group, strata: row.strata, baseline, empty, complete, explicitMode,
    humanReady: reviews.length >= (row.role === "groomer" ? 2 : 1) && reviews.every(review => review.origin === "human"),
    current, reference, delta: complete ? current - reference : null,
    currentHit: metric("current", "hitAt3"), referenceHit: metric(baseline, "hitAt3"),
    deltaBounds: empty ? null : ratings.length ? [mean(ratings.map(r => r.deltaBounds[0])), mean(ratings.map(r => r.deltaBounds[1]))] : [-1, 1],
    disagreements: [...known].filter(id => new Set(ratings.filter(r => Object.hasOwn(r.values, id)).map(r => r.values[id])).size > 1),
    reviewers: ratings.map((rating, index) => ({ reviewer_id: reviews[index].reviewer_id, metrics: rating.metrics })) };
}
function groupedMean(rows, key) {
  const groups = Map.groupBy(rows, row => row.source_group);
  return mean([...groups.values()].map(group => mean(group.map(row => row[key]))));
}
function interval(values, seed) {
  // Fixed PRNG is only for reproducible sampling, never identity or security.
  let state = seed >>> 0;
  const random = () => {
    state += 0x6d2b79f5;
    let value = Math.imul(state ^ state >>> 15, 1 | state);
    value ^= value + Math.imul(value ^ value >>> 7, 61 | value);
    return ((value ^ value >>> 14) >>> 0) / 4294967296;
  };
  const samples = Array.from({ length: 2000 }, () => mean(values.map(() => values[Math.floor(random() * values.length)]))).sort((a, b) => a - b);
  return [samples[49], samples[1949]];
}
function summarize(rows, seed) {
  const sampled = rows.filter(row => !row.explicitMode);
  const nonempty = sampled.filter(row => !row.empty), complete = nonempty.filter(row => row.complete);
  const values = [...Map.groupBy(complete, row => row.source_group).values()].map(group => mean(group.map(row => row.delta)));
  const missingRate = nonempty.length ? (nonempty.length - complete.length) / nonempty.length : null;
  const delta = groupedMean(complete, "delta");
  const inferential = rows[0].source_kind === "real_redacted" && rows[0].split === "holdout";
  const humanReady = sampled.every(row => row.humanReady);
  const confidenceInterval = inferential && humanReady && values.length >= 20 && missingRate <= 0.1 ? interval(values, seed) : null;
  let conclusion = "descriptive_only";
  if (!complete.length || missingRate > 0.1 || (inferential && !humanReady)) conclusion = "insufficient";
  else if (confidenceInterval) {
    const [low, high] = confidenceInterval;
    conclusion = delta >= 0.05 && low > 0 ? "advantage" : low >= -0.05 ? "non_inferior" : high < -0.05 ? "inferior" : "insufficient";
  }
  const bound = index => groupedMean(nonempty.map(row => ({ ...row, bound: row.deltaBounds[index] })), "bound");
  return { role: rows[0].role, source_kind: rows[0].source_kind, baseline: rows[0].baseline,
    caseCount: rows.length, explicitModeCases: rows.length - sampled.length,
    emptyPools: sampled.length - nonempty.length, unknownCases: nonempty.length - complete.length,
    independentGroups: new Set(sampled.map(row => row.source_group)).size, completeGroups: values.length,
    missingRate, delta, current: groupedMean(complete, "current"), reference: groupedMean(complete, "reference"),
    currentHit: groupedMean(complete, "currentHit"), referenceHit: groupedMean(complete, "referenceHit"),
    deltaBounds: nonempty.length ? [bound(0), bound(1)] : null, confidenceInterval, conclusion,
    strata: [...new Set(rows.flatMap(row => row.strata))].map(stratum => {
      const selected = complete.filter(row => row.strata.includes(stratum));
      return { stratum, caseCount: rows.filter(row => row.strata.includes(stratum)).length,
        completeCases: selected.length, independentGroups: new Set(selected.map(row => row.source_group)).size,
        delta: groupedMean(selected, "delta"), conclusion: "descriptive_only" };
    }) };
}
export function evaluateDataset(snapshots, labels, split = "development") {
  assert.ok(["development", "holdout"].includes(split), "Invalid split");
  validateSnapshots(snapshots);
  assert.equal(labels.snapshot_hash, hash(snapshots), "Labels snapshot hash mismatch");
  unique(labels.cases.map(row => row.case_id), "label case ID");
  const caseIDs = new Set(snapshots.cases.map(row => row.case_id));
  assert.ok(labels.cases.every(row => caseIDs.has(row.case_id)), "Labels contain unknown case");
  const labelRows = new Map(labels.cases.map(row => [row.case_id, row]));
  const cases = snapshots.cases.filter(row => row.split === split)
    .map(row => evaluateCase(row, labelRows.get(row.case_id), snapshots.primary_baselines[row.role]));
  return { schema_version: 1, snapshot_hash: hash(snapshots), split, seed: snapshots.seed,
    scope: "Frozen panel judgments only; declared provenance requires independent audit; no causal or service-quality claim.",
    status: cases.length ? "evaluated" : "insufficient", cases,
    groups: [...Map.groupBy(cases, row => `${row.role}:${row.source_kind}`).values()].map(rows => summarize(rows, snapshots.seed)) };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const { values } = parseArgs({ options: { input: { type: "string" }, labels: { type: "string" },
      out: { type: "string" }, split: { type: "string", default: "development" } } });
    for (const key of ["input", "labels", "out"]) text(values[key], `--${key}`);
    const report = evaluateDataset(JSON.parse(readFileSync(values.input, "utf8")), JSON.parse(readFileSync(values.labels, "utf8")), values.split);
    mkdirSync(dirname(resolve(values.out)), { recursive: true, mode: 0o700 });
    writeFileSync(values.out, JSON.stringify(report, null, 2) + "\n", { flag: "wx", mode: 0o600 });
    console.log(JSON.stringify({ status: report.status, split: report.split, cases: report.cases.length,
      conclusions: report.groups.map(group => ({ role: group.role, source_kind: group.source_kind, conclusion: group.conclusion })) }));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
