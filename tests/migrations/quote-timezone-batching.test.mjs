import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const sql=readFileSync('supabase/migrations/20260917011801_t392_batch_quote_timezone_validation.sql','utf8');

test('quote admission shares a statement-local catalog without a persistent or client-controlled cache',()=>{
  for(const name of ['evaluate_quote','groomer_can_admit_service','occupied_time_off_conflict','occupied_weekly_hours_covered']) {
    assert.match(sql,new RegExp(`FUNCTION app_private\\.${name}\\([^\\n]+p_valid_zones text\\[\\]\\)`));
    assert.ok(sql.includes(`revoke all on function app_private.${name}(`));
  }
  assert.match(sql,/not coalesce\(zone=any\(p_valid_zones\),false\)/);
  assert.match(sql,/not coalesce\(v_zone=any\(p_valid_zones\),false\)/);
  assert.match(sql,/groomer_can_admit_service\(o.groomer_id,o.proposed_start,o.proposed_end,p_now,p_valid_zones\)/);
  assert.match(sql,/occupied_time_off_conflict\(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones\)/);
  assert.match(sql,/occupied_weekly_hours_covered\(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones\)/);
  assert.doesNotMatch(sql,/create (?:table|materialized view)|set_config|disable trigger|statement_timeout/i);
});

test('both ranked cores and authorized quote detail batches reuse the catalog with ranking disabled too',()=>{
  assert.equal((sql.match(/evaluation:=app_private.evaluate_quote\(offer_id,clock,valid_zones\)/g)||[]).length,2);
  assert.equal((sql.match(/if config.enabled or p_role='customer' then select array_agg\(name\)/g)||[]).length,2);
  assert.equal((sql.match(/and w.timezone=any\(valid_zones\)/g)||[]).length,2);
  assert.match(sql,/return query select o.id,app_private.evaluate_quote\(o.id,statement_timestamp\(\),valid_zones\)/);
  for(const check of ['p_offer_ids','o.customer_id=actor',"p.role='customer'",'o.groomer_id=actor',"p.role='groomer'",'booking_pet_end','booking_resource_end','assessment_confirmation_required']) assert.ok(sql.includes(check),check);
});
