import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { parseCustomerProfiles, parseGroomerProfiles } from "./testops-core.mjs";
import { connect, recover, query, saveArtifact, runID, directory, marker } from "./test-t387-booking-fixture.mjs";

assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1");
const role = process.argv[2];
const phase = process.argv[3] ?? "SignIn";
assert.ok(["SignIn", "PublishTwoRequests", "QuoteTwoRequests", "AcceptTwoRequests", "CancelOneRequest", "OpenMessageNotification"].includes(phase));
assert.ok(["customer", "groomer"].includes(role));
if (phase !== "SignIn") recover();
const seed = role === "customer" ? "BTC-003" : "BTG-001";
const profile = (role === "customer" ? parseCustomerProfiles() : parseGroomerProfiles()).find(p => p.seedID === seed);
const device = process.env.TESTOPS_SIMULATOR_UDID ?? "FBD6D82D-12FF-457E-884D-AC35D2A8D0C7";
assert.match(device, /^[A-F0-9-]{36}$/i);
const env = { ...process.env, TEST_RUNNER_TESTOPS_INTERACTIVE_ROLE: role,
  TEST_RUNNER_TESTOPS_REMOTE_WRITE_APPROVED: "1",
  TEST_RUNNER_TESTOPS_RUN_ID: runID,
  [`TEST_RUNNER_TESTOPS_UI_${role.toUpperCase()}_EMAIL`]: profile.email,
  [`TEST_RUNNER_TESTOPS_UI_${role.toUpperCase()}_PASSWORD`]: profile.password };
const requests = () => query(`select id,status,preferred_start,preferred_end from public.grooming_requests
  where customer_id=(select id from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-003')
    and service_notes like 'TESTOPS:${runID} B65 UI-%' order by service_notes;`);
const artifactPhase = phase === "OpenMessageNotification" ? `${phase}-${role}` : phase;
let messageProbe;
if (process.env.TESTOPS_VERIFY_ONLY === "1") {
  const ui = JSON.parse(readFileSync(`${directory}/ui-${artifactPhase}.json`, "utf8"));
  if (phase === "OpenMessageNotification") {
    messageProbe = JSON.parse(readFileSync(`${directory}/ui-message-${role}.json`, "utf8"));
    await verifyMessageNotification();
  } else { await verifyOutcomes(requests()); }
  console.log(`${phase} authenticated outcome verification: PASS; original UI exit code: ${ui.exitCode} (unchanged)`);
  process.exit(0);
}
if (phase === "OpenMessageNotification") {
  const { api, actors } = await connect(["C1", "G1"]);
  const sender = role === "customer" ? "G1" : "C1";
  const recipient = role === "customer" ? "C1" : "G1";
  const [conversation] = await api.restSelect("conversations",
    `select=*&customer_id=eq.${actors.C1.id}&groomer_id=eq.${actors.G1.id}`, actors[recipient].token);
  assert.ok(conversation, "Existing UI booking conversation required");
  const body = `${marker} E17 ${sender} notification`;
  let messages = await api.restSelect("messages",
    `select=*&conversation_id=eq.${conversation.id}&sender_id=eq.${actors[sender].id}&body=eq.${encodeURIComponent(body)}`, actors[sender].token);
  assert.ok(messages.length <= 1, "Message intent must remain unique");
  if (!messages.length) {
    saveArtifact(`ui-message-intent-${role}`, { conversation: conversation.id, sender, body, status: "sending" });
    messages = await api.request("/rest/v1/messages", { method: "POST",
      headers: api.headers(actors[sender].token, { Prefer: "return=representation" }),
      body: JSON.stringify({ conversation_id: conversation.id, sender_id: actors[sender].id, body }) }, "rest");
  }
  const notices = await api.restSelect(`${role}_notifications`,
    `select=*&${role}_id=eq.${actors[recipient].id}&kind=eq.new_message&related_conversation_id=eq.${conversation.id}` +
      `&created_at=gte.${encodeURIComponent(messages[0].created_at)}&order=created_at.desc`, actors[recipient].token);
  assert.equal(notices.length, 1);
  messageProbe = { sender, recipient, conversation: conversation.id, message: messages[0].id, body, notification: notices[0].id };
  saveArtifact(`ui-message-${role}`, messageProbe);
  env.TEST_RUNNER_T388_CHAT_MESSAGE = body;
}
if (!["SignIn", "PublishTwoRequests"].includes(phase)) {
  const existing = requests();
  assert.equal(existing.length, 2, "Exactly two UI-published requests required");
  env.TEST_RUNNER_T387_REQUEST_REFS = existing.map(r => r.id.slice(0, 8).toUpperCase()).join(",");
}
if (phase === "CancelOneRequest") {
  const previous = JSON.parse(readFileSync(`${directory}/ui-outcomes-AcceptTwoRequests.json`, "utf8"));
  assert.ok(previous.customer.length === 2 && previous.customer.every(b => b.status === "confirmed"),
    "A complete pre-cancellation snapshot is required before UI writes");
}
const selector = phase === "SignIn" ? "TestOpsLaunchSmokeTests/testAuthorizedInteractiveSeedSignIn"
  : `TestOpsBookingAdversarialTests/test${phase}`;
const resultDirectory = mkdtempSync(`${tmpdir()}/t387-sign-in-`);
const processHandle = spawn("xcodebuild", ["-project", "ios/Beckon/Beckon.xcodeproj", "-scheme", "Beckon",
  "-destination", `platform=iOS Simulator,id=${device}`, "-resultBundlePath", `${resultDirectory}/result.xcresult`,
  "-parallel-testing-enabled", "NO", "test", `-only-testing:BeckonUITests/${selector}`], { env });
let output = "";
processHandle.stdout.on("data", data => { output += data; });
processHandle.stderr.on("data", data => { output += data; });
const code = await new Promise(resolve => processHandle.on("close", resolve));
try {
  const safe = output.replaceAll(profile.email, "<seed-email>").replaceAll(profile.password, "<seed-password>");
  console.log(safe.split("\n").filter(line => /T387 |Test Case|TEST SUCCEEDED|TEST FAILED|error:|Executed/.test(line)).slice(-40).join("\n"));
  if (phase !== "SignIn") {
    const observed = requests();
    saveArtifact(`ui-${artifactPhase}`, { at: new Date().toISOString(), exitCode: code, requests: observed, summary: safe.split("\n")
      .filter(line => /T387 |Test Case|TEST SUCCEEDED|TEST FAILED|error:|Executed/.test(line)).slice(-40) });
    if (code === 0 || phase === "AcceptTwoRequests") {
      if (phase === "OpenMessageNotification") await verifyMessageNotification();
      else await verifyOutcomes(observed);
    }
  }
  assert.equal(code, 0, `Simulator ${phase} did not pass`);
} finally {
  rmSync(resultDirectory, { recursive: true, force: true });
}

async function verifyMessageNotification() {
  const { api, actors } = await connect(["C1", "G1"]);
  const [notice] = await api.restSelect(`${role}_notifications`, `select=*&id=eq.${messageProbe.notification}`,
    actors[messageProbe.recipient].token);
  assert.equal(notice.related_conversation_id, messageProbe.conversation);
  assert.equal(notice.is_read, true, "The exact message notification must be marked read by the UI route");
  const messages = await api.restSelect("messages", `select=*&id=eq.${messageProbe.message}`, actors[messageProbe.recipient].token);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].body, messageProbe.body);
  assert.equal(messages[0].conversation_id, messageProbe.conversation);
  saveArtifact(`ui-outcomes-${artifactPhase}`, { notification: notice.id, conversation: messageProbe.conversation,
    exactMessageVisibleToRecipient: true, isRead: notice.is_read });
}

async function verifyOutcomes(observed) {
  assert.equal(observed.length, 2);
  assert.notEqual(observed[0].id, observed[1].id);
  assert.notEqual(observed[0].preferred_start, observed[1].preferred_start);
  if (phase === "PublishTwoRequests") {
    assert.ok(observed.every(r => r.status === "open"));
    return;
  }
  const { api, actors } = await connect(["C1", "G1"]);
  const filter = `request_id=in.(${observed.map(r => r.id).join(",")})&order=request_id.asc,id.asc`;
  const offers = await api.restSelect("groomer_offers", `select=*&${filter}`, actors.C1.token);
  const customer = await api.restSelect("bookings", `select=*&${filter}`, actors.C1.token);
  const groomer = await api.restSelect("bookings", `select=*&${filter}`, actors.G1.token);
  const evidence = { phase, offers, customer, groomer };
  saveArtifact(`ui-outcomes-${phase}`, evidence);
  assert.deepEqual(customer, groomer, "Participants must see identical booking state");
  const live = offers.filter(o => ["pending", "accepted_by_customer"].includes(o.status));
  assert.equal(live.length, 2);
  for (const request of observed) {
    const matching = live.filter(o => o.request_id === request.id);
    assert.equal(matching.length, 1);
    const offer = matching[0];
    assert.equal(offer.customer_id, actors.C1.id);
    assert.equal(offer.groomer_id, actors.G1.id);
    assert.equal(Number(offer.price_estimate), 105);
    assert.equal(offer.message, `${marker} B66 UI offer`);
    assert.equal(Date.parse(offer.proposed_start), Date.parse(request.preferred_start));
    assert.ok(Date.parse(offer.proposed_end) <= Date.parse(request.preferred_end));
    if (phase === "QuoteTwoRequests") assert.equal(offer.status, "pending");
  }
  if (phase === "QuoteTwoRequests") {
    assert.equal(customer.length, 0, "Pending UI offers must not reserve bookings");
    return;
  }
  assert.equal(customer.length, 2);
  for (const booking of customer) {
    const offer = live.find(o => o.id === booking.offer_id);
    assert.ok(offer);
    assert.equal(booking.scheduled_start, offer.proposed_start);
    assert.equal(booking.scheduled_end, offer.proposed_end);
    assert.equal(booking.customer_id, actors.C1.id);
    assert.equal(booking.groomer_id, actors.G1.id);
    assert.equal(Number(booking.price_estimate), 105);
    if (phase === "AcceptTwoRequests") assert.equal(booking.status, "confirmed");
  }
  if (phase === "CancelOneRequest") {
    const previous = JSON.parse(readFileSync(`${directory}/ui-outcomes-AcceptTwoRequests.json`, "utf8"));
    assert.equal(customer.find(b => b.request_id === observed[0].id).status, "cancelled_by_customer");
    const other = customer.find(b => b.request_id === observed[1].id);
    assert.equal(other.status, "confirmed");
    assert.deepEqual(other, previous.customer.find(b => b.id === other.id), "Cancelling one booking must leave the other unchanged");
  }
}
