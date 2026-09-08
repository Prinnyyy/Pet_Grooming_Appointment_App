import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import test from "node:test";
import { runTimingDatabaseBarrier } from "../../scripts/timing-database-barrier.mjs";

const groomerID = "00000000-0000-4000-8000-000000000001";
function harness(code = 0) {
  const child = new EventEmitter();
  child.stdout = { resume() {} };
  child.stderr = new EventEmitter();
  let sql;
  return { child, options: {
    spawnProcess(command, args) { assert.equal(command, "supabase"); sql = args.at(-1); return child; },
    delay: async () => {},
  }, sql: () => sql, release: () => child.emit("close", code) };
}
test("barrier holds the admission lock and verifies both named sessions blocked by this holder", async () => {
  const h = harness();
  const value = await runTimingDatabaseBarrier(groomerID, async () => { h.release(); return [1, 2]; }, h.options);
  assert.deepEqual(value, [1, 2]);
  assert.match(h.sql(), /hashtextextended.*71071/);
  assert.match(h.sql(), /pg_backend_pid\(\) = any\(pg_blocking_pids\(pid\)\)/);
  assert.match(h.sql(), /accept_groomer_offer/);
  assert.match(h.sql(), /save_groomer_availability/);
  assert.match(h.sql(), /blocked_sessions < 2/);
});
test("unverified database contention cannot count as a passing HTTP race", async () => {
  const h = harness(1);
  await assert.rejects(runTimingDatabaseBarrier(groomerID, async () => { h.release(); return []; }, h.options), /barrier was not verified/);
});
test("operation failure still waits for the holder to finish", async () => {
  const h = harness();
  let finished = false;
  const pending = runTimingDatabaseBarrier(groomerID, async () => { throw new Error("operation failed"); }, h.options)
    .finally(() => { finished = true; });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(finished, false);
  h.release();
  await assert.rejects(pending, /operation failed/);
});
test("invalid fixture identity is rejected before spawning SQL", async () => {
  await assert.rejects(runTimingDatabaseBarrier("x';select 1", async () => {}, {
    spawnProcess() { assert.fail("must not spawn"); },
  }), /groomer identity/);
});
