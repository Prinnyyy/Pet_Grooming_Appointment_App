import assert from "node:assert/strict";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { parseEnv } from "node:util";
import { randomUUID } from "node:crypto";
import { parseCustomerProfiles, parseGroomerProfiles, SupabaseREST } from "./testops-core.mjs";

export const runID = process.env.TESTOPS_RUN_ID ?? "TESTOPS-T387-20260910-A";
assert.match(runID, /^TESTOPS-T387-[A-Z0-9-]{1,70}$/);
export const directory = `artifacts/testops/${runID}`;
export const marker = `TESTOPS:${runID}`;
const recoveryPath = `${directory}/recovery.json`;
export const buffers = { preparation_minutes: 15, cleanup_minutes: 10,
  inbound_travel_minutes: 30, outbound_travel_minutes: 20 };
const settingsTables = ["groomer_availability_windows", "groomer_booking_preferences", "groomer_time_off_windows"];
export const sqlJSON = value => `'${JSON.stringify(value).replaceAll("'", "''")}'::jsonb`;
export const sqlIDs = ids => ids.map(id => { assert.match(id, /^[0-9a-f-]{36}$/i); return `'${id}'::uuid`; }).join(",");
export function saveArtifact(name, value) {
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  writeFileSync(`${directory}/${name}.json`, JSON.stringify(value, null, 2), { mode: 0o600 });
}
export function query(sql) {
  assert.equal(readFileSync("supabase/.temp/project-ref", "utf8").trim(), "lqmasbuqzvcvtawonjlb");
  const result = spawnSync("supabase", ["db", "query", "--linked", "--output", "json", sql], {
    encoding: "utf8", timeout: 120000, maxBuffer: 16 * 1024 * 1024,
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  if (result.status !== 0) {
    saveArtifact("query-error", { message: result.stderr });
    throw Error("Scoped SQL failed; inspect private query-error.json before retrying");
  }
  return JSON.parse(result.stdout).rows;
}
const aggregate = (table, predicate) => `(select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) from ${table} t where ${predicate})`;
export async function connect(aliases = null) {
  assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1", "Explicit test-operation authorization required");
  const env = parseEnv(readFileSync("supabase_environment_variables", "utf8"));
  assert.equal(env.SUPABASE_URL, "https://lqmasbuqzvcvtawonjlb.supabase.co");
  const api = new SupabaseREST(env.SUPABASE_URL, env.SUPABASE_PUBLISHABLE_KEY);
  const customers = parseCustomerProfiles();
  const groomers = parseGroomerProfiles();
  const actors = {};
  for (const [alias, seed] of Object.entries({ C1: "BTC-003", C2: "BTC-004", C3: "BTC-016", C4: "BTC-049",
    C5: "BTC-005", C6: "BTC-007", C7: "BTC-008", C8: "BTC-009", C9: "BTC-010", C10: "BTC-011",
    X: "BTC-002", G1: "BTG-001", G2: "BTG-006" })) {
    if (aliases && !aliases.includes(alias)) continue;
    const profile = [...customers, ...groomers].find(p => p.seedID === seed);
    assert.ok(profile);
    const session = await api.signIn(profile.email, profile.password);
    const actor = { id: session.user.id, token: session.accessToken, seed };
    if (alias.startsWith("C") || alias === "X") {
      actor.pets = await api.restSelect("pets", `select=id,name,species&customer_id=eq.${actor.id}&is_active=eq.true&order=created_at.asc`, actor.token);
      actor.pet = actor.pets.find(p => p.species === "Dog");
      assert.ok(actor.pet);
    } else {
      actor.address = (await api.rpc("get_my_profile_address_v3", {}, actor.token)).address;
      assert.ok(Number.isFinite(actor.address?.latitude));
    }
    actors[alias] = actor;
  }
  return { api, actors };
}
function scope(saved) {
  const customers = sqlIDs(saved.customerIDs), groomers = sqlIDs(saved.groomerIDs);
  return { customers, groomers, owned: `select id from public.grooming_requests where customer_id in (${customers})
    and (service_notes='${marker}' or service_notes like '${marker} %')` };
}
function snapshot(saved) {
  const { customers, groomers } = scope(saved);
  const participants = `${customers},${groomers}`;
  const tables = {
    ...Object.fromEntries(settingsTables.map(t => [`public.${t}`, `groomer_id in (${groomers})`])),
    "public.groomer_profiles": `user_id in (${groomers})`,
    "public.customer_profiles": `user_id in (${customers})`,
    "public.pets": `customer_id in (${customers})`,
    "public.grooming_requests": `customer_id in (${customers})`,
    "public.groomer_offers": `groomer_id in (${groomers}) or customer_id in (${customers})`,
    "public.bookings": `groomer_id in (${groomers}) or customer_id in (${customers})`,
    "public.request_matches": `groomer_id in (${groomers}) or customer_id in (${customers})`,
    "public.conversations": `groomer_id in (${groomers}) and customer_id in (${customers})`,
    "public.customer_notifications": `customer_id in (${customers})`,
    "public.groomer_notifications": `groomer_id in (${groomers})`,
    "app_private.address_locations": `owner_id in (${participants})`,
    "app_private.request_publish_operations": `customer_id in (${customers})`,
  };
  return query(`select ${Object.entries(tables).map(([t, p], i) => {
    const value = t === "public.groomer_booking_preferences"
      ? `(select coalesce(jsonb_agg(to_jsonb(t)-'updated_at' order by groomer_id),'[]'::jsonb) from ${t} t where ${p})`
      : aggregate(t, p);
    return `md5((${value})::text) h${i}`;
  }).join(",")};`)[0];
}
export async function prepare(context) {
  assert.equal(existsSync(recoveryPath), false, "Existing recovery artifact must not be overwritten");
  const { api, actors } = context;
  const saved = { runID, startedAt: new Date().toISOString(), customerIDs: Object.entries(actors).filter(([k]) => k.startsWith("C")).map(([, a]) => a.id),
    groomerIDs: [actors.G1.id, actors.G2.id], operations: [], requests: [], configured: {} };
  const { customers, groomers } = scope(saved);
  const [idle] = query(`select
    (select count(*) from public.grooming_requests where customer_id in (${customers}) and status in ('open','has_offers') and expires_at>now()) requests,
    (select count(*) from public.bookings where (customer_id in (${customers}) or groomer_id in (${groomers})) and scheduled_end>now()) bookings,
    (select count(*) from public.conversations where customer_id in (${customers}) and groomer_id in (${groomers})) conversations;`);
  assert.deepEqual(idle, { requests: 0, bookings: 0, conversations: 0 }, "Test cohort is not idle");
  [saved.backup] = query(`select ${settingsTables.map((t, i) => `${aggregate(`public.${t}`, `groomer_id in (${groomers})`)} rows${i}`).join(",")};`);
  [saved.relatedBaseline] = query(`select
    ${aggregate("public.groomer_profiles", `user_id in (${groomers})`)} profiles,
    ${aggregate("public.customer_notifications", `customer_id in (${customers})`)} customer_notifications,
    ${aggregate("public.groomer_notifications", `groomer_id in (${groomers})`)} groomer_notifications;`);
  saved.baseline = snapshot(saved);
  saveArtifact("recovery", saved);
  for (const name of ["G1", "G2"]) {
    const actor = actors[name];
    const before = await api.rpc("get_groomer_availability", {}, actor.token);
    assert.equal(before.time_off.length, 0, "Do not replace existing time off");
    const configured = await api.rpc("save_groomer_availability", {
      p_expected_revision: before.revision,
      p_windows: Array.from({ length: 7 }, (_, index) => ({ weekday: index + 1, start_time: "08:00", end_time: "22:00",
        is_enabled: true, timezone: "America/Los_Angeles" })),
      p_preferences: { max_appointments_per_day: 4, minimum_advance_notice_days: 1, auto_accept_bookings: false, timing_buffers: buffers },
      p_time_off: [],
    }, actor.token);
    saved.configured[actor.id] = configured;
    saveArtifact("recovery", saved);
  }
  console.log(JSON.stringify({ runID, prepared: true, customers: saved.customerIDs.length, groomers: 2 }));
  return saved;
}
export function recover() {
  const saved = JSON.parse(readFileSync(recoveryPath, "utf8"));
  assert.equal(saved.runID, runID);
  assert.notEqual(saved.restored, true, "Fixture already restored");
  return saved;
}
export async function updateSchedule(context, saved, name, transform) {
  const actor = context.actors[name];
  const before = await context.api.rpc("get_groomer_availability", {}, actor.token);
  const params = { p_expected_revision: before.revision, p_windows: before.windows,
    p_preferences: before.preferences, p_time_off: before.time_off };
  transform(params);
  const result = await context.api.rpc("save_groomer_availability", params, actor.token);
  saved.configured[actor.id] = result;
  saveArtifact("recovery", saved);
  return { before, result, params };
}
export async function cleanup(context, saved) {
  assert.ok(!saved.uncertainWrite, "Resolve the uncertain write outcome before cleanup");
  const { customers, groomers, owned } = scope(saved);
  for (const id of saved.groomerIDs) {
    const actor = Object.values(context.actors).find(a => a.id === id);
    const current = await context.api.rpc("get_groomer_availability", {}, actor.token);
    assert.deepEqual(current, saved.configured[id], "Concurrent schedule change; do not overwrite");
  }
  assert.ok(saved.relatedBaseline, "Old calibration fixture needs its explicit residual audit");
  const originalNotifications = type => {
    const ids = saved.relatedBaseline[type].map(n => n.id);
    return ids.length ? `id not in (${sqlIDs(ids)})` : "true";
  };
  const newMessages = type => `kind='new_message' and ${originalNotifications(type)}
    and created_at>='${saved.startedAt}' and ${type === "customer_notifications" ? `customer_id in (${customers})` : `groomer_id in (${groomers})`}`;
  // Message notifications currently have no foreign-key target. Snapshot IDs and
  // the absence of unrelated recipient conversations guard their test cleanup.
  const [messageNotifications] = query(`select
    ${aggregate("public.customer_notifications", newMessages("customer_notifications"))} customer,
    ${aggregate("public.groomer_notifications", newMessages("groomer_notifications"))} groomer;`);
  saveArtifact("message-notification-cleanup", messageNotifications);
  // The cohort had no pair conversations. Every deleted conversation must still
  // contain only this run's bookings and its exact-marker/generated messages.
  query(`begin; set local lock_timeout='5s'; select set_config('app.availability_batch','1',true);
    ${saved.groomerIDs.map(id => `select pg_advisory_xact_lock(hashtextextended('${id}',71071));`).join("\n")}
    do $$ begin
      ${saved.groomerIDs.flatMap(id => settingsTables.map((table, index) => {
        const current = saved.configured[id];
        const expected = [current.windows, [current.preferences], current.time_off][index];
        return `if ${aggregate(`public.${table}`, `groomer_id='${id}'::uuid`)} is distinct from
          (select coalesce(jsonb_agg(value order by value::text),'[]'::jsonb) from jsonb_array_elements(${sqlJSON(expected)})) then
            raise exception 'Concurrent schedule change under cleanup lock'; end if;`;
      })).join("\n")}
      if exists(select 1 from public.bookings where customer_id in (${customers}) and groomer_id in (${groomers}) and request_id not in (${owned})) then
        raise exception 'Unrelated pair booking appeared'; end if;
      if exists(select 1 from public.messages m join public.conversations c on c.id=m.conversation_id
        where m.created_at>='${saved.startedAt}' and (c.customer_id in (${customers}) or c.groomer_id in (${groomers}))
          and not (c.customer_id in (${customers}) and c.groomer_id in (${groomers}))) then
        raise exception 'Unrelated recipient conversation activity'; end if;
      if exists(select 1 from public.messages m join public.conversations c on c.id=m.conversation_id
        where c.customer_id in (${customers}) and c.groomer_id in (${groomers})
          and not (m.kind='booking_card' and m.booking_id in (select id from public.bookings where request_id in (${owned})))
          and not (m.kind='text' and (m.body='${marker}' or m.body like '${marker} %'))
          and not (m.kind='text' and m.body='Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!'
            and exists(select 1 from public.messages card join public.bookings b on b.id=card.booking_id where b.request_id in (${owned})
              and card.conversation_id=m.conversation_id and card.sender_id=m.sender_id and m.created_at=card.created_at+interval '1 microsecond'))
          and not exists(select 1 from public.booking_fulfillment_events e join public.bookings b on b.id=e.booking_id where b.request_id in (${owned})
            and e.actor_id=m.sender_id and m.created_at=e.recorded_at+interval '1 microsecond')
          and not exists(select 1 from app_private.booking_reschedule_operations o join public.bookings b on b.id=o.booking_id where b.request_id in (${owned})
            and o.actor_id=m.sender_id and m.created_at=(o.receipt->>'recorded_at')::timestamptz+interval '1 microsecond')) then
        raise exception 'Unrelated conversation activity appeared'; end if;
    end $$;
    delete from public.customer_notifications where ${newMessages("customer_notifications")};
    delete from public.groomer_notifications where ${newMessages("groomer_notifications")};
    delete from public.customer_notifications where related_request_id in (${owned}) or related_booking_id in (select id from public.bookings where request_id in (${owned}));
    delete from public.groomer_notifications where related_request_id in (${owned}) or related_booking_id in (select id from public.bookings where request_id in (${owned}));
    delete from public.conversations where customer_id in (${customers}) and groomer_id in (${groomers});
    select app_private.cleanup_testops_request_address_location(id,'${runID}') from public.grooming_requests where id in (${owned});
    delete from public.grooming_requests where id in (${owned});
    ${settingsTables.map((t, i) => i === 1
      ? `insert into public.${t} select * from jsonb_populate_recordset(null::public.${t},${sqlJSON(saved.backup.rows1)})
        on conflict(groomer_id) do update set max_appointments_per_day=excluded.max_appointments_per_day,
          minimum_advance_notice_days=excluded.minimum_advance_notice_days,auto_accept_bookings=excluded.auto_accept_bookings,
          timing_buffers=excluded.timing_buffers;`
      : `delete from public.${t} where groomer_id in (${groomers});
        insert into public.${t} select * from jsonb_populate_recordset(null::public.${t},${sqlJSON(saved.backup[`rows${i}`])});`).join("\n")}
    commit;`);
  const restored = snapshot(saved);
  saveArtifact("restoration", { baseline: saved.baseline, actual: restored });
  assert.deepEqual(restored, saved.baseline, "Exact fixture restoration mismatch");
  assert.equal(query(`select count(*) remaining from public.grooming_requests where id in (${owned});`)[0].remaining, 0);
  saved.restored = true;
  saveArtifact("recovery", saved);
  console.log("Fixture data/settings restoration: PASS; preference updated_at intentionally advances; tagged requests: 0");
}
export function intent(saved, kind) {
  const id = randomUUID();
  saved.operations.push({ id, kind });
  saveArtifact("recovery", saved);
  return id;
}
