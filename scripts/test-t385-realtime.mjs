import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { parseEnv } from "node:util";
import { setTimeout as delay } from "node:timers/promises";
import { parseCustomerProfiles, parseGroomerProfiles, SupabaseREST } from "./testops-core.mjs";

assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1");
const directory = "artifacts/testops/TESTOPS-T385-SIM-20260910-A";
const fixture = JSON.parse(readFileSync(`${directory}/recovery.json`, "utf8"));
const evidence = JSON.parse(readFileSync(`${directory}/evidence.json`, "utf8"));
const conversationID = evidence.messages[0]?.conversation_id;
assert.match(conversationID, /^[0-9a-f-]{36}$/i);
const credentials = parseEnv(readFileSync("supabase_environment_variables", "utf8"));
assert.equal(credentials.SUPABASE_URL, "https://lqmasbuqzvcvtawonjlb.supabase.co");
const api = new SupabaseREST(credentials.SUPABASE_URL, credentials.SUPABASE_PUBLISHABLE_KEY);
const body = `TESTOPS:${fixture.runID} Realtime isolation probe.`;
const sockets = [];
const subjects = [
  ["customer", parseCustomerProfiles().find(p => p.seedID === "BTC-001")],
  ["groomer", parseGroomerProfiles().find(p => p.seedID === "BTG-001")],
  ["nonparticipant", parseCustomerProfiles().find(p => p.seedID === "BTC-002")],
];
try {
  for (const [role, account] of subjects) {
    assert.ok(account);
    const auth = await api.signIn(account.email, account.password);
    if (role !== "nonparticipant") assert.equal(auth.user.id, fixture[role]);
    const state = { role, auth, joined: false, received: [], errors: 0 };
    const url = new URL(credentials.SUPABASE_URL.replace("https:", "wss:") + "/realtime/v1/websocket");
    url.searchParams.set("apikey", credentials.SUPABASE_PUBLISHABLE_KEY);
    url.searchParams.set("vsn", "2.0.0");
    state.socket = new WebSocket(url);
    sockets.push(state);
    state.socket.addEventListener("open", () => state.socket.send(JSON.stringify([
      "1", "1", `realtime:t385-${role}`, "phx_join", {
        config: { postgres_changes: [{ event: "INSERT", schema: "public", table: "messages", filter: `conversation_id=eq.${conversationID}` }] },
        access_token: auth.accessToken,
      },
    ])));
    state.socket.addEventListener("error", () => { state.errors++; });
    state.socket.addEventListener("message", event => {
      const [, ref, , name, payload] = JSON.parse(event.data);
      if (name === "phx_reply" && ref === "1") {
        state.joined = payload.status === "ok" && payload.response?.postgres_changes?.length === 1;
        if (!state.joined) state.errors++;
      }
      if (name === "postgres_changes" && payload.data?.record?.body === body) state.received.push(payload.data.record.id);
    });
    const deadline = Date.now() + 15000;
    while (!state.joined && !state.errors && Date.now() < deadline) await delay(50);
    assert.ok(state.joined && !state.errors, `${role} subscription must be established; network failure is not isolation evidence`);
  }
  const outsiderRows = await api.restSelect("messages", `select=id&conversation_id=eq.${conversationID}`, sockets[2].auth.accessToken);
  assert.equal(outsiderRows.length, 0);
  const [sent] = await api.request("/rest/v1/messages", {
    method: "POST",
    headers: api.headers(sockets[0].auth.accessToken, { Prefer: "return=representation" }),
    body: JSON.stringify({ conversation_id: conversationID, sender_id: fixture.customer, body }),
  }, "rest");
  const deadline = Date.now() + 12000;
  while (sockets.slice(0, 2).some(s => !s.received.includes(sent.id)) && Date.now() < deadline) await delay(50);
  await delay(2000);
  for (const subject of sockets.slice(0, 2)) assert.deepEqual(subject.received, [sent.id], `${subject.role} must receive exactly this committed message`);
  assert.deepEqual(sockets[2].received, [], "Unrelated authenticated account received a private message");
  assert.ok(sockets.every(s => s.errors === 0));
  const result = { customerEvents: 1, groomerEvents: 1, nonparticipantEvents: 0, nonparticipantRows: 0 };
  writeFileSync(`${directory}/realtime-isolation.json`, JSON.stringify(result), { mode: 0o600 });
  console.log(JSON.stringify(result));
} finally {
  for (const { socket } of sockets) socket.close();
}
