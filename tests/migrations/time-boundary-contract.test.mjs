import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const readMigration = (name) =>
  readFileSync(join(process.cwd(), "supabase/migrations", name), "utf8");

const requestDaySql = readMigration("20260701033335_t126_request_day_capacity_matching.sql");
const availabilitySql = readMigration("20260625073116_t071_availability_enforcement.sql");
const expirySql = readMigration("20260706211524_t154_request_expiry_conversion.sql");
const sizeBandSql = readMigration("20260627092014_t104_service_size_bands.sql");

const functionSql = (sql, schema, name) => {
  const match = sql.match(
    new RegExp(
      `create or replace function ${schema}\\.${name}\\([\\s\\S]*?\\n\\$\\$;`,
      "i",
    ),
  );

  assert.ok(match, `missing ${schema}.${name} function body`);
  return match[0];
};

test("request-day matching uses groomer-local dates for midnight and DST boundaries", () => {
  const helper = functionSql(
    requestDaySql,
    "app_private",
    "groomer_has_capacity_on_request_day",
  );

  assert.match(helper, /join pg_catalog\.pg_timezone_names as timezone_name/i);
  assert.match(
    helper,
    /timezone\(availability_window\.timezone,\s*p_requested_start\)::date as local_request_date/i,
  );
  assert.match(
    helper,
    /availability_window\.weekday\s*=\s*extract\(isodow from timezone\(availability_window\.timezone,\s*p_requested_start\)\)::smallint/i,
  );
  assert.match(
    helper,
    /timezone\(matching_window\.timezone,\s*statement_timestamp\(\)\)::date\s*\+\s*booking_preferences\.minimum_advance_notice_days/i,
  );
  assert.match(
    helper,
    /timezone\(matching_window\.timezone,\s*daily_booking\.scheduled_start\)::date\s*=\s*matching_window\.local_request_date/i,
  );
  assert.doesNotMatch(
    helper,
    /p_requested_start::date/i,
    "request-day matching should not derive the service date from the session/UTC date",
  );
});

test("exact availability keeps offer and booking times inside one enabled local window", () => {
  const helper = functionSql(
    availabilitySql,
    "app_private",
    "groomer_is_available_for_range",
  );

  assert.match(helper, /join pg_catalog\.pg_timezone_names as timezone_name/i);
  assert.match(helper, /p_scheduled_end > p_scheduled_start/i);
  assert.match(
    helper,
    /matching_window\.local_start::date\s*=\s*matching_window\.local_end::date/i,
    "exact booking windows should not silently span local midnight",
  );
  assert.match(helper, /matching_window\.local_start::time >= matching_window\.start_time/i);
  assert.match(helper, /matching_window\.local_end::time <= matching_window\.end_time/i);
  assert.match(
    helper,
    /existing_booking\.scheduled_start < p_scheduled_end[\s\S]*p_scheduled_start < existing_booking\.scheduled_end/i,
    "exact booking windows should reject overlaps, not just daily over-capacity",
  );
});

test("time-off, advance notice, and daily capacity are enforced for matching and exact availability", () => {
  const requestDayHelper = functionSql(
    requestDaySql,
    "app_private",
    "groomer_has_capacity_on_request_day",
  );
  const exactRangeHelper = functionSql(
    availabilitySql,
    "app_private",
    "groomer_is_available_for_range",
  );

  for (const [label, helper, localDateColumn] of [
    ["request-day", requestDayHelper, "matching_window.local_request_date"],
    ["exact-range", exactRangeHelper, "feasible_window.local_date"],
  ]) {
    assert.match(
      helper,
      new RegExp(`${localDateColumn.replaceAll(".", "\\.")}\\s*>=\\s*\\([\\s\\S]*minimum_advance_notice_days`, "i"),
      `${label} helper should enforce minimum advance notice against the groomer-local date`,
    );
    assert.match(
      helper,
      new RegExp(`${localDateColumn.replaceAll(".", "\\.")} between time_off\\.start_date and time_off\\.end_date`, "i"),
      `${label} helper should reject whole-day time-off overlaps`,
    );
    assert.match(
      helper,
      /daily_booking\.status in \('confirmed', 'completed'\)[\s\S]*< booking_preferences\.max_appointments_per_day/i,
      `${label} helper should count confirmed/completed bookings against daily capacity`,
    );
  }
});

test("request expiry converts records exactly at the stale boundary and only for active states", () => {
  const helper = functionSql(expirySql, "app_private", "expire_grooming_requests");

  assert.match(
    helper,
    /status in \('open', 'has_offers'\)[\s\S]*expires_at <= statement_timestamp\(\)/i,
    "requests expiring exactly at statement_timestamp should be processed",
  );
  assert.match(
    helper,
    /update public\.groomer_offers[\s\S]*status = 'expired'[\s\S]*status = 'pending'/i,
    "only pending offers should be expired with stale active requests",
  );
  assert.match(
    helper,
    /update public\.request_matches[\s\S]*status = 'expired'[\s\S]*status in \('visible', 'viewed', 'offered'\)/i,
    "only active match states should be expired with stale active requests",
  );
  assert.doesNotMatch(
    helper,
    /status in \('open', 'has_offers', 'cancelled'|'cancelled', 'open', 'has_offers'\)/i,
    "customer-cancelled requests should not be converted by expiry",
  );
});

test("service size-band constraints cover the current Fit Signals vocabulary", () => {
  for (const size of ["XS", "S", "M", "L", "XL", "XXL", "Giant"]) {
    assert.match(sizeBandSql, new RegExp(`'${size}'`, "i"));
  }

  assert.match(sizeBandSql, /cardinality\(accepted_pet_sizes\) <= 7/i);
  assert.match(sizeBandSql, /when 'small' then 'XS'[\s\S]*when 'small' then 'S'/i);
  assert.match(sizeBandSql, /when 'large' then 'L'[\s\S]*when 'large' then 'XL'/i);
  assert.match(sizeBandSql, /when 'giant' then 'XXL'[\s\S]*when 'giant' then 'Giant'/i);
  assert.match(
    sizeBandSql,
    /Empty array means inherit the groomer Fit Signals size experience/i,
  );
});
