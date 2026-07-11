import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDirectory = join(process.cwd(), "supabase/migrations");
const migrationName = readdirSync(migrationsDirectory).find((name) =>
  name.endsWith("_t283_fix_avatar_rls_recursion.sql"),
);

test("T-283 installs a private avatar relationship helper that bypasses recursive RLS", () => {
  assert.ok(migrationName, "T-283 migration is missing");
  const sql = readFileSync(join(migrationsDirectory, migrationName), "utf8");

  assert.match(
    sql,
    /create or replace function app_private\.customer_can_view_groomer_avatar\(\s*p_groomer_id uuid\s*\)[\s\S]*returns boolean[\s\S]*language sql[\s\S]*stable[\s\S]*security definer[\s\S]*set search_path = ''/i,
  );
  assert.match(sql, /\(select auth\.uid\(\)\) is not null/i);
  assert.match(sql, /profiles\.role = 'customer'::public\.user_role/i);
  assert.match(sql, /bookings\.customer_id = \(select auth\.uid\(\)\)/i);
  assert.match(sql, /groomer_offers\.customer_id = \(select auth\.uid\(\)\)/i);
  assert.match(
    sql,
    /revoke all on function app_private\.customer_can_view_groomer_avatar\(uuid\)\s+from public, anon, authenticated, service_role/i,
  );
  assert.match(
    sql,
    /grant execute on function app_private\.customer_can_view_groomer_avatar\(uuid\)\s+to authenticated/i,
  );
});

test("T-283 profile and Storage policies use the helper instead of RLS table joins", () => {
  assert.ok(migrationName, "T-283 migration is missing");
  const sql = readFileSync(join(migrationsDirectory, migrationName), "utf8");
  const profilePolicy = sql.slice(
    sql.indexOf("create policy profiles_select_own_or_customer_groomer_avatar"),
    sql.indexOf("drop policy groomer_avatar_objects_select_owner_or_customer"),
  );
  const storagePolicy = sql.slice(
    sql.indexOf("create policy groomer_avatar_objects_select_owner_or_customer"),
  );

  assert.match(
    profilePolicy,
    /app_private\.customer_can_view_groomer_avatar\(profiles\.id\)/i,
  );
  assert.doesNotMatch(profilePolicy, /from public\.(bookings|groomer_offers)/i);
  assert.match(
    storagePolicy,
    /app_private\.customer_can_view_groomer_avatar\([\s\S]*storage\.foldername/i,
  );
  assert.doesNotMatch(storagePolicy, /from public\.(bookings|groomer_offers)/i);
});
