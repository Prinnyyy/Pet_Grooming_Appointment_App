import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const sql=readFileSync('supabase/migrations/20260915233821_t392_browse_evidence_snapshot.sql','utf8');

test('browse evidence remains private, bounded and independent from booking admission',()=>{
  assert.match(sql,/create table app_private\.match_browse_snapshots/);
  assert.match(sql,/enable row level security/);
  assert.match(sql,/revoke all on app_private\.match_browse_snapshots from public,anon,authenticated,service_role/);
  assert.match(sql,/octet_length\(soft_evidence::text\)<=262144/);
  assert.match(sql,/offset 31/);
  assert.match(sql,/valid_until<=captured_at\+interval '5 minutes'/);
  assert.doesNotMatch(sql,/create or replace function .*accept_groomer_offer|disable trigger/i);
});

test('stable core rechecks current hard eligibility before reusing only soft scores and ratings',()=>{
  assert.match(sql,/ranked_marketplace_page_with_evidence[\s\S]*?language plpgsql stable security definer/);
  for(const expression of ['read_candidate_evaluation(request_id,groomer_id,clock)',
    'evaluate_quote(offer_id,clock)',"q.reason='hard_eligibility'","message='list_changed'",
    "p_soft->'items'->item_id::text",'score_as_of','privacy_revision']) assert.ok(sql.includes(expression),expression);
  assert.match(sql,/from app_private\.match_browse_snapshots[\s\S]*?viewer_id=actor/);
  assert.match(sql,/snapshot\.soft_evidence/);
  assert.match(sql,/payload->'groomer_profile'\)\|\|\(saved->'ratings'\)/);
  assert.match(sql,/cursor_data->>'ranking_revision' is distinct from revision/);
  assert.match(sql,/new\.anonymized_at is distinct from old\.anonymized_at/);
});

test('new POST wrappers keep legacy stable reads and never expose stored scores',()=>{
  for(const name of ['get_ranked_matched_requests_v2','get_ranked_customer_offers_v2']) {
    assert.match(sql,new RegExp(`public\\.${name}\\([\\s\\S]*?language sql volatile security invoker`));
  }
  assert.match(sql,/return result-'_soft_evidence'/);
  assert.match(sql,/app_private\.ranked_marketplace_page\(p_role,p_request,p_sort,p_limit,p_cursor\)/);
  assert.match(sql,/match_cursor_encode\(cursor_data\|\|jsonb_build_object\('snapshot_id'/);
  assert.match(sql,/snapshot\.privacy_revision is distinct from config\.privacy_revision/);
  assert.match(sql,/snapshot\.valid_until<=statement_timestamp\(\)/);
});
