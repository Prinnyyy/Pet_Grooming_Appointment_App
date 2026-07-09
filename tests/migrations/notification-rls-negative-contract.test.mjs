import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");

function readMigration(suffix) {
  const file = readdirSync(migrationsDir)
    .filter((candidate) => candidate.endsWith(suffix))
    .sort()
    .at(-1);

  assert.ok(file, `missing migration ending in ${suffix}`);
  return readFileSync(join(migrationsDir, file), "utf8");
}

function statementFor(sql, pattern, label) {
  const match = sql.match(pattern);
  assert.ok(match, `missing ${label}`);
  return match[0];
}

function assertNoAuthenticatedMutationGrants(sql, tableName) {
  assert.doesNotMatch(
    sql,
    new RegExp(`grant\\s+insert[^;]+public\\.${tableName}[^;]+authenticated`, "i"),
    `${tableName} must not grant authenticated insert`,
  );
  assert.doesNotMatch(
    sql,
    new RegExp(`grant\\s+delete[^;]+public\\.${tableName}[^;]+authenticated`, "i"),
    `${tableName} must not grant authenticated delete`,
  );
  assert.doesNotMatch(
    sql,
    new RegExp(`grant\\s+update\\s+on\\s+table\\s+public\\.${tableName}\\s+to\\s+authenticated`, "i"),
    `${tableName} must only grant column-scoped read-state updates`,
  );
}

function assertOwnerScopedNotificationPolicies(sql, tableName, ownerColumn, ownerProfileTable) {
  const selectPolicy = statementFor(
    sql,
    new RegExp(`create policy ${tableName}_select_own[\\s\\S]*?;`, "i"),
    `${tableName} select policy`,
  );
  const updatePolicy = statementFor(
    sql,
    new RegExp(`create policy ${tableName}_update_own_read_state[\\s\\S]*?;`, "i"),
    `${tableName} update policy`,
  );

  for (const policy of [selectPolicy, updatePolicy]) {
    assert.match(policy, /to authenticated/i);
    assert.match(policy, new RegExp(`${ownerColumn}\\s*=\\s*\\(select auth\\.uid\\(\\)\\)`, "i"));
    assert.match(policy, new RegExp(`from public\\.${ownerProfileTable}`, "i"));
    assert.match(policy, /not coalesce\(\(\(select auth\.jwt\(\)\) ->> 'is_anonymous'\)::boolean, false\)/i);
  }

  assert.match(updatePolicy, /with check\s*\(/i);
  assert.match(updatePolicy, /is_read\s*=\s*true/i);
  assert.match(updatePolicy, /read_at\s+is not null/i);
}

function assertPrivateNotificationHelperIsNotClientCallable(sql, functionName) {
  assert.match(
    sql,
    new RegExp(
      `revoke all on function app_private\\.${functionName}\\([\\s\\S]*?\\)\\s+from public, anon, authenticated, service_role`,
      "i",
    ),
  );
  assert.doesNotMatch(
    sql,
    new RegExp(`grant execute on function app_private\\.${functionName}\\([\\s\\S]*?\\) to authenticated`, "i"),
  );
}

const customerNotificationSql = readMigration("_t153_customer_notifications.sql");
const customerPushSql = readMigration("_t157_customer_push_notifications.sql");
const groomerNotificationSql = readMigration("_t203_groomer_notifications.sql");
const rollbackValidationSql = readFileSync(
  join(process.cwd(), "docs/06_tasks/sql_reviews/T-220_NOTIFICATION_RLS_NEGATIVE_CONTRACT.sql"),
  "utf8",
);

test("Q-31 customer notifications reject cross-customer visibility and direct client mutation", () => {
  assertOwnerScopedNotificationPolicies(
    customerNotificationSql,
    "customer_notifications",
    "customer_id",
    "customer_profiles",
  );
  assertNoAuthenticatedMutationGrants(customerNotificationSql, "customer_notifications");
  assertPrivateNotificationHelperIsNotClientCallable(customerNotificationSql, "create_customer_notification");
});

test("Q-31 groomer notifications reject cross-groomer visibility and direct client mutation", () => {
  assertOwnerScopedNotificationPolicies(
    groomerNotificationSql,
    "groomer_notifications",
    "groomer_id",
    "groomer_profiles",
  );
  assertNoAuthenticatedMutationGrants(groomerNotificationSql, "groomer_notifications");
  assertPrivateNotificationHelperIsNotClientCallable(groomerNotificationSql, "create_groomer_notification");
});

test("Q-31 protected push delivery RPCs are service-role only", () => {
  for (const signature of [
    "claim_customer_push_notifications\\(integer\\)",
    "record_customer_push_delivery\\(uuid,\\s*text,\\s*text\\)",
  ]) {
    assert.match(
      customerPushSql,
      new RegExp(`revoke all on function public\\.${signature}\\s+from public, anon, authenticated, service_role`, "i"),
    );
    assert.match(
      customerPushSql,
      new RegExp(`grant execute on function public\\.${signature}\\s+to service_role`, "i"),
    );
    assert.doesNotMatch(
      customerPushSql,
      new RegExp(`grant execute on function public\\.${signature}\\s+to authenticated`, "i"),
    );
    assert.doesNotMatch(
      customerPushSql,
      new RegExp(`grant execute on function public\\.${signature}\\s+to anon`, "i"),
    );
  }
});

test("Q-31 has a rollback-only runtime validation script for notification negative cases", () => {
  assert.match(rollbackValidationSql, /begin;/i);
  assert.match(rollbackValidationSql, /rollback;/i);
  assert.match(rollbackValidationSql, /set local role authenticated/i);
  assert.match(rollbackValidationSql, /request\.jwt\.claims/i);
  assert.match(rollbackValidationSql, /'customer_cross_read_count'[\s\S]*?count\(\*\)\s*=\s*0/i);
  assert.match(rollbackValidationSql, /'groomer_cross_read_count'[\s\S]*?count\(\*\)\s*=\s*0/i);
  assert.match(rollbackValidationSql, /'customer_insert_rejected'[\s\S]*?v_rejected\s*=\s*true/i);
  assert.match(rollbackValidationSql, /'groomer_insert_rejected'[\s\S]*?v_rejected\s*=\s*true/i);
  assert.match(rollbackValidationSql, /claim_customer_push_notifications\(1\)/i);
  assert.match(rollbackValidationSql, /record_customer_push_delivery\(/i);
});
