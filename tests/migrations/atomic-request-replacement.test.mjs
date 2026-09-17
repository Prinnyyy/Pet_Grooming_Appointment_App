import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const directory = "supabase/migrations";
const correction = readdirSync(directory).find(name => name.endsWith("_t388_atomic_request_replacement.sql"));
const sql = readFileSync(`${directory}/${correction ?? "20260908203810_t376_versioned_agreements.sql"}`, "utf8")
  .split(/create (?:or replace )?function app_private\.supersede_grooming_request/)[1]?.split("end $$;")[0] ?? "";

test("replacement retires the locked original before normal quota-checked publication", () => {
  const cancel = sql.indexOf("perform app_private.cancel_grooming_request(original.id)");
  const create = sql.indexOf("from app_private.create_grooming_request_v4(");
  assert.ok(cancel >= 0 && create > cancel, "Original must be retired inside the transaction before publishing");
  assert.ok(sql.indexOf("for update") < cancel);
  assert.match(sql, /original\.terms_revision is distinct from p_expected_request_revision/);
  assert.match(sql, /original\.expires_at\s*<=\s*statement_timestamp\(\)/);
  assert.doesNotMatch(sql, /exception\s+when|ignore_request|skip_quota/i);
});

test("replacement preserves authenticated ownership and replay intent before mutation", () => {
  assert.match(sql, /is_anonymous/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /r\.customer_id=actor/);
  assert.match(sql, /r\.supersedes_request_id=p_request_id/);
  assert.match(sql, /publish_operation_intent_changed/);
  assert.ok(sql.indexOf("return query select replacement,matches") < sql.indexOf("for update"));
  assert.match(sql, /set supersedes_request_id=original\.id/);
});
