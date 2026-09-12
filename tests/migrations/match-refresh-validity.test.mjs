import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";
const file = readdirSync("supabase/migrations").find(name => name.endsWith("_t390_match_refresh_validity.sql"));
const sql = readFileSync(`supabase/migrations/${file}`, "utf8");

test("refresh reasons separate hard admission from soft evidence rating and display", () => {
  for (const reason of ["hard_eligibility", "evidence", "rating", "display"]) assert.ok(sql.includes(`'${reason}'`), reason);
  assert.match(sql, /add column reason text/);
  assert.match(sql, /enqueue_soft_match_refresh/);
});
test("private candidate proofs include absent matches and bounded recheck fields", () => {
  assert.match(sql, /create table app_private\.match_candidate_evaluations/);
  assert.match(sql, /primary key\s*\(request_id,groomer_id\)/);
  for (const field of ["source_revision", "valid_until", "next_evaluation_at", "witness"]) assert.ok(sql.includes(field), field);
  assert.match(sql, /interval '60 seconds'/);
});
test("worker preserves new events and shares capacity between due proofs and queued events", () => {
  assert.match(sql, /skip locked/i);
  assert.match(sql, /id=any\(event_ids\)/);
  assert.match(sql, /next_evaluation_at<=/);
  assert.match(sql, /status='dismissed'/);
});
test("measured batch adjustment reuses the existing schedule", () => {
  const correction = readFileSync("supabase/migrations/20260911120656_t390_refresh_worker_batch.sql", "utf8");
  assert.match(correction, /cron\.alter_job/);
  assert.match(correction, /drain_match_refresh_queue\(100\)/);
  assert.match(correction, /schedule='10 seconds' and active/);
  assert.doesNotMatch(correction, /cron\.schedule\(/);
});
test("constant-offset fast path retains the original exact DST fallback", () => {
  const correction = readFileSync("supabase/migrations/20260911123342_t390_constant_offset_interval_fast_path.sql", "utf8");
  assert.match(correction, /lowest_offset=highest_offset/);
  assert.match(correction, /interval '1 second'/);
  assert.match(correction, /with wall as materialized/);
  assert.match(correction, /cardinality\(p_starts\) is distinct from 7/);
  assert.doesNotMatch(correction, /interval '1 (minute|hour)'/);
});
