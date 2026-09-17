import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync('supabase/migrations/20260917013719_t392_assessment_interval_proofs.sql','utf8');

test('assessment retains unknown-fact requirements and an optimistic interval rather than becoming estimated fit',()=>{
  assert.match(sql,/'state','assessment_required','reason','service_details_unconfirmed',[\s\S]*?'required_confirmations',to_jsonb\(required\),[\s\S]*?'service_start',allocation.service_start/);
  assert.match(sql,/service.accepted_species is null,cardinality\(required\),duration,service.id/);
  assert.match(sql,/when result->>'state'='assessment_required' then 'optimistic_source_interval'/);
  assert.doesNotMatch(sql,/create or replace function.*(?:accept_groomer_offer|evaluate_quote|read_candidate_evaluation)/i);
});

test('only interval-backed assessments use the same bounded validity proof as estimated matches',()=>{
  assert.match(sql,/result->>'state' in \('estimated_fit','assessment_required'\)[\s\S]*?result \?& array\['service_start','service_end','occupied_start','occupied_end'\]/);
  assert.match(sql,/future_result->>'state'=result->>'state'/);
  assert.match(sql,/future_result \?& array\['service_start','service_end','occupied_start','occupied_end'\]/);
  assert.match(sql,/deadline:=least\(r.expires_at,\(result->>'service_start'\)::timestamptz-interval '5 minutes'\)/);
  assert.match(sql,/if notice>0 then deadline:=least\(deadline,timezone/);
  assert.match(sql,/deadline:=least\(r.expires_at,p_now\+interval '60 seconds'\)/);
  assert.match(sql,/reason='hard_eligibility'/);
  assert.doesNotMatch(sql,/disable trigger|grant execute|update public\.groomer_offers/i);
});
