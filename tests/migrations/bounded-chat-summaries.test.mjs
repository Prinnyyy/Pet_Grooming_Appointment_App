import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { test } from 'node:test';

const file = readdirSync('supabase/migrations').find(name => name.endsWith('_t380_bounded_chat_summaries.sql'));
const sql = readFileSync(`supabase/migrations/${file}`, 'utf8');

test('chat summaries preserve caller RLS and deny anonymous or excessive scopes', () => {
  assert.match(sql, /security invoker/i);
  assert.doesNotMatch(sql, /security definer/i);
  assert.match(sql, /cardinality\(p_conversation_ids\) > 100/i);
  assert.match(sql, /is_anonymous/);
  assert.match(sql, /conversation_not_available/);
  assert.match(sql, /revoke all on function[\s\S]*from public, anon/i);
});

test('chat summaries return at most one stable message and booking per owned conversation', () => {
  assert.equal((sql.match(/left join lateral/gi) ?? []).length, 2);
  assert.match(sql, /order by m.created_at desc, m.id desc\s+limit 1/i);
  assert.match(sql, /order by b.scheduled_start desc, b.id desc\s+limit 1/i);
  assert.match(sql, /b.customer_id = c.customer_id and b.groomer_id = c.groomer_id/i);
  assert.match(sql, /customer_id, groomer_id, scheduled_start desc, id desc/i);
});
