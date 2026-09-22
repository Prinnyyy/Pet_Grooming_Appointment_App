import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

// Migration boundary guards only. SQL/HTTP probes separately establish runtime behavior.
const migration = readdirSync("supabase/migrations").find(name => name.endsWith("_request_discovery_context.sql"));
const sql = migration ? readFileSync(`supabase/migrations/${migration}`, "utf8") : "";

test("calendar reuse is exact, private, and limited to one candidate read", () => {
  const name=readdirSync("supabase/migrations").find(x=>x.endsWith("_request_discovery_calendar_reuse.sql"));
  const optimized=readFileSync(`supabase/migrations/${name}`,"utf8");
  assert.match(optimized,/weekly_cache jsonb:='\{\}'/);
  assert.match(optimized,/calendar_key:=jsonb_build_array\(window_start-make_interval\(mins=>before_minutes\),\s*window_end\+make_interval\(mins=>after_minutes\),zone,starts,ends\)::text/);
  assert.match(optimized,/app_private\.match_weekly_ranges_validated/);
  assert.match(optimized,/revoke all on function app_private\.evaluate_context_eligibility_cached/);
  assert.match(optimized,/evaluate_context_constraints\(p_context,p_groomer,p_now\)/);
  assert.doesNotMatch(optimized,/create table|insert into|grant execute|skip locked|limit 26/i);
});

test("preview qualification uses a private context core without publishing or refreshing matches", () => {
  assert.match(sql, /function app_private\.evaluate_context_constraints\(p_context public\.grooming_requests/i);
  assert.match(sql, /function app_private\.evaluate_context_eligibility\(p_context public\.grooming_requests/i);
  assert.match(sql, /evaluate_context_constraints\(p_context,p_groomer,p_now\)/);
  assert.doesNotMatch(sql, /insert into public\.(grooming_requests|request_matches|groomer_notifications)/i);
  assert.doesNotMatch(sql, /perform app_private\.(create_request_matches|refresh_candidate_evaluation)/i);
});

test("legacy qualification wrappers keep request lifecycle checks and delegate rather than copy rules", () => {
  assert.match(sql, /function app_private\.evaluate_match_constraints\(p_request uuid/i);
  assert.match(sql, /r\.status not in \('open','has_offers'\)/);
  assert.match(sql, /return app_private\.evaluate_context_constraints\(r,p_groomer,p_now\)/);
  assert.match(sql, /return app_private\.evaluate_context_eligibility\(r,p_groomer,p_now,p_valid_zones\)/);
});

test("preview and offer scoring share one evidence calculation with distinct target facts", () => {
  assert.match(sql, /function app_private\.score_context_evidence\(p_context public\.grooming_requests/i);
  assert.match(sql, /function app_private\.context_target_keys\(p_context public\.grooming_requests/i);
  assert.match(sql, /request_id=r\.id and groomer_id=p_groomer/);
  assert.match(sql, /return app_private\.score_context_evidence\(r,p_groomer_id,p_score_as_of,p_offer_id,p_valid_zones\)/);
  assert.equal((sql.match(/'f',50\+50\*/g) ?? []).length, 1);
});

test("context helpers do not expose trusted snapshots or timezone catalogs as client RPCs", () => {
  for (const name of ["evaluate_context_constraints", "evaluate_context_eligibility", "context_target_keys", "score_context_evidence"]) {
    assert.match(sql, new RegExp(`revoke all on function app_private\\.${name}\\([\\s\\S]*?from public,anon,authenticated,service_role;`, "i"));
    assert.doesNotMatch(sql, new RegExp(`grant execute on function app_private\\.${name}`, "i"));
  }
  assert.doesNotMatch(sql, /disable row level security|set search_path\s*=\s*public/i);
});

test("discovery sessions are bounded, owner scoped, and private before publication", () => {
  assert.match(sql, /create table app_private\.request_discovery_sessions/i);
  assert.match(sql, /alter table app_private\.request_discovery_sessions enable row level security/i);
  assert.match(sql, /revoke all on (?:table )?app_private\.request_discovery_sessions from public,anon,authenticated,service_role/i);
  assert.match(sql, /interval '30 minutes'/);
  assert.match(sql, /discovery_session_limit_reached/);
  assert.match(sql, /function public\.prepare_request_discovery_v1\(p_draft_id uuid,p_input jsonb\)/i);
  assert.match(sql, /discovery_validation_actor_ids/);
});

test("preview canonical input rejects arbitrary fields and binds current pet facts", () => {
  assert.match(sql, /jsonb_object_keys\(p_input\)/);
  assert.match(sql, /invalid_discovery_input/);
  assert.match(sql, /source_revision/);
  assert.match(sql, /superseding_request_id/);
  assert.match(sql, /expected_request_revision/);
  assert.match(sql, /service_notes/);
});

test("discovery paging is scope signed and shares the existing bounded snapshot storage", () => {
  assert.match(sql, /function public\.get_request_groomer_candidates_v1/i);
  assert.match(sql, /function app_private\.store_match_browse_snapshot/i);
  assert.match(sql, /'purpose','groomer_discovery'/);
  assert.match(sql, /match_cursor_decode/);
  assert.match(sql, /match_cursor_encode/);
  assert.match(sql, /snapshot\.privacy_revision is distinct from config\.privacy_revision/);
  assert.match(sql, /octet_length\(p_soft::text\)>262144/);
});

test("discovery rechecks live qualification before ranking the complete candidate set", () => {
  assert.match(sql, /evaluate_context_eligibility\(r,g\.user_id,clock,valid_zones\)/);
  assert.match(sql, /score_context_evidence\(r,g\.user_id,as_of,null,valid_zones\)/);
  assert.match(sql, /public_matching_evidence\(score\)/);
  assert.match(sql, /order by value->'sort_key' limit p_limit\+1/);
  assert.match(sql, /function public\.get_discovery_groomer_profile_v1/i);
  assert.doesNotMatch(sql, /from public\.groomer_profiles[^;]*limit (8|10|25|50)\b/i);
});
