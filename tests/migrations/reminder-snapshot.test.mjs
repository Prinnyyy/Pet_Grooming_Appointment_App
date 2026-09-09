import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { test } from 'node:test';
const file = readdirSync('supabase/migrations').find(name => name.endsWith('_t382_reminder_snapshot.sql'));
const sql = file ? readFileSync(`supabase/migrations/${file}`, 'utf8') : '';
test('reminder snapshot is an owned complete bounded scalar under RLS', () => {
  assert.match(sql, /returns jsonb/);
  assert.match(sql, /security invoker/);
  assert.match(sql, /owner is distinct from p_participant_id/);
  assert.match(sql, /is_anonymous/);
  assert.match(sql, /interval '30 days'/);
  assert.match(sql, /limit 4097/);
  assert.match(sql, /snapshot_too_large/);
  assert.match(sql, /from public, anon/);
});
