import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationPath = join(
  process.cwd(),
  "supabase/migrations/20260706213507_t155_backfill_matching.sql",
);
const sql = readFileSync(migrationPath, "utf8");

test("T-155 migration extracts reusable private request matching insertion", () => {
  assert.match(
    sql,
    /create or replace function app_private\.create_request_matches_for_request\(\s*p_request_id uuid,\s*p_only_groomer_id uuid default null\s*\)/i,
  );
  assert.match(sql, /returns integer/i);
  assert.match(sql, /security definer/i);
  assert.match(sql, /set search_path = ''/i);
  assert.match(
    sql,
    /insert into public\.request_matches[\s\S]*on conflict on constraint request_matches_request_groomer_key do nothing/i,
  );
  assert.match(
    sql,
    /app_private\.groomer_has_capacity_on_request_day\(\s*groomer_profile\.user_id,\s*(?:request|selected_request)\.preferred_start\s*\)/i,
  );
  assert.match(
    sql,
    /revoke all on function app_private\.create_request_matches_for_request\(uuid, uuid\)\s+from public, anon, authenticated, service_role/i,
  );
  assert.doesNotMatch(
    sql,
    /grant execute on function app_private\.create_request_matches_for_request\(uuid, uuid\) to authenticated/i,
  );
});

test("T-155 create_grooming_request reuses the private matching insertion path", () => {
  assert.match(
    sql,
    /create or replace function public\.create_grooming_request\([\s\S]*v_match_count := app_private\.create_request_matches_for_request\(\s*v_request_id,\s*null\s*\)/i,
  );
  assert.match(
    sql,
    /comment on function public\.create_grooming_request\([\s\S]*reusable T-155 matching insertion/i,
  );
});

test("T-155 backfills missing matches for active open requests after groomer changes", () => {
  assert.match(
    sql,
    /create or replace function app_private\.backfill_request_matches_for_groomer\(\s*p_groomer_id uuid,\s*p_batch_size integer default 250\s*\)/i,
  );
  assert.match(
    sql,
    /request\.status in \('open', 'has_offers'\)[\s\S]*request\.expires_at > statement_timestamp\(\)[\s\S]*for update(?: of request)? skip locked/i,
  );
  assert.match(
    sql,
    /app_private\.create_request_matches_for_request\(\s*request_record\.id,\s*p_groomer_id\s*\)/i,
  );
  assert.match(
    sql,
    /create trigger groomer_profiles_backfill_matches_after_activation[\s\S]*after insert or update of is_active\s+on public\.groomer_profiles/i,
  );
  assert.match(
    sql,
    /create trigger groomer_availability_backfill_matches_after_change[\s\S]*after insert or update or delete\s+on public\.groomer_availability_windows/i,
  );
  assert.match(
    sql,
    /create trigger groomer_booking_preferences_backfill_matches_after_change[\s\S]*after insert or update or delete\s+on public\.groomer_booking_preferences/i,
  );
  assert.match(
    sql,
    /create trigger groomer_time_off_backfill_matches_after_change[\s\S]*after insert or update or delete\s+on public\.groomer_time_off_windows/i,
  );
});
