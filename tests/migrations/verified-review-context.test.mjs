import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const file = readdirSync("supabase/migrations").find(name => name.endsWith("_t390_verified_review_context.sql"));
const sql = file ? readFileSync(`supabase/migrations/${file}`, "utf8") : "";

test("review context is frozen per booking with private access and service-time facts", () => {
  assert.match(sql, /create table app_private\.booking_review_contexts/);
  assert.match(sql, /booking_id uuid primary key/);
  assert.match(sql, /on delete cascade/);
  assert.match(sql, /on conflict \(booking_id\) do nothing/);
  assert.match(sql, /scheduled_start/);
  assert.match(sql, /get_booking_review_context/);
  assert.doesNotMatch(sql, /coalesce\([^;]*service_at[^;]*(?:now\(\)|statement_timestamp\(\))/i);
});

test("one review writer checks owner, context revision, allowed keys and cardinality", () => {
  for (const required of ["create_review_v2", "review_context_changed", "invalid_pet_fit_context",
    "booking_not_completed", "duplicate_review_outcome", "review_already_exists"]) {
    assert.ok(sql.includes(required), required);
  }
});

test("ratings retain exact sums and cover insert update delete without rounded recurrence", () => {
  assert.match(sql, /rating_sum bigint/);
  assert.match(sql, /after insert or update or delete on public\.reviews/);
  assert.match(sql, /old\.rating/);
  assert.match(sql, /new\.rating/);
  assert.doesNotMatch(sql, /rating_avg\s*\*\s*[^;]*rating_count/i);
});

test("soft account anonymization clears derived facts and prevents evidence rebuilding", () => {
  assert.match(sql, /after insert or update of anonymized_at on public\.account_deletion_requests/);
  assert.match(sql, /service_at=null,service_time_zone_identifier=null/);
  assert.match(sql, /source_state='privacy_withheld',context_revision=gen_random_uuid\(\)/);
  assert.match(sql, /if c\.source_state='privacy_withheld' then return; end if/);
  assert.match(sql, /values\(b\.id,'\[\]','privacy_withheld'\)/);
});

test("account redaction uses versioned cancellation and exact private snapshot transforms", () => {
  const migration = readdirSync("supabase/migrations").find(name => name.endsWith("_t390_account_redaction_compatibility.sql"));
  const redaction = readFileSync(`supabase/migrations/${migration}`, "utf8");
  for (const required of ["active_account_redaction", "redacted_agreement", "redacted_request",
    "mutate_booking_fulfillment", "fulfillment_phase='scheduled'", "scheduled_start>clock_timestamp()",
    "booking_agreement_is_immutable", "quote_terms_are_immutable", "published_request_terms_are_immutable",
    "from public,anon,authenticated,service_role"]) assert.ok(redaction.includes(required),required);
  assert.doesNotMatch(redaction,/disable trigger|session_replication_role|set_config\('app.fulfillment_write'/i);
});

test("latest account writer uses the existing named conflict constraint", () => {
  const files = readdirSync("supabase/migrations").sort();
  const definitions = files.map(file => readFileSync(`supabase/migrations/${file}`, "utf8"))
    .filter(sql => /create or replace function app_private\.request_account_deletion\(\)/i.test(sql));
  const latest = definitions.at(-1);
  assert.match(latest,/on conflict on constraint account_deletion_requests_user_key do update/i);
  assert.doesNotMatch(latest,/account_deletion_requests_user_id_key/);
  assert.ok(latest.includes("where m.sender_id=actor and m.kind='text'"),"Booking cards must not receive text bodies");
  assert.ok(latest.includes("breed='Unspecified'"));
  assert.ok(latest.includes("temperament='Not Sure'"));
  assert.doesNotMatch(latest,/update public\.pets p set[^;]*species='pet'/);
});

test("account API preserves authenticated writer access without exposing transforms", () => {
  const grantFile=readdirSync("supabase/migrations").find(name=>name.endsWith("_t390_restore_account_writer_grant.sql"));
  const grant=readFileSync(`supabase/migrations/${grantFile}`,"utf8");
  assert.match(grant,/grant execute on function app_private\.request_account_deletion\(\) to authenticated;/);
  assert.doesNotMatch(grant,/grant[^;]*(?:active_account_redaction|redacted_agreement|redacted_request)/);
  const runner=readFileSync("scripts/test-t390-matching-scenarios.mjs","utf8");
  assert.match(runner,/set local role authenticated;\s*select \* from public\.request_account_deletion\(\);/);
});

test("account redaction releases attempt locks before bounded source-row retry", () => {
  const file = readdirSync("supabase/migrations").find(name => name.endsWith("_t390_account_redaction_lock_retry.sql"));
  const retry = readFileSync(`supabase/migrations/${file}`, "utf8");
  assert.match(retry, /for attempt in 1\.\.3 loop\s+begin/);
  assert.match(retry, /for no key update nowait/g);
  assert.match(retry, /exception when lock_not_available then/);
  assert.match(retry, /if attempt=3 then raise exception using errcode='PT409',message='account_deletion_retry'/);
  assert.match(retry, /grant execute on function app_private\.request_account_deletion\(\) to authenticated;/);
  assert.doesNotMatch(retry, /exception when (?:others|deadlock_detected)|disable trigger/i);
  assert.match(retry, /end \$\$;/);
});
