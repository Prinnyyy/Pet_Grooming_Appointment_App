import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDirectory = join(process.cwd(), "supabase/migrations");
const migrationName = readdirSync(migrationsDirectory).find((name) =>
  name.endsWith("_t355_chat_counterpart_avatar_access.sql"),
);

test("T-355 limits Customer avatar profile access to conversation Groomers", () => {
  assert.ok(migrationName, "T-355 migration is missing");
  const sql = readFileSync(join(migrationsDirectory, migrationName), "utf8");

  assert.match(
    sql,
    /create or replace function app_private\.groomer_can_view_customer_avatar\(\s*p_customer_id uuid\s*\)[\s\S]*security definer[\s\S]*set search_path = ''/i,
  );
  assert.match(sql, /profiles\.role = 'groomer'::public\.user_role/i);
  assert.match(sql, /conversations\.customer_id = p_customer_id/i);
  assert.match(sql, /conversations\.groomer_id = \(select auth\.uid\(\)\)/i);
  assert.match(
    sql,
    /revoke all on function app_private\.groomer_can_view_customer_avatar\(uuid\)\s+from public, anon, authenticated, service_role/i,
  );
  assert.match(
    sql,
    /grant execute on function app_private\.groomer_can_view_customer_avatar\(uuid\)\s+to authenticated/i,
  );
});

test("T-355 merges related participant profile access without broad role visibility", () => {
  assert.ok(migrationName, "T-355 migration is missing");
  const sql = readFileSync(join(migrationsDirectory, migrationName), "utf8");

  assert.match(sql, /drop policy profiles_select_own_or_customer_groomer_avatar/i);
  assert.match(sql, /create policy profiles_select_own_or_related_participant_avatar/i);
  assert.match(sql, /profiles\.id = \(select auth\.uid\(\)\)/i);
  assert.match(sql, /app_private\.customer_can_view_groomer_avatar\(profiles\.id\)/i);
  assert.match(sql, /app_private\.groomer_can_view_customer_avatar\(profiles\.id\)/i);
  assert.doesNotMatch(sql, /profiles\.role = 'customer'[\s\S]*or true/i);
});

test("T-355 limits private Customer avatar objects to the conversation Groomer", () => {
  assert.ok(migrationName, "T-355 migration is missing");
  const sql = readFileSync(join(migrationsDirectory, migrationName), "utf8");

  assert.match(sql, /drop policy customer_avatar_objects_select_own/i);
  assert.match(sql, /create policy customer_avatar_objects_select_owner_or_conversation_groomer/i);
  assert.match(sql, /bucket_id = 'customer-avatars'/i);
  assert.match(sql, /owner_id = \(select auth\.uid\(\)\)::text/i);
  assert.match(sql, /array_length\(storage\.foldername\(storage\.objects\.name\), 1\) = 1/i);
  assert.match(
    sql,
    /app_private\.groomer_can_view_customer_avatar\([\s\S]*storage\.foldername\(storage\.objects\.name\)/i,
  );
});
