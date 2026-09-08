import assert from "node:assert/strict";
import { test } from "node:test";
import { runWithTimingRestoration } from "../../scripts/timing-restoration.mjs";

for (const failure of [null, "before", "run", "cleanup", "after", "changed"]) {
  test(`timing restoration boundary: ${failure ?? "success"}`, async () => {
    const calls = [];
    let snapshots = 0;
    const operation = () => runWithTimingRestoration({
      snapshot: async () => {
        const phase = snapshots++ === 0 ? "before" : "after";
        calls.push(phase);
        if (failure === phase) throw new Error(phase);
        return [{ fixture: failure === "changed" && phase === "after" ? "changed" : "original" }];
      },
      run: async () => { calls.push("run"); if (failure === "run") throw new Error("run"); return { ok: true }; },
      cleanup: async () => { calls.push("cleanup"); if (failure === "cleanup") throw new Error("cleanup"); return { remainingTaggedRequests: 0 }; },
    });
    if (failure) await assert.rejects(operation);
    else assert.deepEqual(await operation(), { ok: true, cleanup: { remainingTaggedRequests: 0 }, restoration: { verified: true } });
    assert.deepEqual(calls, failure === "before" ? ["before"] : ["before", "run", "cleanup", "after"]);
  });
}

test("operation and cleanup errors are both retained and final snapshot is still attempted", async () => {
  let snapshots = 0;
  await assert.rejects(() => runWithTimingRestoration({
    snapshot: async () => { snapshots += 1; return []; },
    run: async () => { throw new Error("operation failed"); },
    cleanup: async () => { throw new Error("cleanup failed"); },
  }), error => error instanceof AggregateError && error.errors.length === 2);
  assert.equal(snapshots, 2);
});
