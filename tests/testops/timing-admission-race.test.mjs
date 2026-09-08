import assert from "node:assert/strict";
import { test } from "node:test";
import { runTimingAdmissionRace } from "../../scripts/timing-admission-race.mjs";
import { SupabaseREST, redactedResult } from "../../scripts/testops-core.mjs";

test("RPC errors preserve structured conflict identity", async context => {
  context.mock.method(globalThis, "fetch", async () => new Response(JSON.stringify({
    code: "22023", message: "occupied_time_off_conflict",
  }), { status: 400 }));
  const api = new SupabaseREST("https://lqmasbuqzvcvtawonjlb.supabase.co", "sb_publishable_fixture", "sb_secret_fixture");
  await assert.rejects(() => api.rpc("accept_groomer_offer", {}, "customer"), error => {
    assert.equal(error.code, "22023");
    assert.equal(error.serverMessage, "occupied_time_off_conflict");
    assert.equal(error.httpStatus, 400);
    return true;
  });
});

test("race output retains scope without exposing booking identity in verification", () => {
  const id = "123e4567-e89b-12d3-a456-426614174000";
  const result = redactedResult({ timingContract: true, timingRace: true,
    ids: { bookingID: id }, verification: { scope: "timing-admission-save", winner: "booking" },
    restoration: { verified: true } });
  assert.equal(result.timingRace, true);
  assert.doesNotMatch(JSON.stringify(result), new RegExp(id, "i"));
  assert.deepEqual(result.restoration, { verified: true });
});

for (const scenario of ["booking", "time_off", "both", "neither", "network", "bad_readback", "restore_failure", "existing"]) {
  test(`admission/Save race: ${scenario}`, async () => {
    const schedule = { timing_version: 1, revision: "before", preferences: {}, time_off: [],
      windows: Array.from({ length: 7 }, (_, i) => ({ weekday: i + 1, timezone: "America/Los_Angeles" })) };
    const pending = [];
    let bookingExists = false;
    let restores = 0;
    const rejection = serverMessage => Object.assign(new Error(serverMessage), { code: "22023", serverMessage });
    const api = {
      async restSelect(table, query) {
        assert.equal(table, "bookings");
        if (query.includes("groomer_id")) return scenario === "existing"
          ? [{ id: "other", scheduled_start: "2099-01-05T18:00:00Z", scheduled_end: "2099-01-05T19:00:00Z" }] : [];
        return bookingExists && scenario !== "bad_readback" ? [{ id: "booking", offer_id: "offer", status: "confirmed" }] : [];
      },
      async rpc(name, parameters) {
        if (name === "get_groomer_availability") return structuredClone(schedule);
        if (name === "save_groomer_availability" && pending.length === 2) {
          restores += 1;
          if (scenario === "restore_failure") throw new Error("restore failed");
          assert.equal(parameters.p_expected_revision, schedule.revision);
          schedule.time_off = parameters.p_time_off;
          return structuredClone(schedule);
        }
        return new Promise((resolve, reject) => {
          pending.push({ name, parameters, resolve, reject });
          // Neither operation can resolve until both have been dispatched.
          if (pending.length !== 2) return;
          for (const operation of pending) {
            if (operation.name === "accept_groomer_offer") {
              if (["booking", "both", "bad_readback"].includes(scenario)) {
                bookingExists = true;
                operation.resolve([{ booking_id: "booking" }]);
              } else operation.reject(scenario === "network" ? new Error("network") : rejection("occupied_time_off_conflict"));
            } else {
              assert.equal(operation.name, "save_groomer_availability");
              assert.equal(operation.parameters.p_time_off[0].start_date, "2099-01-05");
              if (["time_off", "both", "network", "restore_failure"].includes(scenario)) {
                schedule.time_off = operation.parameters.p_time_off;
                schedule.revision = "saved";
                operation.resolve(structuredClone(schedule));
              } else operation.reject(rejection("time_off_conflicts_with_booking_occupancy"));
            }
          }
        });
      },
    };
    const run = () => runTimingAdmissionRace(api, { offerID: "offer", groomerID: "groomer",
      serviceStart: "2099-01-05T18:00:00Z", customerToken: "customer", groomerToken: "groomer" });
    if (["booking", "time_off"].includes(scenario)) {
      const result = await run();
      assert.equal(result.winner, scenario);
      assert.equal(result.dispatch, "concurrent-http");
      assert.equal(result.bookingReadbackVerified, true);
    } else await assert.rejects(run);
    assert.equal(pending.length, scenario === "existing" ? 0 : 2);
    if (scenario !== "restore_failure") assert.deepEqual(schedule.time_off, []);
    if (scenario === "time_off") assert.equal(restores, 1);
  });
}
