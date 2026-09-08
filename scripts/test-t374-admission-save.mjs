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
const runID = `T374-${randomUUID()}`;
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
const fixtures = [];
let configured;
let unknownOutcome = false;
let preferSave = false;
const originalRPC = api.rpc.bind(api);
api.rpc = async (name, parameters, token) => {
  try {
    // The holder still requires both blocked sessions before release. This only
    // biases their queue order; the actual winner is asserted below.
    if (preferSave && name === "accept_groomer_offer") await new Promise(resolve => setTimeout(resolve, 500));
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
    insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days,timing_buffers)
    values('${groomerID}',12,0,'{"preparation_minutes":15,"cleanup_minutes":10,"inbound_travel_minutes":30,"outbound_travel_minutes":20}')
    on conflict(groomer_id) do update set max_appointments_per_day=12,minimum_advance_notice_days=0,timing_buffers=excluded.timing_buffers;
    commit;`);
  [configured] = query(settingsSQL);
  writeFileSync(`${directory}/configured.json`, JSON.stringify(configured), { mode: 0o600 });
  for (let attempt = 0; attempt < 2; attempt++) {
    const fixture = { operationID: randomUUID(), requestID: null, offerID: null };
    fixtures.push(fixture);
    writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
    const [created] = query(`select id as pet_id,
      timezone('America/Los_Angeles',(timezone('America/Los_Angeles',now())::date+${10 + attempt})+time '10:00') as start
      from public.pets where customer_id='${customerID}' and is_active and species='Dog' order by id limit 1;`);
    assert.ok(created?.pet_id, "Active fixture pet required");
    const publication = await api.rpc("create_grooming_request_v4", {
      p_publish_operation_id: fixture.operationID, p_preference_time_zone_identifier: "America/Los_Angeles",
      p_request: { pet_id: created.pet_id, service_type: "full_groom", service_notes: `TESTOPS:${runID}`,
        preferred_start: created.start,
        preferred_end: new Date(Date.parse(created.start) + (verifyMatchRefresh ? 10800000 : 7200000)).toISOString(),
        location_mode: "groomer_comes_to_customer", street_address: fixtureAddress.line_1, city: fixtureAddress.city,
        state: fixtureAddress.state, zip_code: fixtureAddress.zip_code, provider: fixtureAddress.provider,
        country_code: fixtureAddress.country_code, latitude: fixtureAddress.latitude,
        longitude: fixtureAddress.longitude, resolution_source: "manual_geocode", user_confirmed_at: new Date().toISOString() },
    }, customerAuth.accessToken);
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
    const receipt = await api.rpc("create_groomer_offer", { p_request_id: requestID,
      p_proposed_start: created.start, p_proposed_end: serviceEnd, p_price_estimate: 100,
      p_message: `TESTOPS:${runID} timing allocation` }, groomerAuth.accessToken);
    const offerID = receipt[0]?.offer_id;
    assert.ok(offerID, "Offer RPC receipt missing");
    fixture.offerID = offerID;
    writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
    const allocationFields = "applied_timing_buffers,service_time_zone_identifier,schedule_time_zone_identifier,occupied_start,occupied_end";
    const offers = await api.restSelect("groomer_offers", `select=${allocationFields}&id=eq.${offerID}`, customerAuth.accessToken);
    assert.equal(offers.length, 1);
    const allocation = offers[0];
    assert.deepEqual(allocation.applied_timing_buffers, { preparation_minutes: 15, cleanup_minutes: 10,
      inbound_travel_minutes: 30, outbound_travel_minutes: 20 });
    assert.equal(allocation.service_time_zone_identifier, "America/Los_Angeles");
    assert.equal(allocation.schedule_time_zone_identifier, "America/Los_Angeles");
    assert.equal(Date.parse(allocation.occupied_start), Date.parse(created.start) - 45 * 60000);
    assert.equal(Date.parse(allocation.occupied_end), Date.parse(serviceEnd) + 30 * 60000);
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
          and not (m.kind='text' and m.body='Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!'
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
      ${tables.map((table, index) => `delete from public.${table} where groomer_id='${groomerID}';
        insert into public.${table} select * from jsonb_populate_recordset(null::public.${table},${json(backup[`rows${index}`])});`).join("\n")}
      ${verifyMatchRefresh ? `delete from app_private.match_refresh_queue where request_id in (${requestIDs});` : ""}
      commit;`);
    assert.deepEqual(captureT374TimingSnapshot(), baseline, "Exact fixture restoration failed");
    console.log("Exact 39-field fixture restoration: PASS");
  }
}
