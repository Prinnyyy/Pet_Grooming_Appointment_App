import assert from "node:assert/strict";
import { test } from "node:test";
import { requireLifecycleTiming, lifecyclePublicationParameters, runMarketplaceLifecycle, cleanupRun } from "../../scripts/testops-core.mjs";

for (const notes of ["TESTOPS:TESTOPS-T374-OTHER fixture", "notes TESTOPS:TESTOPS-T374 fixture", null]) {
  test(`cleanup rejects an out-of-scope returned row: ${notes}`, async () => {
    const api = {
      requireServiceRole: () => "server-fixture",
      async restSelect() { return [{ id: "request", service_notes: notes }]; },
      async rpc() { assert.fail("Out-of-scope cleanup RPC"); },
      async restDelete() { assert.fail("Out-of-scope delete"); },
    };
    await assert.rejects(() => cleanupRun(api, "TESTOPS-T374"), /outside the exact run marker/);
  });
}

for (const remaining of [false, true]) for (const notes of ["TESTOPS:TESTOPS-T374", "TESTOPS:TESTOPS-T374 fixture"]) {
  test(`cleanup verifies no tagged requests remain: ${remaining}, ${notes}`, async () => {
    let requestReads = 0;
    const deleted = [];
    const api = {
      requireServiceRole: () => "server-fixture",
      async restSelect(table, query) {
        if (table !== "grooming_requests") return [];
        requestReads += 1;
        assert.equal(query, "select=id,service_notes&or=(service_notes.eq.TESTOPS%3ATESTOPS-T374,service_notes.like.TESTOPS%3ATESTOPS-T374%20*)");
        return requestReads === 1 || remaining
          ? [{ id: "request", service_notes: notes }] : [];
      },
      async rpc(name) { assert.equal(name, "cleanup_testops_request_address_location"); return false; },
      async restDelete(table, query) { deleted.push(table); assert.match(query, /in\.\(request\)/); return 1; },
    };
    if (remaining) await assert.rejects(() => cleanupRun(api, "TESTOPS-T374"), /Tagged requests remain/);
    else assert.equal((await cleanupRun(api, "TESTOPS-T374")).remainingTaggedRequests, 0);
    assert.ok(deleted.includes("grooming_requests"));
    assert.equal(requestReads, 2);
  });
}

const buffers = { preparation_minutes: 15, cleanup_minutes: 15,
  inbound_travel_minutes: 20, outbound_travel_minutes: 20 };
const schedule = () => ({ timing_version: 1, preferences: { timing_buffers: buffers },
  windows: Array.from({ length: 7 }, (_, i) => ({ weekday: i + 1, timezone: "America/Los_Angeles" })) });
const address = () => ({ timing_version: 1, address: { latitude: 33.87, longitude: -117.92,
  time_zone_identifier: "America/Los_Angeles" } });

test("timing race lifecycle stops after admission and never completes or reviews service", async () => {
  const calls = [];
  const plan = { timingContract: true, timingRace: true, runID: "TESTOPS-T374-RACE", caseID: "race",
    customer: { email: "customer@example.test", password: "fixture", seedID: "BTC-001" },
    groomer: { email: "groomer@example.test", password: "fixture", seedID: "BTG-001" },
    request: { serviceType: "full_groom", preferredStart: "2099-01-05T18:00:00Z", preferredEnd: "2099-01-05T21:00:00Z" },
    offer: { proposedStart: "2099-01-05T18:00:00Z", proposedEnd: "2099-01-05T19:00:00Z", priceEstimate: 100 } };
  const api = {
    async signIn(email) { return { user: { id: email }, accessToken: email }; },
    async restSelect(table, query) {
      if (table === "pets") return [{ id: "pet", species: "Dog" }];
      if (table === "request_matches") return [{ id: "match" }];
      assert.equal(table, "bookings");
      return query.includes("groomer_id") ? [] : [{ id: "booking", offer_id: "offer", status: "confirmed" }];
    },
    async rpc(name) {
      calls.push(name);
      if (name === "get_groomer_availability") return { ...schedule(), revision: "revision", time_off: [] };
      if (name === "get_my_profile_address_v3") return address();
      if (name === "create_grooming_request_v4") return [{ request_id: "request", match_count: 1 }];
      if (name === "create_groomer_offer") return [{ offer_id: "offer" }];
      if (name === "accept_groomer_offer") return [{ booking_id: "booking" }];
      if (name === "save_groomer_availability") throw Object.assign(new Error("conflict"), {
        code: "22023", serverMessage: "time_off_conflicts_with_booking_occupancy" });
      assert.fail(`Unexpected lifecycle operation: ${name}`);
    },
  };
  const result = await runMarketplaceLifecycle(api, plan);
  assert.equal(result.timingRace, true);
  assert.equal(result.verification.scope, "timing-admission-save");
  assert.equal(result.verification.winner, "booking");
  assert.equal(result.verification.bookingID, undefined);
  assert.equal(result.ids.bookingID, "booking");
  assert.ok(!calls.includes("complete_booking") && !calls.includes("create_review"));
});

test("v4 publication preserves the receipt identity and request values", () => {
  const parameters = { p_publish_operation_id: "operation", p_pet_id: "pet",
    p_preferred_start: "2099-01-05T18:00:00Z", p_address_line_2: null };
  assert.equal(lifecyclePublicationParameters(parameters), parameters);
  assert.deepEqual(lifecyclePublicationParameters(parameters, "America/Los_Angeles"), {
    p_publish_operation_id: "operation",
    p_request: { pet_id: "pet", preferred_start: "2099-01-05T18:00:00Z", address_line_2: null },
    p_preference_time_zone_identifier: "America/Los_Angeles",
  });
});

for (const ready of [true, false]) {
  test(`timing lifecycle uses v4 only after confirmed setup: ${ready}`, async () => {
    const calls = [];
    const plan = { timingContract: true, runID: "TESTOPS-T374-TIMING", caseID: "timing",
      customer: { email: "customer@example.test", password: "fixture", seedID: "BTC-001" },
      groomer: { email: "groomer@example.test", password: "fixture", seedID: "BTG-001" },
      request: { serviceType: "full_groom", serviceNotes: "TESTOPS-T374-TIMING",
        preferredStart: "2099-01-05T18:00:00Z", preferredEnd: "2099-01-05T21:00:00Z",
        locationMode: "groomer_comes_to_customer" } };
    const api = {
      async signIn(email) { return { user: { id: email }, accessToken: email }; },
      async restSelect(table) { assert.equal(table, "pets"); return [{ id: "pet", species: "Dog" }]; },
      async rpc(name, parameters) {
        calls.push(name);
        if (name === "get_groomer_availability") return { ...schedule(), timing_version: ready ? 1 : 0 };
        if (name === "get_my_profile_address_v3") return address();
        assert.equal(name, "create_grooming_request_v4");
        assert.equal(parameters.p_preference_time_zone_identifier, "America/Los_Angeles");
        assert.equal(parameters.p_request.preferred_start, plan.request.preferredStart);
        assert.equal(parameters.p_request.latitude, address().address.latitude);
        assert.equal(parameters.p_request.pet_id, "pet");
        assert.equal(parameters.p_request.publish_operation_id, undefined);
        assert.match(parameters.p_publish_operation_id, /^[0-9a-f-]{36}$/);
        throw new Error("publication boundary reached");
      },
    };
    await assert.rejects(() => runMarketplaceLifecycle(api, plan),
      ready ? /publication boundary reached/ : /confirmed buffer settings/);
    assert.deepEqual(calls, ready
      ? ["get_groomer_availability", "get_my_profile_address_v3", "create_grooming_request_v4"]
      : ["get_groomer_availability"]);
  });
}

for (const kind of ["supported", "old", "buffers", "bounds", "weekday", "zone", "address", "read-failure"]) {
  test(`timing preflight: ${kind}`, async () => {
    const availability = schedule();
    const location = address();
    if (kind === "old") availability.timing_version = 0;
    if (kind === "buffers") availability.preferences.timing_buffers = null;
    if (kind === "bounds") availability.preferences.timing_buffers = { ...buffers, cleanup_minutes: 121 };
    if (kind === "weekday") availability.windows[6].weekday = 1;
    if (kind === "zone") availability.windows[6].timezone = "America/New_York";
    if (kind === "address") location.address.time_zone_identifier = null;
    const calls = [];
    const api = { async rpc(name, payload, token) {
      calls.push(name);
      assert.deepEqual(payload, {});
      assert.equal(token, "groomer-session");
      if (kind === "read-failure") throw new Error("read failed");
      if (name === "get_groomer_availability") return availability;
      if (name === "get_my_profile_address_v3") return location;
      assert.fail(`Unexpected writer or fallback: ${name}`);
    } };
    if (kind === "supported") {
      assert.deepEqual(await requireLifecycleTiming(api, "groomer-session"), location.address);
      assert.deepEqual(calls, ["get_groomer_availability", "get_my_profile_address_v3"]);
    } else {
      await assert.rejects(() => requireLifecycleTiming(api, "groomer-session"));
      assert.ok(calls.every(name => name.startsWith("get_")));
    }
  });
}
