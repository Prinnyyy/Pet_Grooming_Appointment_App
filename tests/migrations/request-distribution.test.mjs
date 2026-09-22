import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";
const file=readdirSync("supabase/migrations").find(x=>x.endsWith("_request_distribution.sql"));
const sql=file?readFileSync(`supabase/migrations/${file}`,"utf8"):"";
test("cutover requires a restored cohort and retires unsafe legacy publication atomically",()=>{
  const file=readdirSync("supabase/migrations").find(x=>x.endsWith("_request_distribution_cutover.sql"));
  const cutover=readFileSync(`supabase/migrations/${file}`,"utf8");
  assert.match(cutover,/discovery_enabled=true,legacy_publish_retired=true/);
  assert.match(cutover,/not discovery_enabled and not legacy_publish_retired/);
  assert.match(cutover,/cardinality\(discovery_validation_actor_ids\)=0/);
  assert.match(cutover,/if not found then raise exception/);
  assert.doesNotMatch(cutover,/disable row level security|drop policy|grant .*anon/i);
});
test("waiting facts reuse projections and preserve pending versus completed zero",()=>{
  const name=readdirSync("supabase/migrations").find(x=>x.endsWith("_request_distribution_waiting_facts.sql"));
  const fix=readFileSync(`supabase/migrations/${name}`,"utf8");
  assert.match(fix,/'pool_candidate_count'/);
  assert.match(fix,/match_candidate_evaluations/);
  assert.match(fix,/c\.valid_until<=statement_timestamp\(\)/);
  assert.match(fix,/m\.status='dismissed'/);
  assert.doesNotMatch(fix,/evaluate_match_eligibility|score_match_evidence|request_discovery_candidates_page/);
});
test("pool reopening can recover system-hidden matches without resurrecting dismissals",()=>{
  const name=readdirSync("supabase/migrations").find(x=>x.endsWith("_request_distribution_reopen_visibility.sql"));
  const fix=readFileSync(`supabase/migrations/${name}`,"utf8");
  assert.match(fix,/new\.status='hidden' and new\.dismissed_at is null/);
  assert.match(fix,/'state','excluded','reason','request_distribution_closed'/);
  assert.match(fix,/old\.status='dismissed' or old\.dismissed_at is not null/);
});
test("invitations and mutation receipts are private and unique",()=>{
  for(const table of ["request_invitations","request_distribution_operations"]) {
    assert.match(sql,new RegExp(`alter table app_private\\.${table} enable row level security`,"i"));
    assert.match(sql,new RegExp(`revoke all on app_private\\.${table} from public,anon,authenticated,service_role`,"i"));
  }
  assert.match(sql,/primary key\(request_id,groomer_id\)/);
  assert.match(sql,/primary key\(customer_id,operation_id\)/);
});
test("first publication has one receipt and does not use legacy broadcast then undo",()=>{
  assert.match(sql,/function app_private\.publish_request_with_distribution_v1/);
  assert.match(sql,/insert into app_private\.request_publish_operations/);
  assert.match(sql,/already_published/);
  assert.match(sql,/operation_intent_changed/);
  assert.match(sql,/insert_request_context/);
  assert.match(sql,/discovery_pet_source/);
  assert.match(sql,/least\(statement_timestamp\(\)\+interval '48 hours'/);
});
test("post-publication writes are request locked and explicit target state operations",()=>{
  for(const rpc of ["invite_request_groomers_v1","set_request_pool_v1","withdraw_request_invitation_v1","get_customer_request_progress_v1"]) {
    assert.match(sql,new RegExp(`function public\\.${rpc}`));
  }
  assert.match(sql,/for update/);
  assert.match(sql,/invitation_limit_reached/);
  assert.match(sql,/distribution_changed/);
});
test("distribution gates match creation and new quotes but not existing quote qualification",()=>{
  assert.match(sql,/function app_private\.request_distribution_allows_new_quote/);
  assert.match(sql,/function app_private\.guard_offer_distribution/);
  assert.match(sql,/create trigger groomer_offers_.*distribution/);
  assert.match(sql,/function app_private\.guard_match_distribution/);
  assert.doesNotMatch(sql,/create or replace function app_private\.evaluate_quote/i);
});
test("old reads and workers share distribution facts; raw request reads are owner-only",()=>{
  for(const name of ["read_candidate_evaluation","refresh_candidate_evaluation","enqueue_match_refresh","enqueue_request_match_refresh",
    "get_my_matched_request","get_my_matched_requests","get_ranked_matched_requests","get_ranked_matched_requests_v2"]) {
    assert.match(sql,new RegExp(`create or replace function app_private\\.${name}\\(`,"i"));
  }
  assert.match(sql,/drop policy grooming_requests_select_customer_or_matched_groomer/);
  assert.match(sql,/create policy grooming_requests_select_owner/);
  for(const name of ["get_groomer_request_summaries_v1","get_groomer_request_detail_v1","get_booking_request_locations_v1"]) {
    assert.match(sql,new RegExp(`function public\\.${name}\\(`));
  }
  assert.match(sql,/drop policy request_photos_objects_select_customer_or_matched_groomer/);
});
test("booking fallback keeps its contract and media reads avoid quote recomputation",()=>{
  const correction=readdirSync("supabase/migrations").find(x=>x.endsWith("_request_distribution_read_compatibility.sql"));
  const fix=correction?readFileSync(`supabase/migrations/${correction}`,"utf8"):"";
  assert.match(fix,/'service_type',r\.service_type,'pet_snapshot',r\.pet_snapshot/);
  assert.match(fix,/function app_private\.request_has_current_offer/);
  assert.doesNotMatch(fix,/app_private\.evaluate_quote\(/);
  assert.match(fix,/terms_invalid_reason is null/);
  assert.match(fix,/service_eligibility_revision/);
});
