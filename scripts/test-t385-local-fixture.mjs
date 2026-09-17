import assert from "node:assert/strict";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { captureT374TimingSnapshot } from "./t374-timing-snapshot.mjs";

const runID = "TESTOPS-T385-SIM-20260910-A";
const directory = `artifacts/testops/${runID}`;
const path = `${directory}/recovery.json`;
const mode = process.argv[2];
assert.ok(["prepare", "inspect", "day-hours", "restore-notifications", "cleanup"].includes(mode));
assert.equal(readFileSync("supabase/.temp/project-ref", "utf8").trim(), "lqmasbuqzvcvtawonjlb");
if (mode !== "inspect") assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1");
mkdirSync(directory, { recursive: true, mode: 0o700 });
const json = value => `'${JSON.stringify(value).replaceAll("'", "''")}'::jsonb`;
function query(sql) {
  const result = spawnSync("supabase", ["db", "query", "--linked", "--output", "json", sql], {
    encoding: "utf8", timeout: 120000, maxBuffer: 8 * 1024 * 1024,
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  if (result.status !== 0) {
    writeFileSync(`${directory}/query-error.txt`, result.stderr || "SQL failed", { mode: 0o600 });
    throw new Error("Scoped query failed; inspect the private recovery artifact before retrying.");
  }
  return JSON.parse(result.stdout).rows;
}
const tables = ["groomer_availability_windows", "groomer_booking_preferences", "groomer_time_off_windows"];
const aggregate = (table, predicate) => `(select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) from public.${table} t where ${predicate})`;
let saved;
if (mode === "prepare") {
  assert.equal(existsSync(path), false, "An existing fixture must be inspected/restored, never overwritten");
  const [ids] = query(`select
    (select id from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001') customer,
    (select id from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001') groomer;`);
  for (const id of Object.values(ids)) assert.match(id, /^[0-9a-f-]{36}$/i);
  const [backup] = query(`select ${tables.map((t, i) => `${aggregate(t, `groomer_id='${ids.groomer}'`)} rows${i}`).join(",")},
    ${aggregate("groomer_profiles", `user_id='${ids.groomer}'`)} profile,
    ${aggregate("reviews", `groomer_id='${ids.groomer}'`)} reviews;`);
  saved = { runID, ...ids, backup, baseline: captureT374TimingSnapshot() };
  writeFileSync(path, JSON.stringify(saved), { mode: 0o600 });
  query(`begin; set local lock_timeout='5s'; select set_config('app.availability_batch','1',true);
    do $$ begin
      if exists(select 1 from public.bookings where groomer_id='${ids.groomer}' and status in ('confirmed','completed'))
        or exists(select 1 from public.conversations where customer_id='${ids.customer}' and groomer_id='${ids.groomer}')
        or exists(select 1 from public.grooming_requests where customer_id='${ids.customer}' and status in ('open','has_offers') and expires_at>now())
      then raise exception 'Test pair is not idle'; end if;
    end $$;
    insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
      select '${ids.groomer}',d,'00:00'::time,'23:59'::time,true,'America/Los_Angeles' from generate_series(1,7) d
      on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,is_enabled=true,timezone=excluded.timezone;
    insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,minimum_advance_notice_days,timing_buffers)
      values('${ids.groomer}',12,0,'{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}')
      on conflict(groomer_id) do update set max_appointments_per_day=12,minimum_advance_notice_days=0,timing_buffers=excluded.timing_buffers;
    delete from public.groomer_time_off_windows where groomer_id='${ids.groomer}';
    commit;`);
  [saved.configured] = query(`select ${tables.map((t, i) => `${aggregate(t, `groomer_id='${ids.groomer}'`)} rows${i}`).join(",")};`);
  writeFileSync(path, JSON.stringify(saved), { mode: 0o600 });
  console.log(JSON.stringify({ runID, prepared: true, restorationArtifact: path }));
} else {
  saved = JSON.parse(readFileSync(path, "utf8"));
  assert.equal(saved.runID, runID);
}
const { customer, groomer, backup } = saved;
if (mode === "restore-notifications") {
  // The installed RPC only changes false/null to true/statement_timestamp().
  // Its CHECK constraint proves the prior read state of this exact accidental batch.
  const repairPath = `${directory}/notification-read-repair.json`;
  const previousRepair = existsSync(repairPath) ? JSON.parse(readFileSync(repairPath, "utf8")) : null;
  assert.notEqual(previousRepair?.restored, true, "This exact batch was already restored");
  const predicate = `customer_id='${customer}' and created_at<'2026-09-10T06:00:00Z'
    and read_at='2026-09-10T08:21:32.370822Z' and is_read`;
  const before = previousRepair?.before ?? query(`select * from public.customer_notifications where ${predicate} order by id;`);
  assert.equal(before.length, 62);
  writeFileSync(repairPath, JSON.stringify({ before, restored: false }), { mode: 0o600 });
  query(`begin; set local lock_timeout='5s';
    do $$ begin
      if (select jsonb_agg(to_jsonb(t) order by id) from public.customer_notifications t where ${predicate}) <>
        (select jsonb_agg(to_jsonb(t) order by id) from jsonb_populate_recordset(null::public.customer_notifications,${json(before)}) t)
      then raise exception 'Concurrent notification change'; end if;
    end $$;
    update public.customer_notifications set is_read=false,read_at=null where ${predicate}; commit;`);
  const after = query(`select * from public.customer_notifications where id=any(array[${before.map(r => `'${r.id}'::uuid`).join(",")}]) order by id;`);
  assert.deepEqual(after, before.map(r => ({ ...r, is_read: false, read_at: null })));
  writeFileSync(repairPath, JSON.stringify({ before, restored: true, count: after.length }), { mode: 0o600 });
  console.log("Exact accidental read batch restored: 62 rows");
}
if (mode === "day-hours") {
  query(`begin; select set_config('app.availability_batch','1',true);
    do $$ begin
      if ${aggregate(tables[0], `groomer_id='${groomer}'`)} <> ${json(saved.configured.rows0)} then raise exception 'Concurrent hours change'; end if;
    end $$;
    update public.groomer_availability_windows set end_time='23:59' where groomer_id='${groomer}'; commit;`);
  [saved.configured] = query(`select ${tables.map((t, i) => `${aggregate(t, `groomer_id='${groomer}'`)} rows${i}`).join(",")};`);
  writeFileSync(path, JSON.stringify(saved), { mode: 0o600 });
  console.log("Named fixture hours now use the app-supported within-day end time");
}
const owned = `select id from public.grooming_requests where customer_id='${customer}' and (service_notes='TESTOPS:${runID}' or service_notes like 'TESTOPS:${runID} %')`;
if (mode === "inspect") {
  const [evidence] = query(`select
    ${aggregate("grooming_requests", `id in (${owned})`)} requests,
    ${aggregate("groomer_offers", `request_id in (${owned})`)} offers,
    ${aggregate("bookings", `request_id in (${owned})`)} bookings,
    ${aggregate("reviews", `booking_id in (select id from public.bookings where request_id in (${owned}))`)} reviews,
    ${aggregate("booking_reschedule_proposals", `booking_id in (select id from public.bookings where request_id in (${owned}))`)} reschedules,
    (select coalesce(jsonb_agg(to_jsonb(o)),'[]'::jsonb) from app_private.request_publish_operations o where request_id in (${owned})) publish_operations,
    ${aggregate("booking_fulfillment_events", `booking_id in (select id from public.bookings where request_id in (${owned}))`)} fulfillment,
    ${aggregate("messages", `conversation_id in (select id from public.conversations where customer_id='${customer}' and groomer_id='${groomer}')`)} messages;
  `);
  writeFileSync(`${directory}/evidence.json`, JSON.stringify(evidence), { mode: 0o600 });
  console.log(JSON.stringify({ runID, requests: evidence.requests.map(r => ({ status: r.status, zone: r.preference_time_zone_identifier })),
    offers: evidence.offers.map(o => ({ status: o.status, start: o.proposed_start, end: o.proposed_end })),
    bookings: evidence.bookings.map(b => ({ status: b.status, phase: b.fulfillment_phase, start: b.scheduled_start, end: b.scheduled_end })),
    fulfillment: evidence.fulfillment.map(e => e.action), reviews: evidence.reviews.length,
    reschedules: evidence.reschedules.map(p => p.status), publishOperations: evidence.publish_operations.length,
    messages: evidence.messages.length }));
}
if (mode === "cleanup") {
  assert.ok(saved.configured, "Inspect an interrupted prepare before restoration");
  query(`begin; set local lock_timeout='5s'; select set_config('app.availability_batch','1',true);
    select pg_advisory_xact_lock(hashtextextended('${groomer}',71071));
    select 1 from public.groomer_profiles where user_id='${groomer}' for update;
    do $$ begin
      ${tables.map((t, i) => `if ${aggregate(t, `groomer_id='${groomer}'`)} <> ${json(saved.configured[`rows${i}`])} then raise exception 'Concurrent settings change'; end if;`).join("\n")}
      if ${aggregate("reviews", `groomer_id='${groomer}' and booking_id not in (select id from public.bookings where request_id in (${owned}))`)} <> ${json(backup.reviews)}
        then raise exception 'Unrelated review change'; end if;
      if (select to_jsonb(p)-array['rating_avg','rating_count','updated_at','eligibility_revision'] from public.groomer_profiles p where user_id='${groomer}')
        <> (${json(backup.profile[0])}-array['rating_avg','rating_count','updated_at','eligibility_revision']) then raise exception 'Concurrent profile change'; end if;
      if not exists(select 1 from public.groomer_offers where request_id in (${owned}))
        or exists(select 1 from public.groomer_offers o where request_id in (${owned})
          and (o.agreement_snapshot->>'groomer_eligibility_revision') is distinct from
            (select eligibility_revision::text from public.groomer_profiles where user_id='${groomer}'))
        then raise exception 'Eligibility changed after fixture quotes'; end if;
      if exists(select 1 from public.bookings where customer_id='${customer}' and groomer_id='${groomer}' and request_id not in (${owned}))
        then raise exception 'Unrelated pair booking'; end if;
      if exists(select 1 from public.messages m join public.conversations c on c.id=m.conversation_id
        where c.customer_id='${customer}' and c.groomer_id='${groomer}'
        and not (m.kind='booking_card' and m.booking_id in (select id from public.bookings where request_id in (${owned})))
        and not (m.kind='text' and m.body like 'TESTOPS:${runID} %')
        and not (m.kind='text' and m.body='Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!'
          and exists(select 1 from public.messages card join public.bookings b on b.id=card.booking_id
            where b.request_id in (${owned}) and card.conversation_id=m.conversation_id and card.sender_id=m.sender_id
              and m.created_at=card.created_at+interval '1 microsecond'))
        and not exists(select 1 from public.booking_fulfillment_events e join public.bookings b on b.id=e.booking_id
          where b.request_id in (${owned}) and e.actor_id=m.sender_id and m.created_at=e.recorded_at+interval '1 microsecond')
        and not exists(select 1 from app_private.booking_reschedule_operations o join public.bookings b on b.id=o.booking_id
          where b.request_id in (${owned}) and o.actor_id=m.sender_id and m.created_at=(o.receipt->>'recorded_at')::timestamptz+interval '1 microsecond'))
        then raise exception 'Unrelated conversation activity'; end if;
    end $$;
    delete from public.customer_notifications where related_request_id in (${owned}) or related_booking_id in (select id from public.bookings where request_id in (${owned}));
    delete from public.groomer_notifications where related_request_id in (${owned}) or related_booking_id in (select id from public.bookings where request_id in (${owned}));
    delete from public.conversations where customer_id='${customer}' and groomer_id='${groomer}';
    select app_private.cleanup_testops_request_address_location(id,'${runID}') from public.grooming_requests where id in (${owned});
    delete from public.grooming_requests where id in (${owned});
    ${tables.map((t, i) => `delete from public.${t} where groomer_id='${groomer}';
      insert into public.${t} select * from jsonb_populate_recordset(null::public.${t},${json(backup[`rows${i}`])});`).join("\n")}
    alter table public.groomer_profiles disable trigger groomer_profiles_set_updated_at;
    alter table public.groomer_profiles disable trigger groomer_profiles_quote_revision;
    update public.groomer_profiles p set rating_avg=o.rating_avg,rating_count=o.rating_count,updated_at=o.updated_at,eligibility_revision=o.eligibility_revision
      from jsonb_populate_record(null::public.groomer_profiles,${json(backup.profile[0])}) o where p.user_id=o.user_id;
    alter table public.groomer_profiles enable trigger groomer_profiles_quote_revision;
    alter table public.groomer_profiles enable trigger groomer_profiles_set_updated_at;
    commit;`);
  assert.deepEqual(captureT374TimingSnapshot(), saved.baseline, "Exact fixture restoration failed");
  writeFileSync(`${directory}/restored.json`, JSON.stringify({ runID, restored: true }), { mode: 0o600 });
  console.log("Exact named fixture restoration: PASS");
}
