import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';

const sql = readFileSync(new URL('../../supabase/migrations/20260922084557_request_discovery_client_completion.sql', import.meta.url), 'utf8');
const isolation = readFileSync(new URL('../../supabase/migrations/20260922092038_request_discovery_receipt_isolation.sql', import.meta.url), 'utf8');
test('every legacy receipt reader refuses a discovery receipt without changing that receipt', () => {
  for (const name of ['create_grooming_request_v3', 'create_grooming_request_v4', 'supersede_grooming_request']) {
    const start = isolation.indexOf(`create or replace function app_private.${name}(`);
    assert.ok(start >= 0, name);
    const body = isolation.slice(start, isolation.indexOf('$$;', start));
    assert.match(body, /protocol_version<>\x27legacyV4\x27/);
    assert.match(body, /message='publish_operation_intent_changed'/);
    assert.match(body, /pg_advisory_xact_lock/);
  }
  assert.doesNotMatch(isolation, /delete from.*request_publish_operations|update.*protocol_version/i);
});
test('legacy retirement is independent of rollout and does not invalidate receipts', () => {
  assert.match(sql, /legacy_publish_retired boolean not null default false/);
  assert.match(sql, /before insert on public\.grooming_requests/);
  assert.match(sql, /message='client_update_required'/);
  assert.doesNotMatch(sql, /update app_private\.match_ranking_config|delete from.*request_publish_operations/i);
});
test('source labels preserve the safe request projection and private ACL', () => {
  assert.match(sql, /'pool_enabled',p_request\.pool_enabled/);
  assert.match(sql, /request_invitation_state\(p_request.id,\(select auth.uid\(\)\)\)/);
  assert.doesNotMatch(sql, /'street_address'|'zip_code'|'latitude'|'longitude'/);
  assert.match(sql, /revoke all on function app_private\.safe_groomer_request/);
});
