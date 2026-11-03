import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const sql = readFileSync(new URL('../../supabase/migrations/20261103042313_t448_chat_counterpart_names.sql', import.meta.url), 'utf8');
test('name RPC checks auth, anonymous scope and every requested conversation before reading profiles', () => {
  assert.match(sql, /actor is null or coalesce\(\(auth.jwt\(\)->>'is_anonymous'\)/);
  assert.match(sql, /cardinality\(p_conversation_ids\) > 100/);
  assert.match(sql, /array_position\(p_conversation_ids, null\)/);
  assert.equal((sql.match(/actor in \(c.customer_id, c.groomer_id\)/g) ?? []).length, 2);
  assert.ok(sql.indexOf("message = 'conversation_not_available'") < sql.indexOf('join public.profiles'));
});
test('name RPC returns only counterpart identity and keeps profile policies intact', () => {
  assert.match(sql, /returns table \(conversation_id uuid, display_name text\)/);
  assert.match(sql, /case when c.customer_id = actor then c.groomer_id else c.customer_id end/);
  assert.match(sql, /security definer set search_path = ''/);
  assert.doesNotMatch(sql, /create policy|alter table|email|avatar_path|phone/);
});
test('name RPC is authenticated only', () => {
  assert.match(sql, /revoke all on function public.get_chat_counterpart_names\(uuid\[\]\) from public, anon/);
  assert.match(sql, /grant execute on function public.get_chat_counterpart_names\(uuid\[\]\) to authenticated/);
});
test('final RPC privileges reuse current conversation and profile RLS', () => {
  const followup = readFileSync(new URL('../../supabase/migrations/20261103045834_t448_chat_names_reuse_rls.sql', import.meta.url), 'utf8');
  assert.match(followup, /alter function public.get_chat_counterpart_names\(uuid\[\]\) security invoker/);
  assert.doesNotMatch(followup, /create policy|alter table|security definer/);
});
