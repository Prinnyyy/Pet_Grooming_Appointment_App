import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const sql = readFileSync('supabase/migrations/20261103220458_t463_booking_chat_event_cards.sql', 'utf8').replace(/--[^\n]*/g, '');

test('T-463 event facts are display-only and not a client writer', () => {
  assert.match(sql, /add column booking_event jsonb/);
  assert.match(sql, /booking_event->>'actor_id'=sender_id::text/);
  assert.match(sql, /4096\) is true/);
  assert.match(sql, /security invoker set search_path=''/);
  assert.match(sql, /revoke all on function app_private.booking_chat_event[\s\S]*?from public,anon,authenticated,service_role/);
  assert.doesNotMatch(sql, /\bgrant\b|drop policy|disable row level|delete from public.messages/i);
});

test('T-463 replaces only exact message INSERTs and retains writer authorization and receipts', () => {
  const patches = [...sql.matchAll(/old_sql text:=\$old\$([\s\S]*?)\$old\$;\s*new_sql text:=\$new\$([\s\S]*?)\$new\$;/g)];
  assert.equal(patches.length, 7);
  assert.equal(patches.filter(([, , next]) => next.trim()).length, 4);
  for (const [, old, next] of patches) {
    assert.match(old, /^  insert into public.messages/);
    if (next) {
      assert.match(next, /'booking_card'/);
      assert.match(next, /app_private.booking_chat_event/);
      assert.doesNotMatch(next, /'text'/);
    }
  }
  assert.equal((sql.match(/T463 message writer drift/g) ?? []).length, 7);
  assert.match(sql, /'reschedule_'\|\|p_action/);
  assert.match(sql, /proposal.proposed_start/);
});

test('T-463 keeps counterpart notifications when the card replaces automatic text', () => {
  assert.equal((sql.match(/new.kind not in \('text','booking_card'\)/g) ?? []).length, 2);
  assert.match(sql, /groomer_notifications_after_customer_message_insert/);
  assert.match(sql, /customer_notifications_after_groomer_message_insert/);
});
