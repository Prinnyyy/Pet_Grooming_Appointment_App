import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const sql = readFileSync(new URL("../../supabase/migrations/20260908203810_t376_versioned_agreements.sql", import.meta.url), "utf8");
const noticeSQL = readFileSync(new URL("../../supabase/migrations/20260908212824_t376_quote_notice_revocation.sql", import.meta.url), "utf8");

test("notice policy invalidates through admission-locked fresh eligibility revisions", () => {
  assert.match(noticeSQL, /previous_notice is distinct from next_notice/);
  assert.match(noticeSQL, /hashtextextended\(owner::text,71071\)/);
  assert.match(noticeSQL, /new\.eligibility_revision is distinct from old\.eligibility_revision/);
  assert.match(noticeSQL, /new\.eligibility_revision:=gen_random_uuid\(\)/);
  assert.match(noticeSQL, /after insert or update or delete on public\.groomer_booking_preferences/);
});

test("versioned acceptance preserves original receipt implementation and rejects old writers", () => {
  assert.match(sql, /p_expected_quote_revision is distinct from revision/);
  assert.match(sql, /return query select \* from app_private\.accept_groomer_offer\(p_offer_id\)/);
  assert.match(sql, /revoke execute on function app_private\.accept_groomer_offer\(uuid\) from public,anon,authenticated,service_role/);
  assert.match(sql, /updated_agreement_client_required/);
});

test("snapshots retain provenance and do not backfill unknown historical agreements", () => {
  for (const field of ["address_line_2", "source_location_id", "confirmed_at", "service_time_zone_identifier", "request_revision", "quote_revision"]) {
    assert.ok(sql.includes(`'${field}'`), field);
  }
  assert.match(sql, /new\.agreement_snapshot:=o\.agreement_snapshot/);
  assert.doesNotMatch(sql, /update public\.bookings set agreement_snapshot/i);
  assert.match(sql, /booking_agreement_is_immutable/);
});

test("replacement and evaluation preserve atomicity and temporary-capacity distinction", () => {
  assert.match(sql, /create unique index grooming_requests_one_replacement/);
  assert.match(sql, /perform app_private\.cancel_grooming_request\(original\.id\)/);
  assert.match(sql, /'terms_valid',true,'selectable',false,'reason','capacity_unavailable'/);
  assert.match(sql, /'terms_valid',false,'selectable',false,'reason','expired'/);
  assert.match(sql, /notify pgrst, 'reload schema'/);
});
