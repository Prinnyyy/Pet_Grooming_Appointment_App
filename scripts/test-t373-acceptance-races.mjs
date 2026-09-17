import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { parseCustomerProfiles, parseGroomerProfiles, SupabaseREST } from "./testops-core.mjs";

assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1", "Explicit remote test authorization required");
const project = "lqmasbuqzvcvtawonjlb";
assert.equal(readFileSync("supabase/.temp/project-ref", "utf8").trim(), project);
const key = readFileSync("ios/Beckon/Config/Supabase.local.xcconfig", "utf8")
  .match(/^SUPABASE_PUBLISHABLE_KEY\s*=\s*(\S+)/m)?.[1];
assert.ok(key);
const url = `https://${project}.supabase.co`;
const api = new SupabaseREST(url, key);
const runID = `T373-${randomUUID()}`;
const directory = `artifacts/testops/${runID}`;
mkdirSync(directory, { recursive: true });
const env = { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" };
const json = value => `'${JSON.stringify(value).replaceAll("'", "''")}'::jsonb`;
const ids = values => values.map(value => {
  assert.match(value, /^[0-9a-f-]{36}$/i);
  return `'${value}'::uuid`;
}).join(",") || "null::uuid";
function query(sql) {
  const result = spawnSync("supabase", ["db", "query", "--linked", "--output", "json", sql],
    { encoding: "utf8", env, maxBuffer: 8 * 1024 * 1024 });
  if (result.status !== 0) {
    writeFileSync(`${directory}/query-error.txt`, result.stderr, { mode: 0o600 });
    throw new Error("Scoped SQL failed; inspect the local recovery artifact");
  }
  return JSON.parse(result.stdout).rows;
}
const customers = [];
const groomers = [];
for (const seedID of ["BTC-001", "BTC-002"]) {
  const account = parseCustomerProfiles().find(row => row.seedID === seedID);
  assert.ok(account);
  customers.push(await api.signIn(account.email, account.password));
}
for (const seedID of ["BTG-001", "BTG-002"]) {
  const account = parseGroomerProfiles().find(row => row.seedID === seedID);
  assert.ok(account);
  groomers.push(await api.signIn(account.email, account.password));
}
const customerIDs = customers.map(auth => auth.user.id);
const groomerIDs = groomers.map(auth => auth.user.id);
const ownerFilter = `groomer_id in (${ids(groomerIDs)})`;
const pairFilter = `customer_id in (${ids(customerIDs)}) and ${ownerFilter}`;
const tables = ["groomer_availability_windows", "groomer_booking_preferences", "groomer_time_off_windows"];
const aggregate = table => `(select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) from public.${table} t where ${ownerFilter})`;
const [backup] = query(`select ${tables.map((table, i) => `${aggregate(table)} as rows${i}`).join(",")},
  md5(${aggregate("bookings")}::text) as bookings_hash,
  md5(${aggregate("request_matches")}::text) as matches_hash,
  (select count(*) from public.conversations where ${pairFilter}) as conversations;`);
assert.equal(backup.conversations, 0, "Fixtures require unused customer/groomer conversations");
const pets = query(`select distinct on (customer_id) id,customer_id from public.pets
  where customer_id in (${ids(customerIDs)}) order by customer_id,id;`);
assert.equal(pets.length, 2);
const fixtures = [];
let unknownOutcome = false;
let started = false;
let expectedAvailability;
writeFileSync(`${directory}/recovery.json`, JSON.stringify({ runID, customerIDs, groomerIDs, backup }), { mode: 0o600 });

async function rpc(name, params, token) {
  try {
    const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
      method: "POST", headers: { apikey: key, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(params), signal: AbortSignal.timeout(30000),
    });
    return { status: response.status, value: await response.json() };
  } catch {
    unknownOutcome = true;
    return { status: 0, value: null };
  }
}
function prepare(label, { samePet = true, sameGroomer = false, competing = false, duplicate = false, quota = false } = {}) {
  const day = 5 + fixtures.length;
  const start = `2099-01-${String(day).padStart(2, "0")}T18:00:00Z`;
  const first = { request: randomUUID(), offer: randomUUID(), match: randomUUID(), customer: 0, groomer: 0, start };
  const second = duplicate ? first : { request: competing ? first.request : randomUUID(),
    offer: randomUUID(), match: randomUUID(), customer: samePet ? 0 : 1,
    groomer: sameGroomer ? 0 : 1, start: quota ? start.replace("18:00", "20:00") : start };
  const entries = duplicate ? [first] : [first, second];
  fixtures.push({ label, entries });
  writeFileSync(`${directory}/fixtures.json`, JSON.stringify(fixtures), { mode: 0o600 });
  const requestIDs = new Set();
  const statements = [];
  for (const entry of entries) {
    const customerID = customerIDs[entry.customer];
    const groomerID = groomerIDs[entry.groomer];
    const petID = pets.find(pet => pet.customer_id === customerID).id;
    if (!requestIDs.has(entry.request)) {
      statements.push(`insert into public.grooming_requests(id,customer_id,pet_id,pet_snapshot,photo_snapshot,
        service_type,service_notes,preferred_start,preferred_end,city,state,zip_code,street_address,location_mode,status,expires_at)
        values('${entry.request}','${customerID}','${petID}','{}','[]','full_groom','${runID}',
        '${entry.start}','${entry.start}'::timestamptz+interval '1 hour','Fullerton','CA','92832',
        '770 S Harbor Blvd','groomer_comes_to_customer','has_offers',now()+interval '1 day');`);
      requestIDs.add(entry.request);
    }
    statements.push(`insert into public.request_matches(id,request_id,groomer_id,customer_id,status)
      values('${entry.match}','${entry.request}','${groomerID}','${customerID}','offered');
      insert into public.groomer_offers(id,request_id,match_id,customer_id,groomer_id,proposed_start,proposed_end,price_estimate,status,expires_at)
      values('${entry.offer}','${entry.request}','${entry.match}','${customerID}','${groomerID}',
      '${entry.start}','${entry.start}'::timestamptz+interval '1 hour',100,'pending',now()+interval '1 day');`);
  }
  query(`begin; ${statements.join("\n")} commit;`);
  return [first, second];
}

async function race(label, first, second) {
  // The holder verifies two distinct live PostgREST sessions are actually
  // blocked, not merely that JavaScript started two promises together.
  const locked = [...new Set([first.request, second.request])];
  const holderSQL = `begin;
    select id from public.grooming_requests where id in (${ids(locked)}) order by id for update;
    select pg_sleep(5);
    do $$ declare blocked_sessions integer; begin
      for attempt in 1..20 loop
        perform pg_stat_clear_snapshot();
        select count(distinct pid) into blocked_sessions from pg_stat_activity
        where application_name like 'PostgREST %' and state='active'
          and wait_event_type='Lock' and query ~ '(accept|create|withdraw)_groomer_offer';
        exit when blocked_sessions >= 2;
        perform pg_sleep(0.25);
      end loop;
      if blocked_sessions < 2 then
        raise exception 'two independent blocked sessions not observed: %',
          (select jsonb_agg(jsonb_build_object('pid',pid,'app',application_name,'state',state,
            'wait_type',wait_event_type,'wait',wait_event,'offer_query',query ~ '(accept|create|withdraw)_groomer_offer'))
           from pg_stat_activity where usename='authenticator');
      end if;
    end $$; commit;`;
  const holder = spawn("supabase", ["db", "query", "--linked", "--output", "json", holderSQL], { env });
  let errors = "";
  holder.stdout.resume();
  holder.stderr.on("data", chunk => { errors += chunk; });
  const finished = new Promise(resolve => holder.on("close", code => resolve(code)));
  await new Promise(resolve => setTimeout(resolve, 1800));
  const results = await Promise.all([first, second].map(entry =>
    rpc(entry.rpcName ?? "accept_groomer_offer", entry.params ?? { p_offer_id: entry.offer },
      entry.token ?? customers[entry.customer].accessToken)));
  const holderCode = await finished;
  writeFileSync(`${directory}/${label}.json`, JSON.stringify(results), { mode: 0o600 });
  if (holderCode !== 0) writeFileSync(`${directory}/barrier-error.txt`, errors, { mode: 0o600 });
  assert.equal(holderCode, 0, "Independent database-session barrier was not verified");
  assert.ok(results.every(result => result.status !== 0), "Unknown HTTP outcome: recovery required");
  return results;
}

try {
  started = true;
  query(`begin; select set_config('app.availability_batch','1',true);
    insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
    select g,d,'08:00'::time,'20:00'::time,true,'America/Los_Angeles'
    from unnest(array[${ids(groomerIDs)}]) g cross join generate_series(1,7) d
    on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
      is_enabled=true,timezone=excluded.timezone;
    insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days)
    select g,1,0 from unnest(array[${ids(groomerIDs)}]) g on conflict(groomer_id)
      do update set max_appointments_per_day=1,minimum_advance_notice_days=0;
    commit;`);
  [expectedAvailability] = query(`select ${tables.map((table, index) => `${aggregate(table)} as rows${index}`).join(",")};`);
  writeFileSync(`${directory}/expected-availability.json`, JSON.stringify(expectedAvailability), { mode: 0o600 });
  for (const [label, options, winners] of [
    ["same-pet", {}, 1], ["same-groomer", { samePet: false, sameGroomer: true }, 1],
    ["different-pets", { samePet: false }, 2], ["daily-quota", { samePet: false, sameGroomer: true, quota: true }, 1],
    ["duplicate", { duplicate: true }, 2], ["competing", { competing: true }, 1],
  ]) {
    const entries = prepare(label, options);
    const results = await race(label, ...entries);
    assert.equal(results.filter(result => result.status === 200).length, winners, `${label}: wrong admission count`);
    for (const result of results.filter(result => result.status !== 200)) {
      assert.ok(["booking_conflict", "offer_not_pending"].includes(result.value?.message), `${label}: unexpected failure`);
    }
    if (options.duplicate) assert.equal(results[0].value[0].booking_id, results[1].value[0].booking_id);
    const winner = results.find(result => result.status === 200).value[0];
    const entry = entries.find(item => item.offer === winner.offer_id);
    const lookup = await rpc("get_offer_acceptance", { p_offer_id: winner.offer_id }, customers[entry.customer].accessToken);
    assert.equal(lookup.status, 200);
    assert.equal(lookup.value[0].booking_id, winner.booking_id, "Dropped-response lookup changed receipt");
    const replay = await rpc("accept_groomer_offer", { p_offer_id: winner.offer_id }, customers[entry.customer].accessToken);
    assert.deepEqual(replay.value, lookup.value, "Replay did not preserve receipt/current state");
    console.log(`${label}: PASS (two verified database sessions)`);
  }
  {
    const [first, second] = prepare("withdraw-accept", { duplicate: true });
    const results = await race("withdraw-accept", first, { ...second,
      rpcName: "withdraw_groomer_offer", token: groomers[second.groomer].accessToken });
    assert.equal(results.filter(result => result.status === 200).length, 1);
    assert.ok(["offer_not_pending", "offer_not_withdrawable"].includes(
      results.find(result => result.status !== 200).value?.message));
    console.log("withdraw-accept: PASS (two verified database sessions)");
  }
  {
    const [first, second] = prepare("create-accept", { competing: true });
    query(`begin; delete from public.groomer_offers where id='${second.offer}';
      update public.request_matches set status='viewed' where id='${second.match}'; commit;`);
    const results = await race("create-accept", first, { ...second,
      rpcName: "create_groomer_offer", token: groomers[second.groomer].accessToken,
      params: { p_request_id: second.request, p_proposed_start: second.start,
        p_proposed_end: second.start.replace("18:00", "19:00"), p_price_estimate: 100, p_message: runID } });
    assert.equal(results[0].status, 200, "Acceptance failed while another groomer created an offer");
    assert.ok(results[1].status === 200 || ["request_not_open", "match_not_offerable"].includes(results[1].value?.message));
    console.log("create-accept: PASS (two verified database sessions)");
  }
} finally {
  if (started && !unknownOutcome && expectedAvailability) {
    const requestIDs = [...new Set(fixtures.flatMap(fixture => fixture.entries.map(entry => entry.request)))];
    query(`begin; select set_config('app.availability_batch','1',true);
      do $$ begin
        ${tables.map((table, index) => `if ${aggregate(table)} <> ${json(expectedAvailability[`rows${index}`])} then
          raise exception 'Availability changed outside the test; preserve recovery artifact'; end if;`).join("\n")}
        if exists(select 1 from public.bookings where ${pairFilter} and request_id not in (${ids(requestIDs)})) then
          raise exception 'Unrelated booking appeared for a fixture conversation';
        end if;
        if exists(select 1 from public.messages m join public.conversations c on c.id=m.conversation_id
          where c.customer_id in (${ids(customerIDs)}) and c.groomer_id in (${ids(groomerIDs)})
          and not (m.kind='booking_card' and m.booking_id in (select id from public.bookings where request_id in (${ids(requestIDs)})))
          and not (m.kind='text' and m.body='Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!'
            and exists(select 1 from public.messages card join public.bookings b on b.id=card.booking_id
              where b.request_id in (${ids(requestIDs)}) and card.conversation_id=m.conversation_id
              and card.sender_id=m.sender_id and m.created_at=card.created_at+interval '1 microsecond'))) then
          raise exception 'Unrelated conversation activity: preserve fixtures for manual reconciliation';
        end if;
      end $$;
      delete from public.customer_notifications where related_request_id in (${ids(requestIDs)})
        or related_booking_id in (select id from public.bookings where request_id in (${ids(requestIDs)}));
      delete from public.groomer_notifications where related_request_id in (${ids(requestIDs)})
        or related_booking_id in (select id from public.bookings where request_id in (${ids(requestIDs)}));
      delete from public.conversations where ${pairFilter};
      delete from public.grooming_requests where id in (${ids(requestIDs)}) and service_notes='${runID}';
      ${tables.map((table, index) => `delete from public.${table} where ${ownerFilter};
        insert into public.${table} select * from jsonb_populate_recordset(null::public.${table},${json(backup[`rows${index}`])});`).join("\n")}
      commit;`);
    const [after] = query(`select md5(${aggregate("bookings")}::text) as bookings_hash,
      md5(${aggregate("request_matches")}::text) as matches_hash,
      ${tables.map((table, index) => `${aggregate(table)} as rows${index}`).join(",")};`);
    assert.equal(after.bookings_hash, backup.bookings_hash);
    assert.equal(after.matches_hash, backup.matches_hash);
    for (let i = 0; i < tables.length; i++) assert.deepEqual(after[`rows${i}`], backup[`rows${i}`]);
    console.log("Exact fixture restoration: PASS");
  } else if (unknownOutcome) {
    console.error(`Unknown server outcome; fixtures preserved at ${directory}`);
  }
}
