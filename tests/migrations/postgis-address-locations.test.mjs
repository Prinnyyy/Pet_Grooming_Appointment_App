import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationName = "20260712014418_t294_postgis_private_address_locations.sql";
const migrationPath = join(process.cwd(), "supabase/migrations", migrationName);
const validationPath = join(
  process.cwd(),
  "docs/06_tasks/sql_reviews/T-294_POSTGIS_ADDRESS_ROLLBACK_VALIDATION.sql",
);
const sql = readFileSync(migrationPath, "utf8");

test("T-294 installs private PostGIS address storage with spatial indexes", () => {
  assert.match(sql, /create extension if not exists postgis with schema extensions/i);
  assert.match(sql, /create table app_private\.address_locations\s*\(/i);
  assert.match(sql, /owner_id uuid not null references public\.profiles\s*\(id\) on delete cascade/i);
  assert.match(sql, /provider text not null[\s\S]*provider = 'apple_maps'/i);
  assert.match(sql, /country_code text not null[\s\S]*country_code = 'US'/i);
  assert.match(sql, /latitude double precision not null[\s\S]*between -90 and 90/i);
  assert.match(sql, /longitude double precision not null[\s\S]*between -180 and 180/i);
  assert.match(
    sql,
    /location extensions\.geography\(point, 4326\) generated always as\s*\([\s\S]*extensions\.st_makepoint\(longitude, latitude\)[\s\S]*stored/i,
  );
  assert.match(sql, /using gist\s*\(location\)/i);
  assert.match(sql, /on app_private\.address_locations\s*\(owner_id\)/i);
  assert.match(sql, /alter table app_private\.address_locations enable row level security/i);
  assert.match(
    sql,
    /revoke all on table app_private\.address_locations\s+from public, anon, authenticated/i,
  );
  assert.doesNotMatch(
    sql,
    /grant (?:select|insert|update|delete|all)(?:\s*\([^;]*\))?\s+on table app_private\.address_locations\s+to (?:anon|authenticated)/i,
  );
});

test("T-294 adds line two and private location references without exposing coordinates", () => {
  for (const table of ["customer_profiles", "groomer_profiles", "grooming_requests"]) {
    assert.match(
      sql,
      new RegExp(
        `alter table public\\.${table}[\\s\\S]*add column if not exists .*address_line_2 text[\\s\\S]*add column if not exists address_location_id uuid`,
        "i",
      ),
    );
    assert.match(
      sql,
      new RegExp(
        `${table}_address_location_fkey[\\s\\S]*foreign key \\(address_location_id\\)[\\s\\S]*references app_private\\.address_locations \\(id\\)`,
        "i",
      ),
    );
  }

  assert.match(sql, /address_line_2 is null[\s\S]*char_length\(address_line_2\) between 1 and 60/i);
  assert.doesNotMatch(
    sql,
    /grant (?:insert|update)\s*\([^;]*address_location_id[^;]*\)\s+on table public\.(?:customer_profiles|groomer_profiles|grooming_requests)\s+to authenticated/i,
  );
});

test("T-294 exposes only owner-checked profile address RPC wrappers", () => {
  for (const role of ["customer", "groomer"]) {
    assert.match(
      sql,
      new RegExp(`create function app_private\\.save_${role}_profile_address_v2\\(`, "i"),
    );
    assert.match(
      sql,
      new RegExp(
        `app_private\\.save_${role}_profile_address_v2\\([\\s\\S]*v_user_id uuid := \\(select auth\\.uid\\(\\)\\)[\\s\\S]*profile\\.role = '${role}'::public\\.user_role`,
        "i",
      ),
    );
    assert.match(
      sql,
      new RegExp(`create function public\\.save_${role}_profile_address_v2\\(`, "i"),
    );
    assert.match(
      sql,
      new RegExp(
        `create function public\\.save_${role}_profile_address_v2\\([\\s\\S]*security invoker[\\s\\S]*app_private\\.save_${role}_profile_address_v2`,
        "i",
      ),
    );
  }

  assert.match(sql, /revoke all on function public\.save_customer_profile_address_v2\(/i);
  assert.match(sql, /revoke all on function public\.save_groomer_profile_address_v2\(/i);
  assert.match(sql, /grant execute on function public\.save_customer_profile_address_v2\([\s\S]*to authenticated, service_role/i);
  assert.match(sql, /grant execute on function public\.save_groomer_profile_address_v2\([\s\S]*to authenticated, service_role/i);

  for (const role of ["customer", "groomer"]) {
    assert.match(
      sql,
      new RegExp(`create function public\\.get_my_${role}_profile_address_v2\\(\\)`, "i"),
    );
    assert.match(
      sql,
      new RegExp(
        `app_private\\.get_my_${role}_profile_address_v2\\([\\s\\S]*where ${role}_profile\\.user_id = \\(select auth\\.uid\\(\\)\\)`,
        "i",
      ),
    );
  }
});

test("T-294 creates a versioned request RPC and snapshots private coordinates atomically", () => {
  assert.match(sql, /create function app_private\.create_grooming_request_v2\(/i);
  assert.match(sql, /create function public\.create_grooming_request_v2\(/i);
  assert.match(
    sql,
    /create function public\.create_grooming_request_v2\([\s\S]*security invoker[\s\S]*app_private\.create_grooming_request_v2/i,
  );
  assert.match(
    sql,
    /insert into app_private\.address_locations[\s\S]*insert into public\.grooming_requests[\s\S]*address_line_2[\s\S]*address_location_id/i,
  );
  assert.match(sql, /app_private\.create_request_matches_for_request\(\s*v_request_id,\s*null\s*\)/i);
  assert.doesNotMatch(
    sql,
    /create function public\.create_grooming_request_v2\([\s\S]*default\s+(?:null|[0-9'"-])/i,
    "v2 should not use default parameters that can create ambiguous PostgREST overloads",
  );
});

test("T-294 matching uses distance and the direction-correct controlling radius", () => {
  assert.match(
    sql,
    /create or replace function app_private\.create_request_matches_for_request\(/i,
  );
  assert.match(
    sql,
    /create function app_private\.evaluate_request_location_fit\([\s\S]*extensions\.st_distance\(\s*p_request_location,\s*p_groomer_location\s*\)\s*\/\s*1609\.344/i,
  );
  assert.match(
    sql,
    /when p_location_mode = 'customer_comes_to_groomer'[\s\S]*p_customer_travel_radius_miles[\s\S]*else p_groomer_service_radius_miles/i,
  );
  assert.match(sql, /distance_miles <= measured\.allowed_radius/i);
  assert.match(
    sql,
    /round\(\s*80 - 20 \* least\([\s\S]*distance_miles \/ measured\.allowed_radius,[\s\S]*1[\s\S]*\)[\s\S]*location_score/i,
  );
  assert.match(sql, /Legacy location fallback/i);
  assert.match(
    sql,
    /p_request_location is null or p_groomer_location is null[\s\S]*p_groomer_state = p_request_state/i,
  );
  assert.match(
    sql,
    /cross join lateral app_private\.evaluate_request_location_fit\([\s\S]*location_fit[\s\S]*and location_fit\.is_eligible/i,
  );
  assert.match(sql, /within the customer''s[\s\S]*travel range/i);
  assert.match(sql, /within the groomer''s[\s\S]*service range/i);
  assert.match(sql, /app_private\.pet_fit_traits_from_snapshot\(/i);
  assert.match(sql, /from public\.groomer_services as groomer_service/i);
  assert.match(sql, /app_private\.groomer_has_capacity_on_request_day\(/i);
  assert.match(sql, /app_private\.groomer_is_available_for_range\(/i);
  assert.match(
    sql,
    /groomer_profile\.service_location_modes @>[\s\S]*array\[selected_request\.location_mode\]/i,
  );
});

test("T-294 includes rollback-only runtime coverage for privileges and radius boundaries", () => {
  const validation = readFileSync(validationPath, "utf8");
  assert.match(validation, /^begin;/im);
  assert.match(validation, /rollback;\s*$/i);
  assert.match(validation, /set local role authenticated/i);
  assert.match(validation, /has_table_privilege\(\s*'authenticated',[\s\S]*address_locations[\s\S]*<> false/i);
  assert.match(validation, /customer_comes_to_groomer/i);
  assert.match(validation, /groomer_comes_to_customer/i);
  assert.match(validation, /exact radius boundary/i);
  assert.match(validation, /outside radius/i);
  assert.match(validation, /multilingual city/i);
  assert.match(validation, /Legacy location fallback/i);
});
