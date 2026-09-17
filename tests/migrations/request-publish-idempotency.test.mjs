import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t358_request_publish_idempotency.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-358 request publish idempotency migration");

const migration = readFileSync(join(migrationsDir, migrationFile), "utf8");
const validationPath = join(
  process.cwd(),
  "docs/06_tasks/sql_reviews/T-358_REQUEST_PUBLISH_IDEMPOTENCY_ROLLBACK_VALIDATION.sql",
);

test("T-358 stores publish operation results outside the public request surface", () => {
  assert.match(
    migration,
    /create table app_private\.request_publish_operations\s*\(/i,
  );
  assert.match(
    migration,
    /primary key \(customer_id, operation_id\)/i,
  );
  assert.match(
    migration,
    /request_id uuid not null references public\.grooming_requests\s*\(id\) on delete cascade/i,
  );
  assert.match(migration, /match_count integer not null/i);
  assert.match(
    migration,
    /revoke all on table app_private\.request_publish_operations\s+from public, anon, authenticated/i,
  );
  assert.doesNotMatch(
    migration,
    /grant (?:select|insert|update|delete|all).*request_publish_operations.*to authenticated/i,
  );
});

test("T-358 serializes duplicate operations and replays the original result", () => {
  const privateRPC = migration.match(
    /create function app_private\.create_grooming_request_v3\([\s\S]*?\n\$\$;/i,
  )?.[0];
  assert.ok(privateRPC, "missing private create_grooming_request_v3");
  assert.match(privateRPC, /p_publish_operation_id uuid/i);
  assert.doesNotMatch(privateRPC, /p_publish_operation_id uuid\s+default/i);

  const lockIndex = privateRPC.search(/pg_advisory_xact_lock/i);
  const replayIndex = privateRPC.search(
    /from app_private\.request_publish_operations/i,
  );
  const createIndex = privateRPC.search(
    /app_private\.create_grooming_request_v2/i,
  );
  assert.ok(lockIndex >= 0, "missing transaction-level operation lock");
  assert.ok(replayIndex > lockIndex, "replay lookup must occur after the lock");
  assert.ok(createIndex > replayIndex, "request creation must occur after replay lookup");

  assert.match(
    privateRPC,
    /return query[\s\S]*v_existing_request_id[\s\S]*v_existing_match_count/i,
  );
  assert.match(
    privateRPC,
    /insert into app_private\.request_publish_operations[\s\S]*v_request_id[\s\S]*v_match_count/i,
  );
});

test("T-358 exposes only the authenticated v3 wrapper and retains v2 compatibility", () => {
  assert.match(
    migration,
    /create function public\.create_grooming_request_v3\([\s\S]*security invoker[\s\S]*app_private\.create_grooming_request_v3/i,
  );
  assert.match(
    migration,
    /revoke all on function public\.create_grooming_request_v3\([\s\S]*from public, anon, authenticated/i,
  );
  assert.match(
    migration,
    /grant execute on function public\.create_grooming_request_v3\([\s\S]*to authenticated, service_role/i,
  );
  assert.doesNotMatch(
    migration,
    /drop function (?:public|app_private)\.create_grooming_request_v2/i,
  );
});

test("T-358 includes rollback-only positive, replay, and authorization validation", () => {
  assert.ok(existsSync(validationPath), "missing T-358 rollback validation");
  const validation = readFileSync(validationPath, "utf8");

  assert.match(validation, /^begin;/im);
  assert.match(validation, /set local role authenticated/i);
  assert.match(validation, /create_grooming_request_v3/i);
  assert.match(validation, /v_first_request_id\s*=\s*v_second_request_id/i);
  assert.match(validation, /raise exception 'same_request_replayed failed'/i);
  assert.match(validation, /select count\(\*\)\s*=\s*1[\s\S]*v_single_request_created/i);
  assert.match(validation, /raise exception 'single_request_created failed'/i);
  assert.match(validation, /'anonymous_execute_rejected'[\s\S]*v_rejected\s*=\s*true/i);
  assert.match(validation, /^rollback;/im);
});
