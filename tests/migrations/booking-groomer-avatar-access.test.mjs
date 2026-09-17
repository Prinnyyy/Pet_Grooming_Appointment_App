import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import test from "node:test";

const migrationDirectory = new URL("../../supabase/migrations/", import.meta.url);
const migrationName = readdirSync(migrationDirectory).find((name) =>
  name.endsWith("_t263_booking_groomer_avatar_access.sql"),
);
const mergeMigrationName = readdirSync(migrationDirectory).find((name) =>
  name.endsWith("_t263_merge_avatar_select_policies.sql"),
);

test("T-263 limits Groomer avatar profile access to booking customers", () => {
  assert.ok(migrationName, "T-263 migration is missing");
  const sql = readFileSync(new URL(migrationName, migrationDirectory), "utf8");

  assert.match(sql, /create policy profiles_select_booking_groomer_avatar/i);
  assert.match(sql, /profiles\.role\s*=\s*'groomer'/i);
  assert.match(sql, /bookings\.groomer_id\s*=\s*profiles\.id/i);
  assert.match(sql, /bookings\.customer_id\s*=\s*\(select auth\.uid\(\)\)/i);
  assert.match(sql, /groomer_offers\.groomer_id\s*=\s*profiles\.id/i);
  assert.match(sql, /groomer_offers\.customer_id\s*=\s*\(select auth\.uid\(\)\)/i);
});

test("T-263 merges profile and Storage avatar SELECT policies", () => {
  assert.ok(mergeMigrationName, "T-263 merge migration is missing");
  const sql = readFileSync(new URL(mergeMigrationName, migrationDirectory), "utf8");

  assert.match(sql, /drop policy profiles_select_own/i);
  assert.match(sql, /drop policy profiles_select_booking_groomer_avatar/i);
  assert.match(sql, /create policy profiles_select_own_or_customer_groomer_avatar/i);
  assert.match(sql, /profiles\.id\s*=\s*\(select auth\.uid\(\)\)/i);
  assert.match(sql, /drop policy groomer_avatar_objects_select_own/i);
  assert.match(sql, /drop policy groomer_avatar_objects_select_booking_customer/i);
  assert.match(sql, /create policy groomer_avatar_objects_select_owner_or_customer/i);
});

test("T-263 limits private Groomer avatar objects to booking customers", () => {
  assert.ok(migrationName, "T-263 migration is missing");
  const sql = readFileSync(new URL(migrationName, migrationDirectory), "utf8");

  assert.match(sql, /create policy groomer_avatar_objects_select_booking_customer/i);
  assert.match(sql, /bucket_id\s*=\s*'groomer-avatars'/i);
  assert.match(sql, /bookings\.groomer_id::text\s*=\s*\(storage\.foldername\(storage\.objects\.name\)\)\[1\]/i);
  assert.match(sql, /bookings\.customer_id\s*=\s*\(select auth\.uid\(\)\)/i);
  assert.match(sql, /groomer_offers\.groomer_id::text\s*=\s*\(storage\.foldername\(storage\.objects\.name\)\)\[1\]/i);
  assert.match(sql, /groomer_offers\.customer_id\s*=\s*\(select auth\.uid\(\)\)/i);
});
