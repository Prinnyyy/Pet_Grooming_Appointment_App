import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const name = readdirSync("supabase/migrations").find(value => value.endsWith("_t388_message_notification_conversations.sql"));
const sql = name ? readFileSync(`supabase/migrations/${name}`, "utf8") : "";

for (const role of ["customer", "groomer"]) {
  test(`${role} text notifications atomically reference the participant conversation`, () => {
    assert.match(sql, new RegExp(`alter table public\\.${role}_notifications[\\s\\S]*?related_conversation_id uuid`));
    assert.match(sql, /references public\.conversations\(id\) on delete set null/);
    const functionName = role === "customer" ? "customer_notifications_after_groomer_message_insert" : "groomer_notifications_after_customer_message_insert";
    const body = sql.split(`function app_private.${functionName}()`)[1]?.split("end $$;")[0] ?? "";
    assert.match(body, /new\.kind <> 'text'/);
    assert.match(body, /new\.sender_id = v_(groomer|customer)_id/);
    assert.match(body, /conversation\.id = new\.conversation_id/);
    assert.match(body, new RegExp(`insert into public\\.${role}_notifications`));
    assert.match(body, /related_conversation_id/);
    assert.doesNotMatch(body, /new\.body|order by|limit 1/i);
    assert.match(sql, new RegExp(`revoke all on function app_private\\.${functionName}\\(\\)`));
  });
}

test("migration neither rewrites historical targets nor relaxes client privileges", () => {
  assert.doesNotMatch(sql, /update public\.(customer|groomer)_notifications|grant|disable row level security/i);
  assert.match(sql, /notify pgrst, 'reload schema'/);
});
