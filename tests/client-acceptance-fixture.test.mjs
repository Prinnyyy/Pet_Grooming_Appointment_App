import assert from "node:assert/strict";
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { spawnSync } from "node:child_process";

const runner = await import("../scripts/test-t392-client-acceptance.mjs").catch(error => {
  if (error.code !== "ERR_MODULE_NOT_FOUND") throw error;
  return {};
});
const call = (name, ...args) => {
  assert.equal(typeof runner[name], "function", `Missing ${name}`);
  return runner[name](...args);
};
const source = JSON.parse(readFileSync("tests/fixtures/matching-marketplace-la-synthetic.json"));
const recipe = () => JSON.parse(readFileSync("tests/fixtures/matching-client-acceptance.json"));
const options = { anchor: "2026-09-15T20:00:00Z", seed: 392 };
const compile = () => call("compileClientFixture", source, recipe(), options);

test("client UI phases reject unknown roles and allow bilateral booking actions", () => {
  for (const role of ["customer", "groomer"]) {
    assert.equal(call("validateClientUIPhase", "BookingActions", role), "BookingActions");
    assert.equal(call("validateClientUIPhase", "RankingBrowse", role), "RankingBrowse");
  }
  assert.equal(call("validateClientUIPhase", "AcceptanceBatch", "customer"), "AcceptanceBatch");
  assert.equal(call("validateClientUIPhase", "PetUpdate", "customer"), "PetUpdate");
  assert.equal(call("validateClientUIPhase", "SessionSwitch", "customer"), "SessionSwitch");
  assert.equal(call("validateClientUIPhase", "RequestClosure", "customer"), "RequestClosure");
  assert.throws(() => call("validateClientUIPhase", "RequestClosure", "groomer"), /role/);
  assert.throws(() => call("validateClientUIPhase", "SessionSwitch", "groomer"), /role/);
  assert.throws(() => call("validateClientUIPhase", "PetUpdate", "groomer"), /role/);
  assert.throws(() => call("validateClientUIPhase", "AcceptanceBatch", "groomer"), /role/);
  assert.throws(() => call("validateClientUIPhase", "BookingActions", "admin"), /role/);
  assert.throws(() => call("validateClientUIPhase", "Unknown", "customer"), /phase/);
});

test("setup guards can target changed tables without dropping row locks or accepting arbitrary tables", () => {
  const db = {sqlIDs: () => "'00000000-0000-4000-8000-000000000001'::uuid", sqlJSON: JSON.stringify};
  const actors = [{id:"00000000-0000-4000-8000-000000000001",role:"groomer"}];
  const sql = call("guardSetupSQL", db, actors, {groomer_profiles:[]}, ["groomer_profiles"]);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /public\.groomer_profiles.*for update/);
  assert.match(sql, /Concurrent groomer_profiles change/);
  assert.doesNotMatch(sql, /groomer_notifications/);
  assert.throws(() => call("guardSetupSQL", db, actors, {}, []));
  assert.throws(() => call("guardSetupSQL", db, actors, {}, ["auth.users"]));
});

test("fixture freezes source, 60 cases and exact history without source mutation", () => {
  assert.equal(typeof runner.compileClientFixture, "function");
  const before = JSON.stringify(source), data = compile();
  assert.equal(JSON.stringify(source), before);
  assert.deepEqual(data, compile());
  assert.deepEqual(call("validateClientFixture", data).counts,
    { customers: 22, groomers: 12, pets: 24, requests: 24, quotes: 57, negatives: 8, histories: 1228, stars: 5791, cases: 60 });
  assert.ok(data.requests.every(r => Date.parse(r.window[0]) > Date.parse(options.anchor)));
});
test("history respects species, independent customers, service ages, occupancy and rating context", () => {
  const data = compile();
  for (const spec of recipe().history) {
    const rows = data.history.filter(r => r.groomer === spec.groomer);
    assert.equal(rows.reduce((sum, r) => sum + r.rating, 0), spec.sum);
    assert.equal(rows.filter(r => r.species === "cat").length, spec.cat);
    if (!rows.length) continue;
    const customers = new Set(rows.map(r => r.customer));
    assert.ok(customers.size >= (spec.groomer === "G12" ? 3 : 6));
    for (const [low, high] of [[0,7],[7,90],[90,360],[360,731]]) {
      assert.ok(rows.some(r => r.age_days > low && r.age_days <= high), `${spec.groomer} missing age band`);
    }
  }
  assert.equal(data.history.filter(r => r.groomer === "G06" && r.customer === "C01").length, 100);
  assert.equal(new Set(data.history.filter(r => r.groomer === "G12").map(r => r.customer)).size, 3);
  assert.ok(data.history.some(r => r.rating === 5 && Object.values(r.answers).includes("negative")));
  assert.ok(data.history.some(r => r.service === "custom_request" && !Object.keys(r.answers).length));
  assert.ok(data.history.some(r => r.service !== "custom_request" && !Object.keys(r.answers).length));
});
test("source drift, duplicate review, forged key, overlap and future history fail closed", () => {
  const changed = structuredClone(source); changed.requests[0].offers[0].price_estimate_cents++;
  assert.throws(() => call("compileClientFixture", changed, recipe(), options), /source.*hash/i);
  for (const mutate of [
    d => d.history[1].booking_id = d.history[0].booking_id,
    d => d.history[0].answers["service:forged"] = "positive",
    d => d.history[1] = { ...d.history[0], id: d.history[1].id, booking_id: d.history[1].booking_id },
    d => d.history[0].service_at = "2099-01-01T12:00:00Z",
  ]) {
    const data = compile(); mutate(data);
    assert.throws(() => call("validateClientFixture", data));
  }
});
test("historical professional keys follow pet facts, not a self-declared allowlist", () => {
  const data = compile();
  const senior = data.history.filter(r => r.groomer === "G03" && r.allowed_keys.includes("care:senior"));
  assert.ok(senior.length >= 40, "G03 needs genuine senior service contexts");
  assert.ok(data.history.filter(r => r.groomer === "G04" && r.allowed_keys.includes("coat:double_coat")
    && r.pet_snapshot.weight_lbs >= 60).length >= 70, "G04 needs large double-coat contexts");
  assert.ok(data.history.some(r => r.allowed_keys.includes("care:puppy")));
  assert.ok(data.history.some(r => r.allowed_keys.includes("care:anxious")));
  assert.ok(data.history.some(r => r.allowed_keys.includes("care:matted")));
  assert.ok(data.history.some(r => r.pet_snapshot.weight_lbs === null && !r.allowed_keys.some(k => k.startsWith("size:"))));
  for (const mutate of [
    r => { r.allowed_keys.push("service:forged"); r.answers["service:forged"] = "positive"; },
    r => { r.pet_snapshot.weight_lbs = 120; },
    r => { r.pet_snapshot.species = "Cat"; },
  ]) {
    const changed = structuredClone(data); mutate(changed.history[0]);
    assert.throws(() => call("validateClientFixture", changed));
  }
});
test("CLI validates all modes, run IDs, execution approval and phases before credentials", () => {
  const parse = (args, env = {}) => call("parseClientArguments", args, env);
  assert.equal(parse(["plan", "--run-id", "TESTOPS-T392-20260915-A"]).mode, "plan");
  for (const args of [[], ["oops"], ["prepare", "--run-id", "TESTOPS-T392-20260915-A"],
    ["plan", "--run-id", "../bad"], ["run", "--run-id", "TESTOPS-T392-A", "--phase", "unknown", "--execute"]]) {
    assert.throws(() => parse(args, {TESTOPS_REMOTE_WRITE_APPROVED:"1"}));
  }
  assert.throws(() => parse(["prepare", "--run-id", "TESTOPS-T392-A", "--execute"]), /authorization/i);
  assert.throws(() => call("validateActorMap", [{alias:"C01", role:"groomer", seed:"BTG-001", id:"00000000-0000-4000-8000-000000000001"}]), /role/i);
});
test("groomer readback routes only an actor's quoted sources and frozen negative references", () => {
  const data = compile(),runID="TESTOPS-T392-READBACK";
  const requestMap=Object.fromEntries(data.requests.map((r,i)=>[r.id,{id:`00000000-0000-4000-8000-${String(i+1).padStart(12,"0")}`} ]));
  const input=call("clientUIInput",data,{runID,actor:"G12",phase:"GroomerRequestReadback",
    ids:["R03","R09","R13"],requestMap,negativeIDs:["X08"]});
  assert.equal(input.role,"groomer");
  assert.deepEqual(input.rows.map(r=>r.id),["R03","R09","R13"]);
  assert.ok(input.rows.every(r=>r.quotes.length===1));
  assert.equal(input.rows[1].quotes[0].id,"R09-A");
  assert.deepEqual(input.forbiddenReferences,[requestMap.R21.id.slice(0,8).toUpperCase()]);
  for(const change of [{actor:"G01"},{negativeIDs:["X07"]},{ids:["R24"]},{negativeIDs:["X08","X08"]}]) {
    assert.throws(()=>call("clientUIInput",data,{runID,actor:"G12",phase:"GroomerRequestReadback",
      ids:["R03"],requestMap,negativeIDs:["X08"],...change}));
  }
  assert.throws(()=>call("clientUIInput",data,{runID,actor:"C02",phase:"CustomerRequestReadback",
    ids:["R03"],requestMap,negativeIDs:["X08"]}));
});
test("batch reconciliation never retries partial or changed input and receipts cannot overwrite", () => {
  const batch = { ids:["a","b"], input_hash:"h" };
  assert.equal(call("reconcileBatch", batch, []), "not_committed");
  assert.equal(call("reconcileBatch", batch, [{id:"a",input_hash:"h"},{id:"b",input_hash:"h"}]), "committed");
  assert.throws(() => call("reconcileBatch", batch, [{id:"a",input_hash:"h"}]), /partial/i);
  assert.throws(() => call("reconcileBatch", batch, [{id:"a",input_hash:"changed"},{id:"b",input_hash:"h"}]), /hash/i);
  const directory = mkdtempSync(join(tmpdir(), "t392-"));
  try {
    call("writeReceipt", directory, "one", {status:"failed"});
    assert.throws(() => call("writeReceipt", directory, "one", {status:"passed"}), /exist/i);
    assert.throws(() => call("writeReceipt", directory, "../escape", {}));
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
test("T392 reuses matching gates but cannot disable the adopted ranking algorithm", () => {
  const result=spawnSync(process.execPath,["--input-type=module","-e",`
    import assert from 'node:assert/strict';
    import {isMatchingRun,rankingValidationPlan} from './scripts/test-t387-booking-fixture.mjs';
    assert.equal(isMatchingRun(process.env.TESTOPS_RUN_ID),true);
    assert.throws(()=>rankingValidationPlan({enabled:false,validation_actor_ids:[]},['00000000-0000-4000-8000-000000000001']),/enabled/);
  `],{env:{...process.env,TESTOPS_RUN_ID:"TESTOPS-T392-GATES"},encoding:"utf8"});
  assert.equal(result.status,0,result.stderr);
});
test("seed SQL groups JSON path extraction before key subtraction", () => {
  const code=readFileSync("scripts/test-t392-client-acceptance.mjs","utf8");
  assert.doesNotMatch(code,/->'pet'-'id'/);
  assert.match(code,/\(d->'request'->'pet'\)-'id'/);
});
test("UI payload resolves explicit source actors and fails before credentials on phase or source drift", () => {
  const fixture=compile();
  const publication=call("clientUIInput",fixture,{runID:"TESTOPS-T392-TEST",actor:"C01",phase:"PublicationBatch",ids:["R01"],previewOnly:true});
  assert.equal(publication.rows[0].petWeight,12);
  assert.equal(publication.rows[0].serviceType,"full_groom");
  assert.equal(publication.previewOnly,true);
  assert.throws(()=>call("clientUIInput",fixture,{runID:"TESTOPS-T392-TEST",actor:"G01",phase:"PublicationBatch",ids:["R01"]}),/actor/);
  assert.throws(()=>call("clientUIInput",fixture,{runID:"TESTOPS-T392-TEST",actor:"C01",phase:"unknown",ids:["R01"]}),/phase/);
  assert.throws(()=>call("clientUIInput",fixture,{runID:"TESTOPS-T392-TEST",actor:"G01",phase:"QuoteBatch",ids:["R01-A"]}),/request.*mapping/i);
  const quote=call("clientUIInput",fixture,{runID:"TESTOPS-T392-TEST",actor:"G01",phase:"QuoteBatch",ids:["R01-A"],
    requestMap:{R01:{id:"00000000-0000-4000-8000-000000000001"}}});
  assert.equal(quote.rows[0].price,"115.00");
  assert.equal(quote.rows[0].durationMinutes,90);
  assert.equal(quote.rows[0].reference,"00000000");
});
test("setup refuses an irreversible legacy-service deactivation before any write", () => {
  assert.throws(()=>call("assertReversibleSetupServices",[{id:"legacy",is_active:true,accepted_species:null}]),/legacy.*restor/i);
  assert.throws(()=>call("assertReversibleSetupServices",[{id:"legacy",is_active:true,accepted_species:[]}]),/legacy.*restor/i);
  assert.doesNotThrow(()=>call("assertReversibleSetupServices",[
    {id:"inactive",is_active:false,accepted_species:null},{id:"known",is_active:true,accepted_species:["dog"]}]));
});
test("customer readback uses frozen request identity, source quote terms and historical ratings", () => {
  const fixture=compile(),options={runID:"TESTOPS-T392-TEST",actor:"C01",phase:"CustomerRequestReadback",
    ids:["R01"],quoteIDs:["R01-A"],requestMap:{R01:{id:"12345678-0000-4000-8000-000000000001"}}};
  const result=call("clientUIInput",fixture,options);
  assert.equal(result.phase,"CustomerRequestReadback");
  assert.equal(result.role,"customer");
  assert.equal(result.rows[0].reference,"12345678");
  assert.equal(result.rows[0].serviceType,"full_groom");
  assert.equal(result.rows[0].species,"dog");
  assert.equal(result.rows[0].locationMode,fixture.requests[0].location_mode);
  assert.equal(result.rows[0].notes,`TESTOPS:${options.runID} R01\n${fixture.requests[0].customer_text}`);
  assert.deepEqual(result.rows[0].window,fixture.requests[0].window);
  assert.equal(result.rows[0].quotes.length,1);
  assert.equal(result.rows[0].quotes[0].price,"$115.00");
  assert.equal(result.rows[0].quotes[0].ratingCount,68);
  assert.equal(result.rows[0].quotes[0].ratingSum,333);
  assert.equal(result.rows[0].quotes[0].groomerName,fixture.groomers.find(g=>g.id==="G01").alias);
  assert.throws(()=>call("clientUIInput",fixture,{...options,actor:"C02"}),/actor/);
  assert.throws(()=>call("clientUIInput",fixture,{...options,requestMap:{}}),/mapping/i);
  assert.throws(()=>call("clientUIInput",fixture,{...options,quoteIDs:["R02-A"]}),/quote/i);
});
test("acceptance input binds the customer to the selected source groomer and request", () => {
  const fixture=compile(),options={runID:"TESTOPS-T392-TEST",actor:"C01",phase:"AcceptanceBatch",
    ids:["R01-B"],requestMap:{R01:{id:"12345678-0000-4000-8000-000000000001"}}};
  const result=call("clientUIInput",fixture,options);
  assert.equal(result.role,"customer");
  assert.equal(result.phase,"AcceptanceBatch");
  assert.equal(result.rows[0].reference,"12345678");
  assert.equal(result.rows[0].groomerName,fixture.groomers.find(g=>g.id==="G02").alias);
  assert.throws(()=>call("clientUIInput",fixture,{...options,actor:"C02"}),/actor/);
  assert.throws(()=>call("clientUIInput",fixture,{...options,actor:"G02"}),/actor/);
});
test("quote readback includes independent contextual evidence and proposed times", () => {
  const fixture=compile(),options={runID:"TESTOPS-T392-TEST",actor:"C02",phase:"CustomerRequestReadback",
    ids:["R03"],quoteIDs:["R03-A"],requestMap:{R03:{id:"12345678-0000-4000-8000-000000000001"}}};
  const quote=call("clientUIInput",fixture,options).rows[0].quotes[0];
  assert.equal(quote.evidenceSummary,"13 related reviews from 10 customers");
  assert.ok(quote.evidenceLines.includes("Senior: 9 positive, 1 negative, 6 unreported"));
  assert.ok(quote.evidenceLines.includes("S: 0 positive, 0 negative, 0 unreported"));
  assert.equal(quote.start,fixture.requests[2].offers[0].start);
  assert.equal(Date.parse(quote.end)-Date.parse(quote.start),120*60000);
  const changed=structuredClone(fixture);
  changed.history.filter(h=>h.groomer==="G03" && h.service!=="full_groom").forEach(h=>{h.answers={"care:senior":"negative"};});
  const unaffected=call("clientUIInput",changed,options).rows[0].quotes[0];
  assert.equal(unaffected.evidenceSummary,quote.evidenceSummary);
  assert.deepEqual(unaffected.evidenceLines,quote.evidenceLines);
  const cold=call("clientUIInput",fixture,{...options,actor:"C01",ids:["R01"],quoteIDs:["R01-C"],
    requestMap:{R01:options.requestMap.R03}}).rows[0].quotes[0];
  assert.equal(cold.evidenceSummary,"No verified related feedback yet");
  assert.deepEqual(cold.evidenceLines,[]);
});
test("transaction branches preserve source facts and isolate dated competition variants", () => {
  const fixture=compile(),before=JSON.stringify(fixture),options={caseID:"C04",variant:2,
    quoteIDs:["R12-A","R17-A"],shiftDays:7,minuteOffsets:{"R17-A":-1}};
  const branch=call("clientBranchSpec",fixture,options);
  assert.equal(JSON.stringify(fixture),before);
  assert.equal(branch.id,"C04-v2");
  assert.equal(branch.requests.length,2);
  assert.equal(Date.parse(branch.requests[0].window[0])-Date.parse(fixture.requests.find(r=>r.id==="R12").window[0]),7*86400000);
  const quote=branch.requests[1].offers[0],source=fixture.requests.find(r=>r.id==="R17").offers[0];
  assert.equal(Date.parse(quote.start)-Date.parse(source.start),7*86400000-60000);
  assert.equal(quote.price_estimate_cents,source.price_estimate_cents);
  assert.equal(quote.duration_minutes,source.duration_minutes);
  assert.equal(call("clientBranchSpec",fixture,{...options,variant:4}).id,"C04-v4");
  for(const changes of [{caseID:"C99"},{variant:0},{variant:5},{shiftDays:1},{quoteIDs:["R23-A"]},
    {quoteIDs:["R12-A","R12-A"]},{minuteOffsets:{"R17-A":-2000}},{minuteOffsets:{"R01-A":1}}]) {
    assert.throws(()=>call("clientBranchSpec",fixture,{...options,...changes}));
  }
});
test("explicit customer sort checks preserve primary-order ties without picking a winner", () => {
  const fixture=compile(),input=call("clientUIInput",fixture,{runID:"TESTOPS-T392-TEST",actor:"C05",
    phase:"CustomerRequestReadback",ids:["R06"],requestMap:{R06:{id:"12345678-0000-4000-8000-000000000001"}}});
  const checks=input.rows[0].sortChecks,n=id=>fixture.groomers.find(g=>g.id===id).alias;
  assert.deepEqual(checks.find(c=>c.title==="Lowest price").groups,[[n("G11")],[n("G06")],[n("G07"),n("G01")]]);
  assert.deepEqual(checks.find(c=>c.title==="Earliest appointment").groups,[[n("G11")],[n("G01")],[n("G06")],[n("G07")]]);
});
test("customer ranking oracle preserves explicit modes and default two-point score buckets", () => {
  const fixture=compile();fixture.history=[];
  const source=fixture.requests.find(r=>r.id==="R06"),context={asOf:options.anchor,distances:{G01:0,G06:10,G07:10,G11:5}};
  assert.deepEqual(call("customerOrderGroups",fixture,source,"balanced",context),[["R06-D"],["R06-B"],["R06-A","R06-C"]]);
  assert.deepEqual(call("customerOrderGroups",fixture,source,"price",context),[["R06-B"],["R06-A"],["R06-D"],["R06-C"]]);
  assert.deepEqual(call("customerOrderGroups",fixture,source,"earliest",context),[["R06-B"],["R06-D"],["R06-A"],["R06-C"]]);
  assert.deepEqual(call("customerOrderGroups",fixture,source,"distance",context),[["R06-D"],["R06-B"],["R06-A","R06-C"]]);
  assert.throws(()=>call("customerOrderGroups",fixture,source,"newest",context),/mode/i);
  assert.throws(()=>call("customerOrderGroups",fixture,source,"balanced",{...context,distances:{}}),/distance/i);
});
test("legacy restoration exception is restricted to the approved rehearsal and exactly three original rows", () => {
  const manifest={runID:"TESTOPS-T392-20260915-A",kind:"rehearsal",actors:[{alias:"G01",role:"groomer",id:"g"}],
    before:{groomer_services:[1,2,3].map(id=>({id:String(id),groomer_id:"g",is_active:true,accepted_species:null}))}};
  assert.deepEqual(call("legacyRestorationIDs",manifest),["1","2","3"]);
  for(const mutate of [m=>m.kind="base",m=>m.runID="TESTOPS-T392-OTHER",m=>m.before.groomer_services.pop(),
    m=>m.before.groomer_services[0].accepted_species=["dog"],m=>m.before.groomer_services[0].groomer_id="other"]) {
    const changed=structuredClone(manifest);mutate(changed);
    assert.throws(()=>call("legacyRestorationIDs",changed));
  }
});
test("legacy isolation keeps activation/species intact and requires less than twelve available hours", () => {
  const rows=[{id:"legacy",is_active:true,accepted_species:null,duration_minutes:45},
    {id:"known",is_active:true,accepted_species:["dog"],duration_minutes:60},
    {id:"inactive",is_active:false,accepted_species:null,duration_minutes:30}];
  const before=structuredClone(rows),result=call("isolatedServices",rows,[["08:00","19:00"]]);
  assert.deepEqual(rows,before);
  assert.deepEqual(result,[{...rows[0],duration_minutes:720},{...rows[1],is_active:false},rows[2]]);
  assert.throws(()=>call("isolatedServices",rows,[["08:00","20:00"]]),/twelve/i);
  assert.throws(()=>call("isolatedServices",rows,[["20:00","08:00"]]),/twelve/i);
});
test("history batches cover each frozen row exactly once and cap remote transaction size", () => {
  const data=compile(),batches=call("historyBatches",data);
  assert.equal(batches.length,41);
  assert.deepEqual(batches.flat().map(r=>r.id),data.history.map(r=>r.id));
  assert.ok(batches.every(b=>b.length>0 && b.length<=30));
  const changed=structuredClone(data);changed.history[0].rating=0;
  assert.throws(()=>call("historyBatches",changed));
});
test("synthetic profile addresses meet the client street-number/name requirement", () => {
  assert.equal(typeof runner.syntheticStreetAddress,"string");
  assert.match(runner.syntheticStreetAddress,/[0-9]/);
  assert.match(runner.syntheticStreetAddress,/[A-Za-z]/);
  assert.match(runner.syntheticStreetAddress,/synthetic/i);
  assert.ok(runner.syntheticStreetAddress.length<=160);
});
test("publication audit rejects wrong actor, pet snapshot, local time or request terms", () => {
  const source=compile().requests[0],context={runID:"TESTOPS-T392-TEST",customerID:"customer",petID:"pet"};
  const row={customer_id:context.customerID,pet_id:context.petID,service_type:source.service_type,
    service_notes:`TESTOPS:${context.runID} ${source.id}\n${source.customer_text}`,
    preferred_start:source.window[0],preferred_end:source.window[1],preference_time_zone_identifier:"America/Los_Angeles",
    location_mode:source.location_mode,travel_radius_miles:source.travel_radius_miles??null,
    street_address:runner.syntheticStreetAddress,pet_snapshot:{...source.pet,species:"Dog"},
    terms_revision:"00000000-0000-4000-8000-000000000001"};
  assert.doesNotThrow(()=>call("assertPublishedSource",row,source,context));
  for(const mutate of [r=>r.customer_id="other",r=>r.preferred_end=r.preferred_start,
    r=>r.pet_snapshot.weight_lbs=99,r=>r.service_type="nail_trim",r=>r.travel_radius_miles=11]) {
    const changed=structuredClone(row);mutate(changed);
    assert.throws(()=>call("assertPublishedSource",changed,source,context));
  }
});
test("quote audit binds source terms, exact money, confirmations and both participants", () => {
  const request=compile().requests[0],source=request.offers[0];
  const context={runID:"TESTOPS-T392-TEST",customerID:"c",groomerID:"g",
    request:{id:"request",terms_revision:"revision",pet_snapshot:{name:"Mochi"}}};
  const row={request_id:"request",customer_id:"c",groomer_id:"g",proposed_start:source.start,
    proposed_end:new Date(Date.parse(source.start)+source.duration_minutes*60000).toISOString(),
    price_estimate:source.price_estimate_cents/100,message:`TESTOPS:${context.runID} ${source.id}\n${source.message}`,
    assessment_confirmations:source.assessment_confirmations??[],quote_revision:"00000000-0000-4000-8000-000000000001",
    agreement_snapshot:{request_revision:"revision",pet_snapshot:{name:"Mochi"}},status:"pending"};
  assert.doesNotThrow(()=>call("assertQuotedSource",row,source,context));
  for(const mutate of [r=>r.customer_id="other",r=>r.groomer_id="other",r=>r.request_id="other",
    r=>r.price_estimate+=0.01,r=>r.proposed_end=r.proposed_start,r=>r.assessment_confirmations=["forged"],
    r=>r.agreement_snapshot.request_revision="old",r=>r.agreement_snapshot.pet_snapshot.name="other"]) {
    const changed=structuredClone(row);mutate(changed);
    assert.throws(()=>call("assertQuotedSource",changed,source,context));
  }
});
test("source score audit preserves unknown and explicit keys and rejects numeric or coverage drift", () => {
  const source=compile().requests[0],asOf=options.anchor;
  const coverage=[{dimension:"coat",value:"curly_wavy"},{dimension:"service",value:"full_groom"},{dimension:"size",value:"S"}]
    .map(key=>({...key,completed_count:0,positive_count:0,negative_count:0,unknown_count:0}));
  const score={distance_miles:5,f:50,q:50,d:50,b:50,s:50,positive_weight:0,negative_weight:0,
    q_review_count:0,q_customer_count:0,completed_count:0,related_review_count:0,f_customer_count:0,state:"no_evidence",coverage};
  assert.doesNotThrow(()=>call("assertSourceScore",score,source,[],{asOf}));
  for(const mutate of [s=>s.f+=0.001,s=>s.coverage[0].negative_count=1,s=>s.q_customer_count=1,s=>s.state="available"]) {
    const changed=structuredClone(score);mutate(changed);
    assert.throws(()=>call("assertSourceScore",changed,source,[],{asOf}));
  }
  const unknown=structuredClone(source);unknown.pet.weight_lbs=null;unknown.pet.coat_type=null;
  assert.doesNotThrow(()=>call("assertSourceScore",{...score,coverage:[coverage[1]]},unknown,[],{asOf}));
});
test("restoration preserves the adopted privacy epoch without ignoring ranking policy drift", () => {
  const before={singleton:true,enabled:true,algorithm_version:"matching-v1",validation_actor_ids:[]};
  const actual={...before,privacy_revision:"00000000-0000-4000-8000-000000000001"};
  assert.doesNotThrow(()=>call("assertRankingPolicyRestored",actual,before));
  for(const change of [{enabled:false},{algorithm_version:"other"},{validation_actor_ids:["other"]},
    {privacy_revision:"bad"},{unexpected:true}]) {
    assert.throws(()=>call("assertRankingPolicyRestored",{...actual,...change},before));
  }
  assert.doesNotThrow(()=>call("assertRankingPolicyRestored",before,before));
});
