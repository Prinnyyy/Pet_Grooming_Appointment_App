import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { test } from 'node:test';
const file = readdirSync('supabase/migrations').find(name => name.endsWith('_t381_exact_notification_targets.sql'));
const sql = readFileSync(`supabase/migrations/${file}`, 'utf8');
test('exact notification match checks owner and masks pending refresh without paging first', () => {
  assert.match(sql, /owner is distinct from p_groomer_id/);
  assert.match(sql, /is_anonymous/);
  assert.match(sql, /m.request_id=p_request_id/);
  assert.match(sql, /match_refresh_queue/);
  assert.match(sql, /limit 1/);
  assert.match(sql, /security invoker/);
  assert.match(sql, /from public, anon/);
});
