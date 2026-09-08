import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { parseEnv } from "node:util";
import { parseCustomerProfiles, parseGroomerProfiles, SupabaseREST } from "./testops-core.mjs";
import { captureT374TimingSnapshot } from "./t374-timing-snapshot.mjs";
import { runTimingAdmissionRace } from "./timing-admission-race.mjs";
import { runTimingDatabaseBarrier } from "./timing-database-barrier.mjs";

assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1", "Explicit test authorization required");
assert.equal(readFileSync("supabase/.temp/project-ref", "utf8").trim(), "lqmasbuqzvcvtawonjlb");
const credentials = parseEnv(readFileSync("supabase_environment_variables", "utf8"));
assert.equal(credentials.SUPABASE_URL, "https://lqmasbuqzvcvtawonjlb.supabase.co");
const api = new SupabaseREST(credentials.SUPABASE_URL, credentials.SUPABASE_PUBLISHABLE_KEY);
const verifyFulfillment = process.env.TESTOPS_VERIFY_FULFILLMENT === "1";
const verifyRescheduling = process.env.TESTOPS_VERIFY_RESCHEDULING === "1";
const preserveNoticePolicy = verifyFulfillment || verifyRescheduling;
const verifyAgreements = preserveNoticePolicy || process.env.TESTOPS_VERIFY_AGREEMENTS === "1";
const runID = `${verifyRescheduling ? "T378" : verifyFulfillment ? "T377" : verifyAgreements ? "T376" : "T374"}-${randomUUID()}`;
const verifyMatchRefresh = process.env.TESTOPS_VERIFY_MATCH_REFRESH === "1";
const directory = `artifacts/testops/${runID}`;
mkdirSync(directory, { recursive: true, mode: 0o700 });
const json = value => `'${JSON.stringify(value).replaceAll("'", "''")}'::jsonb`;
function query(sql) {
  const result = spawnSync("supabase", ["db", "query", "--linked", "--output", "json", sql], {
    encoding: "utf8", timeout: 120000, maxBuffer: 8 * 1024 * 1024,
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  if (result.status !== 0) {
    writeFileSync(`${directory}/query-error.txt`, result.stderr ?? "SQL process failed", { mode: 0o600 });
    throw new Error("Scoped SQL failed; inspect private recovery artifact.");
  }
  return JSON.parse(result.stdout).rows;
}
const customer = parseCustomerProfiles().find(row => row.seedID === "BTC-001");
const groomer = parseGroomerProfiles().find(row => row.seedID === "BTG-001");
assert.ok(customer && groomer);
const customerAuth = await api.signIn(customer.email, customer.password);
const groomerAuth = await api.signIn(groomer.email, groomer.password);
const fixtureAddress = (await api.rpc("get_my_profile_address_v3", {}, groomerAuth.accessToken)).address;
assert.ok(fixtureAddress && Number.isFinite(fixtureAddress.latitude) && Number.isFinite(fixtureAddress.longitude));
assert.equal(fixtureAddress.state, "CA", "The explicitly Los Angeles timing fixture requires its California location");
const customerID = customerAuth.user.id;
const groomerID = groomerAuth.user.id;
for (const id of [customerID, groomerID]) assert.match(id, /^[0-9a-f-]{36}$/i);
const tables = ["groomer_availability_windows", "groomer_booking_preferences", "groomer_time_off_windows"];
const aggregate = table => `(select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb)
  from public.${table} t where groomer_id='${groomerID}')`;
const settingsSQL = `select ${tables.map((table, index) => `${aggregate(table)} as rows${index}`).join(",")};`;
const baseline = captureT374TimingSnapshot();
const [backup] = query(settingsSQL);
if (preserveNoticePolicy) assert.equal(backup.rows1.length, 1, "Booking fixture requires existing preferences");
const fixtures = [];
let configured;
let unknownOutcome = false;
let preferSave = false;
let revisionRaceOrder = null;
const quoteRevisions = new Map();
const originalRPC = api.rpc.bind(api);
api.rpc = async (name, parameters, token) => {
  try {
    // The holder still requires both blocked sessions before release. This only
    // biases their queue order; the actual winner is asserted below.
    if ((preferSave || revisionRaceOrder === "replacement") && name === "accept_groomer_offer") await new Promise(resolve => setTimeout(resolve, 500));
    if (revisionRaceOrder === "booking" && name === "supersede_grooming_request") await new Promise(resolve => setTimeout(resolve, 500));
    if (verifyAgreements && name === "accept_groomer_offer") {
      assert.ok(quoteRevisions.has(parameters.p_offer_id), "Read the exact quote before acceptance");
      return await originalRPC("accept_groomer_offer_v2", { ...parameters,
        p_expected_quote_revision: quoteRevisions.get(parameters.p_offer_id) }, token);
    }
    return await originalRPC(name, parameters, token);
  }
  catch (error) {
    if (!name.startsWith("get_") && !error.httpStatus) unknownOutcome = true;
    throw error;
  }
};
writeFileSync(`${directory}/recovery.json`, JSON.stringify({ runID, customerID, groomerID, backup, baseline }), { mode: 0o600 });

try {
  if (verifyMatchRefresh) {
    const [worker] = query("select active from cron.job where jobname='beckon_refresh_request_matches';");
    assert.equal(worker?.active, false, "Matching contention acceptance requires the worker to remain paused");
  }
  query(`begin; select set_config('app.availability_batch','1',true);
    do $$ begin
      if exists(select 1 from public.grooming_requests where status in ('open','has_offers') and expires_at>now())
        or exists(select 1 from public.bookings where groomer_id='${groomerID}' and status in ('confirmed','completed'))
        or exists(select 1 from public.conversations where customer_id='${customerID}' and groomer_id='${groomerID}') then
        raise exception 'Timing race fixtures are not isolated';
      end if;
    end $$;
    insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
    select '${groomerID}',d,'00:00'::time,'24:00'::time,true,'America/Los_Angeles' from generate_series(1,7) d
    on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
      is_enabled=true,timezone=excluded.timezone;
    ${preserveNoticePolicy ? `update public.groomer_booking_preferences
      set timing_buffers='{"preparation_minutes":15,"cleanup_minutes":10,"inbound_travel_minutes":30,"outbound_travel_minutes":20}'
      where groomer_id='${groomerID}';` : `insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days,timing_buffers)
    values('${groomerID}',12,0,'{"preparation_minutes":15,"cleanup_minutes":10,"inbound_travel_minutes":30,"outbound_travel_minutes":20}')
    on conflict(groomer_id) do update set max_appointments_per_day=12,minimum_advance_notice_days=0,timing_buffers=excluded.timing_buffers;`}
    commit;`);
  [configured] = query(settingsSQL);
  writeFileSync(`${directory}/configured.json`, JSON.stringify(configured), { mode: 0o600 });
  for (let attempt = 0; attempt < (verifyAgreements && !preserveNoticePolicy ? 4 : 2); attempt++) {
    const fixture = { operationID: randomUUID(), requestID: null, offerID: null };
    fixtures.push(fixture);
    writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
    const [created] = query(`select id as pet_id,
      timezone('America/Los_Angeles',(timezone('America/Los_Angeles',now())::date+${10 + attempt})+time '10:00') as start
      from public.pets where customer_id='${customerID}' and is_active and species='Dog' order by id limit 1;`);
    assert.ok(created?.pet_id, "Active fixture pet required");
    const publishParameters = {
      p_publish_operation_id: fixture.operationID, p_preference_time_zone_identifier: "America/Los_Angeles",
      p_request: { pet_id: created.pet_id, service_type: "full_groom", service_notes: `TESTOPS:${runID}`,
        preferred_start: created.start,
        preferred_end: new Date(Date.parse(created.start) + (verifyMatchRefresh || verifyAgreements ? 10800000 : 7200000)).toISOString(),
        location_mode: "groomer_comes_to_customer", street_address: fixtureAddress.line_1, city: fixtureAddress.city,
        state: fixtureAddress.state, zip_code: fixtureAddress.zip_code, provider: fixtureAddress.provider,
        country_code: fixtureAddress.country_code, latitude: fixtureAddress.latitude,
        longitude: fixtureAddress.longitude, resolution_source: "manual_geocode", user_confirmed_at: new Date().toISOString() },
    };
    const publication = await api.rpc("create_grooming_request_v4", publishParameters, customerAuth.accessToken);
    const requestID = publication[0]?.request_id;
    assert.ok(requestID, "Publication receipt missing");
    fixture.requestID = requestID;
    writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
    const publicationReplay = await api.rpc("create_grooming_request_v4", {
      p_publish_operation_id: fixture.operationID, p_request: {}, p_preference_time_zone_identifier: null,
    }, customerAuth.accessToken);
    assert.deepEqual(publicationReplay, publication, "Publication retry must preserve its receipt");
    const matches = await api.restSelect("request_matches", `select=id&request_id=eq.${requestID}&groomer_id=eq.${groomerID}`, groomerAuth.accessToken);
    assert.equal(matches.length, 1, "Publication must actually match the fixture groomer; do not inject a match");
    const serviceEnd = new Date(Date.parse(created.start) + 3600000).toISOString();
    const [requestTerms] = verifyAgreements ? await api.restSelect("grooming_requests",
      `select=terms_revision&id=eq.${requestID}`, customerAuth.accessToken) : [];
    const receipt = await api.rpc(verifyAgreements ? "create_groomer_offer_v2" : "create_groomer_offer", {
      ...(verifyAgreements ? { p_expected_request_revision: requestTerms?.terms_revision } : {}), p_request_id: requestID,
      p_proposed_start: created.start, p_proposed_end: serviceEnd, p_price_estimate: 100,
      p_message: `TESTOPS:${runID} timing allocation` }, groomerAuth.accessToken);
    const offerID = receipt[0]?.offer_id;
    assert.ok(offerID, "Offer RPC receipt missing");
    fixture.offerID = offerID;
    writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
    const allocationFields = "applied_timing_buffers,service_time_zone_identifier,schedule_time_zone_identifier,occupied_start,occupied_end"
      + (verifyAgreements ? ",agreement_snapshot" : "");
    const offers = await api.restSelect("groomer_offers", `select=${allocationFields}&id=eq.${offerID}`, customerAuth.accessToken);
    assert.equal(offers.length, 1);
    const allocation = offers[0];
    if (verifyAgreements) {
      assert.equal(allocation.agreement_snapshot?.request_revision, requestTerms?.terms_revision);
      assert.equal(allocation.agreement_snapshot?.schema_version, 1);
      quoteRevisions.set(offerID, allocation.agreement_snapshot.quote_revision);
    }
    const expectedBuffers = { preparation_minutes: 15, cleanup_minutes: 10,
      inbound_travel_minutes: 30, outbound_travel_minutes: 20 };
    assert.deepEqual(allocation.applied_timing_buffers, expectedBuffers);
    assert.equal(allocation.service_time_zone_identifier, "America/Los_Angeles");
    assert.equal(allocation.schedule_time_zone_identifier, "America/Los_Angeles");
    assert.equal(Date.parse(allocation.occupied_start), Date.parse(created.start)
      - (expectedBuffers.preparation_minutes + expectedBuffers.inbound_travel_minutes) * 60000);
    assert.equal(Date.parse(allocation.occupied_end), Date.parse(serviceEnd)
      + (expectedBuffers.cleanup_minutes + expectedBuffers.outbound_travel_minutes) * 60000);
    if (verifyRescheduling) {
      const [acceptance] = await api.rpc("accept_groomer_offer", { p_offer_id: offerID }, customerAuth.accessToken);
      const before = (await api.rpc("get_booking_reschedule", { p_booking_id: acceptance.booking_id }, customerAuth.accessToken)).booking;
      const proposalID = randomUUID();
      const newStart = new Date(Date.parse(before.scheduled_start) + 1800000).toISOString();
      const propose = { p_booking_id: before.id, p_expected_revision: before.fulfillment_revision,
        p_operation_id: randomUUID(), p_action: "propose", p_proposal_id: proposalID, p_new_start: newStart };
      const proposed = await api.rpc("mutate_booking_reschedule", propose, customerAuth.accessToken);
      assert.deepEqual(proposed.booking, before, "A pending proposal must retain the original booking");
      const operations = [
        { ...propose, p_operation_id: randomUUID(), p_action: "accept", p_new_start: null },
        { p_booking_id: before.id, p_expected_revision: before.fulfillment_revision,
          p_operation_id: randomUUID(), p_action: "cancel", p_note: null },
      ];
      const names = ["mutate_booking_reschedule", "mutate_booking_fulfillment"];
      const actors = [groomerAuth, customerAuth];
      const outcomes = await runTimingDatabaseBarrier(groomerID, () => Promise.allSettled(actors.map(async (actor, index) => {
        if (index !== attempt) await new Promise(resolve => setTimeout(resolve, 500));
        return api.rpc(names[index], operations[index], actor.accessToken);
      })), { revisionRequestID: requestID, rescheduleRace: true });
      assert.equal(outcomes[attempt].status, "fulfilled");
      assert.equal(outcomes[1 - attempt].status, "rejected");
      assert.equal(outcomes[1 - attempt].reason.code, "PT409");
      const result = outcomes[attempt].value;
      assert.equal(result.booking.id, before.id);
      assert.equal(result.booking.status, attempt === 0 ? "confirmed" : "cancelled_by_customer");
      assert.equal(Date.parse(result.booking.scheduled_start), Date.parse(attempt === 0 ? newStart : before.scheduled_start));
      assert.equal(Date.parse(result.booking.scheduled_end) - Date.parse(result.booking.scheduled_start), 3600000);
      assert.deepEqual(result.booking.applied_timing_buffers, before.applied_timing_buffers);
      const replay = await api.rpc(names[attempt], operations[attempt], actors[attempt].accessToken);
      assert.deepEqual(replay.receipt, result.receipt);
      const proposedReplay = await api.rpc("mutate_booking_reschedule", propose, customerAuth.accessToken);
      assert.deepEqual(proposedReplay.booking, result.booking);
      assert.equal(proposedReplay.proposal.effective_status, attempt === 0 ? "accepted" : "invalidated");
      assert.equal(await api.rpc("get_booking_reschedule_operation", { p_operation_id: propose.p_operation_id }, groomerAuth.accessToken), null);
      const bookings = await api.restSelect("bookings", `select=id&request_id=eq.${requestID}`, customerAuth.accessToken);
      assert.deepEqual(bookings, [{ id: before.id }]);
      writeFileSync(`${directory}/reschedule-race-${attempt}.json`, JSON.stringify({
        winner: attempt === 0 ? "reschedule" : "cancel", dispatch: "verified-database-lock-contention",
        oneBooking: true, currentStateAndOriginalReceipt: true }), { mode: 0o600 });
      console.log(`Reschedule race ${attempt + 1}: PASS (${attempt === 0 ? "reschedule" : "cancel"}; one booking, exact replay)`);
      continue;
    }
    if (verifyFulfillment) {
      const [acceptance] = await api.rpc("accept_groomer_offer", { p_offer_id: offerID }, customerAuth.accessToken);
      const [before] = await api.restSelect("bookings", `select=id,fulfillment_revision,agreement_snapshot&id=eq.${acceptance.booking_id}`, customerAuth.accessToken);
      assert.ok(before?.fulfillment_revision);
      const actors = [customerAuth, groomerAuth];
      const operations = actors.map(() => ({ p_booking_id: before.id,
        p_expected_revision: before.fulfillment_revision, p_operation_id: randomUUID(), p_action: "cancel", p_note: null }));
      const outcomes = await runTimingDatabaseBarrier(groomerID, () => Promise.allSettled(actors.map(async (actor, index) => {
        if (index !== attempt) await new Promise(resolve => setTimeout(resolve, 500));
        return api.rpc("mutate_booking_fulfillment", operations[index], actor.accessToken);
      })), { revisionRequestID: requestID, fulfillmentRace: true });
      assert.equal(outcomes[attempt].status, "fulfilled");
      assert.equal(outcomes[1 - attempt].status, "rejected");
      assert.equal(outcomes[1 - attempt].reason.code, "PT409");
      const result = outcomes[attempt].value;
      assert.equal(result.booking.status, attempt === 0 ? "cancelled_by_customer" : "cancelled_by_groomer");
      assert.deepEqual(result.booking.agreement_snapshot, before.agreement_snapshot);
      const replay = await api.rpc("mutate_booking_fulfillment", operations[attempt], actors[attempt].accessToken);
      const lookup = await api.rpc("get_booking_fulfillment_operation", {
        p_operation_id: operations[attempt].p_operation_id }, actors[attempt].accessToken);
      assert.deepEqual(replay.receipt, result.receipt);
      assert.deepEqual(lookup, replay);
      assert.equal(await api.rpc("get_booking_fulfillment_operation", {
        p_operation_id: operations[attempt].p_operation_id }, actors[1 - attempt].accessToken), null);
      const events = await api.restSelect("booking_fulfillment_events", `select=id,operation_id&booking_id=eq.${before.id}`, customerAuth.accessToken);
      assert.equal(events.length, 1);
      assert.equal(events[0].operation_id, operations[attempt].p_operation_id);
      writeFileSync(`${directory}/fulfillment-race-${attempt}.json`, JSON.stringify({
        winner: attempt === 0 ? "customer" : "groomer", dispatch: "verified-database-lock-contention",
        currentStateAndOriginalReceipt: true, eventCount: events.length }), { mode: 0o600 });
      console.log(`Fulfillment race ${attempt + 1}: PASS (${attempt === 0 ? "customer" : "groomer"}; exact replay, single event)`);
      continue;
    }
    if (verifyAgreements && attempt >= 2) {
      preferSave = false;
      revisionRaceOrder = attempt === 2 ? "booking" : "replacement";
      const replacementFixture = { operationID: randomUUID(), requestID: null, offerID: null };
      fixtures.push(replacementFixture);
      writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
      const parameters = { ...publishParameters, p_request_id: requestID,
        p_expected_request_revision: requestTerms.terms_revision,
        p_publish_operation_id: replacementFixture.operationID,
        p_request: { ...publishParameters.p_request, service_type: "nail_trim" } };
      const [acceptance, replacement] = await runTimingDatabaseBarrier(groomerID, async () => {
        const outcomes = await Promise.allSettled([
          api.rpc("accept_groomer_offer", { p_offer_id: offerID }, customerAuth.accessToken),
          api.rpc("supersede_grooming_request", parameters, customerAuth.accessToken),
        ]);
        if (outcomes[1].status === "fulfilled") {
          replacementFixture.requestID = outcomes[1].value[0]?.request_id;
          writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
        }
        console.log("Revision dispatch:", JSON.stringify(outcomes.map(result => ({ status: result.status,
          message: result.reason?.serverMessage, code: result.reason?.code }))));
        return outcomes;
      }, { revisionRequestID: requestID });
      if (replacement.status === "fulfilled") {
        replacementFixture.requestID = replacement.value[0]?.request_id;
        writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
        assert.ok(replacementFixture.requestID);
      }
      assert.notEqual(acceptance.status, replacement.status, "Exactly one revision race operation must succeed");
      const winner = acceptance.status === "fulfilled" ? "booking" : "replacement";
      assert.equal(winner, revisionRaceOrder);
      const rejection = winner === "booking" ? replacement.reason : acceptance.reason;
      assert.equal(rejection.serverMessage, winner === "booking" ? "request_not_cancellable" : "offer_not_pending");
      const bookings = await api.restSelect("bookings", `select=id,agreement_snapshot&offer_id=eq.${offerID}`, customerAuth.accessToken);
      assert.equal(bookings.length, winner === "booking" ? 1 : 0);
      if (winner === "booking") {
        assert.deepEqual(bookings[0].agreement_snapshot, allocation.agreement_snapshot);
        const replay = await api.rpc("accept_groomer_offer", { p_offer_id: offerID }, customerAuth.accessToken);
        assert.deepEqual(replay, await api.rpc("get_offer_acceptance", { p_offer_id: offerID }, customerAuth.accessToken));
      } else {
        assert.deepEqual(await api.rpc("supersede_grooming_request", parameters, customerAuth.accessToken), replacement.value);
      }
      writeFileSync(`${directory}/revision-race-${attempt}.json`, JSON.stringify({ winner,
        dispatch: "verified-database-lock-contention", originalRequestID: requestID,
        replacementRequestID: replacementFixture.requestID, bookingReadbackVerified: true }), { mode: 0o600 });
      console.log(`Revision race ${attempt - 1}: PASS (${winner}; verified-database-lock-contention)`);
      revisionRaceOrder = null;
      continue;
    }
    preferSave = attempt === 1;
    const result = await runTimingAdmissionRace(api, { offerID, groomerID, serviceStart: created.start,
      customerToken: customerAuth.accessToken, groomerToken: groomerAuth.accessToken,
      databaseBarrier: async (...args) => {
        try { return await runTimingDatabaseBarrier(...args, {
          matchRefreshRequestID: verifyMatchRefresh ? requestID : null,
        }); }
        catch (error) {
          writeFileSync(`${directory}/barrier-error.txt`, error.barrierDiagnostics ?? error.message, { mode: 0o600 });
          throw error;
        }
      } });
    assert.equal(result.winner, preferSave ? "time_off" : "booking", "Both admission orderings must be observed");
    const { bookingID, ...evidence } = result;
    if (verifyMatchRefresh) {
      const parameters = { p_groomer_id: groomerID, p_limit: 100, p_offset: 0 };
      const before = await api.rpc("get_my_matched_requests", parameters, groomerAuth.accessToken);
      if (!bookingID) assert.equal(before.find(row => row.request_id === requestID)?.eligibility_evaluation?.state, "pending");
      query("select app_private.drain_match_refresh_queue(250);");
      const after = await api.rpc("get_my_matched_requests", parameters, groomerAuth.accessToken);
      const refreshed = after.find(row => row.request_id === requestID);
      if (bookingID) assert.equal(refreshed, undefined);
      // The shared race helper restores its temporary time off before returning.
      // The legacy empty-size service therefore returns to assessment, not exclusion.
      else assert.equal(refreshed?.eligibility_evaluation?.state, "assessment_required");
      evidence.lockedRefreshPreservedAndReadbackVerified = true;
    }
    if (bookingID) {
      const bookings = await api.restSelect("bookings", `select=${allocationFields}&id=eq.${bookingID}`, customerAuth.accessToken);
      assert.deepEqual(bookings, [allocation], "Booking must preserve the exact quoted allocation");
      const replay = await api.rpc("accept_groomer_offer", { p_offer_id: offerID }, customerAuth.accessToken);
      const lookup = await api.rpc("get_offer_acceptance", { p_offer_id: offerID }, customerAuth.accessToken);
      assert.equal(replay[0]?.booking_id, bookingID);
      assert.deepEqual(replay, lookup, "Acceptance replay and reconciliation must agree");
    }
    evidence.offerAllocationReadbackVerified = true;
    evidence.publicationAndReplayVerified = true;
    evidence.bookingAllocationAndReplayVerified = Boolean(bookingID);
    writeFileSync(`${directory}/race-${attempt}.json`, JSON.stringify(evidence), { mode: 0o600 });
    console.log(`Race ${attempt + 1}: PASS (${evidence.winner}; ${evidence.dispatch})`);
  }
} finally {
  if (unknownOutcome) {
    console.error(`Unknown write outcome; preserve fixtures for reconciliation: ${directory}`);
  } else if (configured) {
    const [current] = query(settingsSQL);
    // Save updates preference timestamps even when values are unchanged.
    const comparable = value => ({ ...value, rows1: value.rows1.map(({ updated_at, ...row }) => row) });
    assert.deepEqual(comparable(current), comparable(configured), "Unexpected fixture settings change; preserve recovery artifacts");
    const requestIDs = fixtures.filter(row => row.requestID).map(row => `'${row.requestID}'::uuid`).join(",") || "null::uuid";
    query(`begin; select set_config('app.availability_batch','1',true);
      do $$ begin
        ${tables.map((table, index) => `if ${aggregate(table)} <> ${json(current[`rows${index}`])} then
          raise exception 'Concurrent fixture settings change; abort restoration'; end if;`).join("\n")}
        if exists(select 1 from public.messages m join public.conversations c on c.id=m.conversation_id
          where c.customer_id='${customerID}' and c.groomer_id='${groomerID}'
          and not (m.kind='booking_card' and m.booking_id in (select id from public.bookings where request_id in (${requestIDs})))
          and not (m.kind='text' and (m.body='Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!'
            ${preserveNoticePolicy ? `or (m.body='This booking was cancelled before service. The original request remains closed.'
              and exists(select 1 from public.booking_fulfillment_events event join public.bookings booking on booking.id=event.booking_id
                where booking.request_id in (${requestIDs}) and event.actor_id=m.sender_id
                  and event.action='cancel' and m.created_at=event.recorded_at+interval '1 microsecond'))` : ""}
            ${verifyRescheduling ? `or exists(select 1 from app_private.booking_reschedule_operations operation
              join public.bookings booking on booking.id=operation.booking_id
              where booking.request_id in (${requestIDs}) and operation.actor_id=m.sender_id
                and m.created_at=(operation.receipt->>'recorded_at')::timestamptz+interval '1 microsecond'
                and m.body=case operation.receipt->>'action'
                  when 'propose' then 'A new appointment time was proposed. The original appointment remains confirmed until both participants agree.'
                  when 'accept' then 'The proposed appointment time was accepted. This booking now uses the newly agreed time.' end)` : ""})
            and exists(select 1 from public.messages card join public.bookings b on b.id=card.booking_id
              where b.request_id in (${requestIDs}) and card.conversation_id=m.conversation_id
              and card.sender_id=m.sender_id and m.created_at=card.created_at+interval '1 microsecond'))) then
          raise exception 'Unrelated conversation activity; abort restoration'; end if;
        if exists(select 1 from public.bookings where customer_id='${customerID}' and groomer_id='${groomerID}'
          and request_id not in (${requestIDs})) then raise exception 'Unrelated pair booking; abort restoration'; end if;
      end $$;
      delete from public.customer_notifications where related_request_id in (${requestIDs})
        or related_booking_id in (select id from public.bookings where request_id in (${requestIDs}));
      delete from public.groomer_notifications where related_request_id in (${requestIDs})
        or related_booking_id in (select id from public.bookings where request_id in (${requestIDs}));
      delete from public.conversations where customer_id='${customerID}' and groomer_id='${groomerID}';
      select app_private.cleanup_testops_request_address_location(id,'${runID}')
        from public.grooming_requests where id in (${requestIDs}) and service_notes='TESTOPS:${runID}';
      delete from public.grooming_requests where id in (${requestIDs}) and service_notes='TESTOPS:${runID}';
      ${preserveNoticePolicy ? `alter table public.groomer_booking_preferences disable trigger groomer_booking_preferences_set_updated_at;
        update public.groomer_booking_preferences prefs set timing_buffers=original.timing_buffers,updated_at=original.updated_at
          from jsonb_populate_recordset(null::public.groomer_booking_preferences,${json(backup.rows1)}) original
          where prefs.groomer_id=original.groomer_id;
        alter table public.groomer_booking_preferences enable trigger groomer_booking_preferences_set_updated_at;` : ""}
      ${tables.map((table, index) => preserveNoticePolicy && table === "groomer_booking_preferences" ? "" : `delete from public.${table} where groomer_id='${groomerID}';
        insert into public.${table} select * from jsonb_populate_recordset(null::public.${table},${json(backup[`rows${index}`])});`).join("\n")}
      ${verifyMatchRefresh || verifyAgreements ? `delete from app_private.match_refresh_queue where request_id in (${requestIDs});` : ""}
      commit;`);
    assert.deepEqual(captureT374TimingSnapshot(), baseline, "Exact fixture restoration failed");
    console.log("Exact 39-field fixture restoration: PASS");
  }
}
