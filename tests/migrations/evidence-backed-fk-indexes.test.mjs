import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const migrationsDir = join(process.cwd(), "supabase/migrations");
const migrationFile = readdirSync(migrationsDir)
  .filter((file) => file.endsWith("_t234_add_evidence_backed_fk_indexes.sql"))
  .sort()
  .at(-1);

assert.ok(migrationFile, "missing T-234 evidence-backed FK index migration");

const sql = readFileSync(join(migrationsDir, migrationFile), "utf8");

test("T-234 adds exactly the two indexes authorized by the evidence audit", () => {
  const createIndexStatements = sql.match(/create\s+(?:unique\s+)?index\b[^;]+;/gi) ?? [];

  assert.equal(createIndexStatements.length, 2);
  assert.match(
    sql,
    /create index customer_booking_handoff_acknowledgements_booking_id_idx\s+on public\.customer_booking_handoff_acknowledgements \(booking_id\);/i,
  );
  assert.match(
    sql,
    /create index request_photos_customer_id_idx\s+on public\.request_photos \(customer_id\);/i,
  );
  assert.doesNotMatch(sql, /drop\s+index/i);
});

test("T-234 includes a rollback-only forced-plan validation script", () => {
  const reviewSql = readFileSync(
    join(
      process.cwd(),
      "docs/06_tasks/sql_reviews/T-234_FK_INDEX_PLAN_ROLLBACK.sql",
    ),
    "utf8",
  );

  assert.match(reviewSql, /^begin;/im);
  assert.match(reviewSql, /set local enable_seqscan = off/i);
  assert.match(reviewSql, /explain \(costs on, format text\)/i);
  assert.match(reviewSql, /customer_booking_handoff_acknowledgements_booking_id_idx/i);
  assert.match(reviewSql, /request_photos_customer_id_idx/i);
  assert.match(reviewSql, /^rollback;/im);
});
