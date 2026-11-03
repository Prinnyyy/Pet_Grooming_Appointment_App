import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('T-461 adds only client message identity INSERT permission, preserving RLS and server fields', () => {
  const sql = readFileSync('supabase/migrations/20261103194205_t461_client_message_identity.sql', 'utf8')
    .replace(/--[^\n]*/g, '').trim().replace(/\s+/g, ' ').toLowerCase();
  assert.equal(sql, 'begin; grant insert (id) on table public.messages to authenticated; commit;');
});
