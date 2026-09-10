import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { connect, prepare, recover, cleanup, updateSchedule, query, saveArtifact, intent,
  runID, marker, buffers, sqlIDs } from "./test-t387-booking-fixture.mjs";

const mode = process.argv[2];
const sourceHash = createHash("sha256").update(readFileSync(import.meta.filename)).digest("hex");
assert.ok(["prepare", "run", "cleanup", "inspect"].includes(mode), "Use prepare/run/inspect/cleanup");
const context = await connect();
const { api, actors } = context;
if (mode === "prepare") {
  await prepare(context);
} else if (mode === "cleanup") {
  await cleanup(context, recover());
} else if (mode === "inspect") {
  for (const name of ["G1", "G2"]) {
    const state = await api.rpc("get_groomer_availability", {}, actors[name].token);
    console.log(JSON.stringify({ actor: name, days: state.windows.length, buffers: state.preferences.timing_buffers,
      addressZoneConfirmed: !!actors[name].address.time_zone_identifier }));
  }
} else {
  await run(recover());
}

async function run(saved) {
  const results = [];
  const trace = [];
  const selection = process.env.TESTOPS_CASES?.split(",");
  const knownCases = new Set(Array.from({ length: 72 }, (_, i) => i + 1)
    .filter(i => i <= 64 || i >= 69).map(i => `B${String(i).padStart(2, "0")}`));
  for (let i = 1; i <= 8; i++) knownCases.add(`E${String(i).padStart(2, "0")}`);
  for (const id of ["E12", "E17", "E18", "E19", "E21", "E23", "E24"]) knownCases.add(id);
  assert.ok(!selection || selection.every(id => knownCases.has(id)), "Select defined HTTP cases only");
  const dayOffset = Number(process.env.TESTOPS_DAY_OFFSET ?? 0);
  assert.ok(Number.isInteger(dayOffset) && dayOffset >= 0 && dayOffset <= 40);
  const suffix = selection ? `-${selection.join("-")}` : "";
  let current = "setup";
  const originalRequest = api.request.bind(api);
  api.request = async (path, init, kind) => {
    const started = Date.now();
    try {
      const value = await originalRequest(path, { ...init, signal: AbortSignal.timeout(45000) }, kind);
      trace.push({ case: current, path: path.replace(/[0-9a-f]{8}-[0-9a-f-]{27}/gi, "<id>"), ok: true, ms: Date.now() - started });
      return value;
    } catch (error) {
      trace.push({ case: current, path: path.split("?")[0], ok: false, code: error.code, status: error.httpStatus,
        error: safe(error.message), ms: Date.now() - started });
      if (!error.httpStatus && init.method !== "GET") {
        saved.uncertainWrite = { case: current, path, at: new Date().toISOString() };
        saveArtifact("recovery", saved);
      }
      throw error;
    } finally {
      saveArtifact(`http-trace${suffix}`, trace);
    }
  };
  const dates = query(`select jsonb_agg(timezone('America/Los_Angeles',
    (timezone('America/Los_Angeles',now())::date+d)+time '09:00') order by d) starts
    from generate_series(0,80) d;`)[0].starts;
  const at = (day, hour = 9, minute = 0) => new Date(Date.parse(dates[day + dayOffset]) + ((hour - 9) * 60 + minute) * 60000).toISOString();
  const add = (date, minutes) => new Date(Date.parse(date) + minutes * 60000).toISOString();
  const rpc = (actor, name, params) => api.rpc(name, params, actors[actor].token);
  const rows = (actor, table, filter, fields = "*") => api.restSelect(table, `select=${fields}&${filter}`, actors[actor].token);
  const owned = `select id from public.grooming_requests where customer_id in (${sqlIDs(saved.customerIDs)}) and (service_notes='${marker}' or service_notes like '${marker} %')`;
  function digest() {
    const tables = [ ["grooming_requests", `id in (${owned})`], ["groomer_offers", `request_id in (${owned})`],
      ["bookings", `request_id in (${owned})`], ["booking_reschedule_proposals", `booking_id in (select id from public.bookings where request_id in (${owned}))`],
      ["booking_fulfillment_events", `booking_id in (select id from public.bookings where request_id in (${owned}))`],
      ["reviews", `booking_id in (select id from public.bookings where request_id in (${owned}))`],
      ["request_matches", `request_id in (${owned})`],
      ["messages", `conversation_id in (select id from public.conversations where customer_id in (${sqlIDs(saved.customerIDs)}) and groomer_id in (${sqlIDs(saved.groomerIDs)}))`],
      ["customer_notifications", `customer_id in (${sqlIDs(saved.customerIDs)})`],
      ["groomer_notifications", `groomer_id in (${sqlIDs(saved.groomerIDs)})`],
      ["app_private.request_publish_operations", `customer_id in (${sqlIDs(saved.customerIDs)})`],
      ["app_private.address_locations", `owner_id in (${sqlIDs(saved.customerIDs)})`] ];
    return query(`select ${tables.map(([table, where], i) => `(select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb)::text) from ${table.includes(".") ? table : `public.${table}`} t where ${where}) h${i}`).join(",")};`)[0];
  }
  async function denied(action, expected) {
    const before = digest();
    let rejection;
    try { await action(); }
    catch (error) { rejection = error; }
    assert.ok(rejection, `Expected rejection: ${expected}`);
    assert.ok(rejection.httpStatus >= 400 && rejection.httpStatus < 500, `Expected business rejection, got ${safe(rejection.message)}`);
    assert.match(rejection.serverMessage, expected);
    assert.deepEqual(digest(), before, "Rejected action changed authoritative records");
    return { error: rejection.serverMessage, code: rejection.code, unchanged: true };
  }
  async function check(id, name, action) {
    if (selection && !selection.includes(id)) return;
    current = id;
    if (saved.uncertainWrite) throw Error("Uncertain write requires outcome inspection before continuing");
    if (!["B33", "B34", "B37", "B43", "B44"].includes(id)) {
      const requests = query(`select id,customer_id from public.grooming_requests where id in (${owned})
        and status in ('open','has_offers') and expires_at>statement_timestamp();`);
      for (const request of requests) {
        const customer = Object.keys(actors).find(name => actors[name].id === request.customer_id);
        assert.ok(customer?.startsWith("C"));
        await rpc(customer, "cancel_grooming_request", { p_request_id: request.id });
      }
    }
    const start = Date.now();
    const record = { id, name, channel: "H", started: new Date().toISOString() };
    try { record.evidence = await action(); record.status = "PASS"; }
    catch (error) {
      record.status = "FAIL";
      record.error = safe(error.message);
      record.code = error.code;
      record.stack = safe(error.stack?.split("\n").slice(0, 6).join("\n"));
    }
    record.ms = Date.now() - start;
    results.push(record);
    saveArtifact(`results${suffix}`, { runID, dayOffset, source: sourceHash, results });
    console.log(`${id} ${record.status} ${name}${record.error ? `: ${record.error}` : ""}`);
  }
  function publication(customer, day, options = {}) {
    const address = actors.G1.address;
    return { p_publish_operation_id: intent(saved, "publish"), p_preference_time_zone_identifier: "America/Los_Angeles",
      p_request: { pet_id: actors[customer].pet.id, service_type: "full_groom", service_notes: `${marker} ${current}`,
        preferred_start: at(day, 9), preferred_end: at(day, 21), location_mode: "groomer_comes_to_customer",
        street_address: address.line_1, city: address.city, state: address.state, zip_code: address.zip_code,
        provider: address.provider, country_code: address.country_code, latitude: address.latitude, longitude: address.longitude,
        resolution_source: "manual_geocode", user_confirmed_at: new Date().toISOString(), ...options } };
  }
  async function publish(customer, day, options = {}, params = null) {
    const payload = params ?? publication(customer, day, options);
    const [receipt] = await rpc(customer, "create_grooming_request_v4", payload);
    assert.ok(receipt?.request_id, "No publication receipt");
    saved.requests.push(receipt.request_id);
    saveArtifact("recovery", saved);
    const [request] = await rows(customer, "grooming_requests", `id=eq.${receipt.request_id}`);
    assert.equal(request.customer_id, actors[customer].id);
    assert.equal(request.pet_id, payload.p_request.pet_id);
    assert.ok(request.terms_revision);
    return { customer, request, receipt, payload, day };
  }
  async function quote(fixture, groomer = "G1", options = {}) {
    const params = { p_request_id: fixture.request.id, p_expected_request_revision: fixture.request.terms_revision,
      p_proposed_start: at(fixture.day, 10), p_proposed_end: at(fixture.day, 11),
      p_price_estimate: 100, p_message: `${marker} ${current}`, ...options };
    const [receipt] = await rpc(groomer, "create_groomer_offer_v2", params);
    const [offer] = await rows(fixture.customer, "groomer_offers", `id=eq.${receipt.offer_id}`);
    assert.equal(offer.agreement_snapshot.request_revision, fixture.request.terms_revision);
    assert.equal(offer.groomer_id, actors[groomer].id);
    return { ...fixture, offer, groomer, quoteParams: params };
  }
  async function accept(fixture) {
    const [receipt] = await rpc(fixture.customer, "accept_groomer_offer_v2", {
      p_offer_id: fixture.offer.id, p_expected_quote_revision: fixture.offer.quote_revision });
    const [booking] = await rows(fixture.customer, "bookings", `id=eq.${receipt.booking_id}`);
    assert.equal(booking.request_id, fixture.request.id);
    assert.equal(booking.groomer_id, actors[fixture.groomer].id);
    assert.equal(booking.status, "confirmed");
    return { ...fixture, booking, acceptance: receipt };
  }
  async function job(customer, day, hour = 10, groomer = "G1", requestOptions = {}) {
    const request = await publish(customer, day, requestOptions);
    const offer = await quote(request, groomer, { p_proposed_start: at(day, hour), p_proposed_end: add(at(day, hour), 60) });
    return accept(offer);
  }
  function fulfillParams(fixture, action) {
    return { p_booking_id: fixture.booking.id, p_expected_revision: fixture.booking.fulfillment_revision,
      p_operation_id: intent(saved, action), p_action: action, p_note: null };
  }
  async function cancel(fixture, actor = fixture.customer) {
    const [booking] = await rows(actor, "bookings", `id=eq.${fixture.booking.id}`);
    const params = fulfillParams({ ...fixture, booking }, "cancel");
    const result = await rpc(actor, "mutate_booking_fulfillment", params);
    return { result, params };
  }
  const evaluation = async fixture => (await rpc(fixture.customer, "get_quote_evaluations", { p_offer_ids: [fixture.offer.id] }))[0].evaluation;
  async function race(fixtures) {
    const outcomes = await Promise.allSettled(fixtures.map(f => rpc(f.customer, "accept_groomer_offer_v2", {
      p_offer_id: f.offer.id, p_expected_quote_revision: f.offer.quote_revision })));
    assert.equal(outcomes.filter(o => o.status === "fulfilled").length, 1, "Expected exactly one successful acceptance");
    const rejects = outcomes.filter(o => o.status === "rejected").map(o => o.reason);
    for (const error of rejects) assert.match(error.serverMessage, /conflict|unavailable|not_(open|acceptable|pending)|already|quote_terms_invalid/);
    const count = query(`select count(*) count from public.bookings where request_id in (${sqlIDs(fixtures.map(f => f.request.id))});`)[0].count;
    assert.equal(count, 1);
    return { successes: 1, bookings: count, rejected: rejects.map(e => e.serverMessage) };
  }
  const fixtures = {};
  await check("B01", "valid publication", async () => {
    fixtures.first = await publish("C1", 3);
    assert.ok(fixtures.first.receipt.match_count > 0);
    assert.equal((await rows("G1", "request_matches", `request_id=eq.${fixtures.first.request.id}&groomer_id=eq.${actors.G1.id}`)).length, 1);
    return { matches: fixtures.first.receipt.match_count };
  });
  await check("B02", "two pets, two requests", async () => {
    const requests = [];
    for (const pet of actors.C1.pets.slice(0, 2)) requests.push(await publish("C1", 3, { pet_id: pet.id }));
    assert.equal(new Set(requests.map(r => r.request.pet_id)).size, 2);
    return { requests: requests.length };
  });
  await check("B03", "one pet, separate publication intents", async () => {
    const a = await publish("C1", 3), b = await publish("C1", 3);
    assert.notEqual(a.request.id, b.request.id);
    assert.equal(a.request.pet_id, b.request.pet_id);
    return { distinctRequests: 2 };
  });
  await check("B04", "four customers publish", async () => {
    const requests = [];
    for (const c of ["C1", "C2", "C3", "C4"]) requests.push(await publish(c, 3));
    assert.equal(new Set(requests.map(r => r.request.customer_id)).size, 4);
    return { distinctCustomers: 4 };
  });
  await check("B05", "publication receipt replay", async () => {
    const f = fixtures.first;
    const before = digest();
    assert.deepEqual(await rpc(f.customer, "create_grooming_request_v4", f.payload), [f.receipt]);
    assert.deepEqual(digest(), before);
    return { unchanged: true };
  });
  await check("B06", "four concurrent copies of publication", async () => {
    const payload = publication("C2", 3);
    const result = await Promise.all(Array.from({ length: 4 }, () => rpc("C2", "create_grooming_request_v4", payload)));
    for (const row of result) assert.deepEqual(row, result[0]);
    assert.equal((await rows("C2", "grooming_requests", `id=eq.${result[0][0].request_id}`)).length, 1);
    return { attempts: 4, requests: 1 };
  });
  for (const [id, name, options, zone, expected] of [
    ["B07", "foreign pet", { pet_id: actors.C2.pet.id }, undefined, /pet_not_found/],
    ["B08", "empty preferred range", { preferred_end: at(3, 9) }, undefined, /invalid_preferred_range/],
    ["B09", "elapsed preference", { preferred_start: add(new Date().toISOString(), -180), preferred_end: add(new Date().toISOString(), -60) }, undefined, /invalid_preferred_range/],
    ["B10", "missing timezone", {}, null, /request_reference_time_zone_required/],
    ["B11", "invalid timezone", {}, "Mars/Olympus", /request_reference_time_zone_required/],
    ["B12", "invalid service", { service_type: "not_a_service" }, undefined, /invalid_service_type/],
  ]) await check(id, name, async () => {
    const params = publication("C1", 3, options);
    if (zone !== undefined) params.p_preference_time_zone_identifier = zone;
    return denied(() => rpc("C1", "create_grooming_request_v4", params), expected);
  });
  await check("B13", "valid quote captures agreement", async () => {
    fixtures.offer = await quote(await publish("C1", 4));
    const o = fixtures.offer.offer;
    assert.deepEqual(o.applied_timing_buffers, buffers);
    assert.equal(o.service_time_zone_identifier, "America/Los_Angeles");
    assert.equal(Date.parse(o.occupied_start), Date.parse(o.proposed_start) - 45 * 60000);
    assert.equal(Date.parse(o.occupied_end), Date.parse(o.proposed_end) + 30 * 60000);
    return { capturedAgreement: true, occupiedMinutes: 135 };
  });
  await check("B14", "six overlapping pending quotes", async () => {
    fixtures.pending = [];
    for (let i = 0; i < 6; i++) fixtures.pending.push(await quote(await publish(["C1", "C2", "C3", "C4"][i % 4], 5)));
    assert.equal(query(`select count(*) count from public.bookings where request_id in (${sqlIDs(fixtures.pending.map(f => f.request.id))});`)[0].count, 0);
    return { pendingQuotes: 6, bookings: 0 };
  });
  await check("B15", "zero-price quote", async () => {
    const f = await quote(await publish("C1", 6), "G1", { p_price_estimate: 0 });
    assert.equal(Number(f.offer.price_estimate), 0);
    return { price: 0 };
  });
  await check("B16", "negative and sub-cent prices", async () => {
    const f = await publish("C1", 6);
    const results = [];
    for (const price of [-1, 12.345]) results.push(await denied(() => quote(f, "G1", { p_price_estimate: price }), /invalid_price_estimate/));
    return results;
  });
  for (const [id, minutes, valid] of [["B17", 14, false], ["B18", 15, true], ["B19", 720, true], ["B20", 721, false]]) {
    await check(id, `${minutes}-minute duration`, async () => {
      const f = await publish("C1", 7, { preferred_end: at(7, 22) });
      const action = () => quote(f, "G1", { p_proposed_start: at(7, 9), p_proposed_end: add(at(7, 9), minutes) });
      if (!valid) return denied(action, /invalid_service_duration/);
      const o = (await action()).offer;
      assert.equal((Date.parse(o.proposed_end) - Date.parse(o.proposed_start)) / 60000, minutes);
      return { durationMinutes: minutes };
    });
  }
  for (const [id, label, options] of [
    ["B21", "before preferred start", { p_proposed_start: at(8, 9, 59), p_proposed_end: at(8, 10, 59) }],
    ["B22", "after preferred end", { p_proposed_start: at(8, 17, 1), p_proposed_end: at(8, 18, 1) }],
    ["B23", "stale request revision", { p_expected_request_revision: randomUUID() }],
  ]) await check(id, label, async () => {
    const f = await publish("C1", 8, { preferred_start: at(8, 10), preferred_end: at(8, 18) });
    return denied(() => quote(f, "G1", options), id === "B23" ? /request_revision_changed/ : /outside.*preference|outside.*window|consent/);
  });
  await check("B24", "withdraw then requote", async () => {
    const f = await quote(await publish("C1", 8));
    await rpc("G1", "withdraw_groomer_offer", { p_offer_id: f.offer.id });
    const replacement = await quote(f);
    assert.notEqual(replacement.offer.id, f.offer.id);
    assert.equal((await rows("C1", "groomer_offers", `id=eq.${f.offer.id}`))[0].status, "withdrawn_by_groomer");
    return { oldWithdrawn: true, newQuote: true };
  });
  await check("B25", "duplicate pending quote", async () => {
    const f = await quote(await publish("C1", 8));
    return denied(() => quote(f), /match_not_offerable|active_offer_exists/);
  });
  await check("B26", "two groomers quote one request", async () => {
    const f = await publish("C1", 9);
    const a = await quote(f, "G1"), b = await quote(f, "G2");
    assert.notEqual(a.offer.id, b.offer.id);
    return { quotes: 2 };
  });
  await check("B27", "three adjacent buffered jobs", async () => {
    fixtures.three = [];
    for (const [i, c] of ["C1", "C2", "C3"].entries()) {
      const f = await publish(c, 10);
      fixtures.three.push(await accept(await quote(f, "G1", { p_proposed_start: add(at(10, 10), i * 135), p_proposed_end: add(at(10, 11), i * 135) })));
    }
    for (let i = 1; i < 3; i++) assert.equal(Date.parse(fixtures.three[i - 1].booking.occupied_end), Date.parse(fixtures.three[i].booking.occupied_start));
    return { bookings: 3, exactOccupiedAdjacency: true };
  });
  for (const [id, day, gap] of [["B28", 11, 0], ["B29", 12, 25]]) await check(id, "overlapping resource buffers", async () => {
    const a = await quote(await publish("C1", day));
    const b = await quote(await publish("C2", day), "G1", { p_proposed_start: add(at(day, 11), gap), p_proposed_end: add(at(day, 12), gap) });
    await accept(a);
    return denied(() => accept(b), /conflict|unavailable|quote_terms_invalid/);
  });
  await check("B30", "same pet, different groomers", async () => {
    const a = await quote(await publish("C1", 13)), b = await quote(await publish("C1", 13), "G2");
    await accept(a);
    return denied(() => accept(b), /pet_booking_conflict|conflict|quote_terms_invalid/);
  });
  await check("B31", "same customer, different pets", async () => {
    const otherPet = actors.C1.pets.find(p => p.id !== actors.C1.pet.id);
    const a = await quote(await publish("C1", 14));
    const b = await quote(await publish("C1", 14, { pet_id: otherPet.id }), "G2");
    await accept(a); await accept(b);
    return { bookings: 2, customerTravelNotAnAllocatedResource: true };
  });
  await check("B32", "four jobs at daily quota", async () => {
    fixtures.quotaOffers = [];
    for (const [i, hour] of [9, 12, 15, 18, 20.5].entries()) {
      fixtures.quotaOffers.push(await quote(await publish(["C1", "C2", "C3", "C4"][i % 4], 15), "G1", {
        p_proposed_start: at(15, hour), p_proposed_end: add(at(15, hour), i === 4 ? 15 : 60) }));
    }
    fixtures.quotaBookings = [];
    for (const f of fixtures.quotaOffers.slice(0, 4)) fixtures.quotaBookings.push(await accept(f));
    assert.equal(fixtures.quotaBookings.length, 4);
    return { bookings: 4, quota: 4 };
  });
  await check("B33", "fifth job exceeds daily quota", () => denied(() => accept(fixtures.quotaOffers[4]), /conflict|unavailable|quote_terms_invalid/));
  await check("B34", "cancel releases quota", async () => {
    await cancel(fixtures.quotaBookings[0]);
    fixtures.fifth = await accept(fixtures.quotaOffers[4]);
    return { replacementConfirmed: fixtures.fifth.booking.status === "confirmed" };
  });
  await check("B35", "quota scoped to local date", async () => {
    await job("C1", 16);
    return { nextDayConfirmed: true };
  });
  await check("B36", "pending quotes reserve nothing", async () => {
    fixtures.pending = [];
    for (const c of ["C1", "C2", "C3"]) fixtures.pending.push(await quote(await publish(c, 5)));
    fixtures.pendingBooking = await accept(fixtures.pending[0]);
    assert.equal((await evaluation(fixtures.pending[1])).selectable, false);
    return { accepted: 1, remainingCapacityBlocked: true };
  });
  await check("B37", "quote recovers after conflicting cancellation", async () => {
    const before = await evaluation(fixtures.pending[1]);
    assert.equal(before.terms_valid, true);
    assert.equal(before.selectable, false);
    await cancel(fixtures.pendingBooking);
    const after = await evaluation(fixtures.pending[1]);
    assert.equal(after.terms_valid, true); assert.equal(after.selectable, true);
    await accept(fixtures.pending[1]);
    return { before, after };
  });
  await check("B38", "six concurrent accepts, one offer", async () => {
    const f = await quote(await publish("C1", 17));
    const outcomes = await Promise.all(Array.from({ length: 6 }, () => rpc("C1", "accept_groomer_offer_v2", {
      p_offer_id: f.offer.id, p_expected_quote_revision: f.offer.quote_revision })));
    for (const result of outcomes) assert.deepEqual(result, outcomes[0]);
    const [counts] = query(`select (select count(*) from public.bookings where request_id='${f.request.id}') bookings,
      (select count(*) from public.messages where kind='booking_card' and booking_id='${outcomes[0][0].booking_id}') cards;`);
    assert.deepEqual(counts, { bookings: 1, cards: 1 });
    return { attempts: 6, ...counts };
  });
  await check("B39", "two quotes for one request race", async () => {
    const f = await publish("C1", 18);
    return race([await quote(f), await quote(f, "G2")]);
  });
  await check("B40", "two customers race for groomer", async () => race([
    await quote(await publish("C1", 19)), await quote(await publish("C2", 19)) ]));
  await check("B41", "two groomers race for pet", async () => race([
    await quote(await publish("C1", 20)), await quote(await publish("C1", 20), "G2") ]));
  await check("B42", "foreign acceptance", async () => {
    fixtures.foreign = await quote(await publish("C1", 21));
    return denied(() => rpc("X", "accept_groomer_offer_v2", { p_offer_id: fixtures.foreign.offer.id,
      p_expected_quote_revision: fixtures.foreign.offer.quote_revision }), /offer_not_found/);
  });
  await check("B43", "stale quote revision", () => denied(() => rpc("C1", "accept_groomer_offer_v2", {
    p_offer_id: fixtures.foreign.offer.id, p_expected_quote_revision: randomUUID() }), /quote_revision_changed/));
  await check("B44", "cancelled request cannot be accepted", async () => {
    await rpc("C1", "cancel_grooming_request", { p_request_id: fixtures.foreign.request.id });
    return denied(() => accept(fixtures.foreign), /not_acceptable|not_open|not_pending|quote_terms_invalid/);
  });
  function reschedule(f, action, proposalID, newStart = null, operationID = intent(saved, action)) {
    return { p_booking_id: f.booking.id, p_expected_revision: f.booking.fulfillment_revision,
      p_operation_id: operationID, p_action: action, p_proposal_id: proposalID, p_new_start: newStart };
  }
  await check("B45", "reschedule overlaps own old slot", async () => {
    const f = await job("C1", 22);
    const pid = randomUUID();
    const proposed = await rpc("C1", "mutate_booking_reschedule", reschedule(f, "propose", pid, at(22, 10, 30)));
    assert.deepEqual(proposed.booking, f.booking);
    const params = reschedule(f, "accept", pid);
    const result = await rpc("G1", "mutate_booking_reschedule", params);
    assert.equal(result.booking.id, f.booking.id);
    assert.equal(Date.parse(result.booking.scheduled_start), Date.parse(at(22, 10, 30)));
    fixtures.rescheduled = { ...f, booking: result.booking }; fixtures.rescheduleReceipt = { params, result };
    return { sameBooking: true, unchangedDuration: true };
  });
  await check("B46", "proposal author cannot self-consent", async () => {
    const f = await job("C2", 23);
    const pid = randomUUID();
    await rpc("C2", "mutate_booking_reschedule", reschedule(f, "propose", pid, at(23, 15)));
    fixtures.proposal = { f, pid };
    return denied(() => rpc("C2", "mutate_booking_reschedule", reschedule(f, "accept", pid)), /reschedule_other_participant_required/);
  });
  await check("B47", "one pending reschedule only", async () => {
    const { f } = fixtures.proposal;
    return denied(() => rpc("G1", "mutate_booking_reschedule", reschedule(f, "propose", randomUUID(), at(23, 17))), /reschedule_proposal_pending/);
  });
  await check("B48", "pending proposal does not reserve new time", async () => {
    fixtures.competitor = await job("C3", 23, 15);
    return { competingBookingConfirmed: true };
  });
  await check("B49", "reschedule loses target slot without losing original", async () => {
    const { f, pid } = fixtures.proposal;
    return denied(() => rpc("G1", "mutate_booking_reschedule", reschedule(f, "accept", pid)), /reschedule_resource_conflict/);
  });
  await check("B50", "reject proposal", async () => {
    const { f, pid } = fixtures.proposal;
    const result = await rpc("G1", "mutate_booking_reschedule", reschedule(f, "reject", pid));
    assert.deepEqual(result.booking, f.booking); assert.equal(result.proposal.status, "rejected");
    return { unchangedBooking: true };
  });
  await check("B51", "withdraw own proposal", async () => {
    const f = fixtures.rescheduled, pid = randomUUID();
    await rpc("G1", "mutate_booking_reschedule", reschedule(f, "propose", pid, at(22, 16)));
    const result = await rpc("G1", "mutate_booking_reschedule", reschedule(f, "withdraw", pid));
    assert.deepEqual(result.booking, f.booking); assert.equal(result.proposal.status, "withdrawn");
    return { unchangedBooking: true };
  });
  await check("B52", "accepted reschedule operation replay", async () => {
    const { params, result } = fixtures.rescheduleReceipt;
    const before = digest();
    const replay = await rpc("G1", "mutate_booking_reschedule", params);
    assert.deepEqual(replay.receipt, result.receipt);
    assert.equal(replay.booking.id, result.booking.id);
    assert.deepEqual(digest(), before);
    return { replayed: replay.replayed, unchanged: true };
  });
  await check("B53", "cancel versus reschedule acceptance race", async () => {
    const f = await job("C1", 24), pid = randomUUID();
    await rpc("C1", "mutate_booking_reschedule", reschedule(f, "propose", pid, at(24, 16)));
    const outcomes = await Promise.allSettled([
      rpc("G1", "mutate_booking_reschedule", reschedule(f, "accept", pid)),
      rpc("C1", "mutate_booking_fulfillment", fulfillParams(f, "cancel")),
    ]);
    assert.equal(outcomes.filter(o => o.status === "fulfilled").length, 1);
    assert.equal(outcomes.find(o => o.status === "rejected").reason.code, "PT409");
    assert.equal((await rows("C1", "bookings", `request_id=eq.${f.request.id}`)).length, 1);
    return { oneWinner: true, bookings: 1 };
  });
  await check("B54", "time off cannot cover confirmed booking", async () => {
    const state = await rpc("G1", "get_groomer_availability", {});
    const day = new Intl.DateTimeFormat("en-CA", { timeZone: "America/Los_Angeles" }).format(new Date(at(10)));
    const error = await denied(() => rpc("G1", "save_groomer_availability", { p_expected_revision: state.revision,
      p_windows: state.windows, p_preferences: state.preferences, p_time_off: [{ id: randomUUID(), title: marker, start_date: day, end_date: day }] }), /time_off_conflicts_with_booking_occupancy/);
    assert.deepEqual(await rpc("G1", "get_groomer_availability", {}), state);
    return error;
  });
  await check("B55", "stale availability Save", async () => {
    const { params } = await updateSchedule(context, saved, "G1", p => { p.p_windows = p.p_windows.map(w => ({ ...w, end_time: "22:30" })); });
    const error = await denied(() => rpc("G1", "save_groomer_availability", params), /availability_revision_conflict/);
    assert.equal(error.code, "PT409");
    await updateSchedule(context, saved, "G1", p => { p.p_windows = p.p_windows.map(w => ({ ...w, end_time: "22:00" })); });
    return error;
  });
  await check("B56", "early start rejected", () => denied(() => rpc("G1", "mutate_booking_fulfillment",
    fulfillParams(fixtures.rescheduled, "start")), /outside_service_start_window/));
  await check("B57", "complete without Start rejected", () => denied(() => rpc("G1", "mutate_booking_fulfillment",
    fulfillParams(fixtures.rescheduled, "complete")), /service_not_completable/));
  await check("B58", "nonparticipant fulfillment rejected", () => denied(() => rpc("X", "mutate_booking_fulfillment",
    fulfillParams(fixtures.rescheduled, "cancel")), /booking_(not_found|participant_required)/));
  await check("B59", "cancellation operation replay", async () => {
    const f = await job("C4", 25), { result, params } = await cancel(f);
    const before = digest();
    const replay = await rpc("C4", "mutate_booking_fulfillment", params);
    assert.deepEqual(replay.receipt, result.receipt); assert.deepEqual(digest(), before);
    assert.equal((await rows("C4", "booking_fulfillment_events", `booking_id=eq.${f.booking.id}`)).length, 1);
    return { events: 1, replayed: true };
  });
  await check("B60", "review before completion rejected", () => denied(() => rpc("C1", "create_review", {
    p_booking_id: fixtures.rescheduled.booking.id, p_rating: 5, p_content: `${marker} premature review`, p_pet_fit_outcomes: [] }), /booking_not_completed|review_not_allowed/));
  await check("B61", "30 requests across match pages", async () => {
    const ids = [];
    for (let i = 0; i < 30; i++) ids.push((await publish(`C${Math.floor(i / 3) + 1}`, 26, { service_notes: `${marker} B61 ${i + 1}` })).request.id);
    const matches = [];
    for (let offset = 0; offset < 1000; offset += 25) {
      const page = await rpc("G1", "get_my_matched_requests", { p_groomer_id: actors.G1.id, p_limit: 25, p_offset: offset });
      matches.push(...page);
      if (page.length < 25) break;
    }
    for (const id of ids) assert.equal(matches.filter(m => m.request_id === id).length, 1, "Published request missing or duplicated across pages");
    return { created: ids.length, returnedExactlyOnce: ids.length, scannedMatches: matches.length };
  });
  await check("B62", "complete reminder snapshot", async () => {
    const snapshots = [];
    for (const name of ["C1", "G1"]) {
      const role = name === "G1" ? "groomer" : "customer";
      const result = await rpc(name, "get_my_reminder_snapshot", { p_participant_id: actors[name].id, p_role: role });
      assert.equal(result.complete, true);
      const expected = await rows(name, "bookings", `${role}_id=eq.${actors[name].id}&status=eq.confirmed&scheduled_start=gte.${encodeURIComponent(result.as_of)}&scheduled_start=lt.${encodeURIComponent(result.horizon_end)}`, "id");
      assert.deepEqual(result.bookings.map(b => b.id).sort(), expected.map(b => b.id).sort());
      assert.ok(expected.length > 1);
      snapshots.push({ actor: name, bookings: expected.length });
    }
    return snapshots;
  });
  await check("B63", "foreign quote and operation reads", async () => {
    assert.deepEqual(await rpc("X", "get_quote_evaluations", { p_offer_ids: [fixtures.rescheduled.offer.id] }), []);
    assert.equal(await rpc("X", "get_booking_reschedule_operation", { p_operation_id: fixtures.rescheduleReceipt.params.p_operation_id }), null);
    return denied(() => rpc("X", "get_booking_reschedule", { p_booking_id: fixtures.rescheduled.booking.id }), /booking_not_found/);
  });
  await check("B64", "read-only acceptance outcome recovery", async () => {
    const f = fixtures.rescheduled, before = digest();
    const result = await rpc("C1", "get_offer_acceptance", { p_offer_id: f.offer.id });
    assert.equal(result[0].booking_id, f.booking.id);
    assert.deepEqual(digest(), before);
    return { existingBookingRecovered: true, unchanged: true };
  });
  await check("B69", "open request cap and release", async () => {
    const requests = [];
    for (let i = 0; i < 3; i++) requests.push(await publish("C1", 27));
    const rejection = await denied(() => publish("C1", 27), /open_request_limit_exceeded/);
    await rpc("C1", "cancel_grooming_request", { p_request_id: requests[0].request.id });
    await publish("C1", 27);
    return { open: 3, rejection, replacementPublished: true };
  });
  await check("B70", "concurrent publications cannot bypass cap", async () => {
    for (let i = 0; i < 2; i++) await publish("C1", 27);
    const outcomes = await Promise.allSettled(Array.from({ length: 4 }, () => rpc("C1", "create_grooming_request_v4", publication("C1", 27))));
    const open = await rows("C1", "grooming_requests", `customer_id=eq.${actors.C1.id}&status=in.(open,has_offers)`, "id");
    const evidence = { attempts: 4, successful: outcomes.filter(o => o.status === "fulfilled").length, open: open.length,
      errors: outcomes.filter(o => o.status === "rejected").map(o => o.reason.serverMessage) };
    saveArtifact("publication-cap-race", evidence);
    assert.equal(open.length, 3, `Concurrent publication exceeded the cap: ${JSON.stringify(evidence)}`);
    assert.equal(evidence.successful, 1);
    return evidence;
  });
  await check("B71", "new chat notification has a usable destination", async () => {
    const f = await job("C1", 28);
    const sentAt = new Date().toISOString();
    await api.request("/rest/v1/messages", { method: "POST", headers: api.headers(actors.G1.token, { Prefer: "return=representation" }),
      body: JSON.stringify({ conversation_id: f.acceptance.conversation_id, sender_id: actors.G1.id,
        body: `${marker} B71 live booking message` }) }, "rest");
    const notifications = await rows("C1", "customer_notifications", `customer_id=eq.${actors.C1.id}&kind=eq.new_message&created_at=gte.${encodeURIComponent(sentAt)}`);
    assert.equal(notifications.length, 1);
    const evidence = { booking: f.booking.id.slice(0, 8), bookingStatus: f.booking.status,
      notification: notifications[0].id.slice(0, 8), targetBooking: notifications[0].related_booking_id,
      targetRequest: notifications[0].related_request_id, targetOffer: notifications[0].related_offer_id,
      targetConversation: notifications[0].related_conversation_id };
    saveArtifact("chat-notification-destination", evidence);
    assert.equal(notifications[0].related_conversation_id, f.acceptance.conversation_id);
    const target = await rows("C1", "conversations", `id=eq.${notifications[0].related_conversation_id}`);
    assert.equal(target.length, 1);
    assert.equal(target[0].customer_id, actors.C1.id);
    assert.equal(target[0].groomer_id, actors.G1.id);
    return evidence;
  });
  await check("B72", "replace request while already at open cap", async () => {
    const requests = [];
    for (let i = 0; i < 3; i++) requests.push(await publish("C1", 29));
    const original = requests[0];
    const replacement = publication("C1", 29, { service_notes: `${marker} B72 replacement`, preferred_end: at(29, 20) });
    const before = digest();
    let result;
    try {
      result = await rpc("C1", "supersede_grooming_request", { ...replacement, p_request_id: original.request.id,
        p_expected_request_revision: original.request.terms_revision });
    } catch (error) {
      const unchanged = JSON.stringify(digest()) === JSON.stringify(before);
      saveArtifact("replacement-at-cap", { originalOpen: 3, error: error.serverMessage, code: error.code, unchanged });
      throw error;
    }
    const open = await rows("C1", "grooming_requests", `customer_id=eq.${actors.C1.id}&status=in.(open,has_offers)`, "id");
    assert.equal(open.length, 3);
    assert.notEqual(result[0].request_id, original.request.id);
    const [old] = await rows("C1", "grooming_requests", `id=eq.${original.request.id}`);
    const [next] = await rows("C1", "grooming_requests", `id=eq.${result[0].request_id}`);
    assert.equal(old.status, "cancelled");
    assert.equal(next.supersedes_request_id, old.id);
    assert.deepEqual(await rows("C1", "grooming_requests", `id=in.(${requests.slice(1).map(f => f.request.id).join(",")})&order=id`),
      requests.slice(1).map(f => f.request).sort((a, b) => a.id.localeCompare(b.id)));
    return { open: 3, replacementPublished: true };
  });

  const replacementPayload = f => ({ ...publication(f.customer, f.day), p_request_id: f.request.id,
    p_expected_request_revision: f.request.terms_revision });
  const replaceRequest = (f, params = replacementPayload(f), actor = f.customer) => rpc(actor, "supersede_grooming_request", params);
  const openCount = async customer => (await rows(customer, "grooming_requests",
    `customer_id=eq.${actors[customer].id}&status=in.(open,has_offers)&expires_at=gt.${encodeURIComponent(new Date().toISOString())}`, "id")).length;
  async function cancelOpen(customer) {
    const tagged = query(`select id from public.grooming_requests where id in (${owned})
      and customer_id='${actors[customer].id}' and status in ('open','has_offers');`);
    for (const row of tagged) {
      await rpc(customer, "cancel_grooming_request", { p_request_id: row.id });
    }
  }
  await check("E01", "replacement preserves one, two and three request counts and closes quotes", async () => {
    for (let count = 1; count <= 3; count++) {
      await cancelOpen("C1");
      const original = await quote(await publish("C1", 31));
      for (let i = 1; i < count; i++) await publish("C1", 31);
      const [result] = await replaceRequest(original);
      assert.equal(await openCount("C1"), count);
      const [next] = await rows("C1", "grooming_requests", `id=eq.${result.request_id}`);
      assert.equal(next.supersedes_request_id, original.request.id);
      assert.equal((await rows("C1", "groomer_offers", `request_id=eq.${original.request.id}&status=eq.pending`)).length, 0);
      assert.equal((await rows("C1", "request_matches", `request_id=eq.${original.request.id}&status=in.(visible,viewed,offered)`)).length, 0);
    }
    return { counts: [1, 2, 3], originalQuotesAndMatchesClosed: true };
  });
  await check("E02", "replacement replay preserves the first result without extra mutations", async () => {
    const f = await publish("C1", 32);
    const params = replacementPayload(f);
    const results = await Promise.all(Array.from({ length: 4 }, () => replaceRequest(f, params)));
    for (const result of results) assert.deepEqual(result, results[0]);
    const before = digest();
    assert.deepEqual(await replaceRequest(f, { ...params, p_request: { ...params.p_request, service_notes: `${marker} changed replay` } }), results[0]);
    assert.deepEqual(digest(), before);
    assert.equal(await openCount("C1"), 1);
    return { attempts: 5, replacements: 1, unchangedReplay: true };
  });
  await check("E03", "different operations replacing one request have one winner", async () => {
    const f = await publish("C1", 32);
    const outcomes = await Promise.allSettled([replaceRequest(f), replaceRequest(f)]);
    assert.equal(outcomes.filter(o => o.status === "fulfilled").length, 1);
    for (const o of outcomes.filter(o => o.status === "rejected")) assert.match(o.reason.serverMessage, /request_not_cancellable/);
    assert.equal((await rows("C1", "grooming_requests", `supersedes_request_id=eq.${f.request.id}`)).length, 1);
    assert.equal(await openCount("C1"), 1);
    return { replacements: 1 };
  });
  await check("E04", "two different originals can be replaced concurrently", async () => {
    const originals = [await quote(await publish("C1", 33)), await quote(await publish("C1", 33))];
    const results = await Promise.all(originals.map(f => replaceRequest(f)));
    assert.notEqual(results[0][0].request_id, results[1][0].request_id);
    for (let i = 0; i < originals.length; i++) {
      const [next] = await rows("C1", "grooming_requests", `id=eq.${results[i][0].request_id}`);
      assert.equal(next.supersedes_request_id, originals[i].request.id);
    }
    assert.equal(await openCount("C1"), 2);
    return { successfulReplacements: 2 };
  });
  await check("E05", "replacement racing ordinary publication preserves the global cap", async () => {
    for (const initial of [2, 3]) {
      await cancelOpen("C1");
      const f = await publish("C1", 34);
      for (let i = 1; i < initial; i++) await publish("C1", 34);
      const outcomes = await Promise.allSettled([replaceRequest(f), rpc("C1", "create_grooming_request_v4", publication("C1", 34))]);
      assert.equal(outcomes[0].status, "fulfilled");
      assert.equal(outcomes[1].status, initial === 2 ? "fulfilled" : "rejected");
      if (initial === 3) assert.match(outcomes[1].reason.serverMessage, /open_request_limit_exceeded/);
      assert.equal(await openCount("C1"), 3);
    }
    return { initialCounts: [2, 3], finalCounts: [3, 3] };
  });
  await check("E06", "replacement competes atomically with acceptance and cancellation", async () => {
    const f = await quote(await publish("C1", 35));
    const outcomes = await Promise.allSettled([replaceRequest(f), rpc("C1", "accept_groomer_offer_v2", {
      p_offer_id: f.offer.id, p_expected_quote_revision: f.offer.quote_revision })]);
    assert.equal(outcomes.filter(o => o.status === "fulfilled").length, 1);
    for (const o of outcomes.filter(o => o.status === "rejected")) {
      assert.match(o.reason.serverMessage, /request_not_cancellable|offer_not_pending|request_not_open|quote_terms_invalid/);
    }
    assert.equal((await rows("C1", "bookings", `request_id=eq.${f.request.id}`)).length, outcomes[1].status === "fulfilled" ? 1 : 0);
    const other = await publish("C2", 35);
    const cancelRace = await Promise.allSettled([replaceRequest(other), rpc("C2", "cancel_grooming_request", { p_request_id: other.request.id })]);
    assert.equal(cancelRace[1].status, "fulfilled");
    if (cancelRace[0].status === "rejected") assert.match(cancelRace[0].reason.serverMessage, /request_not_cancellable/);
    assert.equal((await rows("C2", "grooming_requests", `supersedes_request_id=eq.${other.request.id}`)).length,
      cancelRace[0].status === "fulfilled" ? 1 : 0);
    return { acceptOrReplacementWinners: 1, cancellationRace: cancelRace.map(o => o.status) };
  });
  await check("E07", "failed replacement rolls back original, quotes, matches, notices, addresses and receipts", async () => {
    const f = await quote(await publish("C1", 36));
    const params = replacementPayload(f);
    const failure = await denied(() => replaceRequest(f, { ...params,
      p_request: { ...params.p_request, pet_id: actors.C2.pet.id } }), /pet_not_found/);
    assert.equal((await rows("C1", "groomer_offers", `id=eq.${f.offer.id}`))[0].status, "pending");
    return failure;
  });
  await check("E08", "replacement denies stale terms, foreign intent and closed originals", async () => {
    const f = await publish("C1", 37);
    const params = replacementPayload(f);
    await denied(() => replaceRequest(f, { ...params, p_expected_request_revision: randomUUID() }), /request_revision_changed/);
    await denied(() => replaceRequest(f, params, "C2"), /request_not_found/);
    await denied(() => replaceRequest(f, { ...params, p_publish_operation_id: f.payload.p_publish_operation_id }), /publish_operation_intent_changed/);
    const [next] = await replaceRequest(f, params);
    const other = await publish("C1", 37);
    await denied(() => replaceRequest(other, { ...replacementPayload(other), p_publish_operation_id: params.p_publish_operation_id }), /publish_operation_intent_changed/);
    await denied(() => replaceRequest(f), /request_not_cancellable/);
    assert.equal((await rows("C1", "grooming_requests", `id=eq.${next.request_id}`))[0].status, "open");
    const booked = await job("C2", 37, 14);
    await denied(() => replaceRequest(booked), /request_not_cancellable/);
    const expiredID = randomUUID();
    // Seed a separate historical fixture; never alter immutable terms or the server clock.
    query(`do $$ declare fixture public.grooming_requests%rowtype; begin
      select * into strict fixture from public.grooming_requests where id='${other.request.id}'
        and customer_id='${actors.C1.id}' and id in (${owned});
      fixture.id:='${expiredID}'; fixture.terms_revision:=gen_random_uuid();
      fixture.supersedes_request_id:=null;
      fixture.created_at:=statement_timestamp()-interval '2 days';
      fixture.expires_at:=statement_timestamp()-interval '1 day';
      insert into public.grooming_requests select fixture.*;
    end $$;`);
    const [expired] = await rows("C1", "grooming_requests", `id=eq.${expiredID}`);
    assert.ok(expired);
    await denied(() => replaceRequest({ ...other, request: expired }), /request_not_cancellable/);
    return { staleForeignReusedClosedBookedAndExpiredRejected: true,
      expiredSetup: "separate SQL-seeded historical fixture; rejection through authenticated HTTP" };
  });

  async function textNotification(f, sender) {
    const recipient = sender === f.customer ? f.groomer : f.customer;
    const role = recipient.startsWith("C") ? "customer" : "groomer";
    const body = `${marker} ${current} ${sender} ${randomUUID()}`;
    const [sent] = await api.request("/rest/v1/messages", { method: "POST",
      headers: api.headers(actors[sender].token, { Prefer: "return=representation" }),
      body: JSON.stringify({ conversation_id: f.acceptance.conversation_id, sender_id: actors[sender].id, body }) }, "rest");
    const notices = await rows(recipient, `${role}_notifications`,
      `${role}_id=eq.${actors[recipient].id}&kind=eq.new_message&related_conversation_id=eq.${sent.conversation_id}` +
        `&created_at=gte.${encodeURIComponent(sent.created_at)}`);
    assert.equal(notices.length, 1);
    assert.equal(notices[0].related_conversation_id, sent.conversation_id);
    return { recipient, role, sent, notice: notices[0] };
  }
  await check("E12", "acceptance recovery resolves the current cancelled booking without writing again", async () => {
    const f = await job("C1", 38);
    await cancel(f);
    const before = digest();
    const result = await rpc("C1", "get_offer_acceptance", { p_offer_id: f.offer.id });
    assert.equal(result.length, 1);
    assert.equal(result[0].booking_id, f.booking.id);
    assert.equal(result[0].offer_id, f.offer.id);
    assert.equal(result[0].booking_status, "cancelled_by_customer");
    const [currentBooking] = await rows("C1", "bookings", `id=eq.${f.booking.id}`);
    assert.equal(currentBooking.status, "cancelled_by_customer");
    assert.deepEqual(digest(), before);
    return { recoveredBooking: f.booking.id, currentStatus: currentBooking.status, readOnly: true };
  });
  await check("E17", "both participants send real text and receive exactly targeted notifications", async () => {
    const f = await job("C1", 39);
    const customer = await textNotification(f, "G1");
    const groomer = await textNotification(f, "C1");
    assert.equal(customer.recipient, "C1");
    assert.equal(groomer.recipient, "G1");
    return { conversation: f.acceptance.conversation_id, notifications: [customer.notice.id, groomer.notice.id] };
  });
  await check("E18", "multiple bookings and one cancellation retain the same message conversation", async () => {
    const first = await job("C1", 39, 14);
    const second = await job("C1", 39, 17);
    assert.equal(first.acceptance.conversation_id, second.acceptance.conversation_id);
    await cancel(first);
    const result = await textNotification(second, "G1");
    assert.equal(result.notice.related_conversation_id, first.acceptance.conversation_id);
    assert.equal((await rows("C1", "bookings", `id=eq.${second.booking.id}`))[0].status, "confirmed");
    return { reusedConversation: first.acceptance.conversation_id, otherBookingUnchanged: true };
  });
  async function existingConversation() {
    const rowsFound = await rows("C1", "conversations", `customer_id=eq.${actors.C1.id}&groomer_id=eq.${actors.G1.id}`);
    assert.equal(rowsFound.length, 1, "Run B71 or E17 setup first");
    return rowsFound[0];
  }
  await check("E19", "participant conversation can be resolved by exact identity without paging", async () => {
    const conversation = await existingConversation();
    for (const [actor, role] of [["C1", "customer"], ["G1", "groomer"]]) {
      const result = await rows(actor, "conversations", `id=eq.${conversation.id}&${role}_id=eq.${actors[actor].id}&limit=1`);
      assert.equal(result.length, 1);
      assert.equal(result[0].id, conversation.id);
    }
    return { exactIdentity: true, unloadedPageBehavior: "covered by Swift repository/store tests" };
  });
  await check("E21", "nonparticipants cannot read or redirect a conversation notification", async () => {
    const conversation = await existingConversation();
    const notices = await rows("C1", "customer_notifications", `related_conversation_id=eq.${conversation.id}&limit=1`);
    assert.equal(notices.length, 1);
    assert.equal((await rows("X", "conversations", `id=eq.${conversation.id}`)).length, 0);
    assert.equal((await rows("X", "customer_notifications", `id=eq.${notices[0].id}`)).length, 0);
    await denied(() => api.request(`/rest/v1/customer_notifications?id=eq.${notices[0].id}`, { method: "PATCH",
      headers: api.headers(actors.C1.token), body: JSON.stringify({ related_conversation_id: randomUUID() }) }, "rest"), /permission denied/);
    await denied(() => api.request("/rest/v1/messages", { method: "POST", headers: api.headers(actors.X.token),
      body: JSON.stringify({ conversation_id: conversation.id, sender_id: actors.X.id, body: `${marker} forbidden` }) }, "rest"), /row-level security|not_allowed|permission denied/);
    return { foreignReads: 0, targetAndSenderWritesDenied: true };
  });
  await check("E23", "old notification column projections remain readable on the expanded schema", async () => {
    const conversation = await existingConversation();
    for (const [actor, role] of [["C1", "customer"], ["G1", "groomer"]]) {
      const legacy = await rows(actor, `${role}_notifications`, `related_conversation_id=eq.${conversation.id}&limit=1`,
        `id,${role}_id,kind,title,body,is_read,created_at,read_at,related_request_id,related_booking_id,related_offer_id`);
      assert.equal(legacy.length, 1);
      assert.equal(legacy[0].kind, "new_message");
    }
    return { oldColumnQueriesReadable: true, oldClientRoutingFixed: false };
  });
  await check("E24", "notification read RPCs retain targets and FK deletion is rollback-verified", async () => {
    const conversation = await existingConversation();
    const ids = [];
    for (const [actor, role] of [["C1", "customer"], ["G1", "groomer"]]) {
      const notices = await rows(actor, `${role}_notifications`, `related_conversation_id=eq.${conversation.id}&limit=1`);
      assert.equal(notices.length, 1);
      ids.push(notices[0].id);
      const marked = await rpc(actor, `mark_${role}_notification_read`, { p_notification_id: notices[0].id });
      assert.equal(marked[0].related_conversation_id, conversation.id);
      // Batch reads can touch baseline notices, so verify the authenticated RPC inside a rollback transaction.
      const beforeBatch = digest();
      query(`begin; set local lock_timeout='5s';
        select set_config('request.jwt.claims','{"sub":"${actors[actor].id}","role":"authenticated","is_anonymous":false}',true);
        set local role authenticated;
        select * from public.mark_all_${role}_notifications_read();
        do $$ begin
          if not exists(select 1 from public.${role}_notifications where id='${notices[0].id}'
            and is_read and related_conversation_id='${conversation.id}')
            or exists(select 1 from public.${role}_notifications where ${role}_id='${actors[actor].id}' and not is_read) then
            raise exception 'Batch read did not preserve target or mark visible notices';
          end if;
        end $$;
        rollback;`);
      assert.deepEqual(digest(), beforeBatch);
    }
    const before = digest();
    // This is a transactional FK test, not a simulated user deleting a conversation.
    query(`begin; set local lock_timeout='5s';
      delete from public.conversations where id='${conversation.id}' and customer_id='${actors.C1.id}' and groomer_id='${actors.G1.id}';
      do $$ begin
        if exists(select 1 from public.customer_notifications where id in (${sqlIDs(ids)}) and related_conversation_id is not null)
          or exists(select 1 from public.groomer_notifications where id in (${sqlIDs(ids)}) and related_conversation_id is not null) then
          raise exception 'Notification conversation FK did not clear';
        end if;
      end $$;
      rollback;`);
    assert.deepEqual(digest(), before);
    return { singleRead: "authenticated HTTP", batchRead: "authenticated SQL transaction rolled back",
      readRPCsRetainTarget: true, deletionFK: "SQL transaction rolled back; no persisted conversation deletion" };
  });
  saveArtifact(`fixture-references${suffix}`, Object.fromEntries(Object.entries(fixtures).filter(([, f]) => f?.request).map(([name, f]) => [name,
    { customer: f.customer, groomer: f.groomer, request: f.request.id, offer: f.offer?.id, booking: f.booking?.id }])));
  console.log(JSON.stringify({ runID, executed: results.length, passed: results.filter(r => r.status === "PASS").length,
    failed: results.filter(r => r.status === "FAIL").length, cleanup: "pending Simulator tests and failure triage" }));
  if (results.some(r => r.status === "FAIL")) process.exitCode = 1;
}

function safe(value) {
  return String(value ?? "").replace(/[0-9a-f]{8}-[0-9a-f-]{27}/gi, "<id>")
    .replace(/\b(?:eyJ|sb_secret_|sb_publishable_)[A-Za-z0-9_.-]+/g, "<credential>");
}
