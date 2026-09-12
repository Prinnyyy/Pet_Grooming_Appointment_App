import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";
import { customerWeights, fitScore, scoreEvidence } from "../support/matching-rating-reference.mjs";

const vectors = JSON.parse(readFileSync("tests/fixtures/matching-rating-v1.json", "utf8"));
const migration = readdirSync("supabase/migrations").find(name => name.endsWith("_t390_matching_evidence_v1.sql"));
const sql = readFileSync(`supabase/migrations/${migration}`, "utf8");
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-9, `${actual} != ${expected}`);
test("fixed fit vectors preserve neutral, negative and polarized evidence", () => {
  for (const { positive, negative, expected } of vectors.fit) near(fitScore(positive, negative), expected);
});

test("fixed denominator, separate cohorts, custom neutrality and missing distance", () => {
  const target = { species: "dog", service: "full_groom", keys: ["service:full_groom", "coat:wire", "size:S"] };
  const review = { customer: "a", species: "dog", service: "full_groom", rating: 5, age: 0,
    answers: { "service:full_groom": "positive" } };
  near(scoreEvidence(target, [review], 0).f, 53.125);
  near(scoreEvidence(target, [{ ...review, species: "cat" }], 0).f, 50);
  near(scoreEvidence(target, [{ ...review, species: "cat" }], 0).q, 58.333333333333336);
  near(scoreEvidence({ ...target, service: "custom_request" }, [review], 0).f, 50);
  assert.equal(scoreEvidence(target, [], null).b, null);
  const repeated = scoreEvidence(target, Array(10).fill(review), 5);
  near(repeated.f, 53.125);
  const independent = scoreEvidence(target, Array.from({ length: 10 }, (_, i) => ({ ...review, customer: `${i}` })), 5);
  assert.ok(independent.f > repeated.f);
});
test("customer influence decays rather than being normalized back to one", () => {
  for (const { ages, expected } of vectors.weights) customerWeights(ages).forEach((weight, i) => near(weight, expected[i]));
  const recent = customerWeights(Array(10).fill(200)).reduce((a, b) => a + b, 0);
  const older = customerWeights(Array(10).fill(380)).reduce((a, b) => a + b, 0);
  near(older, recent / 2);
  assert.ok(recent > 0 && recent < 1);
});

test("partial answers and multiple care keys retain fixed group shares", () => {
  const target = { species: "dog", service: "full_groom",
    keys: ["service:full_groom", "coat:wire", "size:S", "care:senior", "care:anxiety"] };
  const review = { customer: "a", species: "dog", service: "full_groom", rating: 5, age: 0,
    answers: { "care:senior": "positive", "care:anxiety": "positive" } };
  const care = scoreEvidence(target, [review], 5);
  near(care.positive, 0.25);
  near(care.negative, 0);
  const partial = scoreEvidence(target, [{ ...review, answers: { "care:senior": "positive" } }], 5);
  near(partial.positive, 0.125);
  near(partial.negative, 0);
  const negative = scoreEvidence(target, [{ ...review,
    answers: { ...review.answers, "service:full_groom": "negative" } }], 5);
  assert.ok(negative.f < care.f);
  near(negative.positive, care.positive);
});

test("empty and unrelated professional answers cannot dilute the fit cohort", () => {
  const target = { species: "dog", service: "nail_trim", keys: ["service:nail_trim", "size:XS"] };
  const related = { customer: "a", species: "dog", service: "nail_trim", rating: 5, age: 180,
    answers: { "service:nail_trim": "positive", "size:XS": "positive" } };
  const baseline = scoreEvidence(target, [related], 0);
  for (const unrelated of [{ answers: {} }, { species: "cat" }, { service: "bath" }]) {
    const rows = [related, { ...related, ...unrelated, rating: 1, age: 0 }];
    const score = scoreEvidence(target, rows, 0);
    near(score.f, baseline.f);
    assert.ok(score.q < baseline.q);
    const reversed = scoreEvidence(target, rows.toReversed(), 0);
    for (const key of ["f", "q", "d", "b", "s"]) near(score[key], reversed[key]);
  }
});

test("SQL keeps separate cohorts, whole-window age facts and a public allowlist", () => {
  for (const required of ["quality_weights", "fit_weights", "partition by customer_id", "count(distinct dimension)",
    "preferred_end-interval '1 microsecond'", "r.service_type<>'custom_request'", "public_matching_evidence"]) {
    assert.ok(sql.includes(required), required);
  }
  const publicProjection = sql.split("create function app_private.public_matching_evidence")[1];
  assert.doesNotMatch(publicProjection, /p_score->'(?:f|q|d|s|b|distance_miles|customer_id|latitude|longitude)'/);
});

test("decay optimization remains bounded and does not change public rating arithmetic", () => {
  const optimized=readFileSync("supabase/migrations/20260911142538_t390_materialize_review_decay.sql","utf8");
  assert.match(optimized,/fit_rows as materialized/);
  assert.equal((optimized.match(/<=15552000000\.0/g)??[]).length,2);
  assert.equal((optimized.match(/else power\(2\.0::numeric/g)??[]).length,2);
  assert.doesNotMatch(optimized,/update public\.groomer_profiles|double precision.*rating_sum/);
  assert.match(optimized,/max\(decay\) over\(partition by customer_id\)\*decay\/sum\(decay\)/);
});
