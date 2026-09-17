import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { resolve, join } from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs, parseEnv } from "node:util";
import { destinationCoordinateWGS84, parseCustomerProfiles, parseGroomerProfiles, SupabaseREST } from "./testops-core.mjs";
import { scoreEvidence } from "../tests/support/matching-rating-reference.mjs";

const DAY = 86400000;
export const syntheticStreetAddress = "392 TestOps Synthetic Way";
export const hash = value => createHash("sha256").update(JSON.stringify(value)).digest("hex");
const unique = (rows, key) => assert.equal(new Set(rows.map(r => r[key])).size, rows.length, `Duplicate ${key}`);
const iso = value => new Date(value).toISOString();
const pad = n => String(n).padStart(2, "0");
const weightSize = weight => weight === null ? null : weight < 10 ? "XS" : weight < 20 ? "S"
  : weight < 40 ? "M" : weight < 60 ? "L" : weight < 80 ? "XL" : weight <= 100 ? "XXL" : "Giant";
const localDate = value => new Intl.DateTimeFormat("en-CA", { timeZone: "America/Los_Angeles",
  year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(value));
function localTime(day, hour) {
  const utc = Date.parse(`${day}T${pad(hour)}:00:00Z`);
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "America/Los_Angeles", timeZoneName:"longOffset" })
    .formatToParts(new Date(utc));
  const offset = parts.find(p => p.type === "timeZoneName").value.replace("GMT", "");
  return Date.parse(`${day}T${pad(hour)}:00:00${offset}`);
}

// Independent fixture oracle: keys must be derived from frozen service facts,
// never from the supplied answer list or a backend-generated expected result.
export function historicalReviewKeys(snapshot, service, serviceAt) {
  if (!["Dog","Cat"].includes(snapshot.species) || !["full_groom","bath_and_brush","haircut_only","nail_trim","de_shedding"].includes(service)) return [];
  const keys=[`service:${service}`],size=weightSize(snapshot.weight_lbs);
  if (size) keys.push(`size:${size}`);
  if (service !== "nail_trim" && snapshot.coat_type_source === "explicit"
    && ["curly_wavy","wire","double_coat","drop_coat","long_silky","short_smooth","hairless_low_coat"].includes(snapshot.coat_type)) keys.push(`coat:${snapshot.coat_type}`);
  if (["Anxious","Reactive"].includes(snapshot.temperament)) keys.push(`care:${snapshot.temperament.toLowerCase()}`);
  if (service !== "nail_trim" && snapshot.matting_confirmed === true) keys.push("care:matted");
  const birthday=snapshot.birthday,day=localDate(serviceAt);
  if (birthday && /^\d{4}-\d{2}-\d{2}$/.test(birthday) && birthday<=day) {
    const puppy=new Date(`${birthday}T00:00:00Z`);puppy.setUTCMonth(puppy.getUTCMonth()+18);
    const senior=new Date(`${birthday}T00:00:00Z`);senior.setUTCFullYear(senior.getUTCFullYear()+10);
    if (day<iso(puppy).slice(0,10)) keys.push("care:puppy");
    else if (day>=iso(senior).slice(0,10)) keys.push("care:senior");
  }
  return keys;
}

function historyPet(spec, species, index, serviceAt) {
  const large=spec.profile === "large_double_coat";
  const unknown=index%19===18;
  const birthday=spec.profile === "senior" ? "2011-01-01"
    : index%17===16 ? `${localDate(serviceAt).slice(0,4)}-01-01` : "2018-01-01";
  return {species:species === "cat" ? "Cat" : "Dog",
    weight_lbs:unknown ? null : large ? [65,85,110][index%3] : index%3===0 ? 8 : 18,
    birthday,coat_type:unknown ? null : species === "cat" ? "long_silky"
      : large ? "double_coat" : spec.profile === "small_curly" ? "curly_wavy"
      : ["curly_wavy","wire","double_coat","drop_coat","short_smooth"][index%5],
    coat_type_source:unknown ? "unknown" : "explicit",matting_confirmed:unknown ? null : index%13===12,
    temperament:index%11===10 ? "Anxious" : index%23===22 ? "Reactive" : "Friendly"};
}

export function parseClientArguments(args, env = process.env) {
  const {values, positionals} = parseArgs({ args, allowPositionals:true,
    options:{"run-id":{type:"string"},phase:{type:"string"},execute:{type:"boolean"},anchor:{type:"string"},
      "restore-legacy-species":{type:"boolean"}} });
  const [mode] = positionals;
  assert.equal(positionals.length, 1, "One mode required");
  assert.ok(["plan","prepare","run","verify","cleanup"].includes(mode), "Unknown mode");
  assert.match(values["run-id"] ?? "", /^TESTOPS-T392-[A-Z0-9-]{1,70}$/, "Invalid run ID");
  if (mode === "run") assert.ok(["flow","ranking","resilience"].includes(values.phase), "Invalid phase");
  else assert.equal(values.phase, undefined, "Phase only applies to run");
  if (mode !== "plan") {
    assert.equal(values.execute, true, "Explicit --execute required");
    assert.equal(env.TESTOPS_REMOTE_WRITE_APPROVED, "1", "Explicit authorization required");
  }
  if (values.anchor) assert.ok(Number.isFinite(Date.parse(values.anchor)), "Invalid anchor");
  if(values["restore-legacy-species"]) {
    assert.equal(mode,"cleanup");assert.equal(values["run-id"],"TESTOPS-T392-20260915-A");
  }
  return {mode,runID:values["run-id"],phase:values.phase,anchor:values.anchor,restoreLegacySpecies:values["restore-legacy-species"]??false};
}

export function validateActorMap(actors) {
  unique(actors,"alias"); unique(actors,"seed"); unique(actors,"id");
  for (const a of actors) {
    assert.match(a.alias,/^[CG]\d{2}$/);
    const role = a.alias[0] === "C" ? "customer" : "groomer";
    assert.equal(a.role, role, "Actor role mismatch");
    assert.match(a.seed, role === "customer" ? /^BTC-\d{3}$/ : /^BTG-\d{3}$/);
    assert.match(a.id,/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i);
  }
  return actors;
}

export function assertReversibleSetupServices(services) {
  assert.ok(services.every(s=>!s.is_active || (s.accepted_species?.length??0)>0),
    "Legacy active services require an adopted exact-restoration strategy before deactivation");
}

export function legacyRestorationIDs(manifest) {
  assert.equal(manifest.runID,"TESTOPS-T392-20260915-A");
  assert.equal(manifest.kind,"rehearsal","No bulk restoration exception");
  const groomers=manifest.actors.filter(a=>a.role==="groomer");
  assert.equal(groomers.length,1);assert.equal(groomers[0].alias,"G01");
  const rows=manifest.before.groomer_services;
  assert.equal(rows.length,3);
  assert.ok(rows.every(s=>s.groomer_id===groomers[0].id && s.is_active && s.accepted_species===null));
  unique(rows,"id");return rows.map(s=>s.id);
}

export function isolatedServices(services, hours) {
  assert.ok(hours.length>0);
  for(const [start,end] of hours) {
    const minutes=t=>{assert.match(t,/^\d{2}:\d{2}$/);const [h,m]=t.split(':').map(Number);return h*60+m;};
    const duration=minutes(end)-minutes(start);
    assert.ok(duration>0 && duration<720,"Legacy isolation requires less than twelve available hours");
  }
  return services.map(s=>!s.is_active ? {...s} : (s.accepted_species?.length??0)>0
    ? {...s,is_active:false} : {...s,duration_minutes:720});
}

export function historyBatches(fixture) {
  validateClientFixture(fixture);
  return Array.from({length:Math.ceil(fixture.history.length/30)},(_,i)=>fixture.history.slice(i*30,(i+1)*30));
}

export async function prepareClientHistory(config) {
  const directory=`artifacts/testops/${config.runID}`;
  assert.equal(JSON.parse(readFileSync(`${directory}/history-rehearsal-restored.json`)).restored,true);
  const fixture=JSON.parse(readFileSync(`${directory}/fixture-v2.json`));
  const {actors}=JSON.parse(readFileSync(`${directory}/base-manifest.json`));validateActorMap(actors);
  const batches=historyBatches(fixture),db=await fixtureDatabase(config);
  const template=readFileSync("tests/fixtures/matching-client-history.sql","utf8");
  const marker=`TESTOPS:${config.runID} history`;
  for(const [index,rows] of batches.entries()) {
    const name=`history-batch-${String(index+1).padStart(3,'0')}`;
    const previous=existsSync(`${directory}/${name}-input.json`)?JSON.parse(readFileSync(`${directory}/${name}-input.json`)):null;
    const input=previous?.input??{actors,groomers:fixture.groomers,positions:fixture.positions,marker,
      staging_start:fixture.requests[0].window[0],history:rows.map(h=>({...h,operation_id:randomUUID()}))};
    if(previous) {
      assert.equal(previous.fixture_hash,hash(fixture));assert.equal(previous.template_hash,hash(template));
      assert.equal(previous.input_hash,hash(input));assert.deepEqual(input.actors,actors);
      assert.deepEqual(input.history.map(({operation_id,...row})=>row),rows);
    } else writeReceipt(directory,`${name}-input`,{input,input_hash:hash(input),fixture_hash:hash(fixture),template_hash:hash(template)});
    const [observed]=db.query(`select coalesce(jsonb_object_agg(replace(r.service_notes,(${db.sqlJSON(`${marker} `)}#>>'{}'),''),
      jsonb_build_object('request_id',r.id,'booking_id',b.id,'review_id',v.id,'pet_id',r.pet_id,'rating',v.rating)),'{}') receipts
      from public.grooming_requests r left join public.bookings b on b.request_id=r.id left join public.reviews v on v.booking_id=b.id
      where r.service_notes in (select (${db.sqlJSON(`${marker} `)}#>>'{}')||value from jsonb_array_elements_text(${db.sqlJSON(rows.map(h=>h.id))}));`);
    if(Object.keys(observed.receipts).length) {
      assert.deepEqual(Object.keys(observed.receipts).sort(),rows.map(h=>h.id).sort(),"Partial history batch; reconcile before retry");
      for(const h of rows) {
        const r=observed.receipts[h.id];assert.ok(r.booking_id&&r.review_id);assert.equal(r.rating,h.rating);
      }
      if(!existsSync(`${directory}/${name}-committed.json`)) writeReceipt(directory,`${name}-committed`,
        {result:[observed],input_hash:hash(input),reconciled:true,at:new Date().toISOString()});
    } else {
      assert.equal(existsSync(`${directory}/${name}-committed.json`),false,"Committed history disappeared");
      const result=db.query(template.replace("/* INPUT_JSON */",db.sqlJSON(input)).replace("/* END_TRANSACTION */","commit"),170000);
      assert.deepEqual(Object.keys(result[0].receipts).sort(),rows.map(h=>h.id).sort());
      writeReceipt(directory,`${name}-committed`,{result,input_hash:hash(input),at:new Date().toISOString()});
    }
    console.log(JSON.stringify({runID:config.runID,history_committed:Math.min((index+1)*30,fixture.history.length),total:fixture.history.length}));
  }
  const groomers=actors.filter(a=>a.role==="groomer");
  const ratings=db.query(`select user_id,rating_count,rating_sum from public.groomer_profiles where user_id in (${db.sqlIDs(groomers.map(a=>a.id))});`);
  for(const a of groomers) {
    const rows=fixture.history.filter(h=>h.groomer===a.alias),actual=ratings.find(r=>r.user_id===a.id);
    assert.equal(actual.rating_count,rows.length);assert.equal(Number(actual.rating_sum),rows.reduce((n,h)=>n+h.rating,0));
  }
  writeReceipt(directory,"history-baseline-verified",{at:new Date().toISOString(),ratings,records:1228,star_sum:5791});
}

export function reconcileBatch(batch, actual) {
  unique(actual,"id");
  if (!actual.length) return "not_committed";
  assert.deepEqual(actual.map(r => r.id).sort(), [...batch.ids].sort(), "Partial or foreign batch; reconcile before retry");
  assert.ok(actual.every(r => r.input_hash === batch.input_hash), "Batch input hash changed");
  return "committed";
}

export function writeReceipt(directory, name, value) {
  assert.match(name,/^[A-Za-z0-9][A-Za-z0-9-]{0,120}$/);
  mkdirSync(directory,{recursive:true,mode:0o700});
  writeFileSync(join(directory,`${name}.json`),JSON.stringify(value,null,2),{mode:0o600,flag:"wx"});
}

function quoteReadbackEvidence(request, quote, history) {
  const keys=historicalReviewKeys({...request.pet,species:request.pet.species==="cat" ? "Cat" : "Dog",
    coat_type_source:request.pet.coat_type ? "explicit" : "unknown"},
    request.service_type,quote.start);
  const related=request.service_type==="custom_request" ? [] : history.filter(h=>h.species===request.pet.species && h.service===request.service_type);
  const fit=related.filter(h=>keys.some(key=>["positive","negative"].includes(h.answers[key])));
  const titles={full_groom:"Full Groom",bath_and_brush:"Bath & Brush",haircut_only:"Haircut Only",nail_trim:"Nail Trim",
    de_shedding:"De-shedding",curly_wavy:"Curly / Wavy",wire:"Wire / Terrier",double_coat:"Double Coat / Heavy Shedding",
    drop_coat:"Drop Coat",long_silky:"Long Silky / Feathered",short_smooth:"Short Smooth",hairless_low_coat:"Hairless / Very Low Coat",
    anxious:"Anxious",reactive:"Reactive",puppy:"Puppy",senior:"Senior",matted:"Matted Coat"};
  return {evidenceSummary:fit.length ? `${fit.length} related reviews from ${new Set(fit.map(h=>h.customer)).size} customers`
    : "No verified related feedback yet",evidenceLines:fit.length ? keys.map(key=>{
      const [dimension,value]=key.split(":"),title=dimension==="size" ? value : titles[value];assert.ok(title,"Unknown evidence label");
      const completed=related.filter(h=>h.allowed_keys.includes(key)).length,
        positive=related.filter(h=>h.answers[key]==="positive").length,negative=related.filter(h=>h.answers[key]==="negative").length;
      return `${title}: ${positive} positive, ${negative} negative, ${completed-positive-negative} unreported`;
    }) : []};
}

export function customerOrderGroups(fixture, request, mode, {asOf,distances}) {
  assert.ok(["balanced","distance","earliest","price"].includes(mode),"Unknown customer mode");
  assert.ok(Number.isFinite(Date.parse(asOf)),"Invalid score time");
  const rows=request.offers.map(quote=>{
    const distance=distances[quote.groomer_id];assert.ok(Number.isFinite(distance)&&distance>=0,"Missing source distance");
    const keys=historicalReviewKeys({...request.pet,species:request.pet.species==="cat" ? "Cat" : "Dog",
      coat_type_source:request.pet.coat_type ? "explicit" : "unknown"},request.service_type,quote.start);
    const history=fixture.history.filter(h=>h.groomer===quote.groomer_id).map(h=>({customer:h.customer,
      species:h.species,service:h.service,rating:h.rating,answers:h.answers,age:(Date.parse(asOf)-Date.parse(h.service_at))/DAY}));
    const score=scoreEvidence({species:request.pet.species,service:request.service_type,keys},history,distance);
    const primary=mode==="distance" ? distance : mode==="earliest" ? Date.parse(quote.start)
      : mode==="price" ? quote.price_estimate_cents : 0;
    return {id:quote.id,primary,bucket:-Math.floor(score.s/2)};
  }).sort((a,b)=>a.primary-b.primary || a.bucket-b.bucket);
  const groups=[];
  for(const row of rows) {
    const last=groups.at(-1);
    if(last && last.primary===row.primary && last.bucket===row.bucket) last.ids.push(row.id);
    else groups.push({...row,ids:[row.id]});
  }
  return groups.map(g=>g.ids);
}

export function clientUIInput(fixture, {runID,actor,phase,ids,previewOnly=false,requestMap={},quoteIDs,negativeIDs}) {
  assert.match(runID,/^TESTOPS-T392-[A-Z0-9-]{1,70}$/);
  assert.ok(["PublicationBatch","QuoteBatch","CustomerRequestReadback","GroomerRequestReadback","AcceptanceBatch"].includes(phase),"Unknown UI phase");
  assert.ok(ids.length>0 && new Set(ids).size===ids.length,"Distinct source IDs required");
  const role=["QuoteBatch","GroomerRequestReadback"].includes(phase) ? "groomer" : "customer";
  assert.match(actor,role === "customer" ? /^C\d{2}$/ : /^G\d{2}$/, "Wrong UI actor");
  if(negativeIDs) assert.equal(phase,"GroomerRequestReadback");
  if(phase==="GroomerRequestReadback") {
    assert.equal(quoteIDs,undefined,"Readback selects the current groomer's quotes");
    assert.equal(new Set(negativeIDs??[]).size,(negativeIDs??[]).length,"Distinct negatives required");
    const forbiddenReferences=(negativeIDs??[]).map(id=>{
      const negative=fixture.negatives.find(n=>n.id===id);assert.ok(negative,"Unknown negative");
      assert.equal(negative.groomer_id,actor,"Wrong negative actor");
      assert.ok(["X01","X06","X07","X08"].includes(id),"Only hard exclusions lack a matched entry");
      const requestID=requestMap[negative.request_id]?.id;
      assert.match(requestID??"",/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i);
      return requestID.slice(0,8).toUpperCase();
    });
    const rows=ids.map(id=>{
      const request=fixture.requests.find(r=>r.id===id);assert.ok(request,"Unknown source ID");
      const quotes=request.offers.filter(o=>o.groomer_id===actor);assert.equal(quotes.length,1,"Actor must own the source quote");
      const row=clientUIInput(fixture,{runID,actor:request.customer_id,phase:"CustomerRequestReadback",
        ids:[id],requestMap,quoteIDs:quotes.map(o=>o.id)}).rows[0];
      return {...row,sortChecks:[]};
    });
    return {runID,actor,role,phase,previewOnly,rows,forbiddenReferences};
  }
  if(quoteIDs) {
    assert.equal(phase,"CustomerRequestReadback");
    assert.equal(new Set(quoteIDs).size,quoteIDs.length,"Distinct quote IDs required");
    assert.ok(quoteIDs.every(id=>fixture.requests.some(r=>ids.includes(r.id)&&r.offers.some(o=>o.id===id))),"Wrong readback quote");
  }
  const rows=ids.map(id=>{
    const request=fixture.requests.find(r=>["PublicationBatch","CustomerRequestReadback"].includes(phase)
      ? r.id===id : r.offers.some(o=>o.id===id));
    assert.ok(request,"Unknown source ID");
    if (role === "customer") {
      assert.equal(request.customer_id,actor,"Wrong source actor");
      if(phase === "AcceptanceBatch") {
        assert.match(requestMap[request.id]?.id??"",/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i,"Request ID mapping required");
        const quote=request.offers.find(o=>o.id===id);
        return {id,reference:requestMap[request.id].id.slice(0,8).toUpperCase(),
          groomerName:fixture.groomers.find(g=>g.id===quote.groomer_id).alias};
      }
      if(phase === "CustomerRequestReadback") {
        assert.match(requestMap[id]?.id??"",/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i,"Request ID mapping required");
        const offers=request.offers.filter(o=>!quoteIDs || quoteIDs.includes(o.id));
        const sortChecks=["R03","R04","R06"].includes(id) && offers.length===request.offers.length
          ? ["price","earliest"].map(mode=>{
            const primary=o=>mode==="price" ? o.price_estimate_cents : Date.parse(o.start),groups=new Map();
            for(const offer of [...offers].sort((a,b)=>primary(a)-primary(b))) {
              const key=primary(offer);if(!groups.has(key))groups.set(key,[]);
              groups.get(key).push(fixture.groomers.find(g=>g.id===offer.groomer_id).alias);
            }
            return {title:mode==="price" ? "Lowest price" : "Earliest appointment",groups:[...groups.values()]};
          }) : [];
        return {id,reference:requestMap[id].id.slice(0,8).toUpperCase(),petName:request.pet.name,
          species:request.pet.species,serviceType:request.service_type,locationMode:request.location_mode,
          window:request.window,travelRadiusMiles:request.travel_radius_miles,
          notes:`TESTOPS:${runID} ${id}\n${request.customer_text}`,streetAddress:syntheticStreetAddress,
          sortChecks,quotes:offers.map(o=>{
            const history=fixture.history.filter(h=>h.groomer===o.groomer_id);
            return {id:o.id,groomerName:fixture.groomers.find(g=>g.id===o.groomer_id).alias,
              price:`$${(o.price_estimate_cents/100).toFixed(2)}`,
              start:o.start,end:iso(Date.parse(o.start)+o.duration_minutes*60000),
              confirmationAddress:`${syntheticStreetAddress}, ${request.location_mode==="groomer_comes_to_customer"
                ? request.neighborhood : fixture.groomers.find(g=>g.id===o.groomer_id).neighborhood}, CA, 90001, US`,
              message:`TESTOPS:${runID} ${o.id}\n${o.message}`,
              ratingCount:history.length,ratingSum:history.reduce((sum,h)=>sum+h.rating,0),
              ...quoteReadbackEvidence(request,o,history)};
          })};
      }
      assert.notEqual(request.id,"R23","Expiry boundary uses runtime setup");
      return {id,petName:request.pet.name,petWeight:request.pet.weight_lbs,species:request.pet.species,
        serviceType:request.service_type,locationMode:request.location_mode,travelRadiusMiles:request.travel_radius_miles,
        window:request.window,notes:`TESTOPS:${runID} ${id}\n${request.customer_text}`};
    }
    const quote=request.offers.find(o=>o.id===id);
    assert.equal(quote.groomer_id,actor,"Wrong quote actor");
    assert.match(requestMap[request.id]?.id??"",/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i,"Request ID mapping required");
    return {id,reference:requestMap[request.id].id.slice(0,8).toUpperCase(),start:quote.start,durationMinutes:quote.duration_minutes,
      price:(quote.price_estimate_cents/100).toFixed(2),message:`TESTOPS:${runID} ${id}\n${quote.message}`,
      confirmations:quote.assessment_confirmations??[]};
  });
  return {runID,actor,role,phase,previewOnly,rows};
}

export async function connectClientActors(runID, aliases) {
  assert.match(runID,/^TESTOPS-T392-[A-Z0-9-]{1,70}$/);
  assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED,"1");
  const {actors:inventory}=JSON.parse(readFileSync(`artifacts/testops/${runID}/inventory.json`));
  validateActorMap(inventory);
  assert.ok(aliases.length>0 && new Set(aliases).size===aliases.length);
  const selected=aliases.map(alias=>{const actor=inventory.find(a=>a.alias===alias);assert.ok(actor,"Unknown frozen actor");return actor;});
  const env=parseEnv(readFileSync("supabase_environment_variables","utf8"));
  assert.equal(env.SUPABASE_URL,"https://lqmasbuqzvcvtawonjlb.supabase.co");
  const api=new SupabaseREST(env.SUPABASE_URL,env.SUPABASE_PUBLISHABLE_KEY);
  const profiles=[...parseCustomerProfiles(),...parseGroomerProfiles()],actors={};
  for(const actor of selected) {
    const profile=profiles.find(p=>p.seedID===actor.seed);assert.ok(profile);
    const session=await api.signIn(profile.email,profile.password);
    assert.equal(session.user.id,actor.id,"Authenticated actor differs from frozen map");
    actors[actor.alias]={...actor,token:session.accessToken};
  }
  return {api,actors};
}

export function assertPublishedSource(actual, source, {runID,customerID,petID}) {
  assert.equal(actual.customer_id,customerID);assert.equal(actual.pet_id,petID);
  assert.equal(actual.service_type,source.service_type);
  assert.equal(actual.service_notes,`TESTOPS:${runID} ${source.id}\n${source.customer_text}`);
  assert.equal(Date.parse(actual.preferred_start),Date.parse(source.window[0]),"Published start differs from source");
  assert.equal(Date.parse(actual.preferred_end),Date.parse(source.window[1]),"Published end differs from source");
  assert.equal(actual.preference_time_zone_identifier,"America/Los_Angeles");
  assert.equal(actual.location_mode,source.location_mode);
  assert.equal(actual.travel_radius_miles,source.travel_radius_miles??null);
  assert.equal(actual.street_address,syntheticStreetAddress);
  for(const key of ["name","breed","weight_lbs","birthday","temperament","coat_type","matting_confirmed"]) {
    assert.equal(actual.pet_snapshot[key]??null,source.pet[key]??null,`Published pet ${key} differs from source`);
  }
  assert.equal(actual.pet_snapshot.species.toLowerCase(),source.pet.species);
  assert.match(actual.terms_revision,/^[0-9a-f-]{36}$/);
}

export async function auditClientPublications({runID,actor,ids,requireAll=false}) {
  const directory=`artifacts/testops/${runID}`,fixture=JSON.parse(readFileSync(`${directory}/fixture-v2.json`));
  const input=clientUIInput(fixture,{runID,actor,phase:"PublicationBatch",ids});
  const base=JSON.parse(readFileSync(`${directory}/base-committed.json`));
  const {api,actors}=await connectClientActors(runID,[actor]),customer=actors[actor],found={},missing=[];
  for(const row of input.rows) {
    const actual=await api.restSelect("grooming_requests",`select=*&customer_id=eq.${customer.id}&service_notes=eq.${encodeURIComponent(row.notes)}`,customer.token);
    assert.ok(actual.length<=1,`Duplicate published source ${row.id}`);
    if(!actual.length) {missing.push(row.id);continue;}
    const source=fixture.requests.find(r=>r.id===row.id);
    assertPublishedSource(actual[0],source,{runID,customerID:customer.id,petID:base.receipt.pets[source.pet.id]});
    found[row.id]=actual[0];
  }
  const receipt={runID,actor,at:new Date().toISOString(),found,missing,scope:"Authenticated read audit; UI/cross-client evidence separate"};
  writeReceipt(directory,`publication-audit-${actor}-${Date.now()}`,receipt);
  if(requireAll) assert.deepEqual(missing,[],"UI publications missing on authoritative read");
  console.log(JSON.stringify({actor,published:Object.keys(found),missing}));
  return receipt;
}

export function validateClientUIPhase(phase, role) {
  const customer = ["PublicationBatch","CustomerRequestReadback","AcceptanceBatch","CustomerBookingReadback","OfferExpiry","PetUpdate","SessionSwitch","RequestClosure"];
  const groomer = ["QuoteBatch","GroomerRequestReadback","ScheduleReadback","WithdrawalBatch"];
  assert.ok([...customer,...groomer,"BookingActions","RankingBrowse"].includes(phase),"Unknown client UI phase");
  assert.ok(["customer","groomer"].includes(role),"Unknown client UI role");
  if(!["BookingActions","RankingBrowse"].includes(phase)) assert.equal(role,customer.includes(phase)?"customer":"groomer","Client UI role mismatch");
  return phase;
}

export async function executeClientUIBatch(input, device, {skipBuild=true}={}) {
  validateActorMap(JSON.parse(readFileSync(`artifacts/testops/${input.runID}/inventory.json`)).actors);
  assert.match(device,/^[0-9a-f-]{36}$/i);
  const phase=input.phase??(input.role==="customer" ? "PublicationBatch" : "QuoteBatch");
  validateClientUIPhase(phase,input.role);
  const name=`ui-input-${phase}-${input.actor}-${Date.now()}`;
  writeReceipt(`artifacts/testops/${input.runID}`,name,input);
  const child=spawn(process.execPath,["scripts/test-t387-simulator-sign-in.mjs",input.role,phase],{
    stdio:"inherit",env:{...process.env,TESTOPS_RUN_ID:input.runID,TESTOPS_ACTOR_ALIAS:input.actor,
      TESTOPS_SIMULATOR_UDID:device,TESTOPS_UI_INPUT:`${name}.json`,TESTOPS_SKIP_BUILD:skipBuild?"1":"0"}});
  const code=await new Promise((resolve,reject)=>{child.on("error",reject);child.on("close",resolve);});
  assert.equal(code,0,`${phase}/${input.actor} failed; audit committed actions before any retry`);
}

export function assertQuotedSource(actual, source, {runID,customerID,groomerID,request}) {
  assert.equal(actual.request_id,request.id);assert.equal(actual.customer_id,customerID);
  assert.equal(actual.groomer_id,groomerID);
  assert.equal(Date.parse(actual.proposed_start),Date.parse(source.start));
  assert.equal(Date.parse(actual.proposed_end)-Date.parse(actual.proposed_start),source.duration_minutes*60000);
  assert.equal(Math.round(Number(actual.price_estimate)*100),source.price_estimate_cents);
  assert.equal(actual.message,`TESTOPS:${runID} ${source.id}\n${source.message}`);
  assert.deepEqual([...actual.assessment_confirmations].sort(),[...(source.assessment_confirmations??[])].sort());
  assert.match(actual.quote_revision,/^[0-9a-f-]{36}$/);
  assert.equal(actual.agreement_snapshot.request_revision,request.terms_revision);
  assert.deepEqual(actual.agreement_snapshot.pet_snapshot,request.pet_snapshot);
}

export async function auditClientQuotes({runID,actor,ids,requireAll=false}) {
  const directory=`artifacts/testops/${runID}`,fixture=JSON.parse(readFileSync(`${directory}/fixture-v2.json`));
  assert.ok(ids.length && new Set(ids).size===ids.length);
  const sources=ids.map(id=>{
    const request=fixture.requests.find(r=>r.offers.some(o=>o.id===id));assert.ok(request);
    const quote=request.offers.find(o=>o.id===id);assert.equal(quote.groomer_id,actor);
    assert.notEqual(request.id,"R23","Runtime expiry source needs its own mapped audit");
    return {request,quote};
  });
  const {api,actors}=await connectClientActors(runID,[actor,...new Set(sources.map(s=>s.request.customer_id))]);
  const groomer=actors[actor],requestMap={},found={},missing=[];
  const base=JSON.parse(readFileSync(`${directory}/base-committed.json`));
  for(const {request,quote} of sources) {
    const customer=actors[request.customer_id];
    const rows=await api.restSelect("grooming_requests",`select=*&customer_id=eq.${customer.id}&service_notes=eq.${encodeURIComponent(`TESTOPS:${runID} ${request.id}\n${request.customer_text}`)}`,customer.token);
    assert.equal(rows.length,1,"Quote source must have exactly one published request");
    const published=rows[0];
    assertPublishedSource(published,request,{runID,customerID:customer.id,petID:base.receipt.pets[request.pet.id]});
    requestMap[request.id]=published;
    const actual=await api.restSelect("groomer_offers",`select=*&request_id=eq.${published.id}&groomer_id=eq.${groomer.id}`,groomer.token);
    assert.ok(actual.length<=1,"Unexpected existing quote history; reconcile rather than overwrite");
    if(!actual.length) {missing.push(quote.id);continue;}
    assertQuotedSource(actual[0],quote,{runID,customerID:customer.id,groomerID:groomer.id,request:published});
    const counterpart=await api.restSelect("groomer_offers",`select=*&id=eq.${actual[0].id}`,customer.token);
    assert.deepEqual(counterpart,actual,"Customer cannot read the same committed quote");
    found[quote.id]=actual[0];
  }
  const receipt={runID,actor,at:new Date().toISOString(),found,missing,requestMap,
    scope:"Both authenticated parties read the same source terms; client evidence separate"};
  writeReceipt(directory,`quote-audit-${actor}-${Date.now()}`,receipt);
  if(requireAll) assert.deepEqual(missing,[]);
  console.log(JSON.stringify({actor,quoted:Object.keys(found),missing}));
  return receipt;
}

export async function quoteClientSources({runID,device,actor,ids}) {
  const fixture=JSON.parse(readFileSync(`artifacts/testops/${runID}/fixture-v2.json`));
  const before=await auditClientQuotes({runID,actor,ids});
  if(before.missing.length) await executeClientUIBatch(clientUIInput(fixture,
    {runID,actor,phase:"QuoteBatch",ids:before.missing,requestMap:before.requestMap}),device);
  return auditClientQuotes({runID,actor,ids,requireAll:true});
}

export async function publishClientSources({runID,device,aliases}) {
  const fixture=JSON.parse(readFileSync(`artifacts/testops/${runID}/fixture-v2.json`));
  validateClientFixture(fixture);
  for(const actor of aliases) {
    const ids=fixture.requests.filter(r=>r.customer_id===actor && r.id!=="R23").map(r=>r.id);
    assert.ok(ids.length,"Actor has no normal publication sources");
    const before=await auditClientPublications({runID,actor,ids});
    if(before.missing.length) {
      await executeClientUIBatch(clientUIInput(fixture,{runID,actor,phase:"PublicationBatch",ids:before.missing}),device);
    }
    await auditClientPublications({runID,actor,ids,requireAll:true});
  }
}

export function clientBranchSpec(fixture, {caseID,variant,quoteIDs,shiftDays=7,minuteOffsets={}}) {
  assert.ok(fixture.cases.some(c=>c.id===caseID),"Unknown acceptance case");
  // Keep three acceptance variants plus one replacement after a preserved failure.
  assert.ok(Number.isInteger(variant) && variant>=1 && variant<=4,"Invalid branch variant");
  assert.ok(Number.isInteger(shiftDays) && shiftDays>=7 && shiftDays<=56 && shiftDays%7===0,"Whole-week branch shift required");
  assert.ok(quoteIDs.length>0 && new Set(quoteIDs).size===quoteIDs.length,"Distinct branch quotes required");
  assert.ok(Object.keys(minuteOffsets).every(id=>quoteIDs.includes(id)),"Foreign quote offset");
  const requests=[];
  for(const id of quoteIDs) {
    const original=fixture.requests.find(r=>r.offers.some(o=>o.id===id));
    assert.ok(original && original.id!=="R23","Normal source quote required; expiry has separate runtime setup");
    let request=requests.find(r=>r.id===original.id);
    if(!request) {
      request={...structuredClone(original),window:original.window.map(t=>iso(Date.parse(t)+shiftDays*DAY)),offers:[]};
      requests.push(request);
    }
    const offset=minuteOffsets[id]??0;assert.ok(Number.isInteger(offset) && Math.abs(offset)<=60,"Invalid minute boundary offset");
    const quote=structuredClone(original.offers.find(o=>o.id===id));
    quote.start=iso(Date.parse(quote.start)+shiftDays*DAY+offset*60000);
    assert.ok(Date.parse(quote.start)>=Date.parse(request.window[0])
      && Date.parse(quote.start)+quote.duration_minutes*60000<=Date.parse(request.window[1]),"Branch quote outside customer window");
    request.offers.push(quote);
  }
  return {id:`${caseID}-v${variant}`,caseID,variant,shiftDays,minuteOffsets,quoteIDs,requests};
}

export async function prepareClientBranch({runID,...options}) {
  assert.match(runID,/^TESTOPS-T392-[A-Z0-9-]{1,70}$/);
  assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED,"1");
  const directory=`artifacts/testops/${runID}`,fixture=JSON.parse(readFileSync(`${directory}/fixture-v2.json`));
  const spec=clientBranchSpec(fixture,options),name=`branch-${spec.id}`;
  assert.equal(existsSync(`${directory}/base-restored.json`),false,"Acceptance fixture was already restored");
  const existing=existsSync(`${directory}/${name}-intent.json`)
    ? JSON.parse(readFileSync(`${directory}/${name}-intent.json`)) : null;
  if(existing) {assert.equal(existing.fixture_hash,hash(fixture));assert.deepEqual(existing.spec,spec);}
  const intent=existing??{runID,fixture_hash:hash(fixture),spec,
    operation_ids:Object.fromEntries(spec.requests.map(r=>[r.id,randomUUID()])),at:new Date().toISOString(),
    scope:"Independent RPC setup for subsequent client transactions; not main source UI publication/quotation evidence"};
  if(!existing) writeReceipt(directory,`${name}-intent`,intent);
  if(existsSync(`${directory}/${name}-prepared.json`)) return JSON.parse(readFileSync(`${directory}/${name}-prepared.json`));
  const base=JSON.parse(readFileSync(`${directory}/base-committed.json`));
  const aliases=[...new Set(spec.requests.flatMap(r=>[r.customer_id,...r.offers.map(o=>o.groomer_id)]))];
  const {api,actors}=await connectClientActors(runID,aliases),requestMap={},quoteMap={},parents={};
  for(const source of spec.requests) {
    const customer=actors[source.customer_id],original=fixture.requests.find(r=>r.id===source.id);
    const [parent]=await api.restSelect("grooming_requests",`select=*&customer_id=eq.${customer.id}&service_notes=eq.${encodeURIComponent(`TESTOPS:${runID} ${original.id}\n${original.customer_text}`)}`,customer.token);
    assert.ok(parent,"UI-published parent required before branch setup");
    assertPublishedSource(parent,original,{runID,customerID:customer.id,petID:base.receipt.pets[source.pet.id]});
    parents[source.id]=parent.id;
    const notes=`TESTOPS:${runID} ${spec.id} ${source.id}\n${source.customer_text}`;
    let rows=await api.restSelect("grooming_requests",`select=*&customer_id=eq.${customer.id}&service_notes=eq.${encodeURIComponent(notes)}`,customer.token);
    assert.ok(rows.length<=1,"Duplicate branch request; do not create another");
    if(!rows.length) {
      const position=fixture.positions.find(p=>p.alias===source.customer_id);assert.ok(position);
      const [pet]=await api.restSelect("pets",`select=*&id=eq.${parent.pet_id}`,customer.token);
      assert.ok(pet?.is_active,"Active source pet required for branch preparation");
      for(const key of ["name","breed","weight_lbs","birthday","coat_type","matting_confirmed","temperament"]) {
        assert.equal(pet[key]??null,source.pet[key]??null,`Source pet ${key} changed; preserve it before branch setup`);
      }
      assert.equal(pet.species.toLowerCase(),source.pet.species);
      const result=await api.rpc("create_grooming_request_v4",{p_publish_operation_id:intent.operation_ids[source.id],
        p_preference_time_zone_identifier:"America/Los_Angeles",p_request:{pet_id:parent.pet_id,
          service_type:source.service_type,service_notes:notes,preferred_start:source.window[0],preferred_end:source.window[1],
          location_mode:source.location_mode,travel_radius_miles:source.travel_radius_miles??null,
          street_address:parent.street_address,address_line_2:parent.address_line_2,city:parent.city,state:parent.state,zip_code:parent.zip_code,
          provider:"apple_maps",country_code:"US",latitude:position.latitude,longitude:position.longitude,
          resolution_source:"manual_geocode",user_confirmed_at:intent.at}},customer.token);
      assert.equal(result.length,1);assert.match(result[0].request_id,/^[0-9a-f-]{36}$/i);
      rows=await api.restSelect("grooming_requests",`select=*&id=eq.${result[0].request_id}`,customer.token);
    }
    assert.equal(rows.length,1);
    const request=rows[0];
    assertPublishedSource(request,{...source,id:`${spec.id} ${source.id}`},{runID,customerID:customer.id,petID:parent.pet_id});
    assert.ok(["open","has_offers"].includes(request.status),"Branch advanced before preparation completed; reconcile it");
    requestMap[source.id]=request;
    if(!existsSync(`${directory}/${name}-${source.id}-request.json`)) writeReceipt(directory,`${name}-${source.id}-request`,{request,parent_id:parent.id});
    for(const quote of source.offers) {
      const groomer=actors[quote.groomer_id],expected={...quote,id:`${spec.id} ${quote.id}`};
      let offers=await api.restSelect("groomer_offers",`select=*&request_id=eq.${request.id}&groomer_id=eq.${groomer.id}`,groomer.token);
      assert.ok(offers.length<=1,"Existing branch quote history requires reconciliation");
      if(!offers.length) {
        await api.rpc("create_groomer_offer_v3",{p_request_id:request.id,p_expected_request_revision:request.terms_revision,
          p_proposed_start:quote.start,p_proposed_end:iso(Date.parse(quote.start)+quote.duration_minutes*60000),
          p_price_estimate:quote.price_estimate_cents/100,p_message:`TESTOPS:${runID} ${expected.id}\n${quote.message}`,
          p_assessment_confirmations:quote.assessment_confirmations??[]},groomer.token);
        offers=await api.restSelect("groomer_offers",`select=*&request_id=eq.${request.id}&groomer_id=eq.${groomer.id}`,groomer.token);
      }
      assert.equal(offers.length,1);assert.equal(offers[0].status,"pending");
      assertQuotedSource(offers[0],expected,{runID,customerID:customer.id,groomerID:groomer.id,request});
      assert.deepEqual(await api.restSelect("groomer_offers",`select=*&id=eq.${offers[0].id}`,customer.token),offers);
      quoteMap[quote.id]=offers[0];
      if(!existsSync(`${directory}/${name}-${quote.id}-quote.json`)) writeReceipt(directory,`${name}-${quote.id}-quote`,offers[0]);
    }
  }
  const result={runID,spec,parents,requestMap,quoteMap,at:new Date().toISOString(),scope:intent.scope};
  writeReceipt(directory,`${name}-prepared`,result);
  return result;
}

export async function prepareExistingOccupancy({runID}) {
  assert.match(runID,/^TESTOPS-T392-[A-Z0-9-]{1,70}$/);
  assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED,"1");
  const directory=`artifacts/testops/${runID}`,fixture=JSON.parse(readFileSync(`${directory}/fixture-v2.json`)),
    original=JSON.parse(readFileSync("tests/fixtures/matching-marketplace-la-synthetic.json"));
  assert.equal(hash(original),fixture.source_hash);
  assert.equal(existsSync(`${directory}/base-restored.json`),false);
  const slot=original.existing_occupied_slots.find(s=>s.id==="B01");assert.equal(slot.groomer_id,"G04");assert.equal(slot.includes_buffers,true);
  const start=iso(Date.parse(slot.start)+fixture.shift_days*DAY),end=iso(Date.parse(slot.end)+fixture.shift_days*DAY),
    serviceEnd=iso(Date.parse(end)-15*60000),parentSource=fixture.requests.find(r=>r.id==="R21"),
    source={...parentSource,id:"B01 baseline occupancy",service_type:"bath_and_brush",window:[start,serviceEnd],
      location_mode:"customer_comes_to_groomer",travel_radius_miles:50,customer_text:"Synthetic existing calendar booking; bath and brush, including a separate 15-minute cleanup buffer."};
  assert.ok(parentSource.offers.every(o=>Date.parse(o.start)>=Date.parse(end)||Date.parse(o.start)+o.duration_minutes*60000<=Date.parse(start)),"Baseline owner must not conflict with a source quote");
  const spec={slot,start,end,source,customer:"C19",groomer:"G04"},name="baseline-B01";
  const existing=existsSync(`${directory}/${name}-intent.json`) ? JSON.parse(readFileSync(`${directory}/${name}-intent.json`)) : null;
  if(existing) assert.deepEqual(existing.spec,spec);
  const intent=existing??{runID,spec,operation_id:randomUUID(),at:new Date().toISOString(),
    scope:"Missing original B01 occupancy prerequisite; ordinary RPC setup, not a client booking acceptance"};
  if(!existing) writeReceipt(directory,`${name}-intent`,intent);
  const {api,actors}=await connectClientActors(runID,["C19","G04"]),customer=actors.C19,groomer=actors.G04;
  const parents=await api.restSelect("grooming_requests",`select=*&customer_id=eq.${customer.id}&service_notes=eq.${encodeURIComponent(`TESTOPS:${runID} R21\n${parentSource.customer_text}`)}`,customer.token);
  assert.equal(parents.length,1);const parent=parents[0],position=fixture.positions.find(p=>p.alias==="C19"),notes=`TESTOPS:${runID} ${source.id}\n${source.customer_text}`;
  const [pet]=await api.restSelect("pets",`select=*&id=eq.${parent.pet_id}`,customer.token);assert.equal(pet.is_active,true);
  for(const key of ["name","species","breed","weight_lbs","birthday","coat_type","matting_confirmed","temperament"]) {
    assert.equal(pet[key],parent.pet_snapshot[key],"Source pet changed before baseline setup");
  }
  let requests=await api.restSelect("grooming_requests",`select=*&customer_id=eq.${customer.id}&service_notes=eq.${encodeURIComponent(notes)}`,customer.token);
  assert.ok(requests.length<=1);
  if(!requests.length) {
    assert.deepEqual(await api.restSelect("bookings",`select=id&groomer_id=eq.${groomer.id}&status=eq.confirmed`,groomer.token),[],"Unexpected active G04 booking; preserve and reconcile");
    const receipt=await api.rpc("create_grooming_request_v4",{p_publish_operation_id:intent.operation_id,
      p_preference_time_zone_identifier:"America/Los_Angeles",p_request:{pet_id:parent.pet_id,
        service_type:source.service_type,service_notes:notes,preferred_start:start,preferred_end:serviceEnd,
        location_mode:source.location_mode,travel_radius_miles:source.travel_radius_miles,
        street_address:parent.street_address,address_line_2:parent.address_line_2,city:parent.city,state:parent.state,zip_code:parent.zip_code,
        provider:"apple_maps",country_code:"US",latitude:position.latitude,longitude:position.longitude,
        resolution_source:"manual_geocode",user_confirmed_at:intent.at}},customer.token);
    assert.equal(receipt.length,1);
    requests=await api.restSelect("grooming_requests",`select=*&id=eq.${receipt[0].request_id}`,customer.token);
  }
  assert.equal(requests.length,1);const request=requests[0];
  assertPublishedSource(request,source,{runID,customerID:customer.id,petID:parent.pet_id});
  if(!existsSync(`${directory}/${name}-request.json`)) writeReceipt(directory,`${name}-request`,{request,parent_id:parent.id});
  let offers=await api.restSelect("groomer_offers",`select=*&request_id=eq.${request.id}&groomer_id=eq.${groomer.id}`,groomer.token);assert.ok(offers.length<=1);
  if(!offers.length) {
    await api.rpc("create_groomer_offer_v3",{p_request_id:request.id,p_expected_request_revision:request.terms_revision,
      p_proposed_start:start,p_proposed_end:serviceEnd,p_price_estimate:120,p_message:`TESTOPS:${runID} B01 calendar setup`,
      p_assessment_confirmations:[]},groomer.token);
    offers=await api.restSelect("groomer_offers",`select=*&request_id=eq.${request.id}&groomer_id=eq.${groomer.id}`,groomer.token);
  }
  assert.equal(offers.length,1);const offer=offers[0];
  assert.equal(Date.parse(offer.occupied_start),Date.parse(start));assert.equal(Date.parse(offer.occupied_end),Date.parse(end));
  if(!existsSync(`${directory}/${name}-quote.json`)) writeReceipt(directory,`${name}-quote`,offer);
  let bookings=await api.restSelect("bookings",`select=*&request_id=eq.${request.id}`,customer.token);assert.ok(bookings.length<=1);
  if(!bookings.length) {
    await api.rpc("accept_groomer_offer_v2",{p_offer_id:offer.id,p_expected_quote_revision:offer.quote_revision},customer.token);
    bookings=await api.restSelect("bookings",`select=*&request_id=eq.${request.id}`,customer.token);
  }
  assert.equal(bookings.length,1);const booking=bookings[0];assert.equal(booking.status,"confirmed");
  assert.equal(booking.customer_id,customer.id);assert.equal(booking.groomer_id,groomer.id);
  assert.equal(Date.parse(booking.occupied_start),Date.parse(start));assert.equal(Date.parse(booking.occupied_end),Date.parse(end));
  assert.deepEqual(await api.restSelect("bookings",`select=*&id=eq.${booking.id}`,groomer.token),bookings);
  const [committedRequest]=await api.restSelect("grooming_requests",`select=*&id=eq.${request.id}`,customer.token),
    [committedOffer]=await api.restSelect("groomer_offers",`select=*&id=eq.${offer.id}`,customer.token);
  assert.equal(committedRequest.status,"booked");assert.equal(committedOffer.status,"accepted_by_customer");
  const result={runID,spec,request:committedRequest,offer:committedOffer,booking,at:new Date().toISOString(),scope:intent.scope};
  if(!existsSync(`${directory}/${name}-committed.json`)) writeReceipt(directory,`${name}-committed`,result);
  return result;
}

export function assertSourceScore(actual, source, history, {asOf,serviceAt=source.window[0]}) {
  const pet={...source.pet,species:source.pet.species === "cat" ? "Cat" : "Dog",
    coat_type_source:source.pet.coat_type ? "explicit" : "unknown"};
  let keys=historicalReviewKeys(pet,source.service_type,serviceAt);
  if(serviceAt===source.window[0]) {
    const last=historicalReviewKeys(pet,source.service_type,new Date(Date.parse(source.window[1])-1).toISOString());
    keys=keys.filter(key=>last.includes(key));
  }
  const rows=history.map(h=>({customer:h.customer,species:h.species,service:h.service,
    rating:h.rating,age:(Date.parse(asOf)-Date.parse(h.service_at))/DAY,answers:h.answers}));
  const expected=scoreEvidence({species:source.pet.species,service:source.service_type,keys},rows,actual.distance_miles);
  for(const key of ["f","q","d","b","s"]) {
    if(expected[key]===null) assert.equal(actual[key],null);
    else assert.ok(Number.isFinite(actual[key]) && Math.abs(actual[key]-expected[key])<=1e-7,`Score ${key} differs for ${source.id}`);
  }
  for(const [field,key] of [["positive_weight","positive"],["negative_weight","negative"]]) {
    assert.ok(Math.abs(actual[field]-expected[key])<=1e-7,`Evidence ${field} differs`);
  }
  const valid=history.filter(h=>Date.parse(h.service_at)<=Date.parse(asOf));
  const related=source.service_type==="custom_request" ? [] : valid.filter(h=>h.species===source.pet.species && h.service===source.service_type);
  const fit=related.filter(h=>keys.some(key=>["positive","negative"].includes(h.answers[key])));
  assert.equal(actual.q_review_count,valid.length);
  assert.equal(actual.q_customer_count,new Set(valid.map(h=>h.customer)).size);
  assert.equal(actual.completed_count,related.length);
  assert.equal(actual.related_review_count,fit.length);
  assert.equal(actual.f_customer_count,new Set(fit.map(h=>h.customer)).size);
  assert.equal(actual.state,fit.length ? "available" : "no_evidence");
  const coverage=keys.map(key=>{
    const [dimension,value]=key.split(":"),completed=related.filter(h=>h.allowed_keys.includes(key)).length;
    const positive=related.filter(h=>h.answers[key]==="positive").length,negative=related.filter(h=>h.answers[key]==="negative").length;
    return {dimension,value,completed_count:completed,positive_count:positive,negative_count:negative,unknown_count:completed-positive-negative};
  }).sort((a,b)=>`${a.dimension}:${a.value}`.localeCompare(`${b.dimension}:${b.value}`));
  assert.deepEqual([...actual.coverage].sort((a,b)=>`${a.dimension}:${a.value}`.localeCompare(`${b.dimension}:${b.value}`)),coverage);
  return {keys,expected,coverage};
}

export async function auditSourceScoring({runID,requestMap}) {
  assert.match(runID,/^TESTOPS-T392-[A-Z0-9-]{1,70}$/);
  assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED,"1");
  const directory=`artifacts/testops/${runID}`,fixture=JSON.parse(readFileSync(`${directory}/fixture-v2.json`));
  const {actors}=JSON.parse(readFileSync(`${directory}/inventory.json`));validateActorMap(actors);
  const ids=Object.keys(requestMap);assert.ok(ids.length>0);
  const db=await fixtureDatabase({runID}),results=[];
  for(const groomer of fixture.groomers) {
    const actor=actors.find(a=>a.alias===groomer.id);assert.ok(actor);
    const rows=db.query(`begin read only;set local statement_timeout='45s';
      select r.id,statement_timestamp() as_of,app_private.score_match_evidence(r.id,'${actor.id}',statement_timestamp()) score
      from public.grooming_requests r where r.id in (${db.sqlIDs(ids.map(id=>requestMap[id].id))}) order by r.id;commit;`);
    assert.equal(rows.length,ids.length);
    for(const row of rows) {
      const id=ids.find(id=>requestMap[id].id===row.id),source=fixture.requests.find(r=>r.id===id);assert.ok(source);
      results.push({source:id,groomer:groomer.id,...row});
    }
  }
  const name=`source-scoring-${Date.now()}`;
  writeReceipt(directory,`${name}-raw`,{runID,results,scope:"Private read-only score audit against frozen histories; not UI/ranking-order evidence"});
  for(const row of results) assertSourceScore(row.score,fixture.requests.find(r=>r.id===row.source),
    fixture.history.filter(h=>h.groomer===row.groomer),{asOf:row.as_of});
  writeReceipt(directory,`${name}-verified`,{runID,pairs:results.length,sourceIDs:ids,tolerance:1e-7,raw:`${name}-raw.json`});
  console.log(JSON.stringify({sourceScoring:"PASS",pairs:results.length,sourceIDs:ids}));
  return results;
}

export async function auditClientCustomerPool({runID}) {
  assert.match(runID,/^TESTOPS-T392-[A-Z0-9-]{1,70}$/);
  assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED,"1");
  const directory=`artifacts/testops/${runID}`,fixture=JSON.parse(readFileSync(`${directory}/fixture-v2.json`));
  const files=readdirSync(directory),requests=fixture.requests.filter(r=>r.id!=="R23"),requestMap={},quoteMap={};
  for(const name of files.filter(n=>/^(publication|quote)-audit-.*\.json$/.test(n))) {
    const row=JSON.parse(readFileSync(`${directory}/${name}`));
    for(const [id,value] of Object.entries(row.found)) {
      const map=name.startsWith("publication") ? requestMap : quoteMap;
      if(map[id]) assert.equal(map[id].id,value.id,"Source identity drift across receipts");
      map[id]=value;
    }
  }
  for(const request of requests) {
    assert.ok(requestMap[request.id],`Missing UI source ${request.id}`);
    for(const quote of request.offers) assert.ok(quoteMap[quote.id],`Missing UI quote ${quote.id}`);
  }
  const scores=files.filter(n=>/^source-scoring-.*-raw\.json$/.test(n))
    .flatMap(n=>JSON.parse(readFileSync(`${directory}/${n}`)).results);
  const geometry=requests.flatMap(r=>r.offers.map(o=>{
    const customer=fixture.positions.find(p=>p.alias===r.customer_id),groomer=fixture.positions.find(p=>p.alias===o.groomer_id);
    return {source:r.id,groomer:o.groomer_id,clat:customer.latitude,clon:customer.longitude,glat:groomer.latitude,glon:groomer.longitude};
  }));
  const db=await fixtureDatabase({runID});
  const distances=db.query(`select source,groomer,extensions.st_distance(
    extensions.st_setsrid(extensions.st_makepoint(clon,clat),4326)::extensions.geography,
    extensions.st_setsrid(extensions.st_makepoint(glon,glat),4326)::extensions.geography)/1609.344 distance
    from jsonb_to_recordset(${db.sqlJSON(geometry)}) x(source text,groomer text,clat float8,clon float8,glat float8,glon float8);`);
  assert.equal(distances.length,geometry.length);
  for(const row of distances) {
    const score=scores.find(s=>s.source===row.source&&s.groomer===row.groomer);assert.ok(score,"Missing verified score pair");
    assert.ok(Math.abs(row.distance-score.score.distance_miles)<=1e-7,"Stored location distance differs from frozen coordinates");
  }
  const {api,actors}=await connectClientActors(runID,[...new Set(requests.map(r=>r.customer_id))]);
  const pages=[],groups={},stamp=Date.now(),titles={balanced:"Recommended",distance:"Nearest",earliest:"Earliest appointment",price:"Lowest price"};
  try {
    for(const request of requests) {
      const actor=actors[request.customer_id],sourceDistances=Object.fromEntries(distances.filter(d=>d.source===request.id).map(d=>[d.groomer,d.distance]));
      groups[request.id]=[];
      for(const mode of Object.keys(titles)) {
        const page=await api.rpc("get_ranked_customer_offers_v2",{p_request_id:requestMap[request.id].id,p_sort:mode,p_limit:50,p_cursor:null},actor.token);
        pages.push({source:request.id,mode,page});
        assert.equal(page.algorithm_version,"matching-v1");assert.equal(page.requested_mode,mode);assert.equal(page.effective_mode,mode);
        assert.equal(page.next_cursor,null);assert.equal(page.pending_count,0);
        assert.deepEqual(page.items.map(i=>i.offer.id).sort(),request.offers.map(o=>quoteMap[o.id].id).sort(),"Incomplete or duplicate source pool");
        for(const item of page.items) {
          const source=request.offers.find(o=>quoteMap[o.id].id===item.offer.id),quote=quoteMap[source.id],groomer=fixture.groomers.find(g=>g.id===source.groomer_id);
          assert.equal(item.offer.customer_id,actor.id);assert.equal(item.offer.request_id,requestMap[request.id].id);
          assert.equal(item.offer.groomer_id,quote.groomer_id);assert.equal(item.offer.status,"pending");
          assert.equal(item.quote_evaluation.selectable,true);assert.equal(item.quote_evaluation.terms_valid,true);
          assert.equal(item.offer.price_estimate*100,source.price_estimate_cents);assert.equal(item.offer.message,quote.message);
          assert.equal(Date.parse(item.offer.proposed_start),Date.parse(source.start));assert.equal(Date.parse(item.offer.proposed_end),Date.parse(quote.proposed_end));
          assert.deepEqual(item.offer.agreement_snapshot,quote.agreement_snapshot);
          const history=fixture.history.filter(h=>h.groomer===source.groomer_id),sum=history.reduce((n,h)=>n+h.rating,0),profile=item.groomer_profile;
          assert.equal(profile.user_id,quote.groomer_id);assert.equal(profile.business_name,groomer.alias);
          assert.equal(profile.rating_count,history.length);assert.equal(profile.rating_sum,sum);
          assert.equal(profile.rating_avg,history.length ? Math.round(sum*100/history.length)/100 : 0);
          const baseline=scores.find(s=>s.source===request.id&&s.groomer===source.groomer_id).score,evidence=item.evidence;
          assert.equal(evidence.algorithm_version,"matching-v1");assert.equal(evidence.state,baseline.state);
          assert.equal(evidence.related_review_count,baseline.related_review_count);assert.equal(evidence.independent_customers,baseline.f_customer_count);
          assert.equal(evidence.completed_count,baseline.completed_count);assert.deepEqual(evidence.coverage,baseline.coverage);
          assert.equal(Date.parse(evidence.score_as_of),Date.parse(page.score_as_of));assert.equal(evidence.source_revision,page.ranking_revision);
        }
        const expected=customerOrderGroups(fixture,request,mode,{asOf:page.score_as_of,distances:sourceDistances});
        let offset=0;
        for(const group of expected) {
          assert.deepEqual(page.items.slice(offset,offset+group.length).map(i=>i.offer.id).sort(),group.map(id=>quoteMap[id].id).sort(),`Incorrect ${request.id}/${mode} source order`);
          offset+=group.length;
        }
        groups[request.id].push({title:titles[mode],groups:expected.map(ids=>ids.map(id=>fixture.groomers.find(g=>g.id===request.offers.find(o=>o.id===id).groomer_id).alias))});
      }
      console.log(JSON.stringify({source:request.id,customerModes:4,quotes:request.offers.length,result:"PASS"}));
    }
  } finally {
    writeReceipt(directory,`customer-pool-${stamp}-raw`,{runID,distances,pages,scope:"Full normal source pool, authenticated HTTP; independent coordinates/history/order, not UI acceptance"});
  }
  const result={runID,at:new Date().toISOString(),raw:`customer-pool-${stamp}-raw.json`,groups,requestMap,quoteMap,modes:pages.length};
  writeReceipt(directory,`customer-pool-${stamp}-verified`,result);
  return result;
}

export async function verifyDriverPreflight(runID, cli) {
  assert.match(runID,/^TESTOPS-T392-[A-Z0-9-]{1,70}$/);
  assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED,"1");
  const directory=`artifacts/testops/${runID}`;
  const slots=JSON.parse(readFileSync("tests/fixtures/matching-client-acceptance.json")).slots;
  const builds=JSON.parse(readFileSync(`${directory}/installed-builds.json`));
  assert.equal(new Set(builds.hashes.map(s=>s.build_hash)).size,1);
  const logins=readdirSync(directory).filter(f=>f.startsWith("signin-") && f.endsWith(".json"))
    .map(f=>JSON.parse(readFileSync(`${directory}/${f}`)));
  const run=args=>new Promise((resolve,reject)=>{
    const start=Date.now(),child=spawn(cli,[...args,"--output","json"]);
    let out="",err="";
    child.stdout.on("data",chunk=>{out+=chunk;});child.stderr.on("data",chunk=>{err+=chunk;});
    child.on("error",reject);child.on("close",code=>{
      try {resolve({start,end:Date.now(),code,result:JSON.parse(out),err});}
      catch {reject(Error("Invalid Simulator CLI response"));}
    });
  });
  const observed=[];
  try {
    for (const slot of slots) {
      assert.ok(logins.some(r=>r.actor===slot.actor && r.device===slot.udid && r.role===slot.role && r.exitCode===0),"Slot login missing");
      const before=await run(["ui-automation","snapshot-ui","--simulator-id",slot.udid]);
      observed.push({...slot,before});
      assert.equal(before.result.didError,false);
      assert.ok(before.result.data.capture.scroll.some(row=>row.endsWith(`${slot.role}.tabs`)),`${slot.id} role root missing`);
      const target=before.result.data.capture.targets.find(row=>row.split("|")[2]==="tab" && row.split("|")[3]==="Requests");
      assert.ok(target,`${slot.id} Requests tab missing`);
      observed.at(-1).ref=target.split("|")[0];
    }
    // Separate installed clients receive the same barrier; this proves control,
    // not overlap of the later business HTTP transactions.
    await Promise.all(observed.map(async slot=>{
      slot.action=await run(["ui-automation","tap","--simulator-id",slot.udid,"--element-ref",slot.ref]);
    }));
    for (const slot of observed) {
      assert.equal(slot.action.result.didError,false);
      slot.after=await run(["ui-automation","wait-for-ui","--simulator-id",slot.udid,"--predicate","exists",
        "--identifier",`${slot.role}.requests.list`,"--timeout-ms","20000"]);
      assert.equal(slot.after.result.didError,false);
    }
    writeReceipt(directory,"driver-ready",{runID,at:new Date().toISOString(),all_four_roles_verified:true,
      multi_device_control:true,scope:"Navigation barrier only, not booking HTTP overlap",builds,slots:observed});
    console.log(JSON.stringify({runID,four_roles:true,simultaneous_navigation:true,business_race_coverage:false}));
  } catch(error) {
    writeReceipt(directory,`driver-failed-${Date.now()}`,{error:error.message,slots:observed});throw error;
  }
}

export function compileClientFixture(source, recipe, {anchor, seed}) {
  assert.equal(hash(source), recipe.source_hash, "Source hash drift");
  assert.equal(source.source_kind,"synthetic");
  assert.equal(seed,recipe.seed); assert.equal(seed,392);
  const now = Date.parse(anchor); assert.ok(Number.isFinite(now), "Invalid anchor");
  const days = (Date.parse(`${localDate(now)}T00:00:00Z`) - Date.parse("2026-09-14T00:00:00Z")) / DAY;
  const shiftDays = Math.max(1,Math.ceil((days+2)/7))*7;
  const shifted = stamp => {
    const day = iso(Date.parse(`${stamp.slice(0,10)}T00:00:00Z`)+shiftDays*DAY).slice(0,10);
    return iso(localTime(day,Number(stamp.slice(11,13))) + Number(stamp.slice(14,16))*60000);
  };
  const requests = structuredClone(source.requests).map(r => ({...r,
    window:r.window.map(shifted), offers:r.offers.map(o => ({...o,start:shifted(o.start)})),
    execution_layer:r.id === "R23" ? "runtime_expiry_setup_then_UI_quotes" : "UI_publish_and_quotes"}));
  const customers = [...new Set(requests.map(r => r.customer_id))].sort();
  const occupied = new Map(), daily = new Map(), history = [];
  const used = (actor, start, end) => (occupied.get(actor) ?? []).some(([s,e]) => start<e && end>s);
  const occupy = (actor,s,e) => occupied.set(actor,[...(occupied.get(actor) ?? []),[s,e]]);
  const baseDay = Date.parse(`${localDate(now)}T00:00:00Z`);
  for (const spec of recipe.history) {
    const groomer = source.groomers.find(g => g.id === spec.groomer);
    assert.ok(groomer);
    let deficit = spec.count*5-spec.sum;
    for (let i=0;i<spec.count;i++) {
      const species = i < spec.cat ? "cat" : "dog";
      const customer = spec.groomer === "G06" ? (i<100 ? "C01" : customers[1+(i-100)%21])
        : spec.groomer === "G12" ? recipe.history_policy.sparse_customers[i%3] : customers[(i+Number(spec.groomer.slice(1)))%22];
      const band = i<4 ? [1,7] : [[8,90],[91,360],[361,730]][(i-4)%3];
      let start, day;
      search: for (let attempt=0;attempt<=band[1]-band[0];attempt++) {
        const age = band[0]+((i*37+seed+attempt)%(band[1]-band[0]+1));
        day = iso(baseDay-age*DAY).slice(0,10);
        if (new Date(`${day}T12:00:00Z`).getUTCDay() === 0 || (daily.get(`${spec.groomer}:${day}`)??0)>=4) continue;
        for (let hour=10;hour<=16;hour+=2) {
          const candidate = localTime(day,hour);
          if (!used(spec.groomer,candidate-groomer.buffers_minutes[0]*60000,candidate+(60+groomer.buffers_minutes[1])*60000)
            && !used(customer,candidate,candidate+3600000)) { start=candidate;break search; }
        }
      }
      assert.ok(start, `No historical capacity for ${spec.groomer}/${i}`);
      occupy(spec.groomer,start-groomer.buffers_minutes[0]*60000,start+(60+groomer.buffers_minutes[1])*60000);
      occupy(customer,start,start+3600000);
      daily.set(`${spec.groomer}:${day}`,(daily.get(`${spec.groomer}:${day}`)??0)+1);
      const service = groomer.services[i%groomer.services.length];
      const petSnapshot=historyPet(spec,species,i,start);
      const allowed=historicalReviewKeys(petSnapshot,service,start);
      const answers = Object.fromEntries(allowed.filter((_,k) => i%7 !== 0 && (i%5 !== 0 || k === 0)).map((key,k) =>
        [key,spec.groomer === "G05" && (now-start)/DAY<90 ? "negative" : (i*3+k+seed)%11===0 ? "negative" : "positive"]));
      const reduction = Math.min(deficit, i%4 === 0 ? 2 : 1); deficit-=reduction;
      const id = `H-${spec.groomer}-${String(i+1).padStart(4,"0")}`;
      history.push({id,booking_id:`${id}-booking`,request_id:`${id}-request`,pet_id:`HP-${customer}-${hash(petSnapshot).slice(0,12)}`,
        groomer:spec.groomer,customer,species,service,service_at:iso(start),service_end:iso(start+3600000),
        occupied_start:iso(start-groomer.buffers_minutes[0]*60000),occupied_end:iso(start+(60+groomer.buffers_minutes[1])*60000),
        age_days:(now-start)/DAY,time_zone:recipe.time_zone,status:"completed",source_kind:"synthetic",
        pet_snapshot:petSnapshot,
        allowed_keys:allowed,answers,rating:5-reduction});
    }
    assert.equal(deficit,0,`Rating sum impossible for ${spec.groomer}`);
  }
  const positions = [...source.groomers.map(g=>({alias:g.id,neighborhood:g.neighborhood})),
    ...customers.map(alias=>({alias,neighborhood:requests.find(r=>r.customer_id===alias).neighborhood}))].map((a,i)=>{
      const point=recipe.neighborhoods[a.neighborhood]; assert.ok(point);
      return {...a,...destinationCoordinateWGS84({latitude:point[0],longitude:point[1]},0.05+(i%7)*0.025,(i*137.5)%360),source_kind:"synthetic_offset"};
    });
  const fixture = {schema_version:recipe.schema_version,source_kind:"synthetic",anchor:iso(now),seed,source_hash:hash(source),recipe_hash:hash(recipe),
    shift_days:shiftDays,customers,groomers:structuredClone(source.groomers),requests,positions,history,
    history_expectations:structuredClone(recipe.history),cases:structuredClone(recipe.cases),
    negatives:source.rejected_proposals.map(x=>({...x,start:shifted(x.start)})),
    sequences:structuredClone(source.sequence_checks),budgets:structuredClone(recipe.budgets)};
  validateClientFixture(fixture);
  return fixture;
}

export function validateClientFixture(fixture) {
  assert.equal(fixture.source_kind,"synthetic");
  for (const rows of [fixture.requests,fixture.groomers,fixture.cases,fixture.history]) unique(rows,"id");
  unique(fixture.history,"booking_id"); unique(fixture.history,"request_id");
  const occupations = new Map(), counts = new Map();
  for (const r of fixture.history) {
    assert.equal(r.status,"completed");assert.equal(r.source_kind,"synthetic");
    assert.ok(fixture.customers.includes(r.customer));
    assert.ok(fixture.groomers.find(g=>g.id===r.groomer)?.species.includes(r.species));
    assert.equal(r.pet_snapshot.species.toLowerCase(),r.species,"History pet species mismatch");
    assert.ok(r.pet_snapshot.weight_lbs === null || (Number.isFinite(r.pet_snapshot.weight_lbs) && r.pet_snapshot.weight_lbs>0));
    assert.deepEqual(r.allowed_keys,historicalReviewKeys(r.pet_snapshot,r.service,r.service_at),"History key context mismatch");
    assert.ok(Number.isInteger(r.rating) && r.rating>=1 && r.rating<=5);
    const start=Date.parse(r.service_at),end=Date.parse(r.service_end),now=Date.parse(fixture.anchor);
    assert.ok(start<end && end<now && now-start<=731*DAY,"Invalid historical service time");
    assert.ok(Math.abs(r.age_days-(now-start)/DAY)<1e-10,"History age mismatch");
    for (const [key,value] of Object.entries(r.answers)) {
      assert.ok(r.allowed_keys.includes(key),"Forged answer key");assert.ok(["positive","negative"].includes(value));
    }
    if (r.service === "custom_request") assert.deepEqual(r.allowed_keys,[]);
    const day=`${r.groomer}:${localDate(start)}`;
    counts.set(day,(counts.get(day)??0)+1); assert.ok(counts.get(day)<=4,"Daily capacity exceeded");
    for (const [actor,s,e] of [[r.customer,start,end],[r.groomer,Date.parse(r.occupied_start),Date.parse(r.occupied_end)]]) {
      assert.ok(s<=start && e>=end,"Invalid occupancy");
      const existing=occupations.get(actor)??[];
      assert.ok(!existing.some(([a,b])=>s<b && e>a),`Historical overlap ${actor}`);
      occupations.set(actor,[...existing,[s,e]]);
    }
  }
  for (const expected of fixture.history_expectations) {
    const rows=fixture.history.filter(r=>r.groomer===expected.groomer);
    assert.equal(rows.length,expected.count); assert.equal(rows.reduce((s,r)=>s+r.rating,0),expected.sum);
    assert.equal(rows.filter(r=>r.species==="cat").length,expected.cat);
  }
  const countsResult = {customers:fixture.customers.length,groomers:fixture.groomers.length,
    pets:new Set(fixture.requests.map(r=>r.pet.id)).size,requests:fixture.requests.length,
    quotes:fixture.requests.reduce((s,r)=>s+r.offers.length,0),negatives:fixture.negatives.length,
    histories:fixture.history.length,stars:fixture.history.reduce((s,r)=>s+r.rating,0),cases:fixture.cases.length};
  assert.deepEqual(countsResult,{customers:22,groomers:12,pets:24,requests:24,quotes:57,negatives:8,histories:1228,stars:5791,cases:60});
  return {counts:countsResult,hash:hash(fixture)};
}

async function main() {
  const config=parseClientArguments(process.argv.slice(2));
  if (config.mode === "prepare") return prepareClientFixture(config);
  if (config.mode === "cleanup") return cleanupClientFixture(config);
  if (config.mode !== "plan") throw Error("Client phase adapters not yet ready; no credentials loaded or writes made");
  const source=JSON.parse(readFileSync("tests/fixtures/matching-marketplace-la-synthetic.json"));
  const recipe=JSON.parse(readFileSync("tests/fixtures/matching-client-acceptance.json"));
  const fixture=compileClientFixture(source,recipe,{anchor:config.anchor??new Date().toISOString(),seed:392});
  writeReceipt(`artifacts/testops/${config.runID}`,"fixture",fixture);
  console.log(JSON.stringify({runID:config.runID,...validateClientFixture(fixture),ui_cases_passed:0,remote_writes:0}));
}

const profileFields = {
  customer_profiles:["street_address","address_line_2","city","state","zip_code","address_location_id"],
  groomer_profiles:["business_name","bio","is_active","base_street_address","base_address_line_2","base_city","base_state",
    "base_zip_code","address_location_id","service_location_mode","service_location_modes","service_radius_miles"],
};
const backupTables = {
  customer_profiles:["public","user_id"],groomer_profiles:["public","user_id"],groomer_services:["public","groomer_id"],
  groomer_availability_windows:["public","groomer_id"],groomer_booking_preferences:["public","groomer_id"],
  groomer_time_off_windows:["public","groomer_id"],pets:["public","customer_id"],
  customer_notifications:["public","customer_id"],groomer_notifications:["public","groomer_id"],
  address_locations:["app_private","owner_id"],
};
async function fixtureDatabase(config) {
  process.env.TESTOPS_RUN_ID=config.runID;
  const db=await import("./test-t387-booking-fixture.mjs");
  assert.equal(db.runID,config.runID,"Fixture module run identity mismatch");
  return db;
}
export function captureSetup(db, actors) {
  const ids=db.sqlIDs(actors.map(a=>a.id));
  return db.query(`select ${Object.entries(backupTables).map(([table,[schema,key]])=>
    `(select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]') from ${schema}.${table} t where ${key} in (${ids})) ${table}`
  ).join(",")},(select to_jsonb(c)-'signing_key' from app_private.match_ranking_config c where singleton) ranking_config;`)[0];
}
export function assertRankingPolicyRestored(actual, baseline) {
  if(Object.hasOwn(actual,"privacy_revision")) {
    assert.match(actual.privacy_revision,/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i);
    // D-056 added an independently advancing privacy epoch, not a ranking policy change.
    const {privacy_revision:currentEpoch,...currentPolicy}=actual;
    const {privacy_revision:originalEpoch,...originalPolicy}=baseline;
    assert.deepEqual(currentPolicy,originalPolicy,"Ranking policy drift; preserve and reconcile");
  } else assert.deepEqual(actual,baseline);
}
export function guardSetupSQL(db, actors, expected, tables = Object.keys(backupTables)) {
  assert.ok(tables.length > 0 && new Set(tables).size === tables.length);
  assert.ok(tables.every(table => Object.hasOwn(backupTables, table) && Array.isArray(expected[table])));
  const ids=db.sqlIDs(actors.map(a=>a.id));
  const omitted="array['updated_at','eligibility_revision']";
  return `select 1 from public.profiles where id in (${ids}) order by id for update;
    ${actors.filter(a=>a.role==="groomer").map(a=>`select pg_advisory_xact_lock(hashtextextended('${a.id}',71071));`).join("\n")}
    ${tables.map(table=>[table,backupTables[table]]).map(([table,[schema,key]])=>`
      select 1 from ${schema}.${table} where ${key} in (${ids}) for update;
      do $$ begin if
        (select coalesce(jsonb_agg(to_jsonb(t)-${omitted} order by (to_jsonb(t)-${omitted})::text),'[]') from ${schema}.${table} t where ${key} in (${ids}))
        is distinct from
        (select coalesce(jsonb_agg(value-${omitted} order by (value-${omitted})::text),'[]') from jsonb_array_elements(${db.sqlJSON(expected[table])}))
        then raise exception 'Concurrent ${table} change; preserve existing work';end if;end $$;`).join("\n")}`;
}

export async function prepareClientFixture(config) {
  const directory=`artifacts/testops/${config.runID}`;
  if (existsSync(`${directory}/setup-rehearsal-restored.json`)) return prepareBaseFixture(config);
  const ready=JSON.parse(readFileSync(`${directory}/driver-ready.json`));
  assert.equal(ready.runID,config.runID);assert.equal(ready.all_four_roles_verified,true);
  assert.equal(ready.multi_device_control,true);
  const fixture=JSON.parse(readFileSync(`${directory}/fixture.json`)); validateClientFixture(fixture);
  const inventory=JSON.parse(readFileSync(`${directory}/inventory.json`));validateActorMap(inventory.actors);
  // The first committed preparation is deliberately one actor pair and one pet.
  const previous=existsSync(`${directory}/setup-rehearsal-manifest.json`)
    ? JSON.parse(readFileSync(`${directory}/setup-rehearsal-manifest.json`)) : null;
  assert.equal(existsSync(`${directory}/setup-rehearsal-committed.json`),false,"Restore committed rehearsal before another preparation");
  assert.equal(existsSync(`${directory}/setup-rehearsal-restored.json`),false,"Rehearsal completed; next stage is full preparation");
  const actors=inventory.actors.filter(a=>["C01","G01"].includes(a.alias));assert.equal(actors.length,2);
  const db=await fixtureDatabase(config), ids=db.sqlIDs(actors.map(a=>a.id));
  const before=captureSetup(db,actors);
  assertReversibleSetupServices(before.groomer_services);
  assert.equal(before.ranking_config.enabled,true);
  assert.equal(before.groomer_profiles[0].rating_count,0);assert.equal(Number(before.groomer_profiles[0].rating_sum),0);
  const manifest=previous??{runID:config.runID,kind:"rehearsal",input_hash:hash(fixture),actors,before,
    marker:`TESTOPS:${config.runID} rehearsal`,location_ids:Object.fromEntries(actors.map(a=>[a.alias,randomUUID()])),
    started_at:new Date().toISOString()};
  if (previous) {
    assert.equal(previous.runID,config.runID);assert.equal(previous.input_hash,hash(fixture));
    assert.deepEqual(previous.actors,actors);assert.deepEqual(before,previous.before,"Previous batch is not rolled back; reconcile instead of retrying");
    const [owned]=db.query(`select count(*)::integer n from app_private.address_locations where id in (${db.sqlIDs(Object.values(previous.location_ids))});`);
    assert.equal(owned.n,0,"Previous batch may have committed; never blindly retry");
    writeReceipt(directory,`setup-rehearsal-retry-${Date.now()}`,{reconciled:"not_committed",at:new Date().toISOString(),
      previous_error:existsSync(`${directory}/query-error.json`)?JSON.parse(readFileSync(`${directory}/query-error.json`)):null});
  } else writeReceipt(directory,"setup-rehearsal-manifest",manifest);
  const recipe=JSON.parse(readFileSync("tests/fixtures/matching-client-acceptance.json"));
  const input={...manifest,positions:fixture.positions,groomer:fixture.groomers[0],request:fixture.requests[0],
    sizes:JSON.parse(readFileSync("tests/fixtures/matching-marketplace-la-synthetic.json")).service_size_configurations.G01};
  const result=db.query(`begin;set local lock_timeout='5s';set local statement_timeout='100s';
    ${guardSetupSQL(db,actors,before)}
    do $$ declare d jsonb:=${db.sqlJSON(input)};a jsonb;p jsonb;g jsonb:=d->'groomer';cfg jsonb;pet uuid;gid uuid;
    begin
      if exists(select 1 from public.grooming_requests where customer_id in (${ids}) and status in('open','has_offers') and expires_at>now())
        or exists(select 1 from public.bookings where (customer_id in (${ids}) or groomer_id in (${ids})) and status='confirmed')
        or exists(select 1 from public.groomer_offers o join public.grooming_requests r on r.id=o.request_id
          where o.groomer_id in (${ids}) and o.status='pending' and r.status in('open','has_offers') and r.expires_at>now()) then
        raise exception 'Rehearsal actor no longer idle';end if;
      for a in select value from jsonb_array_elements(d->'actors') loop
        select value into strict p from jsonb_array_elements(d->'positions') where value->>'alias'=a->>'alias';
        insert into app_private.address_locations(id,owner_id,provider,country_code,latitude,longitude,resolution_source,user_confirmed_at,time_zone_identifier)
          values((d->'location_ids'->>(a->>'alias'))::uuid,(a->>'id')::uuid,'apple_maps','US',
            (p->>'latitude')::float8,(p->>'longitude')::float8,'manual_geocode',now(),'America/Los_Angeles');
        if a->>'role'='customer' then
          update public.customer_profiles set street_address='${syntheticStreetAddress}',address_line_2=null,city=p->>'neighborhood',
            state='CA',zip_code='90001',address_location_id=(d->'location_ids'->>(a->>'alias'))::uuid where user_id=(a->>'id')::uuid;
        else
          gid:=(a->>'id')::uuid;
          perform pg_advisory_xact_lock(hashtextextended(gid::text,71071));
          update public.groomer_profiles set business_name=g->>'alias',bio=g->>'context',is_active=true,
            base_street_address='${syntheticStreetAddress}',base_address_line_2=null,base_city=g->>'neighborhood',base_state='CA',base_zip_code='90001',
            address_location_id=(d->'location_ids'->>(a->>'alias'))::uuid,service_location_mode=g->>'location_mode',
            service_location_modes=array[g->>'location_mode'],service_radius_miles=25 where user_id=gid;
          update public.groomer_services set is_active=false where groomer_id=gid and is_active;
          insert into public.groomer_services(groomer_id,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species)
            select gid,'Synthetic source service',d->>'marker',100,case s when 'nail_trim' then 20 else 60 end,
              array(select jsonb_array_elements_text(d->'sizes')),true,s,array(select jsonb_array_elements_text(g->'species'))
              from jsonb_array_elements_text(g->'services') s;
          perform set_config('request.jwt.claims',jsonb_build_object('sub',gid,'role','authenticated','is_anonymous',false)::text,true);
          perform set_config('request.jwt.claim.sub',gid::text,true);
          cfg:=public.get_groomer_availability();
          perform public.save_groomer_availability(cfg->>'revision',
            (select jsonb_agg(jsonb_build_object('weekday',day,'start_time',g->'hours_local'->>0,'end_time',g->'hours_local'->>1,
              'is_enabled',day<>7,'timezone','America/Los_Angeles')) from generate_series(1,7) day),
            jsonb_build_object('max_appointments_per_day',4,'minimum_advance_notice_days',0,'auto_accept_bookings',false,
              'timing_buffers',jsonb_build_object('preparation_minutes',0,'cleanup_minutes',15,'inbound_travel_minutes',0,'outbound_travel_minutes',0)),'[]');
        end if;
      end loop;
      select value into a from jsonb_array_elements(d->'actors') where value->>'alias'='C01';
      perform set_config('request.jwt.claims',jsonb_build_object('sub',a->>'id','role','authenticated','is_anonymous',false)::text,true);
      perform set_config('request.jwt.claim.sub',a->>'id',true);
      select id into pet from public.save_my_pet_v2(null,((d->'request'->'pet')-'id')||jsonb_build_object('species','Dog',
        'grooming_notes',(d->>'marker')||' P01'),true);
      perform set_config('test.t392_prepared',jsonb_build_object('pet_id',pet,'source_id','P01')::text,true);
    end $$;
    select current_setting('test.t392_prepared')::jsonb receipt;commit;`)[0];
  const configured=captureSetup(db,actors);
  writeReceipt(directory,"setup-rehearsal-committed",{...result,configured,at:new Date().toISOString(),recipe_hash:hash(recipe)});
  console.log(JSON.stringify({runID:config.runID,stage:"rehearsal_prepared",pets:1,groomers:1,histories:0,
    next:"Verify both clients, then cleanup rehearsal; full import remains pending"}));
}

async function prepareBaseFixture(config) {
  const directory=`artifacts/testops/${config.runID}`;
  assert.equal(existsSync(`${directory}/base-committed.json`),false,"Base already committed; continue with owned history/UI, never reseed");
  const fixture=JSON.parse(readFileSync(`${directory}/fixture-v2.json`));validateClientFixture(fixture);
  const {actors:inventory}=JSON.parse(readFileSync(`${directory}/inventory.json`));validateActorMap(inventory);
  const actors=inventory.filter(a=>fixture.customers.includes(a.alias)||fixture.groomers.some(g=>g.id===a.alias));
  assert.equal(actors.length,34);
  const db=await fixtureDatabase(config),before=captureSetup(db,actors);
  const isolated=isolatedServices(before.groomer_services,fixture.groomers.map(g=>g.hours_local));
  assert.equal(before.ranking_config.enabled,true);
  assert.ok(before.groomer_profiles.every(g=>g.rating_count===0 && Number(g.rating_sum)===0),"Existing history must be preserved");
  const previous=existsSync(`${directory}/base-manifest.json`) ? JSON.parse(readFileSync(`${directory}/base-manifest.json`)) : null;
  const manifest=previous??{runID:config.runID,kind:"base",input_hash:hash(fixture),actors,before,
    marker:`TESTOPS:${config.runID} base`,location_ids:Object.fromEntries(actors.map(a=>[a.alias,randomUUID()])),
    started_at:new Date().toISOString()};
  if(previous) {
    assert.equal(previous.input_hash,hash(fixture));assert.deepEqual(previous.actors,actors);
    assert.deepEqual(before,previous.before,"Previous batch may have committed; reconcile before retry");
    writeReceipt(directory,`base-retry-${Date.now()}`,{reconciled:"not_committed",
      previous_error:existsSync(`${directory}/query-error.json`)?JSON.parse(readFileSync(`${directory}/query-error.json`)):null});
  } else writeReceipt(directory,"base-manifest",manifest);
  const input={...manifest,isolated_services:isolated,positions:fixture.positions,groomers:fixture.groomers,requests:fixture.requests,
    sizes:JSON.parse(readFileSync("tests/fixtures/matching-marketplace-la-synthetic.json")).service_size_configurations};
  const ids=db.sqlIDs(actors.map(a=>a.id));
  const [result]=db.query(`begin;set local lock_timeout='5s';set local statement_timeout='100s';
    ${guardSetupSQL(db,actors,before)}
    do $$ declare d jsonb:=${db.sqlJSON(input)};a jsonb;p jsonb;g jsonb;r jsonb;cfg jsonb;pet uuid;actor uuid;pets jsonb:='{}';
    begin
      if exists(select 1 from public.grooming_requests where customer_id in (${ids}) and status in('open','has_offers') and expires_at>now())
        or exists(select 1 from public.bookings where (customer_id in (${ids}) or groomer_id in (${ids})) and status='confirmed')
        or exists(select 1 from public.groomer_offers o join public.grooming_requests r on r.id=o.request_id
          where o.groomer_id in (${ids}) and o.status='pending' and r.status in('open','has_offers') and r.expires_at>now()) then
        raise exception 'Base actor no longer idle';end if;
      for a in select value from jsonb_array_elements(d->'actors') loop
        actor:=(a->>'id')::uuid;
        select value into strict p from jsonb_array_elements(d->'positions') where value->>'alias'=a->>'alias';
        insert into app_private.address_locations(id,owner_id,provider,country_code,latitude,longitude,resolution_source,user_confirmed_at,time_zone_identifier)
          values((d->'location_ids'->>(a->>'alias'))::uuid,actor,'apple_maps','US',(p->>'latitude')::float8,(p->>'longitude')::float8,
            'manual_geocode',now(),'America/Los_Angeles');
        if a->>'role'='customer' then
          update public.customer_profiles set street_address='${syntheticStreetAddress}',address_line_2=null,city=p->>'neighborhood',
            state='CA',zip_code='90001',address_location_id=(d->'location_ids'->>(a->>'alias'))::uuid where user_id=actor;
        else
          select value into strict g from jsonb_array_elements(d->'groomers') where value->>'id'=a->>'alias';
          update public.groomer_profiles set business_name=g->>'alias',bio=g->>'context',is_active=true,
            base_street_address='${syntheticStreetAddress}',base_address_line_2=null,base_city=g->>'neighborhood',base_state='CA',base_zip_code='90001',
            address_location_id=(d->'location_ids'->>(a->>'alias'))::uuid,service_location_mode=g->>'location_mode',
            service_location_modes=array[g->>'location_mode'],service_radius_miles=coalesce((g->>'service_radius_miles')::integer,25) where user_id=actor;
          update public.groomer_services t set is_active=b.is_active,duration_minutes=b.duration_minutes from
            jsonb_populate_recordset(null::public.groomer_services,d->'isolated_services') b where t.id=b.id and t.groomer_id=actor;
          insert into public.groomer_services(groomer_id,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species)
            select actor,'Synthetic source service',d->>'marker',100,case s when 'nail_trim' then 20 else 60 end,
              array(select jsonb_array_elements_text(d->'sizes'->(g->>'id'))),true,s,
              array(select jsonb_array_elements_text(g->'species')) from jsonb_array_elements_text(g->'services') s;
          perform set_config('request.jwt.claim.sub',actor::text,true);
          perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
          perform set_config('role','authenticated',true);
          cfg:=public.get_groomer_availability();
          perform public.save_groomer_availability(cfg->>'revision',
            (select jsonb_agg(jsonb_build_object('weekday',day,'start_time',g->'hours_local'->>0,'end_time',g->'hours_local'->>1,
              'is_enabled',day<>7,'timezone','America/Los_Angeles')) from generate_series(1,7) day),
            jsonb_build_object('max_appointments_per_day',4,'minimum_advance_notice_days',0,'auto_accept_bookings',false,
              'timing_buffers',jsonb_build_object('preparation_minutes',0,'cleanup_minutes',(g->'buffers_minutes'->>1)::integer,
                'inbound_travel_minutes',(g->'buffers_minutes'->>0)::integer,'outbound_travel_minutes',0)),'[]');
          perform set_config('role','none',true);
        end if;
      end loop;
      for r in select value from jsonb_array_elements(d->'requests') loop
        select (value->>'id')::uuid into strict actor from jsonb_array_elements(d->'actors') where value->>'alias'=r->>'customer_id';
        perform set_config('request.jwt.claim.sub',actor::text,true);
        perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
        perform set_config('role','authenticated',true);
        select id into pet from public.save_my_pet_v2(null,((r->'pet')-'id'-'breed_note')||jsonb_build_object(
          'species',initcap(r->'pet'->>'species'),'grooming_notes',(d->>'marker')||' '||(r->'pet'->>'id')),
          r->'pet'->>'coat_type' is not null);
        perform set_config('role','none',true);
        pets:=pets||jsonb_build_object(r->'pet'->>'id',pet);
      end loop;
      perform set_config('test.t392_base',jsonb_build_object('pets',pets)::text,true);
    end $$;
    select current_setting('test.t392_base')::jsonb receipt;commit;`);
  const configured=captureSetup(db,actors);
  assert.equal(Object.keys(result.receipt.pets).length,24);
  writeReceipt(directory,"base-committed",{...result,configured,at:new Date().toISOString(),input_hash:hash(fixture)});
  console.log(JSON.stringify({runID:config.runID,stage:"base_prepared",customers:22,groomers:12,pets:24,histories:0}));
}

export async function repairClientFixtureAddresses(config) {
  const directory=`artifacts/testops/${config.runID}`;
  const manifest=JSON.parse(readFileSync(`${directory}/base-manifest.json`));
  const committed=JSON.parse(readFileSync(`${directory}/base-committed.json`));
  assert.equal(manifest.runID,config.runID);validateActorMap(manifest.actors);
  const db=await fixtureDatabase(config),before=captureSetup(db,manifest.actors);
  const fields={customer_profiles:"street_address",groomer_profiles:"base_street_address"};
  const configured=structuredClone(committed.configured);
  for(const [table,field] of Object.entries(fields)) {
    for(const row of before[table]) {
      const original=committed.configured[table].find(r=>r.user_id===row.user_id);
      assert.ok(original);assert.equal(row.address_location_id,original.address_location_id);
      assert.ok(["TestOps synthetic location",syntheticStreetAddress].includes(row[field]),"Unrelated address edit; preserve it");
    }
    for(const row of configured[table]) row[field]=syntheticStreetAddress;
  }
  const intent={runID:config.runID,fields,street:syntheticStreetAddress,configured,at:new Date().toISOString()};
  if(!existsSync(`${directory}/base-address-repair-input.json`)) writeReceipt(directory,"base-address-repair-input",intent);
  else assert.deepEqual(JSON.parse(readFileSync(`${directory}/base-address-repair-input.json`)).configured,configured);
  db.query(`begin;set local lock_timeout='5s';set local statement_timeout='30s';
    select 1 from public.profiles where id in (${db.sqlIDs(manifest.actors.map(a=>a.id))}) order by id for update;
    ${Object.entries(fields).map(([table,field])=>`
      select 1 from public.${table} where user_id in (${db.sqlIDs(before[table].map(r=>r.user_id))}) for update;
      do $$ begin if exists(select 1 from public.${table} t join
        jsonb_populate_recordset(null::public.${table},${db.sqlJSON(before[table])}) b using(user_id)
        where to_jsonb(t)-'updated_at'-'eligibility_revision' is distinct from to_jsonb(b)-'updated_at'-'eligibility_revision')
        then raise exception 'Concurrent profile change; preserve it';end if;end $$;
      update public.${table} set ${field}='${syntheticStreetAddress}'
        where user_id in (${db.sqlIDs(before[table].map(r=>r.user_id))});`).join("\n")}
    commit;`);
  const after=captureSetup(db,manifest.actors);
  for(const [table,field] of Object.entries(fields)) {
    for(const row of after[table]) {
      const expected={...before[table].find(r=>r.user_id===row.user_id),[field]:syntheticStreetAddress};
      const normalized=r=>Object.fromEntries(Object.entries(r).filter(([k])=>!["updated_at","eligibility_revision"].includes(k)));
      assert.deepEqual(normalized(row),normalized(expected));
    }
  }
  if(!existsSync(`${directory}/base-address-repaired.json`)) writeReceipt(directory,"base-address-repaired",{
    runID:config.runID,at:new Date().toISOString(),profiles:34,configured,after});
  console.log(JSON.stringify({runID:config.runID,synthetic_addresses_repaired:34}));
}

export async function cleanupClientFixture(config) {
  const directory=`artifacts/testops/${config.runID}`;
  const stage=existsSync(`${directory}/base-committed.json`) ? "base" : "setup-rehearsal";
  const manifest=JSON.parse(readFileSync(`${directory}/${stage}-manifest.json`));
  const committed=JSON.parse(readFileSync(`${directory}/${stage}-committed.json`));
  if(stage==="base" && existsSync(`${directory}/base-address-repaired.json`)) {
    const repair=JSON.parse(readFileSync(`${directory}/base-address-repaired.json`));
    assert.equal(repair.runID,config.runID);
    committed.configured=repair.configured;
  }
  assert.equal(manifest.runID,config.runID);
  assert.equal(existsSync(`${directory}/${stage}-restored.json`),false,"Setup already restored");
  const db=await fixtureDatabase(config);
  const legacyIDs=config.restoreLegacySpecies ? legacyRestorationIDs(manifest) : [];
  const securitySQL=`select jsonb_build_object('table',(select jsonb_build_object('rls',relrowsecurity,
    'force_rls',relforcerowsecurity,'acl',relacl) from pg_class where oid='public.groomer_services'::regclass),
    'triggers',(select jsonb_agg(jsonb_build_object('oid',oid,'enabled',tgenabled,'definition',pg_get_triggerdef(oid)) order by oid)
      from pg_trigger where tgrelid='public.groomer_services'::regclass),
    'guard',pg_get_functiondef('app_private.guard_service_species()'::regprocedure)) security;`;
  const securityBefore=legacyIDs.length ? db.query(securitySQL)[0].security : null;
  if(legacyIDs.length) assert.ok(securityBefore.triggers.some(t=>t.enabled==='O' && t.definition.includes('groomer_services_species')));
  const current=captureSetup(db,manifest.actors);
  const normalize=rows=>rows.map(r=>Object.fromEntries(Object.entries(r).filter(([key])=>!["updated_at","eligibility_revision"].includes(key))));
  for (const table of Object.keys(backupTables)) assert.deepEqual(normalize(current[table]),normalize(committed.configured[table]),
    `Concurrent ${table} change; preserve and reconcile before cleanup`);
  assertRankingPolicyRestored(current.ranking_config,manifest.before.ranking_config);
  const groomers=db.sqlIDs(manifest.actors.filter(a=>a.role==="groomer").map(a=>a.id));
  const pets=stage === "base" ? Object.values(committed.receipt.pets) : [committed.receipt.pet_id];
  const ownedPets=committed.configured.pets.filter(p=>pets.includes(p.id));
  assert.equal(ownedPets.length,pets.length);
  assert.ok(ownedPets.every(p=>p.grooming_notes.startsWith(`${manifest.marker} P`)));
  const restoreProfiles=Object.entries(profileFields).map(([table,fields])=>{
    return `update public.${table} t set ${fields.map(k=>`${k}=b.${k}`).join(",")} from
      jsonb_populate_recordset(null::public.${table},${db.sqlJSON(manifest.before[table])}) b where t.user_id=b.user_id;`;
  }).join("\n");
  db.query(`begin;set local lock_timeout='5s';set local statement_timeout='60s';select set_config('app.availability_batch','1',true);
    ${legacyIDs.length ? "lock table public.groomer_services in access exclusive mode;" : ""}
    ${guardSetupSQL(db,manifest.actors,committed.configured)}
    ${legacyIDs.length ? `do $$ begin if not exists(select 1 from pg_trigger where tgrelid='public.groomer_services'::regclass
      and tgname='groomer_services_species' and tgenabled='O') then raise exception 'Species guard state changed';end if;end $$;` : ""}
    do $$ begin if exists(select 1 from public.grooming_requests where pet_id in (${db.sqlIDs(pets)})) then
      raise exception 'Setup pets still have transactions; clean exact owned transactions first';end if;end $$;
    delete from public.pets t using jsonb_populate_recordset(null::public.pets,${db.sqlJSON(ownedPets)}) b
      where t.id=b.id and t.customer_id=b.customer_id and t.grooming_notes=b.grooming_notes;
    delete from public.groomer_services where groomer_id in (${groomers}) and description=(${db.sqlJSON(manifest.marker)}#>>'{}');
    ${legacyIDs.length ? `alter table public.groomer_services disable trigger groomer_services_species;` : ""}
    update public.groomer_services t set is_active=b.is_active,duration_minutes=b.duration_minutes from
      jsonb_populate_recordset(null::public.groomer_services,${db.sqlJSON(manifest.before.groomer_services)}) b where t.id=b.id;
    ${legacyIDs.length ? `alter table public.groomer_services enable trigger groomer_services_species;` : ""}
    ${["groomer_availability_windows","groomer_booking_preferences","groomer_time_off_windows"].map(table=>`
      delete from public.${table} where groomer_id in (${groomers});
      insert into public.${table} select * from jsonb_populate_recordset(null::public.${table},${db.sqlJSON(manifest.before[table])});
      update public.${table} set updated_at=statement_timestamp() where groomer_id in (${groomers});`).join("\n")}
    ${restoreProfiles}
    delete from app_private.address_locations where id in (${db.sqlIDs(Object.values(manifest.location_ids))});
    commit;`);
  if(legacyIDs.length) assert.deepEqual(db.query(securitySQL)[0].security,securityBefore,"Service security state changed");
  const after=captureSetup(db,manifest.actors);
  for (const table of Object.keys(backupTables)) assert.deepEqual(normalize(after[table]),normalize(manifest.before[table]),`Restoration mismatch: ${table}`);
  assertRankingPolicyRestored(after.ranking_config,manifest.before.ranking_config);
  writeReceipt(directory,`${stage}-restored`,{at:new Date().toISOString(),restored:true,after,
    ...(legacyIDs.length?{legacy_exception:{ids:legacyIDs,security_unchanged:true,authorization:"2026-09-15 user requested resolution after exact-restoration explanation"}}:{})});
  console.log(JSON.stringify({runID:config.runID,stage,restored:true}));
}

export async function cleanupHistoryRehearsal(config) {
  const directory=`artifacts/testops/${config.runID}`;
  assert.equal(existsSync(`${directory}/history-rehearsal-restored.json`),false);
  const {input}=JSON.parse(readFileSync(`${directory}/history-rehearsal-input.json`));
  const {before,actors}=JSON.parse(readFileSync(`${directory}/history-rehearsal-baseline.json`));
  const receipts=JSON.parse(readFileSync(`${directory}/history-rehearsal-committed.json`)).result[0].receipts;
  assert.equal(Object.keys(receipts).length,1);assert.equal(before.conversations.length,0);
  const row=receipts[input.history[0].id],db=await fixtureDatabase(config);
  const ids=db.sqlIDs(actors.map(a=>a.id)),request=db.sqlIDs([row.request_id]),booking=db.sqlIDs([row.booking_id]);
  const [chat]=db.query(`select c.id from public.conversations c join public.bookings b
    on b.customer_id=c.customer_id and b.groomer_id=c.groomer_id where b.id in (${booking});`);
  assert.ok(chat?.id);
  const conversation=db.sqlIDs([chat.id]);
  db.query(`begin;set local lock_timeout='5s';set local statement_timeout='60s';
    select 1 from public.profiles where id in (${ids}) order by id for update;
    select 1 from public.conversations where id in (${conversation}) for update;
    do $$ begin
      if not exists(select 1 from public.grooming_requests where id in (${request})
        and service_notes=(${db.sqlJSON(`${input.marker} ${input.history[0].id}`)}#>>'{}')) then raise exception 'History ownership changed';end if;
      if exists(select 1 from public.bookings b join public.conversations c
          on c.customer_id=b.customer_id and c.groomer_id=b.groomer_id where c.id in (${conversation}) and b.id not in (${booking}))
        or exists(select 1 from public.messages where conversation_id in (${conversation})
          and not (kind='booking_card' and booking_id in (${booking}))
          and not (kind='text' and body='Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!'))
        then raise exception 'Unrelated conversation activity; preserve it';end if;
    end $$;
    delete from public.customer_notifications where related_request_id in (${request}) or related_booking_id in (${booking}) or related_conversation_id in (${conversation});
    delete from public.groomer_notifications where related_request_id in (${request}) or related_booking_id in (${booking}) or related_conversation_id in (${conversation});
    delete from public.conversations where id in (${conversation});
    select app_private.cleanup_testops_request_address_location(id,'${config.runID}') from public.grooming_requests where id in (${request});
    delete from public.grooming_requests where id in (${request});
    delete from public.pets where id in (${db.sqlIDs([row.pet_id])}) and customer_id in (${ids})
      and grooming_notes=(${db.sqlJSON(`${input.marker} ${input.history[0].pet_id}`)}#>>'{}');
    commit;`);
  const after=captureSetup(db,actors),normalize=rows=>rows.map(r=>Object.fromEntries(Object.entries(r)
    .filter(([key])=>!["updated_at","eligibility_revision"].includes(key)))).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));
  for(const table of ["groomer_profiles","customer_notifications","groomer_notifications"])
    assert.deepEqual(normalize(after[table]),normalize(before[table]),`Historical restoration mismatch: ${table}`);
  const [remaining]=db.query(`select (select count(*) from public.grooming_requests where id in (${request})) requests,
    (select count(*) from public.bookings where id in (${booking})) bookings,
    (select count(*) from public.reviews where id in (${db.sqlIDs([row.review_id])})) reviews,
    (select count(*) from public.pets where id in (${db.sqlIDs([row.pet_id])})) pets,
    (select count(*) from app_private.booking_review_contexts where booking_id in (${booking})) contexts;`);
  assert.ok(Object.values(remaining).every(n=>Number(n)===0));
  writeReceipt(directory,"history-rehearsal-restored",{at:new Date().toISOString(),restored:true,remaining,after});
  console.log(JSON.stringify({history_rehearsal_restored:true,remaining}));
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(error=>{console.error(error.message);process.exitCode=1;});
}
