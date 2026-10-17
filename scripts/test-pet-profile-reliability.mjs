import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { parseCustomerProfiles, parseGroomerProfiles, SupabaseREST, requireRemoteWriteApproval } from "./testops-core.mjs";

requireRemoteWriteApproval();
const project = "lqmasbuqzvcvtawonjlb";
assert.equal(readFileSync("supabase/.temp/project-ref", "utf8").trim(), project);
const key = readFileSync("ios/Beckon/Config/Supabase.local.xcconfig", "utf8")
  .match(/^SUPABASE_PUBLISHABLE_KEY\s*=\s*(\S+)/m)?.[1];
assert.ok(key, "Client configuration missing");
const api = new SupabaseREST(`https://${project}.supabase.co`, key);
const account = parseCustomerProfiles().find(x => x.seedID === "BTC-001");
const other = parseCustomerProfiles().find(x => x.seedID === "BTC-002");
const groomer = parseGroomerProfiles().find(x => x.seedID === "BTG-001");
assert.ok(account && other && groomer, "Named test identities required");
const mode = process.argv[2] ?? "backend";
assert.ok(["backend", "ui-login", "prepare-ui", "cleanup-ui"].includes(mode));
if (mode === "ui-login") {
  const simulator = process.argv[3];
  assert.match(simulator ?? "", /^[0-9A-F-]{36}$/i);
  const result = spawnSync("xcodebuild", ["-project", "ios/Beckon/Beckon.xcodeproj", "-scheme", "Beckon",
    "-destination", `platform=iOS Simulator,id=${simulator}`, "-parallel-testing-enabled", "NO",
    "-only-testing:BeckonUITests/TestOpsLaunchSmokeTests/testAuthorizedInteractiveSeedSignIn", "test"], {
    env: { ...process.env, TEST_RUNNER_TESTOPS_INTERACTIVE_ROLE: "customer",
      TEST_RUNNER_TESTOPS_UI_CUSTOMER_EMAIL: account.email, TEST_RUNNER_TESTOPS_UI_CUSTOMER_PASSWORD: account.password },
    encoding: "utf8", maxBuffer: 32 * 1024 * 1024,
  });
  const log = `${result.stdout}\n${result.stderr}`.replaceAll(account.email, "[redacted]").replaceAll(account.password, "[redacted]");
  writeFileSync(`/tmp/beckon-t406-login-${simulator}.log`, log);
  console.log(log.split("\n").filter(x => /Test Case|TEST SUCCEEDED|TEST FAILED|error:/.test(x)).join("\n"));
  assert.equal(result.status, 0, "Simulator sign-in failed");
  process.exit(0);
}
const session = await api.signIn(account.email, account.password);
const second = await api.signIn(account.email, account.password);
const stranger = await api.signIn(other.email, other.password);
const groomerSession = await api.signIn(groomer.email, groomer.password);
const actor = session.user.id;
assert.match(actor, /^[0-9a-f-]{36}$/i);
let restored;
if (mode === "cleanup-ui") {
  assert.match(process.argv[3] ?? "", /^artifacts\/testops\/T406-[0-9a-f]{8}\/result\.json$/);
  restored = JSON.parse(readFileSync(process.argv[3], "utf8"));
  assert.equal(restored.actor, actor);
  assert.match(restored.run, /^T406-[0-9a-f]{8}$/);
  for (const operation of restored.operations) assert.match(operation, /^[0-9a-f-]{36}$/i);
}
const operations = restored?.operations ?? [randomUUID(), randomUUID(), randomUUID()];
const run = restored?.run ?? `T406-${randomUUID().slice(0, 8)}`;
const directory = `artifacts/testops/${run}`;
mkdirSync(directory, { recursive: true });
const evidence = restored ?? { run, actor, operations, checks: [], restored: false };
const save = () => writeFileSync(`${directory}/result.json`, JSON.stringify(evidence, null, 2));
save();

function query(sql) {
  const result = spawnSync("supabase", ["db", "query", "--linked", "--output", "json", sql], {
    encoding: "utf8", env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" }, maxBuffer: 4 * 1024 * 1024,
  });
  assert.equal(result.status, 0, "Scoped DB assertion/cleanup failed; retain recovery artifact");
  return JSON.parse(result.stdout).rows;
}
const quote = value => `'${JSON.stringify(value).replaceAll("'", "''")}'::jsonb`;
const claims = quote({ sub: actor, role: "authenticated", is_anonymous: false });
const facts = { name: run, species: "Dog", breed: "Unspecified", temperament: "Not Sure", weight_lbs: 23.75, coat_type: null,
  medical_notes: `TESTOPS:${run}`, matting_confirmed: null };
const creation = operation => ({ p_pet_id: null, p_facts: facts, p_coat_confirmed: false,
  p_operation_id: operation, p_expected_revision: null });
const rpc = (input, auth = session) => api.rpc("save_my_pet_v3", input, auth.accessToken);
const reject = async (input, code, auth = session) => assert.rejects(() => rpc(input, auth), error => error.code === code);
const check = name => { evidence.checks.push(name); save(); console.log(`PASS: ${name}`); };
const opSQL = operations.map(x => `'${x}'::uuid`).join(",");
const scope = `customer_id='${actor}'::uuid and operation_id in (${opSQL})`;
const baseline = evidence.baseline ?? query(`select md5(coalesce(jsonb_agg(to_jsonb(r) order by r.id)::text,'[]')) hash
  from public.grooming_requests r where customer_id='${actor}'::uuid;`)[0].hash;
evidence.baseline = baseline; save();
const bookingBaseline = evidence.bookingBaseline ?? query(`select md5(coalesce(jsonb_agg(to_jsonb(b) order by b.id)::text,'[]')) hash
  from public.bookings b where customer_id='${actor}'::uuid;`)[0].hash;
evidence.bookingBaseline = bookingBaseline; save();
if (mode === "prepare-ui") {
  const result = await rpc(creation(operations[0]));
  evidence.uiPetID = result.pet_id;
  evidence.uiNewPetName = `${run}U`;
  save();
  console.log(JSON.stringify({ file: `${directory}/result.json`, petName: run, newPetName: evidence.uiNewPetName }));
  process.exit(0);
}
if (mode === "cleanup-ui") {
  const uiRows = query(`select o.operation_id from app_private.pet_create_operations o join public.pets p on p.id=o.pet_id
    where o.customer_id='${actor}' and p.customer_id='${actor}' and p.name='${run}U';`);
  assert.ok(uiRows.length <= 1, "Unexpected duplicate UI creation: preserve evidence");
  for (const row of uiRows) {
    assert.match(row.operation_id, /^[0-9a-f-]{36}$/i);
    if (!operations.includes(row.operation_id)) operations.push(row.operation_id);
  }
  evidence.operations = operations; save();
  cleanup();
  process.exit(0);
}
try {
  const created = await rpc(creation(operations[0]));
  assert.equal(created.state, "active");
  const replay = await rpc(creation(operations[0]));
  assert.equal(replay.pet_id, created.pet_id);
  assert.equal(replay.replayed, true);
  const race = await Promise.all([rpc(creation(operations[1])), rpc(creation(operations[1]), second)]);
  assert.equal(race[0].pet_id, race[1].pet_id);
  assert.deepEqual(race.map(x => x.replayed).sort(), [false, true]);
  assert.notEqual(created.pet_id, race[0].pet_id);
  assert.equal(query(`select count(*)::int n from app_private.pet_create_operations where ${scope}`)[0].n, 2);
  check("A01/A02: sequential and concurrent create replay, distinct intents remain distinct");
  await reject({ ...creation(operations[0]), p_facts: { ...facts, name: "Changed" } }, "PT409");
  check("A02: operation payload cannot change");
  const update = { p_pet_id: created.pet_id, p_facts: { ...facts, medical_notes: "First writer" },
    p_coat_confirmed: false, p_operation_id: null, p_expected_revision: created.pet.revision };
  const edits = await Promise.allSettled([rpc(update), rpc({ ...update, p_facts: { ...facts, weight_lbs: 45 } }, second)]);
  assert.equal(edits.filter(x => x.status === "fulfilled").length, 1);
  const loser = edits.find(x => x.status === "rejected");
  assert.equal(loser.reason.code, "PT409");
  assert.equal(loser.reason.serverMessage, "pet_revision_conflict");
  const winner = edits.find(x => x.status === "fulfilled").value;
  const rows = await api.restSelect("pets", `id=eq.${created.pet_id}&select=*`, session.accessToken);
  assert.deepEqual(rows[0], winner.pet);
  check("A05: independent sessions admit one edit and reject the stale edit");
  const afterEdit = await rpc(creation(operations[0]));
  assert.equal(afterEdit.pet.revision, winner.pet.revision);
  assert.equal(afterEdit.result_revision, created.result_revision);
  const editedSource = query(`select app_private.discovery_pet_source('${actor}','${created.pet_id}') source;`)[0].source;
  assert.equal(Number(editedSource.pet_snapshot.weight_lbs), winner.pet.weight_lbs);
  assert.equal(editedSource.pet_snapshot.medical_notes, winner.pet.medical_notes);
  check("A12: new discovery reads the winning edit, not the creation receipt snapshot");
  const deletion = await api.request(`/rest/v1/pets?id=eq.${created.pet_id}`, {
    method: "PATCH", headers: api.headers(session.accessToken, { Prefer: "return=representation" }),
    body: JSON.stringify({ is_active: false, deleted_at: new Date().toISOString() }),
  }, "rest");
  assert.notEqual(deletion[0].revision, winner.pet.revision);
  const deletedReplay = await rpc(creation(operations[0]));
  assert.equal(deletedReplay.state, "unavailable");
  assert.equal(deletedReplay.pet, null);
  await reject({ ...update, p_expected_revision: deletion[0].revision }, "PT404");
  check("A08: replay reads current facts and never revives a deleted target");
  await reject({ ...update, p_pet_id: race[0].pet_id, p_expected_revision: race[0].pet.revision }, "PT404", stranger);
  await reject(creation(operations[2]), "42501", groomerSession);
  await assert.rejects(() => api.rpc("save_my_pet_v2", {
    p_pet_id: null, p_facts: facts, p_coat_confirmed: false,
  }, session.accessToken), error => error.serverMessage === "pet_client_update_required");
  for (const [method, body] of [["POST", facts], ["PATCH", { name: "Bypass" }]]) {
    await assert.rejects(() => api.request(`/rest/v1/pets?id=eq.${race[0].pet_id}`, {
      method, headers: api.headers(session.accessToken), body: JSON.stringify(body),
    }, "rest"), error => error.code === "42501");
  }
  query(`begin;
    select set_config('request.jwt.claims',${claims}::text,true);
    insert into public.account_deletion_requests(user_id,role,anonymized_at)
      values('${actor}','customer',statement_timestamp()) on conflict(user_id) do update set anonymized_at=excluded.anonymized_at;
    do $$ begin
      if exists(select 1 from app_private.pet_create_operations where ${scope}) then raise exception 'receipt_redaction_failed';end if;
      begin perform public.save_my_pet_v3(null,${quote(facts)},false,'${operations[0]}',null);
        raise exception 'redacted_actor_was_allowed';
      exception when insufficient_privilege then null;end;
    end $$; rollback;`);
  query(`begin; select set_config('request.jwt.claims',${quote({ sub: actor, role: "authenticated", is_anonymous: true })}::text,true);
    do $$ begin begin perform public.save_my_pet_v3(null,${quote(facts)},false,'${operations[2]}',null);
      raise exception 'anonymous_was_allowed'; exception when insufficient_privilege then null;end;end $$; rollback;`);
  check("A09: owner, role, anonymous, redacted actor and legacy write denials; rollback redaction");
  const activePet = race[0].pet;
  assert.equal(activePet.weight_lbs, 23.75);
  assert.equal(activePet.coat_type, null);
  assert.equal(activePet.coat_type_source, "unknown");
  const source = query(`select app_private.discovery_pet_source('${actor}','${activePet.id}') source;`)[0].source;
  assert.ok(JSON.stringify(source).includes("23.75"));
  check("A12: discovery source preserves the current exact weight and unknown coat");
} finally {
  cleanup();
}

function cleanup() {
  const allOps = operations.map(x => `'${x}'::uuid`).join(",");
  const cleanupScope = `customer_id='${actor}'::uuid and operation_id in (${allOps})`;
  // Only exact operations allocated above and owned, tagged pets are removed.
  query(`begin;
    create temporary table t406_cleanup_ids on commit drop as
      select pet_id from app_private.pet_create_operations where ${cleanupScope};
    do $$ begin if exists(select 1 from public.pets p join t406_cleanup_ids t on t.pet_id=p.id
      where p.customer_id<>'${actor}'::uuid or p.name not in ('${run}','${run}U')) then raise exception 'cleanup_scope_changed';end if;end $$;
    delete from app_private.pet_create_operations where ${cleanupScope};
    delete from public.pets p using t406_cleanup_ids t where p.id=t.pet_id and p.customer_id='${actor}';
    commit;`);
  assert.equal(query(`select count(*)::int n from app_private.pet_create_operations where ${cleanupScope}`)[0].n, 0);
  assert.equal(query(`select count(*)::int n from public.pets where customer_id='${actor}' and name in ('${run}','${run}U')`)[0].n, 0);
  assert.equal(query(`select md5(coalesce(jsonb_agg(to_jsonb(r) order by r.id)::text,'[]')) hash
    from public.grooming_requests r where customer_id='${actor}'::uuid;`)[0].hash, baseline);
  assert.equal(query(`select md5(coalesce(jsonb_agg(to_jsonb(b) order by b.id)::text,'[]')) hash
    from public.bookings b where customer_id='${actor}'::uuid;`)[0].hash, bookingBaseline);
  evidence.restored = true; save();
  console.log(`RESTORED: ${directory}/result.json`);
}
