import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const sql = readFileSync(new URL('../../supabase/migrations/20260911081552_t390_ranked_marketplace_reads.sql', import.meta.url), 'utf8');

test('ranked reads keep signing material private and bind the full cursor scope', () => {
  assert.match(sql, /extensions\.gen_random_bytes\(32\)/);
  assert.match(sql, /extensions\.hmac/);
  assert.match(sql, /revoke all on app_private\.match_ranking_config from public,anon,authenticated,service_role/);
  for (const field of ['viewer', 'role', 'scope', 'requested_mode', 'effective_mode', 'algorithm_version', 'score_as_of', 'valid_until', 'ranking_revision', 'last_key']) {
    assert.ok(sql.includes(`'${field}'`), field);
  }
});

test('sorting consumes the full authorized set before keyset pagination', () => {
  assert.match(sql, /STABLE SECURITY DEFINER/i);
  assert.match(sql, /ranking_revision/);
  assert.match(sql, /list_changed/);
  assert.match(sql, /invalid_cursor/);
  assert.match(sql, /order by value->'sort_key'/);
  assert.match(sql, /value->'sort_key'>last_key/);
  assert.doesNotMatch(sql, /\boffset\b/i);
  assert.doesNotMatch(sql, /max\(updated_at\)/i);
});

test('both role-scoped entry points are present and scoring failures stay narrow', () => {
  assert.match(sql, /public\.get_ranked_matched_requests/);
  assert.match(sql, /public\.get_ranked_customer_offers/);
  assert.match(sql, /customer_id=actor/);
  assert.match(sql, /groomer_id=actor/);
  assert.match(sql, /'time_fallback'/);
  assert.doesNotMatch(sql, /when others then/i);
});
test("snapshot invalidation returns business conflict rather than serialization retry", () => {
  const correction = readFileSync("supabase/migrations/20260911114919_t390_ranked_read_conflicts.sql", "utf8");
  assert.match(correction, /errcode='PT409',message='list_changed'/);
  assert.doesNotMatch(correction, /errcode='40001'/);
});

test("page scoring shares validated timezones without dropping validation", () => {
  const correction = readFileSync("supabase/migrations/20260911115915_t390_batch_ranking_timezone_validation.sql", "utf8");
  assert.match(correction, /select array_agg\(name\) into valid_zones from pg_catalog\.pg_timezone_names/);
  assert.match(correction, /request_id,groomer_id,as_of,offer_id,valid_zones/);
  assert.match(correction, /p_zone=any\(p_valid_zones\)/);
  assert.match(correction, /p_snapshot->>'birthday' is null/);
  assert.match(correction, /from public,anon,authenticated,service_role/);
});

test("private validation cohort changes rollout only, after existing authorization", () => {
  const correction=readFileSync("supabase/migrations/20260911141434_t390_private_ranking_validation_cohort.sql","utf8");
  const previous=readFileSync("supabase/migrations/20260911115915_t390_batch_ranking_timezone_validation.sql","utf8");
  const start="create or replace function app_private.ranked_marketplace_page";
  const body=correction.slice(correction.indexOf(start),correction.indexOf("\nnotify pgrst"));
  assert.equal(body.replace("\n  config.enabled:=config.enabled or actor=any(config.validation_actor_ids);", "").trim(),
    previous.slice(previous.indexOf(start)).trim());
  assert.match(correction,/validation_actor_ids uuid\[\] not null default '\{\}'/);
  assert.doesNotMatch(correction,/grant /i);
  assert.ok(correction.indexOf("message='not_allowed'")<correction.indexOf("actor=any(config.validation_actor_ids)"));
});

test("page-local reuse includes every scoring input without a persistent cache", () => {
  const source=readFileSync("supabase/migrations/20260911143541_t390_reuse_page_evidence.sql","utf8");
  assert.match(source,/score_cache jsonb:='\{\}'/);
  assert.match(source,/jsonb_build_array\(groomer_id,lower\(r.pet_snapshot->>'species'\),r.service_type,/);
  assert.match(source,/match_target_keys\(request_id,groomer_id,offer_id,valid_zones\),distance_miles,as_of/);
  assert.match(source,/score:=score_cache->score_key/);
  assert.doesNotMatch(source,/create table|alter table|grant /i);
  assert.ok(source.indexOf("message='not_allowed'")<source.indexOf("score:=score_cache->score_key"));
});
