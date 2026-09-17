import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t351_participant_conversations_booking_events.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-351 participant chat migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");

const privateFunctionSql = (name) => {
  const match = sql.match(
    new RegExp(
      `create or replace function app_private\\.${name}\\([\\s\\S]*?\\n\\$\\$;`,
      "i",
    ),
  );
  assert.ok(match, `${name} must be rebuilt under app_private`);
  return match[0];
};

test("T-351 merges historical conversations and makes participant pairs unique", () => {
  assert.match(sql, /create temporary table t351_conversation_merge_map/i);
  assert.match(
    sql,
    /row_number\(\) over\s*\(\s*partition by conversation\.customer_id, conversation\.groomer_id/i,
  );
  assert.match(sql, /update public\.messages as message[\s\S]*canonical_conversation_id/i);
  assert.match(sql, /set updated_at = greatest[\s\S]*max\(message\.created_at\)/i);
  assert.match(sql, /delete from public\.conversations as conversation[\s\S]*canonical_conversation_id/i);
  assert.match(sql, /drop column booking_id/i);
  assert.match(sql, /drop column request_id/i);
  assert.match(sql, /unique \(customer_id, groomer_id\)/i);
});

test("T-351 adds typed booking-card messages and keeps direct writes text-only", () => {
  assert.match(sql, /add column kind text not null default 'text'/i);
  assert.match(sql, /add column booking_id uuid/i);
  assert.match(sql, /kind in \('text', 'booking_card'\)/i);
  assert.match(sql, /kind = 'booking_card'[\s\S]*booking_id is not null[\s\S]*body is null/i);
  assert.match(sql, /kind = 'text'[\s\S]*booking_id is null/i);
  assert.match(sql, /grant insert \(conversation_id, sender_id, body\)/i);
  assert.doesNotMatch(sql, /grant insert \([^)]*(kind|booking_id)/i);
  assert.match(sql, /messages_insert_conversation_participants[\s\S]*kind = 'text'/i);
});

test("T-351 acceptance inserts the booking card before friendly plain text", () => {
  const acceptSql = privateFunctionSql("accept_groomer_offer");
  assert.match(acceptSql, /on conflict \(customer_id, groomer_id\)/i);
  assert.match(acceptSql, /returning id[\s\S]*into v_conversation_id/i);

  const cardIndex = acceptSql.indexOf("'booking_card'");
  const textIndex = acceptSql.indexOf("Hi! I''ve accepted your offer");
  assert.ok(cardIndex >= 0, "acceptance must insert a booking card");
  assert.ok(textIndex > cardIndex, "acceptance text must be inserted after the card");
  assert.match(acceptSql, /v_event_created_at \+ interval '1 microsecond'/i);
});

test("T-351 cancellation inserts the booking card before actor-authored text", () => {
  const cancelSql = privateFunctionSql("cancel_booking");
  const cardIndex = cancelSql.indexOf("'booking_card'");
  const textIndex = cancelSql.indexOf("Hi, I''m sorry, but I''ve had to cancel this booking");
  assert.ok(cardIndex >= 0, "cancellation must insert a booking card");
  assert.ok(textIndex > cardIndex, "cancellation text must be inserted after the card");
  assert.match(cancelSql, /sender_id[\s\S]*v_user_id/i);
  assert.match(cancelSql, /v_event_created_at \+ interval '1 microsecond'/i);
});

test("T-351 preserves message ordering and notification compatibility", () => {
  assert.match(sql, /messages_conversation_created_idx[\s\S]*created_at asc, id asc/i);
  assert.match(sql, /after insert on public\.messages[\s\S]*t351_touch_conversation/i);
  assert.match(sql, /groomer_notifications_after_customer_message_insert[\s\S]*new\.kind <> 'text'[\s\S]*return new/i);
  assert.match(sql, /customer_notifications_after_groomer_message_insert[\s\S]*new\.kind <> 'text'[\s\S]*return new/i);
  assert.doesNotMatch(
    sql,
    /conversation\.(booking_id|request_id)/i,
    "notification helpers must not read removed conversation booking columns",
  );
});

test("T-351 keeps private lifecycle helpers and public wrappers least-privileged", () => {
  assert.match(sql, /security definer\s+set search_path = ''/i);
  assert.match(sql, /security invoker\s+set search_path = ''/i);
  assert.match(sql, /revoke all on function app_private\.accept_groomer_offer\(uuid\)/i);
  assert.match(sql, /revoke all on function app_private\.cancel_booking\(uuid\)/i);
  assert.match(
    sql,
    /grant execute on function public\.accept_groomer_offer\(uuid\)\s+to authenticated/i,
  );
  assert.match(
    sql,
    /grant execute on function public\.cancel_booking\(uuid\)\s+to authenticated/i,
  );
});
