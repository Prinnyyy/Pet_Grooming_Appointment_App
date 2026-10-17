import assert from "node:assert/strict";
import {readFileSync,readdirSync} from "node:fs";
import test from "node:test";
const file=readdirSync("supabase/migrations").find(x=>x.endsWith("_customer_groomer_favorites.sql"));
const sql=file?readFileSync(`supabase/migrations/${file}`,"utf8"):"";
test("favorites are private target-state writes with revision and bounded retention",()=>{
  assert.match(sql,/alter table app_private\.customer_groomer_favorites enable row level security/);
  assert.match(sql,/primary key\(customer_id,groomer_id\)/);
  assert.match(sql,/favorite_changed/);
  assert.match(sql,/favorite_limit_reached/);
  assert.match(sql,/>=500/);
  assert.match(sql,/interval '30 days'/);
});
test("favorites reuse safe summaries and signed keyset cursors without affecting scoring",()=>{
  assert.match(sql,/function public\.set_groomer_favorite_v1/);
  assert.match(sql,/function public\.get_my_favorite_groomers_v1/);
  assert.match(sql,/app_private\.match_cursor_encode/);
  assert.match(sql,/app_private\.match_cursor_decode/);
  assert.match(sql,/app_private\.marketplace_groomer_summary/);
  assert.doesNotMatch(sql,/create or replace function app_private\.(score_|evaluate_context_)/);
});
test("avatar discovery requires the exact current path and redaction cleans new private data",()=>{
  assert.match(sql,/function app_private\.customer_can_read_marketplace_avatar/);
  assert.match(sql,/p\.avatar_path=p_path/);
  assert.doesNotMatch(sql,/update storage\.buckets/);
  for(const table of ["customer_groomer_favorites","request_discovery_sessions","request_invitations","request_distribution_operations"]) {
    assert.match(sql,new RegExp(`delete from app_private\\.${table}`));
  }
});
test("address deletion invalidates previews without cascading durable receipts",()=>{
  const file=readdirSync("supabase/migrations").find(x=>x.endsWith("_request_discovery_address_cleanup.sql"));
  const fix=readFileSync(`supabase/migrations/${file}`,"utf8");
  assert.match(fix,/references app_private\.address_locations\(id\)\s+on delete cascade/);
  assert.doesNotMatch(fix,/alter table app_private\.request_publish_operations/);
});
test("favorite capacity has one executable boundary under the existing account lock",()=>{
  const file=readdirSync("supabase/migrations").find(x=>x.endsWith("_request_favorite_capacity_policy.sql"));
  const fix=readFileSync(`supabase/migrations/${file}`,"utf8");
  assert.match(fix,/function app_private\.require_groomer_favorite_capacity\(p_current_count bigint\)/);
  assert.match(fix,/p_current_count>=500/);
  assert.match(fix,/perform app_private\.require_groomer_favorite_capacity\(\s*\(select count\(\*\)/);
  assert.ok(fix.indexOf("for update")<fix.indexOf("perform app_private.require_groomer_favorite_capacity"));
});
