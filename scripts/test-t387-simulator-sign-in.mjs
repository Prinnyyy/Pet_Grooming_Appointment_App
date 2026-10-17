import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { parseCustomerProfiles, parseGroomerProfiles } from "./testops-core.mjs";
import { connect, recover, query, saveArtifact, runID, directory, marker } from "./test-t387-booking-fixture.mjs";
import { validateActorMap, validateClientUIPhase, writeReceipt } from "./test-t392-client-acceptance.mjs";

assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1");
const role = process.argv[2];
const phase = process.argv[3] ?? "SignIn";
const clientAcceptance = runID.startsWith("TESTOPS-T392-");
const discoveryAcceptance = runID.startsWith("TESTOPS-T399-");
const clientTransaction = clientAcceptance && phase !== "SignIn";
if(clientTransaction) validateClientUIPhase(phase,role);
const matchingPhase=["MatchingSortPreferenceAndPaging","CustomerMatchingSortModes","MatchingLivePageChanges","MatchingOfferExpiresDuringConfirmation"].includes(phase);
assert.ok(clientTransaction || matchingPhase || (discoveryAcceptance && ["PrivatePreviewAndFavorites","InvitationAndPoolLifecycle","RecoveryAndExpiredHistory"].includes(phase)) || ["SignIn", "PublishTwoRequests", "QuoteTwoRequests", "AcceptTwoRequests", "CancelOneRequest", "OpenMessageNotification"].includes(phase));
if(matchingPhase) assert.ok(runID.startsWith("TESTOPS-T391-"));
assert.ok(["customer", "groomer"].includes(role));
if (phase !== "SignIn" && !clientAcceptance && !discoveryAcceptance) recover();
let clientInput;
let seed = role === "customer" ? "BTC-003" : matchingPhase ? "BTG-006" : "BTG-001";
if(discoveryAcceptance && role==="groomer") {
  assert.ok(["G1","G2"].includes(process.env.TESTOPS_ACTOR_ALIAS));
  seed=process.env.TESTOPS_ACTOR_ALIAS==="G2"?"BTG-006":"BTG-001";
}
if (clientAcceptance) {
  assert.ok(phase === "SignIn" || clientTransaction,"T392 transaction phases require the data-driven acceptance driver");
  const {actors} = JSON.parse(readFileSync(`${directory}/inventory.json`,"utf8"));
  validateActorMap(actors);
  const selected=actors.find(a=>a.alias===process.env.TESTOPS_ACTOR_ALIAS);
  assert.ok(selected,"Explicit frozen actor alias required");
  assert.equal(selected.role,role,"Actor role mismatch");
  assert.ok(process.env.TESTOPS_SIMULATOR_UDID,"Explicit device required");
  seed=selected.seed;
  if (clientTransaction) {
    const name=process.env.TESTOPS_UI_INPUT;
    assert.match(name??"",/^ui-input-[A-Za-z0-9-]+\.json$/,"Scoped UI input artifact required");
    clientInput=JSON.parse(readFileSync(`${directory}/${name}`));
    assert.equal(clientInput.runID,runID);assert.equal(clientInput.actor,selected.alias);
    assert.equal(clientInput.role,role);assert.ok(Array.isArray(clientInput.rows) && clientInput.rows.length>0);
    assert.equal(typeof clientInput.previewOnly,"boolean");
  }
}
const profile = (role === "customer" ? parseCustomerProfiles() : parseGroomerProfiles()).find(p => p.seedID === seed);
const device = process.env.TESTOPS_SIMULATOR_UDID ?? "FBD6D82D-12FF-457E-884D-AC35D2A8D0C7";
assert.match(device, /^[A-F0-9-]{36}$/i);
const env = { ...process.env, TEST_RUNNER_TESTOPS_INTERACTIVE_ROLE: role,
  TEST_RUNNER_TESTOPS_REMOTE_WRITE_APPROVED: "1",
  TEST_RUNNER_TESTOPS_RUN_ID: runID,
  [`TEST_RUNNER_TESTOPS_UI_${role.toUpperCase()}_EMAIL`]: profile.email,
  [`TEST_RUNNER_TESTOPS_UI_${role.toUpperCase()}_PASSWORD`]: profile.password };
if(discoveryAcceptance) {
  const input=JSON.parse(readFileSync(`${directory}/ui-input-discovery.json`,"utf8"));
  assert.equal(input.runID,runID);
  input.action=process.env.TESTOPS_DISCOVERY_ACTION??null;
  input.role=role;
  input.customerID=JSON.parse(readFileSync(`${directory}/distribution-manifest.json`,"utf8")).actors.C1;
  const presentation=JSON.parse(readFileSync(`${directory}/distribution-manifest.json`,"utf8")).presentation;
  if(presentation&&!presentation.restored) {
    input.presentationGroomerID=presentation.groomerID.toUpperCase();input.presentationName=presentation.businessName;
  }
  if(input.action==="savedPausedAndSwitch") {
    const other=parseCustomerProfiles().find(p=>p.seedID==="BTC-004");
    env.TEST_RUNNER_T399_OTHER_EMAIL=other.email;env.TEST_RUNNER_T399_OTHER_PASSWORD=other.password;
  }
  input.requestID=process.env.TESTOPS_DISCOVERY_REQUEST_ID??null;
  if(phase==="RecoveryAndExpiredHistory") {
    const manifest=JSON.parse(readFileSync(`${directory}/distribution-manifest.json`,"utf8"));
    const rows=query(`select id from public.grooming_requests where customer_id='${manifest.actors.C1}'
      and service_notes='${marker}' and status in ('cancelled','expired') order by created_at desc,id desc offset 4 limit 1;`);
    assert.ok(rows.length===1&&manifest.requests.includes(rows[0].id),"An older owned history entry beyond the first three is required");
    input.olderHistoryRequestID=rows[0].id;
  }
  if(input.action==="legacyRecovery") {
    const manifest=JSON.parse(readFileSync(`${directory}/distribution-manifest.json`,"utf8"));
    assert.equal(input.requestID,manifest.legacy?.receipt?.request_id);
    const result=spawnSync("xcrun",["simctl","get_app_container",device,"com.hellobeckon.beckon","data"],{encoding:"utf8"});
    assert.equal(result.status,0);
    const container=result.stdout.trim();assert.ok(container.includes(`/Devices/${device}/data/Containers/Data/Application/`));
    const folder=`${container}/Library/Application Support/Beckon/PendingPublications`;
    const target=`${folder}/${manifest.actors.C1.toUpperCase()}.json`;
    assert.ok(!existsSync(target),"Preserve an existing pending publication");
    mkdirSync(folder,{recursive:true,mode:0o700});copyFileSync(`${directory}/legacy-pending.json`,target);
  }
  input.expectedSource=process.env.TESTOPS_DISCOVERY_SOURCE??(process.env.TESTOPS_ACTOR_ALIAS==="G1"?"Invited + Request Pool":"Request Pool");
  assert.ok(["Invited + Request Pool","Invited","Request Pool"].includes(input.expectedSource));
  if(input.requestID) {
    assert.match(input.requestID,/^[0-9a-f-]{36}$/i);
    const manifest=JSON.parse(readFileSync(`${directory}/distribution-manifest.json`,"utf8"));
    assert.ok(manifest.requests.includes(input.requestID),"UI may only mutate a manifest-owned request");
    if(input.action==="verifyBooking") {
      const [booking]=query(`select to_char(scheduled_start at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') start
        from public.bookings where request_id='${input.requestID}' and customer_id='${manifest.actors.C1}';`);
      assert.ok(booking,"A committed booking is required for restart verification");input.bookingStart=booking.start;
    }
  }
  env.TEST_RUNNER_T399_UI_INPUT=Buffer.from(JSON.stringify(input)).toString("base64");
}
if(clientInput) {
  env.TEST_RUNNER_T392_UI_INPUT=Buffer.from(JSON.stringify(clientInput)).toString("base64");
  env.TEST_RUNNER_TESTOPS_ACTOR_ALIAS=process.env.TESTOPS_ACTOR_ALIAS;
  if(phase==="SessionSwitch") {
    const {actors}=JSON.parse(readFileSync(`${directory}/inventory.json`));
    const counterpart=actors.find(a=>a.alias===clientInput.switchActor);
    assert.equal(role,"customer");assert.equal(counterpart?.role,"groomer");
    const groomer=parseGroomerProfiles().find(p=>p.seedID===counterpart.seed);
    assert.ok(groomer);
    env.TEST_RUNNER_TESTOPS_UI_GROOMER_EMAIL=groomer.email;
    env.TEST_RUNNER_TESTOPS_UI_GROOMER_PASSWORD=groomer.password;
  }
}
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
if(matchingPhase) {
  const saved=recover();
  const {api,actors}=await connect(["C1","G2"]);
  const ref=id=>id.slice(0,8).toUpperCase();
  if(phase==="MatchingSortPreferenceAndPaging") {
    const pages=[];
    for(const sort of ["distance","newest","fit"]) pages.push(await api.rpc("get_ranked_matched_requests",
      {p_sort:sort,p_limit:50,p_cursor:null},actors.G2.token));
    assert.equal(pages[2].items.length,26);
    env.TEST_RUNNER_T387_REQUEST_REFS=[...pages.map(page=>ref(page.items[0].request.id)),ref(pages[2].items[25].request.id)].join(",");
    saveArtifact(`ui-input-${phase}`,{references:env.TEST_RUNNER_T387_REQUEST_REFS});
  } else if(phase==="CustomerMatchingSortModes") {
    // Keep quote-sort navigation independent of the synthetic history volume.
    const [order]=query(`update public.grooming_requests set created_at=statement_timestamp()
      where id='${saved.requests[0]}' and customer_id='${actors.C1.id}' and service_notes='${marker}' returning id,created_at;`);
    assert.ok(order);
    saveArtifact(`ui-order-${phase}`,{...order,controlledFixtureOrder:true});
    const prices=[];
    for(const sort of ["balanced","distance","earliest","price"]) {
      const page=await api.rpc("get_ranked_customer_offers",{p_request_id:saved.requests[0],p_sort:sort,p_limit:25,p_cursor:null},actors.C1.token);
      prices.push(String(page.items[0].offer.price_estimate));
    }
    env.TEST_RUNNER_T387_REQUEST_REFS=ref(saved.requests[0]);
    env.TEST_RUNNER_T390_SORT_PRICES=prices.join(",");
    saveArtifact(`ui-input-${phase}`,{request:saved.requests[0],prices});
  } else {
    const requestID=saved.matching.httpRequests[phase==="MatchingLivePageChanges"?0:1];
    assert.match(requestID,/^[0-9a-f-]{36}$/);
    const [request]=query(`select r.id,r.terms_revision,
      app_private.evaluate_match_eligibility(r.id,'${actors.G2.id}',statement_timestamp()) eligibility
      from public.grooming_requests r where r.id='${requestID}' and r.customer_id='${actors.C1.id}'
        and r.service_notes='${marker} http-ranking' and not exists
        (select 1 from public.groomer_offers o where o.request_id=r.id);`);
    assert.equal(request?.eligibility.state,"estimated_fit");
    const quote={p_request_id:requestID,p_expected_request_revision:request.terms_revision,
      p_proposed_start:request.eligibility.service_start,p_proposed_end:request.eligibility.service_end,
      p_price_estimate:100,p_message:marker,p_assessment_confirmations:[]};
    env.TEST_RUNNER_T387_REQUEST_REFS=ref(requestID);
    if(phase==="MatchingLivePageChanges") {
      const [review]=query(`select v.id,v.booking_id,c.context_revision from public.reviews v
        join public.bookings b on b.id=v.booking_id join public.grooming_requests r on r.id=b.request_id
        join app_private.booking_review_contexts c on c.booking_id=b.id
        where r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}'
          and r.service_notes='${marker} evidence-db' and v.content='${marker}' order by c.service_at desc limit 1;`);
      assert.ok(review);
      saveArtifact(`ui-input-${phase}`,{request:requestID,review,syntheticServiceContext:true});
      const deleted=query(`delete from public.reviews where id='${review.id}' and booking_id='${review.booking_id}'
        and customer_id='${actors.C1.id}' and content='${marker}' returning id;`);
      assert.equal(deleted.length,1);
      env.TEST_RUNNER_T390_API_KEY=api.publishableKey;
      env.TEST_RUNNER_T390_REVIEW_TOKEN=actors.C1.token;
      env.TEST_RUNNER_T390_REVIEW_BODY=JSON.stringify({p_booking_id:review.booking_id,
        p_expected_context_revision:review.context_revision,p_rating:5,p_content:marker,
        p_pet_fit_outcomes:[{trait_type:"service",trait_value:"nail_trim",outcome:"negative"},
          {trait_type:"size",trait_value:"XS",outcome:"positive"}]});
      env.TEST_RUNNER_T390_QUOTE_TOKEN=actors.G2.token;
      env.TEST_RUNNER_T390_QUOTE_BODY=JSON.stringify(quote);
    } else {
      const expiryID=randomUUID();
      quote.p_request_id=expiryID;
      saveArtifact(`ui-input-${phase}`,{request:expiryID,source:requestID,quote,controlledExpiry:true,status:"preparing"});
      // Published terms are immutable: create a disposable boundary fixture, never relax its guard.
      const [changed]=query(`begin;do $$ declare r public.grooming_requests%rowtype;i integer;begin
        select * into strict r from public.grooming_requests where id='${requestID}'
          and customer_id='${actors.C1.id}' and service_notes='${marker} http-ranking';
        r.id:='${expiryID}';r.terms_revision:=gen_random_uuid();r.status:='open';r.supersedes_request_id:=null;
        r.service_notes:='${marker} expiry-ui';r.created_at:=statement_timestamp();r.updated_at:=r.created_at;
        r.expires_at:=statement_timestamp()+interval '240 seconds';
        insert into public.grooming_requests select r.*;
        for i in 1..12 loop
          perform app_private.drain_match_refresh_queue(250);
          exit when not exists(select 1 from app_private.match_refresh_queue where request_id=r.id);
        end loop;
        if not exists(select 1 from public.request_matches where request_id=r.id and groomer_id='${actors.G2.id}'
          and status in('visible','viewed')) then raise exception 'Expiry fixture was not discovered';end if;
        end $$;
        select terms_revision,expires_at from public.grooming_requests where id='${expiryID}';commit;`);
      assert.ok(changed);
      quote.p_expected_request_revision=changed.terms_revision;
      const receipt=await api.rpc("create_groomer_offer_v3",quote,actors.G2.token);
      env.TEST_RUNNER_T387_REQUEST_REFS=ref(expiryID);
      saveArtifact(`ui-input-${phase}`,{request:expiryID,quote,receipt,expiresAt:changed.expires_at,
        controlledExpiry:true,status:"ready"});
    }
  }
}
if (!clientAcceptance && !matchingPhase && !discoveryAcceptance && !["SignIn", "PublishTwoRequests"].includes(phase)) {
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
  : discoveryAcceptance ? `TestOpsRequestDiscoveryTests/test${phase}`
  : clientTransaction ? `TestOpsMarketplaceAcceptanceTests/test${phase}`
  : `TestOpsBookingAdversarialTests/test${phase}`;
if (clientAcceptance) mkdirSync(directory,{recursive:true,mode:0o700});
const resultDirectory = mkdtempSync(matchingPhase || clientAcceptance || discoveryAcceptance?`${directory}/ui-${phase}-${role}-`:`${tmpdir()}/t387-sign-in-`);
const processHandle = spawn("xcodebuild", ["-project", "ios/Beckon/Beckon.xcodeproj", "-scheme", "Beckon",
  "-destination", `platform=iOS Simulator,id=${device}`, "-resultBundlePath", `${resultDirectory}/result.xcresult`,
  ...(clientAcceptance ? ["-derivedDataPath",`${directory}/DerivedData`,"-test-timeouts-enabled","YES",
    "-maximum-test-execution-time-allowance",clientTransaction ? "600" : "180"] : []),
  ...(discoveryAcceptance ? ["-test-timeouts-enabled","YES","-maximum-test-execution-time-allowance","300"] : []),
  "-parallel-testing-enabled", "NO", process.env.TESTOPS_SKIP_BUILD === "1" && (clientAcceptance || discoveryAcceptance) ? "test-without-building" : "test",
  `-only-testing:BeckonUITests/${selector}`], { env });
let output = "";
const collect = data => {
  output += data;
  // Only non-sensitive progress markers escape the private XCTest output buffer.
  for (const line of data.toString().split("\n")) {
    if (/^Test Case '-\[BeckonUITests\..*\]' (started|passed|failed)|^T39[29] UI /.test(line)) console.log(line);
  }
};
processHandle.stdout.on("data", collect);
processHandle.stderr.on("data", collect);
const code = await new Promise(resolve => processHandle.on("close", resolve));
try {
  let safe = output.replaceAll(profile.email, "<seed-email>").replaceAll(profile.password, "<seed-password>");
  for(const [key,value] of Object.entries(env)) {
    if(/TOKEN|PASSWORD|SECRET|API_KEY|EMAIL/.test(key) && value?.length>5) safe=safe.replaceAll(value,"<redacted>");
  }
  console.log(safe.split("\n").filter(line => /T387 |Test Case|TEST SUCCEEDED|TEST FAILED|error:|Executed/.test(line)).slice(-40).join("\n"));
  if (clientAcceptance) {
    writeReceipt(directory,`${clientTransaction ? `ui-${phase}` : "signin"}-${process.env.TESTOPS_ACTOR_ALIAS}-${Date.now()}`,{
      at:new Date().toISOString(),actor:process.env.TESTOPS_ACTOR_ALIAS,seed,role,device,exitCode:code,
      build_hash:createHash("sha256").update(readFileSync(`${directory}/DerivedData/Build/Products/Debug-iphonesimulator/Beckon.app/Beckon.debug.dylib`)).digest("hex"),
      resultBundle:`${resultDirectory}/result.xcresult`,
      ...(clientInput ? {input:process.env.TESTOPS_UI_INPUT,previewOnly:clientInput.previewOnly,
        sourceIDs:clientInput.rows.map(r=>r.id),events:safe.split("\n").filter(line=>line.startsWith("T392 UI ")),
        scope:"UI execution only; server/cross-client reconciliation required"} : {}),
      summary:safe.split("\n").filter(line=>/Test Case|TEST SUCCEEDED|TEST FAILED|error:|Executed/.test(line)).slice(-40)});
  } else if(matchingPhase || discoveryAcceptance) {
    saveArtifact(`ui-${phase}${discoveryAcceptance&&process.env.TESTOPS_DISCOVERY_ACTION?`-${process.env.TESTOPS_DISCOVERY_ACTION}-${process.env.TESTOPS_ACTOR_ALIAS??role}`:""}`,{at:new Date().toISOString(),exitCode:code,resultBundle:`${resultDirectory}/result.xcresult`,
      events:safe.split("\n").filter(line=>line.startsWith("T399 UI ")),
      summary:safe.split("\n").filter(line=>/Test Case|TEST SUCCEEDED|TEST FAILED|error:|Executed/.test(line)).slice(-40)});
  } else if (phase !== "SignIn") {
    const observed = requests();
    saveArtifact(`ui-${artifactPhase}`, { at: new Date().toISOString(), exitCode: code, requests: observed, summary: safe.split("\n")
      .filter(line => /T387 |Test Case|TEST SUCCEEDED|TEST FAILED|error:|Executed/.test(line)).slice(-40) });
    if (code === 0 || phase === "AcceptTwoRequests") {
      if (phase === "OpenMessageNotification") await verifyMessageNotification();
      else await verifyOutcomes(observed);
    }
  }
  assert.equal(code, 0, `Simulator ${phase} did not pass`);
  if(discoveryAcceptance) {
    assert.ok(!/[1-9]\d* tests? skipped/.test(safe),"Skipped discovery UI tests are not acceptance");
    assert.match(safe,/Executed 1 test/);
  }
} finally {
  if(discoveryAcceptance) {
    const manifest=JSON.parse(readFileSync(`${directory}/distribution-manifest.json`,"utf8"));
    assert.equal(manifest.runID,runID);
    const customer=manifest.actors.C1,pet=manifest.live.pet_id;
    const scoped=`customer_id='${customer}' and service_notes='${marker}' and pet_id='${pet}'`;
    manifest.requests=[...new Set([...manifest.requests,...query(`select id from public.grooming_requests where ${scoped};`).map(r=>r.id)])];
    manifest.draftIDs=[...new Set([...manifest.draftIDs,...query(`select draft_id from app_private.request_discovery_sessions where customer_id='${customer}'
      and normalized_input->>'service_notes'='${marker}' and normalized_input->>'pet_id'='${pet}';`).map(r=>r.draft_id)])];
    manifest.client.favoritesAfter=query(`select * from app_private.customer_groomer_favorites where customer_id='${customer}' and groomer_id='${manifest.actors.G1}';`);
    saveArtifact("distribution-manifest",manifest);
  }
  if(!matchingPhase && !clientAcceptance && !discoveryAcceptance) rmSync(resultDirectory, { recursive: true, force: true });
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
