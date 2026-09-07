import assert from "node:assert/strict";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { isDeepStrictEqual } from "node:util";
import { parseGroomerProfiles, SupabaseREST } from "./testops-core.mjs";
import { verifySaveAcceptance } from "./test-t371-save-acceptance.mjs";

// This is an opt-in, named-fixture integration test, not a general test runner.
assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1", "Remote write approval required");
const expectedProject = "lqmasbuqzvcvtawonjlb";
assert.equal(readFileSync("supabase/.temp/project-ref", "utf8").trim(), expectedProject);
const config = readFileSync("ios/Beckon/Config/Supabase.local.xcconfig", "utf8");
const key = config.match(/^SUPABASE_PUBLISHABLE_KEY\s*=\s*(\S+)/m)?.[1];
assert.ok(key, "Missing client publishable key");
const url = `https://${expectedProject}.supabase.co`;
const account = parseGroomerProfiles().find(row => row.seedID === "BTG-001");
assert.ok(account, "Missing dedicated fixture");
const api = new SupabaseREST(url, key);
const mode = process.argv[2] ?? "race";
assert.ok(["race", "ui-save", "acceptance-race", "acceptance-save-first", "acceptance-accept-first"].includes(mode), "Unsupported validation mode");

function query(sql) {
  const result = spawnSync("supabase", ["db", "query", "--linked", "--output", "json", sql], {
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
    encoding: "utf8",
    maxBuffer: 8 * 1024 * 1024,
  });
  // Do not expose raw database/CLI output or fixture payloads in a failure.
  assert.equal(result.status, 0, "Linked validation/restore query failed; preserve recovery artifact");
  return JSON.parse(result.stdout).rows;
}
const literal = value => `'${JSON.stringify(value).replaceAll("'", "''")}'::jsonb`;
const auth = await api.signIn(account.email, account.password);
const id = auth.user.id;
assert.match(id, /^[0-9a-f-]{36}$/i);
const owned = `groomer_id = '${id}'::uuid`;
const tables = ["groomer_availability_windows", "groomer_booking_preferences", "groomer_time_off_windows"];
const aggregate = table => `(select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.${table} t where ${owned})`;
const backupSQL = `select ${tables.map((table, i) => `${aggregate(table)} as rows${i}`).join(",")}, md5(${aggregate("bookings")}::text) as bookings_hash, md5(${aggregate("request_matches")}::text) as matches_hash;`;
const [backup] = query(backupSQL);
const original = await api.rpc("get_groomer_availability", {}, auth.accessToken);
assert.ok(original.windows.length > 0, "Fixture requires an existing weekly schedule");
const closedWeek = Array.from({ length: 7 }, (_, index) => ({
  weekday: index + 1,
  start_time: "09:00:00",
  end_time: "17:00:00",
  timezone: original.windows[0].timezone,
  ...original.windows.find(window => window.weekday === index + 1),
  is_enabled: false,
}));
const directory = `artifacts/testops/T-371-RACE-${Date.now()}`;
mkdirSync(directory, { recursive: true });
writeFileSync(`${directory}/recovery.json`, JSON.stringify({ id, backup, original }, null, 2));

let winner;
let started = false;
try {
  if (mode.startsWith("acceptance-")) {
    started = true;
    await verifySaveAcceptance({ api, query, groomerID: id, token: auth.accessToken,
      closedWeek, original, order: mode.slice("acceptance-".length),
      onSaved: snapshot => {
        winner = snapshot;
        writeFileSync(`${directory}/winner.json`, JSON.stringify(winner));
      },
    });
  } else if (mode === "ui-save") {
    started = true;
    const result = spawnSync("xcodebuild", [
      "-project", "ios/Beckon/Beckon.xcodeproj", "-scheme", "Beckon",
      "-destination", "platform=iOS Simulator,id=45D452E8-DC6C-4CD4-A747-4D21671E68A6",
      "-only-testing:BeckonUITests/TestOpsLaunchSmokeTests/testSeededGroomerAvailabilitySavePersistsAfterReload", "test",
    ], {
      env: { ...process.env, TEST_RUNNER_TESTOPS_UI_GROOMER_EMAIL: account.email,
        TEST_RUNNER_TESTOPS_UI_GROOMER_PASSWORD: account.password,
        TEST_RUNNER_TESTOPS_AVAILABILITY_WRITE_APPROVED: "1" },
      encoding: "utf8", maxBuffer: 32 * 1024 * 1024,
    });
    let summary = `${result.stdout}\n${result.stderr}`.split("\n")
      .filter(line => /Test Case|Executed|error:|TEST SUCCEEDED|TEST FAILED/.test(line)).join("\n");
    for (const value of [account.email, account.password]) summary = summary.replaceAll(value, "[redacted]");
    console.log(summary);
    const current = await api.rpc("get_groomer_availability", {}, auth.accessToken);
    if (current.revision !== original.revision) {
      const originalMonday = original.windows.find(window => window.weekday === 1);
      const currentMonday = current.windows.find(window => window.weekday === 1);
      assert.equal(currentMonday?.is_enabled, !originalMonday?.is_enabled,
        "Unexpected post-UI state; retain recovery artifact instead of overwriting it");
      winner = current;
      writeFileSync(`${directory}/winner.json`, JSON.stringify(winner));
    }
    assert.equal(result.status, 0, "Availability Save UI test failed");
    assert.ok(winner, "UI success must correspond to a new server revision");
    console.log("PASS: client Save persisted and was confirmed by an independent server read");
  } else {
  const requests = [5, 6].map(max => ({
    p_expected_revision: original.revision,
    p_windows: closedWeek,
    p_preferences: { ...original.preferences, max_appointments_per_day: max },
    p_time_off: original.time_off,
  }));
  started = true;
  // Application requests intentionally overlap; linked CLI operations stay sequential.
  const results = await Promise.all(requests.map(async payload => {
    const response = await fetch(`${url}/rest/v1/rpc/save_groomer_availability`, {
      method: "POST",
      headers: { apikey: key, Authorization: `Bearer ${auth.accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(30000),
    });
    return { status: response.status, body: await response.json() };
  }).map(request => request.catch(error => ({ status: 0, body: { code: error.name } }))));
  const successes = results.filter(result => result.status >= 200 && result.status < 300);
  winner = successes[0]?.body;
  if (winner) writeFileSync(`${directory}/winner.json`, JSON.stringify(winner));
  assert.equal(successes.length, 1, "Expected exactly one successful same-revision writer");
  const loser = results.find(result => result !== successes[0]);
  assert.equal(loser.status, 409, "Losing writer must receive conflict");
  assert.equal(loser.body.code, "PT409");
  assert.equal(loser.body.message, "availability_revision_conflict");
  assert.ok(isDeepStrictEqual(await api.rpc("get_groomer_availability", {}, auth.accessToken), winner));
  assert.ok(winner.windows.every(window => !window.is_enabled));
  console.log("PASS: concurrent same-revision submissions produced one winner and one version conflict");
  }
} finally {
  if (winner) {
    // Restore exact original rows, including IDs/timestamps, only while our winner
    // is still current. Never overwrite a newer external edit during cleanup.
    query(`begin;
      set local statement_timeout = '30s';
      do $restore$ begin
        perform pg_advisory_xact_lock(hashtextextended('${id}', 71071));
        perform set_config('request.jwt.claims', jsonb_build_object('sub','${id}','role','authenticated','is_anonymous',false)::text,true);
        if app_private.get_groomer_availability()->>'revision' <> '${winner.revision}' then
          raise exception 'Restore refused: a newer external edit exists';
        end if;
        perform set_config('app.availability_batch','1',true);
        ${tables.map((table, i) => `delete from public.${table} where ${owned}; insert into public.${table} select * from jsonb_populate_recordset(null::public.${table}, ${literal(backup[`rows${i}`])});`).join("\n")}
      end; $restore$;
      commit;`);
    assert.ok(isDeepStrictEqual(query(backupSQL)[0], backup), "Exact restoration or booking/match preservation failed");
    assert.ok(isDeepStrictEqual(await api.rpc("get_groomer_availability", {}, auth.accessToken), original));
    console.log("PASS: original rows/revision restored; bookings and matches unchanged");
  } else if (started) {
    assert.ok(isDeepStrictEqual(await api.rpc("get_groomer_availability", {}, auth.accessToken), original),
      "Unknown outcome: preserve recovery artifact and reconcile before any further writes");
  }
}
