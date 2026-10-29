import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import test from 'node:test';
const latest = readdirSync('supabase/migrations').sort().filter(n => n.endsWith('_t421_grooming_review_eligibility.sql')).at(-1);
const sql = latest ? readFileSync(`supabase/migrations/${latest}`, 'utf8') : '';

test('elapsed reviews are server-authorized without completing the booking or inventing expertise', () => {
  assert.match(sql, /function app_private\.grooming_finished_at/);
  assert.match(sql, /outcome_reported/);
  assert.match(sql, /pg_catalog\.pg_timezone_names/);
  assert.match(sql, /greatest\(/);
  assert.match(sql, /elapsed_unverified/);
  assert.match(sql, /values\(b.id,'\[\]','elapsed_unverified'\)/);
  assert.doesNotMatch(sql, /update public\.bookings|interval '14 days'/i);
});

test('review read and write share eligibility and retain ownership and trusted context guards', () => {
  assert.equal((sql.match(/if app_private\.grooming_finished_at\(b\) is null or app_private\.grooming_finished_at\(b\)>statement_timestamp\(\)/g) ?? []).length, 2);
  for (const token of ['customer_id=actor', 'for update', 'authenticated_user_required', 'customer_profile_required', 'review_context_changed', 'duplicate_review_outcome', 'review_already_exists', 'from public,anon,authenticated,service_role']) assert.ok(sql.includes(token), token);
});

const profileMigration = readdirSync('supabase/migrations').sort().find(n => n.endsWith('_t421_customer_groomer_profile.sql'));
const profileSQL = profileMigration ? readFileSync(`supabase/migrations/${profileMigration}`, 'utf8') : '';
test('customer profile reuses actor and active-groomer guards without widening table or storage access', () => {
  for (const fragment of ['require_discovery_customer()', 'marketplace_groomer_summary(p_groomer_id)',
    "message='groomer_unavailable'", "security definer set search_path = ''", 'from public,anon,authenticated,service_role', 'to authenticated']) {
    assert.ok(profileSQL.includes(fragment), fragment);
  }
  assert.doesNotMatch(profileSQL, /create policy|alter table|grant select/i);
  assert.doesNotMatch(profileSQL, /base_street_address|base_zip_code|address_location_id|auto_accept_bookings|max_appointments_per_day/);
});
test('profile time off hides private titles and omits inactive services and claims', () => {
  assert.match(profileSQL, /'title','Unavailable'/);
  assert.doesNotMatch(profileSQL, /t\.title|to_jsonb\([a-z]\)/);
  assert.match(profileSQL, /s\.groomer_id=g\.user_id and s\.is_active/);
  assert.match(profileSQL, /c\.groomer_id=g\.user_id and c\.is_active/);
});
