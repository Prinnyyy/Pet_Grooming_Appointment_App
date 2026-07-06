import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationPath = join(
  process.cwd(),
  "supabase/migrations/20260706211524_t154_request_expiry_conversion.sql",
);
const sql = readFileSync(migrationPath, "utf8");

test("T-154 migration defines a private controlled expiry function", () => {
  assert.match(sql, /create extension if not exists pg_cron/i);
  assert.match(
    sql,
    /create or replace function app_private\.expire_grooming_requests\(\s*p_batch_size integer default 250\s*\)/i,
  );
  assert.match(
    sql,
    /returns table\s*\(\s*expired_request_count integer,\s*expired_offer_count integer,\s*expired_match_count integer\s*\)/i,
  );
  assert.match(sql, /language plpgsql/i);
  assert.match(sql, /security definer/i);
  assert.match(sql, /set search_path = ''/i);
  assert.match(
    sql,
    /revoke all on function app_private\.expire_grooming_requests\(integer\)\s+from public, anon, authenticated, service_role/i,
  );
  assert.match(
    sql,
    /grant execute on function app_private\.expire_grooming_requests\(integer\) to service_role/i,
  );
  assert.doesNotMatch(
    sql,
    /grant execute on function app_private\.expire_grooming_requests\(integer\) to authenticated/i,
  );
});

test("T-154 expiry function converts only stale active request state", () => {
  assert.match(
    sql,
    /from public\.grooming_requests[\s\S]*status in \('open', 'has_offers'\)[\s\S]*expires_at <= statement_timestamp\(\)[\s\S]*order by expires_at, created_at[\s\S]*for update skip locked/i,
  );
  assert.match(
    sql,
    /update public\.groomer_offers[\s\S]*set\s+status = 'expired'[\s\S]*where[\s\S]*request_id = any[\s\S]*status = 'pending'/i,
  );
  assert.match(
    sql,
    /update public\.request_matches[\s\S]*set\s+status = 'expired'[\s\S]*where[\s\S]*request_id = any[\s\S]*status in \('visible', 'viewed', 'offered'\)/i,
  );
  assert.match(
    sql,
    /update public\.grooming_requests[\s\S]*set\s+status = 'expired'[\s\S]*where[\s\S]*id = any/i,
  );
});

test("T-154 migration schedules recurring request expiry processing", () => {
  assert.match(
    sql,
    /cron\.schedule\(\s*'groomly_expire_grooming_requests'/i,
  );
  assert.match(sql, /'\*\/5 \* \* \* \*'/i);
  assert.match(sql, /select app_private\.expire_grooming_requests\(250\)/i);
});
