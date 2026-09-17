import assert from "node:assert/strict";
import { randomUUID, createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { parseCustomerProfiles, parseGroomerProfiles } from "./testops-core.mjs";
import { scoreEvidence } from "../tests/support/matching-rating-reference.mjs";
import { connect, prepare, recover, cleanup, query, saveArtifact, intent,
  runID, marker, sqlIDs, sqlJSON, isMatchingRun, rankingValidationPlan, fixedPagingSchedule } from "./test-t387-booking-fixture.mjs";

assert.ok(isMatchingRun(runID), "Invalid matching run ID");
const mode = process.argv[2];
assert.ok(["run", "prepare", "marketplace-db", "revision-live", "paging-matrix", "role-latency", "verify", "roles", "review-db", "review-race", "privacy-db", "event-db", "admission-db", "paging-db", "paging-live", "http-ranking", "cohort-db", "evidence-db", "time-db", "ranges-db", "qualification-clock-db", "release-db", "fallback-db", "scale-db", "live-worker", "cleanup"].includes(mode), "Unknown scenario mode");
assert.ok(process.argv.includes("--execute"), "Explicit --execute is required before any remote scenario operation");
if (mode === "marketplace-db") {
  await marketplaceDatabase();
  process.exit(0);
}
const context = await connect(mode === "cohort-db"
  ? ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "G1", "G2"]
  : ["C1", "C2", "X", "G1", "G2"]);
const {api, actors} = context;
const rpc = (actor, name, params) => api.rpc(name, params, actors[actor].token);
const results = [];
const saved = ["run", "prepare"].includes(mode) ? await prepare(context) : recover();
saved.matching ??= {pets: [], services: []};
saveArtifact("recovery", saved);
const originalRequest = api.request.bind(api);
api.request = async (path, init, kind) => {
  try { return await originalRequest(path, {...init,signal:AbortSignal.timeout(45000)},kind); }
  catch (error) {
    if (!error.httpStatus && init.method !== "GET" && !path.startsWith("/rest/v1/rpc/get_")) {
      saved.uncertainWrite = {path,at:new Date().toISOString()}; saveArtifact("recovery",saved);
    }
    throw error;
  }
};

async function restore() {
  if (saved.uncertainWrite?.path === "/rest/v1/rpc/get_ranked_customer_offers") {
    // The deployed STABLE getter has no writes; its timed-out response needs no write reconciliation.
    delete saved.uncertainWrite; saveArtifact("recovery",saved);
  }
  assert.ok(!saved.uncertainWrite, "Inspect uncertain response before cleanup");
  const [cleanupScope]=query(`with owned as (select id from public.grooming_requests
    where customer_id in (${sqlIDs(saved.customerIDs)})
      and (service_notes='${marker}' or service_notes like '${marker} %'))
    select array(select id from owned) requests,
      array(select id from public.bookings where request_id in (select id from owned)) bookings,
      array(select id from public.reviews where booking_id in
        (select id from public.bookings where request_id in (select id from owned))) reviews;`);
  saveArtifact("matching-cleanup-scope",cleanupScope);
  const services = saved.matching.services;
  // Delete only captured new IDs, additionally constrained by test owners and marker.
  query(`begin;
    ${services.length ? `delete from public.groomer_services where id in (${sqlIDs(services)})
      and groomer_id in (${sqlIDs(saved.groomerIDs)}) and description='${marker}';` : ""}
    commit;`);
  await cleanup(context, saved,async()=>{
    const predicate=(column,ids)=>ids.length?`${column} in (${sqlIDs(ids)})` : "false";
    const readRestoration=()=>query(`select
    (select count(*)::integer from app_private.booking_review_contexts where ${predicate("booking_id",cleanupScope.bookings)}) contexts,
    (select count(*)::integer from app_private.review_evidence_projection where ${predicate("review_id",cleanupScope.reviews)}) projections,
    (select count(*)::integer from app_private.match_candidate_evaluations where ${predicate("request_id",cleanupScope.requests)}) candidates,
    (select count(*)::integer from app_private.match_refresh_queue where ${predicate("request_id",cleanupScope.requests)}) queue;`)[0];
    let privateRestoration=readRestoration();
    // Bulk deletion can enqueue more than one cron batch; use the same bounded worker as fixture setup.
    for(let attempt=0;privateRestoration.queue>0 && attempt<12;attempt++) {
      query("select app_private.drain_match_refresh_queue(250);");
      privateRestoration=readRestoration();
    }
    saveArtifact("matching-private-restoration",privateRestoration);
    assert.deepEqual(privateRestoration,{contexts:0,projections:0,candidates:0,queue:0});
  });
}

async function check(name, action) {
  const started = Date.now();
  try {
    const evidence = await action();
    results.push({name, status: "PASS", ms: Date.now()-started, evidence});
    console.log(`PASS ${name}`);
  } catch (error) {
    results.push({name, status: "FAIL", ms: Date.now()-started,
      code: error.code, message: error.serverMessage ?? error.message});
    console.log(`FAIL ${name}: ${error.serverMessage ?? error.message}`);
    throw error;
  } finally { saveArtifact(`matching-results-${mode}`, results); }
}

async function denied(actor, name, params, expected) {
  let failure;
  try { await rpc(actor, name, params); } catch (error) { failure = error; }
  assert.ok(failure, "Expected rejection");
  assert.match(failure.serverMessage ?? failure.message, expected);
  assert.ok(failure.httpStatus >= 400 && failure.httpStatus < 500);
  return {code: failure.code, reason: failure.serverMessage};
}

if (mode === "cleanup") {
  await restore();
} else {
  try {
    if (mode === "prepare") await run();
    else if (mode === "revision-live") await revisionLive();
    else if (mode === "paging-matrix") await pagingMatrix();
    else if (mode === "role-latency") await roleLatency();
    else if (mode === "roles") await roleBoundaries();
    else if (mode === "fallback-db") await fallbackDatabase();
    else if (mode === "qualification-clock-db") await qualificationClockDatabase();
    else if (mode === "release-db") await releaseDatabase();
    else if (mode === "ranges-db") await rangeDatabase();
    else if (mode === "time-db") await timeDatabase();
    else if (mode === "evidence-db") await evidenceDatabase();
    else if (mode === "live-worker") await liveWorker();
    else if (mode === "scale-db") await scaleDatabase();
    else if (mode === "review-db") await reviewDatabase();
    else if (mode === "review-race") await reviewRace();
    else if (mode === "privacy-db") await privacyDatabase();
    else if (mode === "event-db") await eventDatabase();
    else if (mode === "admission-db") await admissionDatabase();
    else if (mode === "paging-db") await pagingDatabase();
    else if (mode === "paging-live") await pagingLive();
    else if (mode === "http-ranking") await httpRanking();
    else if (mode === "cohort-db") await cohortDatabase();
    else if (mode === "verify") await verify(); else { await run(); await verify(); }
  } finally {
    // Keep a failed run recoverable; fixture cleanup is an explicit second command.
    saveArtifact(`matching-results-${mode}`, results);
  }
}

async function releaseDatabase() {
  await check("M40 completed service release invalidates and rediscovers a blocked candidate",async()=>{
    const [row]=query(`begin;set local lock_timeout='5s';set local statement_timeout='30s';
      select set_config('app.fulfillment_write','1',true);
      do $$ declare b public.bookings%rowtype;r public.grooming_requests%rowtype;before_state jsonb;after_state jsonb;
      begin
        select * into strict b from public.bookings where request_id='${saved.requests[0]}' and status='completed';
        if b.actual_ended_at-b.actual_started_at<interval '1 minute' or b.resource_release_at is null
          then raise exception 'Requires actual completed service';end if;
        select * into strict r from public.grooming_requests where id=b.request_id;
        r.id:=gen_random_uuid();r.terms_revision:=gen_random_uuid();r.status:='open';r.supersedes_request_id:=null;
        r.service_notes:='${marker} rollback resource';r.preferred_start:=b.scheduled_end+interval '20 minutes';
        r.preferred_end:=r.preferred_start+interval '1 hour';r.expires_at:=r.preferred_end;
        insert into public.grooming_requests select r.*;
        -- Counterfactual retained allocation and its restoration exist only in this rollback.
        update public.bookings set resource_release_at=null,pet_release_at=null where id=b.id;
        perform app_private.refresh_candidate_evaluation(r.id,b.groomer_id,statement_timestamp(),0);
        delete from app_private.match_refresh_queue where request_id=r.id and groomer_id=b.groomer_id;
        before_state:=app_private.evaluate_match_eligibility(r.id,b.groomer_id,statement_timestamp());
        if before_state->>'state'<>'excluded' then raise exception 'Retained allocation should exclude: %',before_state;end if;
        update public.bookings set resource_release_at=b.resource_release_at,pet_release_at=b.pet_release_at where id=b.id;
        if not exists(select 1 from app_private.match_refresh_queue where request_id=r.id and groomer_id=b.groomer_id
          and reason='hard_eligibility') then raise exception 'Completion release event missing';end if;
        if app_private.read_candidate_evaluation(r.id,b.groomer_id,statement_timestamp())->>'state'<>'pending'
          then raise exception 'Release did not invalidate old proof';end if;
        perform app_private.refresh_candidate_evaluation(r.id,b.groomer_id,statement_timestamp(),0);
        delete from app_private.match_refresh_queue where request_id=r.id and groomer_id=b.groomer_id;
        after_state:=app_private.read_candidate_evaluation(r.id,b.groomer_id,statement_timestamp());
        if after_state->>'state'<>'estimated_fit' then raise exception 'Released candidate not rediscovered: %',after_state;end if;
        perform set_config('testops.result',jsonb_build_object('before',before_state,'after',after_state,
          'actualResourceRelease',b.resource_release_at,'sourceEvent',true,'rolledBack',true)::text,true);
      end $$;select current_setting('testops.result')::jsonb result;rollback;`);
    saveArtifact("release-db",row.result);return row.result;
  });
}

async function qualificationClockDatabase() {
  await check("M37/38 full qualification across DST and local notice boundaries",async()=>{
    const [row]=query(`begin; set local lock_timeout='5s'; set local statement_timeout='30s';
      update public.groomer_availability_windows set timezone='America/Los_Angeles',is_enabled=true,
        start_time='00:00',end_time='04:00' where groomer_id='${actors.G1.id}';
      update public.groomer_booking_preferences set minimum_advance_notice_days=0 where groomer_id='${actors.G1.id}';
      do $$ declare r public.grooming_requests%rowtype; v record; result jsonb; checks jsonb:='[]';
      begin
        for v in select * from (values
          ('fall repeated hour','2026-11-01 08:30Z'::timestamptz,'2026-11-01 09:30Z'::timestamptz),
          ('spring skipped hour','2027-03-14 09:30Z'::timestamptz,'2027-03-14 10:30Z'::timestamptz)) c(label,starts,ends)
        loop
          select * into strict r from public.grooming_requests where id='${saved.requests[0]}';
          r.id:=gen_random_uuid();r.terms_revision:=gen_random_uuid();r.status:='open';r.supersedes_request_id:=null;
          r.service_notes:='${marker} rollback clock';r.preferred_start:=v.starts;r.preferred_end:=v.ends;r.expires_at:=v.ends;
          r.location_mode:='groomer_comes_to_customer';r.preference_time_zone_identifier:='America/Los_Angeles';
          insert into public.grooming_requests select r.*;
          result:=app_private.evaluate_match_eligibility(r.id,'${actors.G1.id}',v.starts-interval '2 days');
          if result->>'state'<>'estimated_fit' or (result->>'service_start')::timestamptz<>v.starts
            or (result->>'service_end')::timestamptz<>v.ends
            or (result->>'occupied_start')::timestamptz<>v.starts-interval '45 minutes'
            or (result->>'occupied_end')::timestamptz<>v.ends+interval '30 minutes'
          then raise exception 'DST qualification mismatch %: %',v.label,result;end if;
          checks:=checks||jsonb_build_array(jsonb_build_object('case',v.label,'result',result));
        end loop;
        update public.groomer_booking_preferences set minimum_advance_notice_days=1 where groomer_id='${actors.G1.id}';
        select * into strict r from public.grooming_requests where id='${saved.requests[0]}';
        r.id:=gen_random_uuid();r.terms_revision:=gen_random_uuid();r.status:='open';r.supersedes_request_id:=null;
        r.service_notes:='${marker} rollback notice';r.preferred_start:='2026-11-01 08:30Z';
        r.preferred_end:='2026-11-01 09:30Z';r.expires_at:=r.preferred_end;
        r.location_mode:='groomer_comes_to_customer';r.preference_time_zone_identifier:='America/Los_Angeles';
        insert into public.grooming_requests select r.*;
        result:=app_private.evaluate_match_eligibility(r.id,'${actors.G1.id}','2026-11-01 06:59:59Z');
        if result->>'state'<>'estimated_fit' then raise exception 'Notice before local midnight: %',result;end if;
        checks:=checks||jsonb_build_array(jsonb_build_object('case','notice before local midnight','result',result));
        result:=app_private.evaluate_match_eligibility(r.id,'${actors.G1.id}','2026-11-01 07:00Z');
        if result->>'state'<>'excluded' then raise exception 'Notice after local midnight: %',result;end if;
        checks:=checks||jsonb_build_array(jsonb_build_object('case','notice at local midnight','result',result));
        perform set_config('testops.result',checks::text,true);
      end $$;select current_setting('testops.result')::jsonb result;rollback;`);
    saveArtifact("qualification-clock-db",row.result);return row.result;
  });
}

async function fallbackDatabase() {
  await check("M57/60 scoring exception isolates cursors and preserves versioned transactions",async()=>{
    const [row]=query(`begin; set local lock_timeout='5s'; set local statement_timeout='30s';
      update app_private.match_ranking_config set enabled=true where singleton;
      do $$ declare r public.grooming_requests%rowtype; offer uuid; revision uuid; page jsonb; rejected boolean:=false;
        g uuid; confirmations text[];
      begin
        select * into strict r from public.grooming_requests where id='${saved.requests[0]}';
        r.id:=gen_random_uuid(); r.terms_revision:=gen_random_uuid(); r.status:='open';
        r.supersedes_request_id:=null; r.service_notes:='${marker} rollback fallback';
        r.preferred_start:=date_trunc('day',now())+interval '2 days 17 hours';
        r.preferred_end:=r.preferred_start+interval '4 hours'; r.expires_at:=r.preferred_end;
        r.pet_snapshot:=r.pet_snapshot||'{"weight_lbs":null,"size":null,"coat_type":null,"coat_type_source":"unknown","matting_confirmed":null}'::jsonb;
        insert into public.grooming_requests select r.*;
        perform app_private.refresh_candidate_evaluation(r.id,'${actors.G1.id}',statement_timestamp(),0);
        perform app_private.refresh_candidate_evaluation(r.id,'${actors.G2.id}',statement_timestamp(),0);
        perform set_config('request.jwt.claims',jsonb_build_object('sub','${actors.G1.id}','role','authenticated','is_anonymous',false)::text,true);
        begin
          perform public.create_groomer_offer_v2(r.id,r.terms_revision,r.preferred_start,r.preferred_start+interval '1 hour',100,'${marker}');
        exception when others then
          if sqlerrm not in ('assessment_confirmation_required','client_update_required') then raise;end if;
          rejected:=true;
        end;
        if not rejected then raise exception 'Old client bypassed explicit assessment';end if;
        foreach g in array array['${actors.G1.id}'::uuid,'${actors.G2.id}'::uuid] loop
          perform set_config('request.jwt.claims',jsonb_build_object('sub',g,'role','authenticated','is_anonymous',false)::text,true);
          select app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes)
            into confirmations from public.groomer_services s where s.groomer_id=g and s.id in (${sqlIDs(saved.matching.services)}) limit 1;
          select offer_id into offer from public.create_groomer_offer_v3(r.id,r.terms_revision,r.preferred_start,
            r.preferred_start+interval '1 hour',100,'${marker}',confirmations);
        end loop;
        perform set_config('request.jwt.claims',jsonb_build_object('sub','${actors.C1.id}','role','authenticated','is_anonymous',false)::text,true);
        page:=public.get_ranked_customer_offers(r.id,'balanced',1,null);
        if page->>'effective_mode'<>'balanced' or page->>'next_cursor' is null then raise exception 'Missing ranked first page';end if;
        perform set_config('testops.old_cursor',page->>'next_cursor',true);
        perform set_config('testops.request',r.id::text,true);
        perform set_config('testops.offer',offer::text,true);
      end $$;
      create or replace function app_private.score_match_evidence(p_request_id uuid,p_groomer_id uuid,p_score_as_of timestamptz,p_offer_id uuid,p_valid_zones text[])
      returns jsonb language plpgsql stable set search_path='' as $$ begin raise division_by_zero;end $$;
      do $$ declare page jsonb; rejected boolean:=false; receipt record; offer uuid:=current_setting('testops.offer')::uuid;
      begin
        begin
          perform public.get_ranked_customer_offers(current_setting('testops.request')::uuid,'balanced',1,current_setting('testops.old_cursor'));
        exception when sqlstate 'PT409' then rejected:=sqlerrm='list_changed';end;
        if not rejected then raise exception 'Mixed ranked and fallback cursor';end if;
        page:=public.get_ranked_customer_offers(current_setting('testops.request')::uuid,'balanced',1,null);
        if page->>'effective_mode'<>'time_fallback' or page->>'next_cursor' is null then raise exception 'Missing independent fallback page';end if;
        page:=public.get_ranked_customer_offers(current_setting('testops.request')::uuid,'balanced',1,page->>'next_cursor');
        if jsonb_array_length(page->'items')<>1 or page->>'next_cursor' is not null then raise exception 'Fallback pagination incomplete';end if;
        select * into strict receipt from public.accept_groomer_offer_v2(offer,(select quote_revision from public.groomer_offers where id=offer));
        if receipt.booking_id is null then raise exception 'Soft failure blocked acceptance';end if;
        perform set_config('testops.result',jsonb_build_object('oldClientRejected',true,'softFailureFallback',true,
          'independentCursor',true,'fallbackPages',2,'accepted',true,'rolledBack',true)::text,true);
      end $$;
      select current_setting('testops.result')::jsonb result; rollback;`);
    saveArtifact("fallback-db",row.result);return row.result;
  });
}

async function roleBoundaries() {
  const id=saved.matching.uiService;
  assert.ok(id);
  for(const actor of ['C1','X','G2']) await check(`service species write denied for ${actor}`,async()=>{
    let response;
    try { response=await api.request(`/rest/v1/groomer_services?id=eq.${id}`,{
      method:'PATCH',headers:api.headers(actors[actor].token,{Prefer:'return=representation'}),
      body:JSON.stringify({accepted_species:['dog']})},'rest'); }
    catch(error) { assert.ok(error.httpStatus>=400 && error.httpStatus<500); return {code:error.code}; }
    assert.deepEqual(response,[],"Non-owner changed or received the service row");
    return {rows:0};
  });
  await check('service eligibility revision remains protected',async()=>{
    let failure;
    try { await api.request(`/rest/v1/groomer_services?id=eq.${id}`,{
      method:'PATCH',headers:api.headers(actors.G1.token,{Prefer:'return=representation'}),
      body:JSON.stringify({eligibility_revision:randomUUID()})},'rest'); } catch(error) { failure=error; }
    assert.ok(failure && failure.httpStatus>=400 && failure.httpStatus<500);
    return {code:failure.code};
  });
  for(const actor of ['C2','X','G1','G2']) await check(`private booking review context denied for ${actor}`,()=>
    denied(actor,'get_booking_review_context',{p_booking_id:saved.matching.booking},/booking_not_found|customer_profile_required/));
  for(const name of ['get_ranked_matched_requests','get_booking_review_context']) await check(`unauthenticated ${name} rejected`,async()=>{
    let failure;
    try { await api.request(`/rest/v1/rpc/${name}`,{method:'POST',
      headers:{apikey:api.publishableKey,'Content-Type':'application/json'},
      body:JSON.stringify(name==='get_booking_review_context'?{p_booking_id:saved.matching.booking}:{p_sort:'fit'})},'rpc');
    } catch(error) { failure=error; }
    assert.ok(failure && [401,403].includes(failure.httpStatus));
    return {status:failure.httpStatus};
  });
  await check('owner can insert accepted species through the actual REST writer',async()=>{
    const serviceID=saved.matching.permissionService ?? randomUUID();
    if(!saved.matching.permissionService) {
      saved.matching.permissionService=serviceID; saved.matching.services.push(serviceID); saveArtifact('recovery',saved);
    }
    const existing=await api.restSelect('groomer_services',`select=id&id=eq.${serviceID}`,actors.G1.token);
    assert.equal(existing.length,0,'Inspect existing permission fixture before retry');
    const rows=await api.request('/rest/v1/groomer_services',{method:'POST',
      headers:api.headers(actors.G1.token,{Prefer:'return=representation'}),
      body:JSON.stringify({groomer_id:actors.G1.id,title:'Matching permission test',description:marker,
        base_price:100,duration_minutes:60,accepted_pet_sizes:[],is_active:false,service_type:'custom_request',accepted_species:['dog']})},'rest');
    saved.matching.services=saved.matching.services.filter(value=>value!==serviceID);
    saved.matching.permissionService=rows[0].id; saved.matching.services.push(rows[0].id); saveArtifact('recovery',saved);
    assert.deepEqual(rows[0].accepted_species,['dog']); return {inserted:1};
  });
}

async function rangeDatabase() {
  await check("M36/37 exact second-oracle differential across clock transitions",async()=>{
    const rows=query(`with cases(zone,a,b) as (values
      ('UTC','2026-09-11T13:07:00.123Z'::timestamptz,'2026-09-11T21:12:00.456Z'::timestamptz),
      ('America/Los_Angeles','2026-03-08T08:00:00Z','2026-03-09T04:00:00Z'),
      ('America/Los_Angeles','2026-11-01T07:00:00Z','2026-11-02T03:00:00Z'),
      ('Australia/Lord_Howe','2026-04-04T13:00:00Z','2026-04-05T15:00:00Z'),
      ('Australia/Lord_Howe','2026-10-03T13:00:00Z','2026-10-04T15:00:00Z'),
      ('Pacific/Apia','2011-12-29T12:00:00Z','2011-12-31T12:00:00Z'),
      ('Asia/Kathmandu','1985-12-31T12:00:00Z','1986-01-01T12:00:00Z'),
      ('Africa/Monrovia','1972-01-07T00:00:00Z','1972-01-07T06:00:00Z'),
      ('UTC','2026-09-11T00:00:00Z','2026-09-14T00:00:00Z'),
      ('America/Los_Angeles','2026-09-11T23:59:59.999Z','2026-09-12T00:00:00.001Z')
    ), schedules(starts,ends) as (values
      (array_fill(time '00:00',array[7]),array_fill(time '24:00',array[7])),
      (array_fill(time '01:15:00.123',array[7]),array_fill(time '03:30:00.456',array[7])),
      (array[time '08:00',null,time '09:00:00.001',time '08:00',time '23:00',time '00:00',time '01:00'],
       array[time '18:00',null,time '09:30:00.999',time '08:30',time '23:30',time '23:59:59.75',time '03:30'])
    )
    select zone,a,b,starts::text schedule,
      app_private.match_weekly_ranges_validated(a,b,zone,starts,ends)::text actual,
      (with wall as materialized (
        select t,timezone(zone,t) local_time from generate_series(date_trunc('second',a),b,interval '1 second') t where t<b
      ), bounds as (
        select greatest(t,a,t+((local_time::date+starts[extract(isodow from local_time)::integer])-local_time)) x,
          least(t+interval '1 second',b,t+((local_time::date+ends[extract(isodow from local_time)::integer])-local_time)) y
        from wall where starts[extract(isodow from local_time)::integer] is not null
          and ends[extract(isodow from local_time)::integer] is not null
      ) select coalesce(range_agg(case when x<y then tstzrange(x,y,'[)') end),'{}'::tstzmultirange)::text from bounds) expected
    from cases cross join schedules;`);
    for(const row of rows) assert.equal(row.actual,row.expected,`${row.zone} ${row.a} ${row.schedule}`);
    assert.equal(rows.length,30);
    saveArtifact("range-oracle-differential",rows);
    return {vectors:rows.length,oracle:"unchanged per-second SQL",writes:0};
  });
}

async function timeDatabase() {
  await check("MR04 cached witness, event invalidation and 25-call oracle budgets",async()=>{
    const [row]=query(`begin; set local lock_timeout='5s'; set local statement_timeout='60s';
      do $$ declare fixture public.grooming_requests%rowtype; open_id uuid; closed_id uuid; cached jsonb; oracle jsonb;
        i integer; started timestamptz; open_ms numeric; closed_ms numeric; validated_ms numeric; constraints_ms numeric;
        valid_zones text[]; deadline timestamptz; evaluated timestamptz; quote_id uuid; quote_revision uuid;
      begin
        select * into strict fixture from public.grooming_requests where id='${saved.requests[0]}' and customer_id='${actors.C1.id}';
        fixture.status:='open'; fixture.supersedes_request_id:=null; fixture.service_notes:='${marker} time-db';
        fixture.preferred_start:=fixture.preferred_start+interval '1 day'; fixture.preferred_end:=fixture.preferred_end+interval '1 day';
        fixture.id:=gen_random_uuid(); fixture.terms_revision:=gen_random_uuid(); open_id:=fixture.id;
        insert into public.grooming_requests select fixture.*;
        fixture.id:=gen_random_uuid(); fixture.terms_revision:=gen_random_uuid(); closed_id:=fixture.id;
        fixture.preferred_end:=fixture.preferred_start+interval '30 minutes';
        insert into public.grooming_requests select fixture.*;
        started:=clock_timestamp();
        for i in 1..25 loop
          oracle:=app_private.evaluate_match_eligibility(open_id,'${actors.G1.id}',statement_timestamp());
          if oracle->>'state'<>'estimated_fit' then raise exception 'Open oracle unexpected: %',oracle; end if;
        end loop;
        open_ms:=extract(epoch from clock_timestamp()-started)*1000;
        started:=clock_timestamp();
        for i in 1..25 loop
          oracle:=app_private.evaluate_match_eligibility(closed_id,'${actors.G1.id}',statement_timestamp());
          if oracle->>'state'<>'excluded' then raise exception 'Partial interval incorrectly accepted: %',oracle; end if;
        end loop;
        closed_ms:=extract(epoch from clock_timestamp()-started)*1000;
        select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names;
        started:=clock_timestamp();
        for i in 1..25 loop perform app_private.evaluate_match_eligibility_with_zones(open_id,'${actors.G1.id}',statement_timestamp(),valid_zones); end loop;
        validated_ms:=extract(epoch from clock_timestamp()-started)*1000;
        started:=clock_timestamp();
        for i in 1..25 loop perform app_private.evaluate_match_constraints(open_id,'${actors.G1.id}',statement_timestamp()); end loop;
        constraints_ms:=extract(epoch from clock_timestamp()-started)*1000;
        perform app_private.refresh_candidate_evaluation(open_id,'${actors.G1.id}',statement_timestamp(),0);
        -- Component probe represents the worker's captured hard-event consumption.
        delete from app_private.match_refresh_queue where request_id=open_id and groomer_id='${actors.G1.id}';
        select valid_until,evaluated_at into deadline,evaluated from app_private.match_candidate_evaluations
          where request_id=open_id and groomer_id='${actors.G1.id}';
        cached:=app_private.read_candidate_evaluation(open_id,'${actors.G1.id}',statement_timestamp()+interval '61 seconds');
        if cached->>'state'<>'estimated_fit' then raise exception 'Unchanged proof expired at arbitrary 60 seconds'; end if;
        oracle:=app_private.evaluate_match_eligibility(open_id,'${actors.G1.id}',deadline-interval '1 microsecond');
        if oracle->>'state'<>'estimated_fit' then raise exception 'Witness unsafe before boundary'; end if;
        if app_private.read_candidate_evaluation(open_id,'${actors.G1.id}',deadline)->>'state'<>'pending' then
          raise exception 'Expired witness still advertised'; end if;
        perform app_private.enqueue_soft_match_refresh('${actors.G1.id}','rating');
        if app_private.read_candidate_evaluation(open_id,'${actors.G1.id}',statement_timestamp())->>'state'<>'estimated_fit' then
          raise exception 'Soft event blocked eligibility'; end if;
        perform set_config('request.jwt.claims',jsonb_build_object('sub','${actors.G1.id}','role','authenticated','is_anonymous',false)::text,true);
        select offer_id into quote_id from public.create_groomer_offer_v3(open_id,
          (select terms_revision from public.grooming_requests where id=open_id),
          fixture.preferred_start+interval '5 hours',fixture.preferred_start+interval '6 hours',100,'${marker}','{}');
        select o.quote_revision into quote_revision from public.groomer_offers o where o.id=quote_id;
        if app_private.evaluate_quote(quote_id)->>'terms_valid'<>'true' then raise exception 'New quote not initially valid'; end if;
        perform app_private.refresh_candidate_evaluation(open_id,'${actors.G1.id}',statement_timestamp(),0);
        delete from app_private.match_refresh_queue where request_id=open_id and groomer_id='${actors.G1.id}';
        if app_private.read_candidate_evaluation(open_id,'${actors.G1.id}',statement_timestamp())->>'state'<>'estimated_fit' then
          raise exception 'Quote setup did not leave a valid hard-change baseline'; end if;
        update public.groomer_services set accepted_species=array['cat'] where id='${saved.matching.services[0]}' and groomer_id='${actors.G1.id}';
        if app_private.read_candidate_evaluation(open_id,'${actors.G1.id}',statement_timestamp())->>'state'<>'pending' then
          raise exception 'Hard service mutation failed immediate invalidation'; end if;
        update public.groomer_services set accepted_species=array['dog'] where id='${saved.matching.services[0]}' and groomer_id='${actors.G1.id}';
        if app_private.evaluate_quote(quote_id)->>'reason'<>'eligibility_revoked' then
          raise exception 'M35 changing service scope back revived an old quote'; end if;
        perform set_config('request.jwt.claims',jsonb_build_object('sub','${actors.C1.id}','role','authenticated','is_anonymous',false)::text,true);
        begin
          perform public.accept_groomer_offer_v2(quote_id,quote_revision);
          raise exception 'M35 stale scope quote was accepted';
        exception when sqlstate '22023' then if sqlerrm<>'quote_terms_invalid' then raise; end if; end;
        perform set_config('test.time_result',jsonb_build_object('open_25_ms',open_ms,'closed_25_ms',closed_ms,
          'validated_open_25_ms',validated_ms,'constraints_25_ms',constraints_ms,
          'valid_until',deadline,'evaluated_at',evaluated,'rollback',true)::text,true);
      end $$;
      select current_setting('test.time_result')::jsonb result; rollback;`);
    saveArtifact("time-db-metrics",row.result);
    assert.ok(row.result.open_25_ms<=3500,"25 open oracle calls exceeded 3500ms");
    assert.ok(row.result.closed_25_ms<=2000,"25 closed oracle calls exceeded 2000ms");
    return row.result;
  });
}

async function evidenceDatabase() {
  const count=Number(process.env.TESTOPS_REVIEW_COUNT ?? 10);
  assert.ok(Number.isInteger(count) && count>=10 && count<=1000 && count%5===0);
  await check(`MR02/03 ${count} actual review rows with bounded customer influence`,async()=>{
    const committed=count>50;
    let completed=0;
    if(committed) {
      const [baseline]=query(`select rating_sum,rating_count,
        (select count(*)::integer from public.grooming_requests where customer_id='${actors.C1.id}'
          and service_notes='${marker} evidence-db') existing from public.groomer_profiles where user_id='${actors.G2.id}';`);
      if(!saved.matching.evidenceBaseline) {
        assert.equal(baseline.existing,0,"Reconcile pre-existing evidence fixture before recording baseline");
        saved.matching.evidenceBaseline={rating_sum:baseline.rating_sum,rating_count:baseline.rating_count,count};
        saveArtifact("recovery",saved);
      }
      assert.equal(saved.matching.evidenceBaseline.count,count);
      completed=baseline.existing;
      assert.ok(completed<=count && completed%25===0,"Incomplete evidence batch requires reconciliation");
    }
    let data;
    for(let offset=completed;offset<count;offset+=committed?25:count) {
      const end=Math.min(count,offset+(committed?25:count));
      const [result]=query(`begin; set local lock_timeout='5s'; set local statement_timeout='110s';
      select set_config('app.fulfillment_write','1',true);
      do $$ declare template public.grooming_requests%rowtype; fixture public.grooming_requests%rowtype;
        i integer; offer uuid; booking uuid; context jsonb; review jsonb; score jsonb; receipt record;
        total_before bigint; n_before integer; as_of timestamptz; samples jsonb:='[]'; started timestamptz:=clock_timestamp();
      begin
        select * into strict template from public.grooming_requests where id='${saved.requests[0]}' and customer_id='${actors.C1.id}';
        select rating_sum,rating_count into total_before,n_before from public.groomer_profiles where user_id='${actors.G2.id}';
        for i in ${offset+1}..${end} loop
          fixture:=template; fixture.id:=gen_random_uuid(); fixture.terms_revision:=gen_random_uuid();
          fixture.status:='open'; fixture.supersedes_request_id:=null; fixture.service_notes:='${marker} evidence-db';
          fixture.preferred_start:=template.preferred_start+make_interval(days=>i)+interval '1 hour';
          fixture.preferred_end:=fixture.preferred_start+interval '1 hour';
          insert into public.grooming_requests select fixture.*;
          perform app_private.refresh_candidate_evaluation(fixture.id,'${actors.G2.id}',statement_timestamp(),0);
          perform set_config('request.jwt.claims',jsonb_build_object('sub','${actors.G2.id}','role','authenticated','is_anonymous',false)::text,true);
          select offer_id into offer from public.create_groomer_offer_v3(fixture.id,fixture.terms_revision,
            fixture.preferred_start,fixture.preferred_end,100,'${marker}','{}');
          perform set_config('request.jwt.claims',jsonb_build_object('sub','${actors.C1.id}','role','authenticated','is_anonymous',false)::text,true);
          select * into receipt from public.accept_groomer_offer_v2(offer,
            (select quote_revision from public.groomer_offers where id=offer));
          booking:=receipt.booking_id;
          -- SQL completion fixtures preserve the actual accepted allocation; not real-time fulfillment.
          update public.bookings set status='completed',fulfillment_phase='completed',completed_at=statement_timestamp(),
            completed_by=groomer_id where id=booking;
          context:=public.get_booking_review_context(booking);
          review:=public.create_review_v2(booking,(context->>'context_revision')::uuid,
            case when i<=${count}*4/5 then 5 else 1 end,'${marker}',
            '[{"trait_type":"service","trait_value":"nail_trim","outcome":"positive"},{"trait_type":"size","trait_value":"XS","outcome":"positive"}]');
          samples:=samples||jsonb_build_array(jsonb_build_object('service_at',context->'service_at','rating',review->'rating'));
          as_of:=(context->>'service_at')::timestamptz;
        end loop;
        if (select rating_sum-total_before from public.groomer_profiles where user_id='${actors.G2.id}')<>
            (select sum(case when sample.ordinal<=${count}*4/5 then 5 else 1 end)
              from generate_series(${offset+1},${end}) sample(ordinal))
          or (select rating_count-n_before from public.groomer_profiles where user_id='${actors.G2.id}')<>${end-offset} then
          raise exception 'Exact rating aggregation drift'; end if;
        score:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G2.id}',as_of);
        if (score->>'positive_weight')::numeric>1.000000001 or (score->>'f_customer_count')::integer<>1 then
          raise exception 'Repeat customer influence exceeded one: %',score; end if;
        perform set_config('test.evidence_result',jsonb_build_object('score',score,'samples',samples,'as_of',as_of,
          'reviews',${end-offset},'setup_ms',extract(epoch from clock_timestamp()-started)*1000,'rollback',${!committed})::text,true);
      end $$;
      select current_setting('test.evidence_result')::jsonb result; ${committed?"commit":"rollback"};`);
      data=result.result;
      if(committed) {
        saved.matching.evidenceCompleted=end;
        saveArtifact("recovery",saved);
        console.log(`Evidence fixture: ${end}/${count} committed; cleanup required`);
      }
    }
    if(committed) {
      const [row]=query(`with samples as (
        select c.service_at,v.rating from public.reviews v join public.bookings b on b.id=v.booking_id
        join public.grooming_requests r on r.id=b.request_id
        join app_private.booking_review_contexts c on c.booking_id=b.id
        where r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}'
          and r.service_notes='${marker} evidence-db'
      ) select jsonb_build_object('samples',jsonb_agg(to_jsonb(samples) order by service_at),
        'as_of',max(service_at),'reviews',count(*),'rollback',false,
        'score',app_private.score_match_evidence('${saved.requests[0]}','${actors.G2.id}',max(service_at))) result,
        (select rating_sum from public.groomer_profiles where user_id='${actors.G2.id}') rating_sum,
        (select rating_count from public.groomer_profiles where user_id='${actors.G2.id}') rating_count from samples;`);
      data=row.result;
      assert.equal(Number(row.rating_sum)-Number(saved.matching.evidenceBaseline.rating_sum),count*4.2);
      assert.equal(row.rating_count-saved.matching.evidenceBaseline.rating_count,count);
      assert.equal(data.reviews,count);
    }
    const expected=scoreEvidence({species:'dog',service:'nail_trim',keys:['service:nail_trim','size:XS']},
      data.samples.map(sample=>({customer:'one',species:'dog',service:'nail_trim',rating:sample.rating,
        age:(Date.parse(data.as_of)-Date.parse(sample.service_at))/86400000,
        answers:{'service:nail_trim':'positive','size:XS':'positive'}})),data.score.distance_miles);
    for(const key of ['f','q','d','b','s']) assert.ok(Math.abs(data.score[key]-expected[key])<1e-7,`${key} differs from independent oracle`);
    saveArtifact(`evidence-db-${count}`,data);
    return {reviews:count,setup_ms:data.setup_ms,score:data.score,rollback:!committed};
  });
}

async function liveWorker() {
  await check("M55 live cron drains 250+ pairs without periodic rebuild", async () => {
    assert.ok(!saved.matching.liveRequests?.length, "Reconcile existing live probe before rerunning");
    const ids=Array.from({length:26},()=>randomUUID());
    saved.matching.liveRequests=ids;
    saveArtifact("recovery",saved);
    const [initial]=query(`begin; set local lock_timeout='5s'; set local statement_timeout='30s';
      do $$ declare fixture public.grooming_requests%rowtype; id uuid; begin
        if exists(select 1 from app_private.match_refresh_queue) then raise exception 'Probe requires idle queue'; end if;
        select r.* into strict fixture from public.grooming_requests r where r.id='${saved.requests[0]}'
          and r.customer_id='${actors.C1.id}';
        fixture.status:='open'; fixture.supersedes_request_id:=null;
        fixture.service_notes:='${marker} live-worker';
        foreach id in array array[${sqlIDs(ids)}] loop
          fixture.id:=id; fixture.terms_revision:=gen_random_uuid();
          fixture.created_at:=statement_timestamp(); fixture.updated_at:=fixture.created_at;
          insert into public.grooming_requests select fixture.*;
        end loop;
      end $$;
      select count(distinct(request_id,groomer_id))::integer pairs, clock_timestamp() started
        from app_private.match_refresh_queue where request_id in (${sqlIDs(ids)}); commit;`);
    assert.ok(initial.pairs>=250);
    const samples=[];
    const started=Date.now();
    let emptyAt=null;
    while (Date.now()-started<180000) {
      const [sample]=query(`select clock_timestamp() at,
        (select count(*)::integer from app_private.match_refresh_queue where request_id in (${sqlIDs(ids)})) queued,
        (select count(*)::integer from cron.job_run_details d join cron.job j using(jobid)
          where j.jobname='beckon_refresh_request_matches' and d.start_time>='${initial.started}'::timestamptz
          and d.status='succeeded') completed_cycles;`);
      samples.push(sample);
      saveArtifact("live-worker-samples",{initial,samples});
      if(sample.queued===0) {
        emptyAt ??= {time:Date.now(),cycles:sample.completed_cycles};
        if(sample.completed_cycles>=emptyAt.cycles+3) break;
      } else if(emptyAt) assert.fail("Unchanged live candidates were queued again");
      await new Promise(resolve=>setTimeout(resolve,10000));
    }
    assert.ok(emptyAt,"Live queue did not drain within 180 seconds");
    assert.ok(samples.at(-1).completed_cycles>=emptyAt.cycles+3,"Three completed cron cycles not observed");
    return {pairs:initial.pairs,drained_ms:emptyAt.time-started,samples,manualWorkerCalls:0};
  });
}

async function scaleDatabase() {
  await check("MR04/05 250-pair rollback scale probe",async()=>{
    const rows=query(`begin; set local lock_timeout='5s'; set local statement_timeout='100s';
      select set_config('request.jwt.claims',jsonb_build_object('sub','${actors.G1.id}','role','authenticated','is_anonymous',false)::text,true);
      do $$ declare fixture public.grooming_requests%rowtype; ids uuid[]:='{}'; i integer;
        before_time timestamptz; setup_ms numeric; worker_ms numeric; read_ms numeric[]:='{}';
        page jsonb; cursor text; seen uuid[]:='{}'; id uuid; initial_pairs integer; remaining integer; processed integer;
      begin
        if exists(select 1 from app_private.match_refresh_queue) then raise exception 'Unrelated queue work; probe requires idle baseline'; end if;
        select r.* into strict fixture from public.grooming_requests r where r.id='${saved.requests[0]}'
          and r.customer_id='${actors.C1.id}';
        fixture.status:='open'; fixture.supersedes_request_id:=null;
        fixture.service_notes:='${marker} scale'; before_time:=clock_timestamp();
        for i in 1..26 loop
          fixture.id:=gen_random_uuid(); fixture.terms_revision:=gen_random_uuid();
          fixture.created_at:=statement_timestamp()-make_interval(secs=>i); fixture.updated_at:=fixture.created_at;
          insert into public.grooming_requests select fixture.*;
          ids:=array_append(ids,fixture.id);
        end loop;
        setup_ms:=extract(epoch from clock_timestamp()-before_time)*1000;
        select count(distinct (request_id,groomer_id)) into initial_pairs from app_private.match_refresh_queue where request_id=any(ids);
        if initial_pairs<250 then raise exception 'Scale fixture has only % pairs',initial_pairs; end if;
        before_time:=clock_timestamp();
        for i in 1..20 loop
          perform app_private.drain_match_refresh_queue(100);
          exit when not exists(select 1 from app_private.match_refresh_queue where request_id=any(ids));
        end loop;
        worker_ms:=extract(epoch from clock_timestamp()-before_time)*1000;
        select count(*) into remaining from app_private.match_refresh_queue where request_id=any(ids);
        if remaining<>0 then raise exception 'Queue not drained: %',remaining; end if;
        for i in 1..3 loop
          processed:=app_private.drain_match_refresh_queue(100);
          if processed<>0 then raise exception 'Unchanged evidence was recomputed: %',processed; end if;
        end loop;
        -- Enable only inside this rolled-back transaction; other sessions keep fallback.
        update app_private.match_ranking_config set enabled=true where singleton;
        cursor:=null;
        loop
          page:=public.get_ranked_matched_requests('fit',25,cursor);
          for id in select (value->'request'->>'id')::uuid from jsonb_array_elements(page->'items') loop
            if id=any(seen) then raise exception 'Duplicate page member'; end if;
            seen:=array_append(seen,id);
          end loop;
          cursor:=page->>'next_cursor'; exit when cursor is null;
        end loop;
        if not ids<@seen then raise exception 'Missing ranked members: % of %',cardinality(seen),cardinality(ids); end if;
        for i in 1..30 loop
          before_time:=clock_timestamp(); page:=public.get_ranked_matched_requests('fit',25,null);
          read_ms:=array_append(read_ms,extract(epoch from clock_timestamp()-before_time)*1000);
        end loop;
        perform set_config('test.matching_metrics',jsonb_build_object('pairs',initial_pairs,'members',cardinality(seen),
          'setup_ms',setup_ms,'worker_ms',worker_ms,'read_ms',to_jsonb(read_ms),'rollback',true)::text,true);
      end $$;
      select current_setting('test.matching_metrics')::jsonb metrics; rollback;`);
    const metrics=rows[0].metrics;
    saveArtifact("scale-db-metrics",metrics);
    const sorted=[...metrics.read_ms].sort((a,b)=>a-b);
    assert.ok(sorted[Math.ceil(sorted.length*.95)-1]<=1500, "SQL page P95 exceeds 1500ms");
    assert.ok(metrics.worker_ms<=180000,"Worker burst exceeded 180 seconds");
    return metrics;
  });
}

async function cohortDatabase() {
  await check("M17 ten independent customers retain independent influence",async()=>{
    const customers=Object.entries(actors).filter(([alias])=>/^C\d+$/.test(alias)).map(([,actor])=>actor.id);
    assert.equal(customers.length,10);
    const [row]=query(`begin; set local lock_timeout='5s'; set local statement_timeout='110s';
      select set_config('app.fulfillment_write','1',true);
      do $$ declare fixture public.grooming_requests%rowtype; pet public.pets%rowtype;
        actor uuid; ordinal integer:=0; offer uuid; booking uuid; venue uuid;
        context jsonb; samples jsonb:='[]'; score jsonb; negative_score jsonb; as_of timestamptz; confirmations text[];
      begin
        foreach actor in array array[${sqlIDs(customers)}] loop
          ordinal:=ordinal+1;
          select * into strict fixture from public.grooming_requests where id='${saved.requests[0]}';
          select * into strict pet from public.pets where customer_id=actor and is_active and species='Dog' order by id limit 1;
          fixture.id:=gen_random_uuid(); fixture.terms_revision:=gen_random_uuid(); fixture.customer_id:=actor;
          fixture.pet_id:=pet.id; fixture.pet_snapshot:=to_jsonb(pet)||jsonb_build_object('facts_version',2);
          fixture.status:='open'; fixture.supersedes_request_id:=null; fixture.service_notes:='${marker} cohort-db';
          -- Independent pet owners request service at the same already-confirmed venue.
          -- Copy only that venue's facts into request-owned locations; profiles stay unchanged.
          insert into app_private.address_locations(owner_id,provider,place_id,country_code,latitude,longitude,
            resolution_source,user_confirmed_at,time_zone_identifier)
            select actor,provider,place_id,country_code,latitude,longitude,resolution_source,user_confirmed_at,time_zone_identifier
            from app_private.address_locations where id=fixture.address_location_id
              and owner_id='${actors.C1.id}' returning id into venue;
          if venue is null then raise exception 'Confirmed fixture venue missing'; end if;
          fixture.address_location_id:=venue;
          fixture.preferred_start:=fixture.preferred_start+make_interval(days=>ordinal+2)+interval '5 hours';
          fixture.preferred_end:=fixture.preferred_start+interval '1 hour';
          insert into public.grooming_requests select fixture.*;
          perform app_private.refresh_candidate_evaluation(fixture.id,'${actors.G1.id}',statement_timestamp(),0);
          select result into score from app_private.match_candidate_evaluations
            where request_id=fixture.id and groomer_id='${actors.G1.id}';
          if score->>'state' not in ('estimated_fit','assessment_required') then
            raise exception 'Cohort ordinal % is not eligible: %',ordinal,score; end if;
          select app_private.match_required_confirmations(fixture.pet_snapshot,fixture.service_type,
            s.accepted_species,s.accepted_pet_sizes) into confirmations
            from app_private.offer_service_configuration(fixture.id,'${actors.G1.id}',null) s;
          perform set_config('request.jwt.claims',jsonb_build_object('sub','${actors.G1.id}','role','authenticated','is_anonymous',false)::text,true);
          select offer_id into offer from public.create_groomer_offer_v3(fixture.id,fixture.terms_revision,
            fixture.preferred_start,fixture.preferred_end,100,'${marker}',confirmations);
          perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
          select booking_id into booking from public.accept_groomer_offer_v2(offer,
            (select quote_revision from public.groomer_offers where id=offer));
          update public.bookings set status='completed',fulfillment_phase='completed',completed_at=statement_timestamp(),
            completed_by=groomer_id where id=booking;
          context:=public.get_booking_review_context(booking);
          perform public.create_review_v2(booking,(context->>'context_revision')::uuid,5,'${marker}',
            '[{"trait_type":"service","trait_value":"nail_trim","outcome":"positive"}]');
          as_of:=(context->>'service_at')::timestamptz;
          samples:=samples||jsonb_build_array(jsonb_build_object('customer',actor,'service_at',as_of));
        end loop;
        score:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G1.id}',as_of);
        if (score->>'f_customer_count')::integer<>10 or (score->>'positive_weight')::numeric<=1 then
          raise exception 'Independent customer influence was incorrectly collapsed'; end if;
        update public.reviews v set rating=1 from public.bookings b,public.grooming_requests r
          where b.id=v.booking_id and r.id=b.request_id and r.customer_id in (${sqlIDs(customers)})
            and b.groomer_id='${actors.G1.id}' and r.service_notes='${marker} cohort-db';
        update public.review_pet_fit_outcomes o set outcome='negative' from public.bookings b,public.grooming_requests r
          where b.id=o.booking_id and r.id=b.request_id and r.customer_id in (${sqlIDs(customers)})
            and b.groomer_id='${actors.G1.id}' and r.service_notes='${marker} cohort-db';
        negative_score:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G1.id}',as_of);
        perform set_config('test.cohort_result',jsonb_build_object('score',score,'negative_score',negative_score,
          'samples',samples,'as_of',as_of,'rollback',true)::text,true);
      end $$;
      select current_setting('test.cohort_result')::jsonb result; rollback;`);
    const data=row.result;
    const expected=scoreEvidence({species:'dog',service:'nail_trim',keys:['service:nail_trim','size:XS']},
      data.samples.map(sample=>({customer:sample.customer,species:'dog',service:'nail_trim',rating:5,
        age:(Date.parse(data.as_of)-Date.parse(sample.service_at))/86400000,answers:{'service:nail_trim':'positive'}})),
      data.score.distance_miles);
    for(const key of ['f','q','d','b','s']) assert.ok(Math.abs(data.score[key]-expected[key])<1e-7,key);
    const negative=scoreEvidence({species:'dog',service:'nail_trim',keys:['service:nail_trim','size:XS']},
      data.samples.map(sample=>({customer:sample.customer,species:'dog',service:'nail_trim',rating:1,
        age:(Date.parse(data.as_of)-Date.parse(sample.service_at))/86400000,answers:{'service:nail_trim':'negative'}})),data.negative_score.distance_miles);
    for(const key of ['f','q','d','b','s']) assert.ok(Math.abs(data.negative_score[key]-negative[key])<1e-7,`negative ${key}`);
    saveArtifact("cohort-db",data);
    return {customers:10,score:data.score,negativeScore:data.negative_score,rollback:true,independentHumansNotProven:true};
  });
}

async function reviewRace() {
  await check("M13 concurrent HTTP review creates exactly one rating",async()=>{
    assert.equal(saved.matching.evidenceCompleted,1000,"Complete the isolated evidence fixture first");
    const [fixture]=query(`select b.id booking_id,c.context_revision,v.id review_id,v.rating,
      g.rating_sum,g.rating_count from public.bookings b join public.grooming_requests r on r.id=b.request_id
      join public.reviews v on v.booking_id=b.id join app_private.booking_review_contexts c on c.booking_id=b.id
      join public.groomer_profiles g on g.user_id=b.groomer_id
      where r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}'
        and r.service_notes='${marker} evidence-db' order by b.scheduled_start limit 1;`);
    assert.ok(fixture);
    saved.matching.reviewRace=fixture;
    saveArtifact("recovery",saved);
    query(`begin; set local lock_timeout='5s'; delete from public.reviews where id='${fixture.review_id}'
      and booking_id='${fixture.booking_id}' and customer_id='${actors.C1.id}' and content='${marker}'; commit;`);
    const responses=await Promise.all(Array.from({length:4},async()=>{
      try { return {ok:true,value:await rpc("C1","create_review_v2",{
        p_booking_id:fixture.booking_id,p_expected_context_revision:fixture.context_revision,
        p_rating:fixture.rating,p_content:marker,p_pet_fit_outcomes:[
          {trait_type:"service",trait_value:"nail_trim",outcome:"positive"},
          {trait_type:"size",trait_value:"XS",outcome:"positive"}],
      })}; }
      catch(error) { return {ok:false,status:error.httpStatus,reason:error.serverMessage??error.message}; }
    }));
    assert.equal(responses.filter(response=>response.ok).length,1);
    for(const response of responses.filter(response=>!response.ok)) {
      assert.ok(response.status>=400 && response.status<500);
      assert.match(response.reason,/review_already_exists/);
    }
    const [actual]=query(`select rating_sum,rating_count,
      (select count(*)::integer from public.reviews where booking_id='${fixture.booking_id}') reviews
      from public.groomer_profiles where user_id='${actors.G2.id}';`);
    assert.equal(actual.reviews,1);
    assert.equal(actual.rating_sum,fixture.rating_sum);
    assert.equal(actual.rating_count,fixture.rating_count);
    return {requests:4,created:1,rejected:3,exactRatingRestored:true};
  });
}

async function reviewDatabase() {
  const booking=saved.matching.booking;
  assert.match(booking,/^[0-9a-f-]{36}$/i);
  await check("MR02 review context and exact-rating transaction",async()=>{
    const rows=query(`begin;
      set local lock_timeout='5s'; set local statement_timeout='30s';
      select set_config('request.jwt.claims',jsonb_build_object('sub','${actors.C1.id}','role','authenticated','is_anonymous',false)::text,true);
      select set_config('app.fulfillment_write','1',true);
      -- Test-only completion fixture. No claim of a real-time fulfillment/UI execution.
      update public.bookings set status='completed',fulfillment_phase='completed',
        completed_at=statement_timestamp(),completed_by=groomer_id
        where id='${booking}' and customer_id='${actors.C1.id}' and request_id in (${sqlIDs(saved.requests)});
      do $$ declare c jsonb; r jsonb; n bigint; total bigint; actual_n bigint; actual_total bigint;
        score jsonb; aged jsonb; as_of timestamptz; offer uuid; alternate public.grooming_requests%rowtype;
        frozen jsonb; alias_id uuid; keys jsonb; begin
        c:=public.get_booking_review_context('${booking}');
        as_of:=(c->>'service_at')::timestamptz;
        score:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G1.id}',as_of);
        if (score->>'related_review_count')::integer<>0 or (score->>'positive_weight')::numeric<>0
          or (score->>'completed_count')::integer<>1 then raise exception 'M05 completion invented positive evidence'; end if;
        select to_jsonb(context) into frozen from app_private.booking_review_contexts context where booking_id='${booking}';
        perform public.save_my_pet_v2('${saved.matching.pets[0]}',
          '{"name":"Matching test","species":"Dog","breed":"Unspecified","temperament":"Not Sure","weight_lbs":200,"grooming_notes":"${marker}"}',false);
        if (select to_jsonb(context) from app_private.booking_review_contexts context where booking_id='${booking}') is distinct from frozen then
          raise exception 'M06 mutable pet changed frozen context'; end if;
        keys:=app_private.review_allowed_keys('{"species":"Dog","birthday":"2024-02-29"}','nail_trim','2025-08-29T06:30:00Z','America/Los_Angeles');
        if not keys @> '[{"dimension":"care","value":"puppy"}]'::jsonb then raise exception 'M10 service-local age boundary'; end if;
        keys:=app_private.review_allowed_keys('{"species":"Dog","birthday":"2024-02-29"}','nail_trim','2025-08-29T06:30:00Z','UTC');
        if keys @> '[{"dimension":"care","value":"puppy"}]'::jsonb then raise exception 'M10 puppy calendar boundary'; end if;
        keys:=app_private.review_allowed_keys('{"species":"Dog","birthday":"2024-02-29"}','nail_trim','2034-02-28T20:00:00Z','America/Los_Angeles');
        if not keys @> '[{"dimension":"care","value":"senior"}]'::jsonb then raise exception 'M10 leap-year senior boundary'; end if;
        keys:=app_private.review_allowed_keys('{"species":"Dog","birthday":"2024-02-30"}','nail_trim',as_of,'America/Los_Angeles');
        if exists(select 1 from jsonb_array_elements(keys) k where k->>'dimension'='care') then raise exception 'Invalid birthday invented age'; end if;
        if not c->'allowed_keys' @> '[{"dimension":"size","value":"XS"},{"dimension":"service","value":"nail_trim"}]'::jsonb
          or exists(select 1 from jsonb_array_elements(c->'allowed_keys') k where k->>'dimension'='coat') then
          raise exception 'Incorrect small nail-trim context'; end if;
        begin
          perform public.create_review_v2('${booking}',(c->>'context_revision')::uuid,5,'${marker}',
            '[{"trait_type":"size","trait_value":"Giant","outcome":"positive"}]');
          raise exception 'Giant assertion was accepted';
        exception when sqlstate '22023' then if sqlerrm<>'invalid_pet_fit_context' then raise; end if; end;
        begin
          perform public.create_review_v2('${booking}',(c->>'context_revision')::uuid,5,'${marker}',
            '[{"trait_type":"coat","trait_value":"curly_wavy","outcome":"positive"}]');
          raise exception 'Unrelated coat assertion was accepted';
        exception when sqlstate '22023' then if sqlerrm<>'invalid_pet_fit_context' then raise; end if; end;
        begin
          perform public.create_review_v2('${booking}',gen_random_uuid(),5,'${marker}','[]');
          raise exception 'Stale context was accepted';
        exception when sqlstate '22023' then if sqlerrm<>'review_context_changed' then raise; end if; end;
        begin
          perform public.create_review_v2('${booking}',(c->>'context_revision')::uuid,5,'${marker}',
            '[{"trait_type":"service","trait_value":"nail_trim","outcome":"positive"},
              {"trait_type":"service","trait_value":"nail_trim","outcome":"negative"}]');
          raise exception 'Conflicting duplicate accepted';
        exception when sqlstate '22023' then if sqlerrm<>'duplicate_review_outcome' then raise; end if; end;
        select rating_count,rating_sum into n,total from public.groomer_profiles where user_id='${actors.G1.id}';
        r:=public.create_review_v2('${booking}',(c->>'context_revision')::uuid,5,'${marker}',
          '[{"trait_type":"service","trait_value":"nail_trim","outcome":"positive"},
            {"trait_type":"size","trait_value":"XS","outcome":"negative"}]');
        if (select count(*) from app_private.review_evidence_projection where review_id=(r->>'review_id')::uuid and is_valid)<>2 then
          raise exception 'Verified projection missing'; end if;
        select * into alternate from public.grooming_requests where id='${saved.requests[0]}';
        alternate.id:=gen_random_uuid(); alternate.terms_revision:=gen_random_uuid();
        alternate.pet_snapshot:=jsonb_set(alternate.pet_snapshot,'{species}','"Cat"');
        insert into public.grooming_requests select alternate.*;
        score:=app_private.score_match_evidence(alternate.id,'${actors.G1.id}',as_of);
        if (score->>'f')::numeric<>50 or (score->>'q_review_count')::integer<>1 then
          raise exception 'M03/M20 species-specific F leaked or removed valid Q'; end if;
        alternate.id:=gen_random_uuid(); alternate.terms_revision:=gen_random_uuid(); alternate.service_type:='custom_request';
        insert into public.grooming_requests select alternate.*;
        score:=app_private.score_match_evidence(alternate.id,'${actors.G1.id}',as_of);
        if (score->>'f')::numeric<>50 then raise exception 'M27 custom inherited fixed-service evidence'; end if;
        update public.reviews set created_at=as_of+interval '365 days' where id=(r->>'review_id')::uuid;
        if (select service_at from app_private.booking_review_contexts where booking_id='${booking}')<>as_of then
          raise exception 'M07 late review changed service clock'; end if;
        as_of:=(c->>'service_at')::timestamptz;
        select offer_id into offer from public.bookings where id='${booking}';
        score:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G1.id}',as_of,offer);
        if abs((score->>'positive_weight')::numeric-0.5)>0.000001
          or abs((score->>'negative_weight')::numeric-0.5)>0.000001
          or (score->>'f')::numeric<>50 or abs((score->>'q')::numeric-100*3.5/6)>0.000001 then
          raise exception 'Polarized fixed-vector score mismatch: %',score; end if;
        update public.review_pet_fit_outcomes set outcome='positive' where review_id=(r->>'review_id')::uuid;
        score:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G1.id}',as_of,offer);
        if abs((score->>'positive_weight')::numeric-1)>0.000001
          or abs((score->>'f')::numeric-(50+50.0/6))>0.000001 then raise exception 'Positive vector mismatch'; end if;
        aged:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G1.id}',as_of+interval '180 days',offer);
        if abs((aged->>'positive_weight')::numeric-0.5)>0.000001 then raise exception 'Half-life mismatch'; end if;
        update public.review_pet_fit_outcomes set outcome='negative' where review_id=(r->>'review_id')::uuid;
        aged:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G1.id}',as_of,offer);
        if (aged->>'f')::numeric>=50 or (aged->>'related_review_count')::integer<>1 then
          raise exception 'Negative evidence hidden or did not lower score'; end if;
        insert into public.review_pet_fit_outcomes(review_id,booking_id,customer_id,groomer_id,trait_type,trait_value,outcome)
          values((r->>'review_id')::uuid,'${booking}','${actors.C1.id}','${actors.G1.id}',
            'service_fit','nail_paw_care','positive') returning id into alias_id;
        if (select count(*) from app_private.review_evidence_projection where review_id=(r->>'review_id')::uuid
          and dimension='service' and isolation_reason='conflicting_alias' and not is_valid)<>2 then
          raise exception 'M04 historical conflicting aliases were not both isolated'; end if;
        delete from public.review_pet_fit_outcomes where id=alias_id;
        select rating_count,rating_sum into actual_n,actual_total from public.groomer_profiles where user_id='${actors.G1.id}';
        if actual_n<>n+1 or actual_total<>total+5 then raise exception 'Insert rating drift'; end if;
        update app_private.booking_review_contexts set service_at=null where booking_id='${booking}';
        score:=app_private.score_match_evidence('${saved.requests[0]}','${actors.G1.id}',as_of,offer);
        if (score->>'related_review_count')::integer<>0 or (score->>'q_review_count')::integer<>0 then
          raise exception 'M09 missing trusted time entered internal evidence'; end if;
        if (select rating_sum from public.groomer_profiles where user_id='${actors.G1.id}')<>total+5 then
          raise exception 'M09 missing trusted time removed public stars'; end if;
        update app_private.booking_review_contexts set service_at=as_of where booking_id='${booking}';
        update public.reviews set rating=1 where id=(r->>'review_id')::uuid;
        select rating_count,rating_sum into actual_n,actual_total from public.groomer_profiles where user_id='${actors.G1.id}';
        if actual_n<>n+1 or actual_total<>total+1 then raise exception 'Update rating drift'; end if;
        delete from public.reviews where id=(r->>'review_id')::uuid;
        select rating_count,rating_sum into actual_n,actual_total from public.groomer_profiles where user_id='${actors.G1.id}';
        if actual_n<>n or actual_total<>total then raise exception 'Delete rating drift'; end if;
        if exists(select 1 from app_private.review_evidence_projection where review_id=(r->>'review_id')::uuid) then
          raise exception 'Orphan projection'; end if;
        if public.get_booking_review_context('${booking}') is distinct from c then raise exception 'Context drift'; end if;
        r:=public.create_review_v2('${booking}',(c->>'context_revision')::uuid,4,'${marker}','[]');
        if exists(select 1 from app_private.review_evidence_projection where review_id=(r->>'review_id')::uuid) then
          raise exception 'Empty answers invented evidence'; end if;
      end $$;
      select true passed, 'DB rollback, not real-time fulfillment' scope; rollback;`);
    assert.equal(rows[0].passed,true); return rows[0];
  });
}

async function verify() {
  assert.equal(saved.requests.length,1);
  const requestID=saved.requests[0];
  const params={p_request_id:requestID,p_sort:"balanced",p_limit:1,p_cursor:null};
  const first=await rpc("C1","get_ranked_customer_offers",params);
  assert.ok(first.next_cursor);
  await check("M49 tampered cursor",()=>denied("C1","get_ranked_customer_offers",
    {...params,p_cursor:first.next_cursor.slice(0,-1)+(first.next_cursor.endsWith("0")?"1":"0")},/invalid_cursor/));
  await check("M49 wrong-role cursor",()=>denied("G1","get_ranked_customer_offers",
    {...params,p_cursor:first.next_cursor},/not_allowed/));
  await check("M49 cross-mode cursor",()=>denied("C1","get_ranked_customer_offers",
    {...params,p_sort:"price",p_cursor:first.next_cursor},/invalid_cursor/));
  await check("duplicate service configuration preserves existing quote",async()=>{
    const rows=query(`begin; insert into public.groomer_services(groomer_id,title,description,base_price,
      duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species)
      select groomer_id,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species
      from public.groomer_services where id in (${sqlIDs(saved.matching.services.slice(0,1))});
      select status,app_private.evaluate_quote(id) evaluation from public.groomer_offers where request_id='${requestID}'; rollback;`);
    assert.ok(rows.filter(row=>row.status==='pending').length>=2);
    assert.ok(rows.every(row=>Boolean(row.evaluation.selectable)===(row.status==='pending')));
    return {checked:rows.length,withdrawnRemainUnselectable:true,rollback:true};
  });
  const offers=await api.restSelect("groomer_offers",`select=*&request_id=eq.${requestID}`,actors.C1.token);
  const selected=offers.find(offer=>offer.groomer_id===actors.G1.id);
  await check("M13 concurrent acceptance is one receipt",async()=>{
    const responses=await Promise.all(Array.from({length:4},()=>rpc("C1","accept_groomer_offer_v2",
      {p_offer_id:selected.id,p_expected_quote_revision:selected.quote_revision})));
    assert.equal(new Set(responses.map(result=>result[0].booking_id)).size,1);
    saved.matching.booking=responses[0][0].booking_id; saveArtifact("recovery",saved);
    const rows=await api.restSelect("bookings",`select=id&request_id=eq.${requestID}`,actors.C1.token);
    assert.equal(rows.length,1); return {attempts:4,bookings:1};
  });
  await check("M46 accepted list invalidates old cursor",()=>denied("C1","get_ranked_customer_offers",
    {...params,p_cursor:first.next_cursor},/list_changed/));
  await check("M01 unfinished booking review rejected",()=>denied("C1","get_booking_review_context",
    {p_booking_id:saved.matching.booking},/booking_not_completed/));
}

function delay(ms) { return new Promise(resolve => setTimeout(resolve,ms)); }
function revisionFixture() {
  assert.ok(runID.startsWith("TESTOPS-T391-"));
  assert.equal(saved.matching.httpRequests?.length,26);
  assert.equal(saved.matching.evidenceCompleted,1000);
  const [config]=query("select enabled,validation_actor_ids from app_private.match_ranking_config where singleton;");
  assert.equal(config.enabled,true);
  assert.deepEqual(config,saved.matching.rankingConfigBaseline);
  if(!saved.matching.validationHistory?.prepared) {
    const [history]=query(`select count(*)::integer n,min(c.service_at) minimum,max(c.service_at) maximum,
      greatest(0,ceil(extract(epoch from max(c.service_at)-statement_timestamp()+interval '1 day')))::integer shift
      from app_private.booking_review_contexts c join public.bookings b on b.id=c.booking_id
      join public.grooming_requests r on r.id=b.request_id where r.customer_id='${actors.C1.id}'
        and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';`);
    assert.equal(history.n,1000);
    saved.matching.validationHistory??={...history,prepared:false,synthetic:true,cleanup:"delete exact owned contexts with fixture"};
    const before=saved.matching.validationHistory;
    saveArtifact("recovery",saved);
    if(history.maximum===before.maximum) query(`begin;set local lock_timeout='5s';set local statement_timeout='100s';
      update app_private.booking_review_contexts c set service_at=c.service_at-make_interval(secs=>${before.shift})
        from public.bookings b,public.grooming_requests r where b.id=c.booking_id and r.id=b.request_id
          and r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';
      update app_private.review_evidence_projection e set service_at=c.service_at
        from public.reviews v,app_private.booking_review_contexts c,public.bookings b,public.grooming_requests r
        where v.id=e.review_id and c.booking_id=v.booking_id and b.id=c.booking_id and r.id=b.request_id
          and r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';commit;`);
    else assert.equal(Date.parse(history.maximum),Date.parse(before.maximum)-before.shift*1000,"History changed outside this run");
    saved.matching.validationHistory.prepared=true;saveArtifact("recovery",saved);
  }
  const [review]=query(`select v.id,v.rating,o.id outcome_id,o.outcome,c.service_at from public.reviews v
    join public.bookings b on b.id=v.booking_id join public.grooming_requests r on r.id=b.request_id
    join public.review_pet_fit_outcomes o on o.review_id=v.id and o.trait_type='service'
    join app_private.booking_review_contexts c on c.booking_id=b.id
    where r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}'
      and r.service_notes='${marker} evidence-db' order by c.service_at desc,v.id limit 1;`);
  assert.ok(review,"Owned review required");
  return review;
}
function changeReview(review,kind,value) {
  const isRating=kind==="rating";
  const result=query(`begin;set local lock_timeout='5s';set local statement_timeout='30s';
    update public.${isRating?"reviews":"review_pet_fit_outcomes"} v set ${isRating?"rating":"outcome"}=${isRating?Number(value):`'${value}'`}
    from public.bookings b,public.grooming_requests r where v.id='${isRating?review.id:review.outcome_id}'
      and b.id=v.booking_id and r.id=b.request_id and r.customer_id='${actors.C1.id}'
      and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db'
      and v.${isRating?"rating":"outcome"} in (${isRating?`${review.rating},${review.rating===5?1:5}`:"'positive','negative'"})
    returning v.id;commit;`);
  assert.equal(result.length,1,"Mutation must affect exactly one owned row");
}
function pageRequest(role,cursor=null) {
  return role==="groomer"
    ? rpc("G2","get_ranked_matched_requests",{p_sort:"fit",p_limit:6,p_cursor:cursor})
    : rpc("C1","get_ranked_customer_offers",{p_request_id:saved.requests[0],p_sort:"balanced",p_limit:1,p_cursor:cursor});
}
function pageIDs(role,page) { return page.items.map(item => role==="groomer"?item.request.id:item.offer.id); }
async function browsePages(role,waitMS=0) {
  const result={complete:false,pages:[],ids:[],readMS:[],startedAt:new Date().toISOString()};
  let cursor=null;
  do {
    try {
      const start=performance.now(),page=await pageRequest(role,cursor);
      result.readMS.push(performance.now()-start);
      assert.equal(page.effective_mode,role==="groomer"?"fit":"balanced");
      const ids=pageIDs(role,page);
      assert.ok(ids.every(id=>!result.ids.includes(id)),"Repeated page member");
      result.ids.push(...ids);result.pages.push({revision:page.ranking_revision,asOf:page.score_as_of,ids});
      cursor=page.next_cursor;
      if(cursor) await delay(waitMS);
    } catch(error) {
      if(!/list_changed/.test(error.serverMessage??error.message)) throw error;
      result.reason="list_changed";result.finishedAt=new Date().toISOString();return result;
    }
  } while(cursor);
  result.complete=true;result.finishedAt=new Date().toISOString();return result;
}
async function revisionLive() {
  const review=revisionFixture();
  const expectConflict=process.argv.includes("--expect-conflict");
  await check(`V01 real HTTP star-only update ${expectConflict?"reproduction":"correction"}`,async()=>{
    const groomer=await pageRequest("groomer"),customer=await pageRequest("customer");
    assert.ok(groomer.next_cursor && customer.next_cursor);
    const score=()=>query(`select app_private.score_match_evidence('${groomer.items[0].request.id}',
      '${actors.G2.id}','${groomer.score_as_of}') score;`)[0].score;
    const before=score();
    saved.matching.revisionMutation={review,restored:false};saveArtifact("recovery",saved);
    try {
      changeReview(review,"rating",review.rating===5?1:5);
      const after=score();
      assert.equal(after.f,before.f);assert.equal(after.b,before.b);
      assert.notEqual(after.q,before.q,"The star update must affect actual historical rating evidence");
      let response,error;
      try {response=await pageRequest("groomer",groomer.next_cursor);} catch(caught) {error=caught;}
      if(expectConflict) assert.match(error?.serverMessage??error?.message??"",/list_changed/);
      else {assert.ifError(error);assert.equal(response.ranking_revision,groomer.ranking_revision);}
      await denied("C1","get_ranked_customer_offers",{p_request_id:saved.requests[0],p_sort:"balanced",p_limit:1,
        p_cursor:customer.next_cursor},/list_changed/);
      query(`set statement_timeout='100s';do $$ declare i integer;begin for i in 1..12 loop
        perform app_private.drain_match_refresh_queue(250);
        exit when not exists(select 1 from app_private.match_refresh_queue where request_id in (${sqlIDs(saved.matching.httpRequests)}));
      end loop;end $$;`);
      if(!expectConflict) {
        const drained=await pageRequest("groomer",groomer.next_cursor);
        assert.equal(drained.ranking_revision,groomer.ranking_revision);
      }
      return {reviewID:review.id,first:groomer.ranking_revision,before,after,
        oldCodeConflict:expectConflict,customerVisibleChangeRejected:true,softDrainChecked:!expectConflict};
    } finally {
      changeReview(review,"rating",review.rating);
      saved.matching.revisionMutation.restored=true;saveArtifact("recovery",saved);
    }
  });
}
async function pagingMatrix() {
  const review=revisionFixture();
  const loads=[{name:"unchanged",periodMS:0},{name:"unrelated",periodMS:10000},
    {name:"soft-60s",periodMS:60000},{name:"soft-10s",periodMS:10000}];
  const evidence={seed:391,loads:[],mutationType:"owned SQL outcome update with actual projection/queue triggers",hard:[]};
  const [pet]=query(`select id,name from public.pets where id='${saved.matching.pets[1]}' and customer_id='${actors.C1.id}'
    and grooming_notes='${marker}';`);
  assert.equal(pet.name,"Matching test");
  saved.matching.matrixMutation={review,pet,restored:false};saveArtifact("recovery",saved);
  try {
    for(const load of loads) for(const role of ["groomer","customer"]) {
      const baseline=await browsePages(role);
      assert.ok(baseline.complete);
      assert.equal(baseline.ids.length,role==="groomer"?26:2);
      const row={...load,role,sessions:[]};evidence.loads.push(row);
      for(const schedule of fixedPagingSchedule(load.periodMS)) {
        let timer,mutationError,sequence=0,nextDue=schedule.phaseMS;
        const started=performance.now(),mutations=[];
        const mutate=()=>{
          const begun=performance.now()-started;sequence++;
          try {
            if(load.name==="unrelated") {
              const updated=query(`update public.pets set name='${sequence%2?"Matching test alternate":"Matching test"}'
                where id='${pet.id}' and customer_id='${actors.C1.id}' and grooming_notes='${marker}'
                  and name in('Matching test','Matching test alternate') returning id;`);
              assert.equal(updated.length,1);
            } else changeReview(review,"outcome",sequence%2?(review.outcome==="positive"?"negative":"positive"):review.outcome);
            mutations.push({plannedMS:nextDue,begunMS:begun,committedMS:performance.now()-started,committedAt:new Date().toISOString()});
            nextDue+=load.periodMS;
            timer=setTimeout(mutate,Math.max(0,nextDue-(performance.now()-started)));
          } catch(error) {mutationError=error;}
        };
        if(load.periodMS) {
          if(nextDue===0) mutate(); else timer=setTimeout(mutate,nextDue);
        }
        let session;
        try {session=await browsePages(role,schedule.waitMS);} finally {clearTimeout(timer);}
        if(mutationError) throw mutationError;
        Object.assign(session,schedule,{mutations,refreshes:0});
        row.sessions.push(session);saveArtifact("paging-matrix",evidence);
        if(session.complete) assert.deepEqual([...session.ids].sort(),[...baseline.ids].sort());
        else {
          const recovered=await browsePages(role,schedule.waitMS);
          session.refreshes=1;session.recovery=recovered;
          assert.ok(recovered.complete,"First refresh after changes stop must finish");
          assert.deepEqual([...recovered.ids].sort(),[...baseline.ids].sort());
        }
        if(load.name.startsWith("soft")) changeReview(review,"outcome",review.outcome);
        if(load.name==="unrelated") query(`update public.pets set name='Matching test' where id='${pet.id}'
          and customer_id='${actors.C1.id}' and grooming_notes='${marker}' and name in('Matching test','Matching test alternate');`);
        saveArtifact("paging-matrix",evidence);
      }
      row.complete=row.sessions.filter(s=>s.complete).length;
      row.required=load.name==="soft-10s"?8:load.name==="soft-60s"?9:10;
      row.budgetMet=row.complete>=row.required;
      row.overlappingSessions=row.sessions.filter(s=>s.mutations.some(m=>m.committedAt>s.startedAt && m.committedAt<s.finishedAt)).length;
      saveArtifact("paging-matrix",evidence);
      console.log(`Paging ${load.name}/${role}: ${row.complete}/10 first-pass; budget ${row.required}/10`);
      if(!load.name.startsWith("soft")) assert.ok(row.budgetMet,"Unchanged/unrelated load must never interrupt");
    }
    const starts=[];
    for(const role of ["groomer","customer"]) for(const schedule of fixedPagingSchedule(0)) {
      const first=await pageRequest(role);assert.ok(first.next_cursor);
      starts.push({role,...schedule,first});
    }
    const [offer]=await api.restSelect("groomer_offers",`select=*&request_id=eq.${saved.requests[0]}&groomer_id=eq.${actors.G2.id}&status=eq.pending`,actors.C1.token);
    assert.ok(offer);
    saved.matching.hardMutation={offerID:offer.id,restored:false};saveArtifact("recovery",saved);
    try {
      const changedAt=new Date().toISOString();
      await rpc("G2","withdraw_groomer_offer",{p_offer_id:offer.id});
      const rejected=await denied("C1","accept_groomer_offer_v2",{p_offer_id:offer.id,
        p_expected_quote_revision:offer.quote_revision},/offer_not_pending|offer_not_available|offer_unavailable|quote_terms_invalid/);
      evidence.hardChange={offerID:offer.id,changedAt,staleAcceptance:rejected};
      for(const start of starts) {
        await delay(start.waitMS);
        let failure;
        try {await pageRequest(start.role,start.first.next_cursor);} catch(error) {failure=error;}
        assert.match(failure?.serverMessage??failure?.message??"",/list_changed/);
        const recovery=await browsePages(start.role,start.waitMS);
        evidence.hard.push({role:start.role,index:start.index,waitMS:start.waitMS,
          firstRevision:start.first.ranking_revision,oldCursorRejected:true,recovery});
        saveArtifact("paging-matrix",evidence);
        assert.ok(recovery.complete,"Hard change must recover on the first fresh browse");
      }
    } finally {
      assert.ok(!saved.uncertainWrite,"Reconcile an uncertain role write before restoring the hard-change fixture");
      const [request]=await api.restSelect("grooming_requests",`select=terms_revision&id=eq.${saved.requests[0]}`,actors.C1.token);
      const [replacement]=await rpc("G2","create_groomer_offer_v3",{p_request_id:saved.requests[0],
        p_expected_request_revision:request.terms_revision,p_proposed_start:offer.proposed_start,p_proposed_end:offer.proposed_end,
        p_price_estimate:offer.price_estimate,p_message:marker,p_assessment_confirmations:[]});
      saved.matching.hardMutation={...saved.matching.hardMutation,restored:true,replacementID:replacement.offer_id};
      saveArtifact("recovery",saved);
    }
  } finally {
    changeReview(review,"outcome",review.outcome);
    query(`update public.pets set name='Matching test' where id='${pet.id}' and customer_id='${actors.C1.id}'
      and grooming_notes='${marker}' and name in('Matching test','Matching test alternate');`);
    saved.matching.matrixMutation.restored=true;saveArtifact("recovery",saved);
    saveArtifact("paging-matrix",evidence);
  }
}
async function roleLatency() {
  revisionFixture();
  for(const role of ["groomer","customer"]) await check(`RV02 ${role} 30 SQL and HTTP reads`,async()=>{
    const actor=actors[role==="groomer"?"G2":"C1"].id;
    const call=role==="groomer"?"public.get_ranked_matched_requests('fit',6,null)":
      `public.get_ranked_customer_offers('${saved.requests[0]}','balanced',1,null)`;
    const full=await browsePages(role);assert.ok(full.complete);
    assert.equal(full.ids.length,role==="groomer"?26:2);
    const [row]=query(`begin;set local statement_timeout='90s';
      select set_config('request.jwt.claims','${JSON.stringify({sub:actor,role:"authenticated",is_anonymous:false})}',true);
      set local role authenticated;
      do $$ declare i integer;t timestamptz;readings numeric[]:='{}';page jsonb;begin
        for i in 1..30 loop t:=clock_timestamp();page:=${call};
          if page->>'effective_mode'<>'${role==="groomer"?"fit":"balanced"}' then raise exception 'Unexpected fallback';end if;
          readings:=array_append(readings,extract(epoch from clock_timestamp()-t)*1000);end loop;
        perform set_config('test.t391_readings',to_jsonb(readings)::text,true);end $$;
      select current_setting('test.t391_readings')::jsonb readings;rollback;`);
    const http=[];
    for(let i=0;i<30;i++) {const start=performance.now();await pageRequest(role);http.push(performance.now()-start);}
    const p95=values=>[...values].sort((a,b)=>a-b)[28];
    const result={candidateCount:full.ids.length,firstHTTP:full.readMS[0],sql:row.readings.map(Number),http,
      sqlP95:p95(row.readings.map(Number)),httpP95:p95(http)};
    saveArtifact(`role-latency-${role}`,result);
    assert.ok(result.sqlP95<=1500);assert.ok(result.httpP95<=2500);return result;
  });
}

async function pagingLive() {
  await check("M47/M50 five-page HTTP browsing with ten-second review mutations",async()=>{
    const [config]=query("select enabled,validation_actor_ids from app_private.match_ranking_config where singleton;");
    const validationPolicy=rankingValidationPlan(config,[actors.G2.id]);
    const [review]=query(`select v.id,v.rating from public.reviews v join public.bookings b on b.id=v.booking_id
      join public.grooming_requests r on r.id=b.request_id where r.customer_id='${actors.C1.id}'
        and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db' order by v.id limit 1;`);
    assert.ok(review && review.rating>=1 && review.rating<=5);
    const alternative=review.rating===5 ? 4 : 5,attempts=[],mutations=[];
    saved.matching.pagingMutation={...review,alternative,restored:false};
    saved.matching.rankingValidationRestored=false;saveArtifact("recovery",saved);
    let timer,mutationError,consecutiveFailures=0;
    try {
      if(validationPolicy.activateSQL) query(validationPolicy.activateSQL);
      const started=Date.now();
      timer=setInterval(()=>{
        try {
          const rows=query(`update public.reviews v set rating=case when v.rating=${review.rating} then ${alternative} else ${review.rating} end
            from public.bookings b,public.grooming_requests r where v.id='${review.id}' and b.id=v.booking_id and r.id=b.request_id
              and v.rating in(${review.rating},${alternative}) and r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}'
              and r.service_notes='${marker} evidence-db' returning v.rating;`);
          assert.equal(rows.length,1);mutations.push({atMS:Date.now()-started,rating:rows[0].rating});
        } catch(error) {mutationError=error;clearInterval(timer);}
      },10000);
      while(Date.now()-started<35000) {
        if(mutationError) throw mutationError;
        let cursor=null,pages=0;const seen=[],attemptStart=Date.now();
        try {
          do {
            const page=await rpc("G2","get_ranked_matched_requests",{p_sort:"fit",p_limit:6,p_cursor:cursor});
            assert.equal(page.effective_mode,"fit");pages++;seen.push(...page.items.map(item=>item.request.id));
            cursor=page.next_cursor;
            if(cursor) await new Promise(resolve=>setTimeout(resolve,1000));
          } while(cursor);
          assert.equal(pages,5);assert.equal(new Set(seen).size,seen.length);
          assert.deepEqual([...seen].sort(),[...saved.matching.httpRequests].sort());
          attempts.push({complete:true,pages,ms:Date.now()-attemptStart});consecutiveFailures=0;
        } catch(error) {
          if(!/list_changed/.test(error.serverMessage??error.message)) throw error;
          attempts.push({complete:false,pages,ms:Date.now()-attemptStart,reason:"list_changed"});consecutiveFailures++;
        }
        saveArtifact("paging-live",{attempts,mutations});
        assert.ok(consecutiveFailures<3,"Three consecutive explicit refresh attempts could not finish");
      }
      assert.ok(mutations.length>=3);assert.ok(attempts.some(attempt=>attempt.complete));
      const complete=attempts.filter(attempt=>attempt.complete).length;
      return {attempts,mutations,completionRate:complete/attempts.length,restartRate:1-complete/attempts.length};
    } finally {
      clearInterval(timer);
      try {
        const rows=query(`update public.reviews v set rating=${review.rating} from public.bookings b,public.grooming_requests r
          where v.id='${review.id}' and b.id=v.booking_id and r.id=b.request_id and v.rating in(${review.rating},${alternative})
            and r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db' returning v.id;`);
        assert.equal(rows.length,1,"Review changed outside the fixture; preserve it");
        saved.matching.pagingMutation.restored=true;saveArtifact("recovery",saved);
      } finally {
        query(validationPolicy.restoreSQL ?? validationPolicy.verifySQL);
        saved.matching.rankingValidationRestored=true;saveArtifact("recovery",saved);
      }
    }
  });
}

async function pagingDatabase() {
  await check("M41/M43 full-scope top candidate survives old-page placement",async()=>{
    const groomer=actors.G2.id;
    query(`begin;set local lock_timeout='5s';set local statement_timeout='20s';
      update app_private.match_ranking_config set validation_actor_ids=array['${groomer}'::uuid] where singleton;
      select set_config('request.jwt.claims','${JSON.stringify({sub:groomer,role:"authenticated",is_anonymous:false})}',true);
      do $$ declare page jsonb;best uuid;oldest timestamptz;begin
        page:=public.get_ranked_matched_requests('fit',25,null);
        best:=(page->'items'->0->'request'->>'id')::uuid;
        if best not in(select id from public.grooming_requests where customer_id='${actors.C1.id}'
          and service_notes='${marker} http-ranking') then raise exception 'Top candidate outside owned fixture';end if;
        select min(created_at)-interval '1 day' into oldest from public.request_matches where groomer_id='${groomer}';
        update public.request_matches set created_at=oldest where request_id=best and groomer_id='${groomer}';
        update public.grooming_requests set created_at=oldest where id=best;
        if best in(select request_id from public.request_matches where groomer_id='${groomer}'
          and status in('visible','viewed') order by created_at desc,id desc limit 25)
          then raise exception 'Fixture did not place top candidate on old second page';end if;
        page:=public.get_ranked_matched_requests('fit',25,null);
        if(page->'items'->0->'request'->>'id')::uuid<>best then raise exception 'Top full-scope candidate was truncated';end if;
        page:=public.get_ranked_matched_requests('newest',25,null);
        if(page->'items'->0->'request'->>'id')::uuid=best then raise exception 'Explicit newest was overridden by default ranking';end if;
      end $$;rollback;`);
    return {rollback:true,topTotalRankOutsideOld25:true,defaultTieStable:true,explicitNewestPrimary:true};
  });
  await check("M44 enabled customer price order remains primary",async()=>{
    query(`begin;set local statement_timeout='20s';
      update app_private.match_ranking_config set validation_actor_ids=array['${actors.C1.id}'::uuid] where singleton;
      select set_config('request.jwt.claims','${JSON.stringify({sub:actors.C1.id,role:"authenticated",is_anonymous:false})}',true);
      set local role authenticated;
      do $$ declare page jsonb;begin
        page:=public.get_ranked_customer_offers('${saved.requests[0]}','price',25,null);
        if page->>'effective_mode'<>'price' or (page->'items'->0->'offer'->>'price_estimate')::numeric<>80
          then raise exception 'Enabled ranking overrode price';end if;
      end $$;rollback;`);
    return {rollback:true,enabledAlgorithm:true,lowestPrice:80};
  });
}

async function admissionDatabase() {
  await check("M32 legacy null species blocks quotes until explicit save",async()=>{
    query(`begin;set local lock_timeout='5s';set local statement_timeout='30s';
      do $$ declare s public.groomer_services%rowtype;r public.grooming_requests%rowtype; confirmations text[];begin
        select * into strict s from public.groomer_services where groomer_id='${actors.G1.id}'
          and is_active and accepted_species is null order by id limit 1;
        update public.groomer_services set is_active=false where groomer_id=s.groomer_id
          and service_type=s.service_type and id<>s.id and is_active;
        select * into strict r from public.grooming_requests where id='${saved.matching.httpRequests[0]}';
        r.id:=gen_random_uuid();r.terms_revision:=gen_random_uuid();r.service_type:=s.service_type;
        r.service_notes:='${marker} legacy-species';
        insert into public.grooming_requests select r.*;
        begin perform app_private.validate_offer_match_facts(r.id,s.groomer_id,'{}');
          raise exception 'Legacy species allowed quote';
        exception when sqlstate '22023' then if sqlerrm<>'service_species_confirmation_required' then raise;end if;end;
        update public.groomer_services set accepted_species=array[lower(r.pet_snapshot->>'species')] where id=s.id;
        select * into strict s from public.groomer_services where id=s.id;
        confirmations:=app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes);
        perform app_private.validate_offer_match_facts(r.id,s.groomer_id,confirmations);
      end $$;rollback;`);
    return {rollback:true,legacyQuoteBlocked:true,explicitSaveRestoresQuoteValidation:true};
  });
  await check("M31/M32/M34 explicit exclusions and missing coordinates cannot become assessment",async()=>{
    const request=saved.matching.httpRequests[0],groomer=actors.G1.id,service=saved.matching.services[0];
    query(`begin;set local lock_timeout='5s';set local statement_timeout='30s';
      do $$ declare verdict jsonb;reason text;r public.grooming_requests%rowtype;begin
        if (select count(*) from public.groomer_services where groomer_id='${groomer}' and is_active and service_type='nail_trim')<>1
          then raise exception 'Admission fixture requires one supporting configuration';end if;
        if app_private.evaluate_match_constraints('${request}','${groomer}',statement_timestamp())->>'state'<>'eligible'
          then raise exception 'Admission fixture lacks eligible baseline';end if;
        foreach reason in array array['pet_species_excluded','pet_size_excluded','service_unavailable','location_excluded'] loop
          begin
            case reason
            when 'pet_species_excluded' then update public.groomer_services set accepted_species=array['cat'] where id='${service}';
            when 'pet_size_excluded' then update public.groomer_services set accepted_pet_sizes=array['Giant'] where id='${service}';
            when 'service_unavailable' then update public.groomer_services set is_active=false where id='${service}';
            when 'location_excluded' then update public.groomer_profiles set address_location_id=null where user_id='${groomer}';
            end case;
            verdict:=app_private.evaluate_match_eligibility('${request}','${groomer}',statement_timestamp());
            if verdict->>'state'<>'excluded' or verdict->>'reason'<>reason then raise exception 'Unexpected exclusion: %',verdict;end if;
            begin perform app_private.validate_offer_match_facts('${request}','${groomer}','{}');raise exception 'Explicit exclusion allowed quote';
            exception when sqlstate '22023' then if sqlerrm<>'match_constraints_changed' then raise;end if;end;
            raise exception using errcode='Z3901',message='restore_fixture_branch';
          exception when sqlstate 'Z3901' then null;end;
        end loop;
        begin update public.groomer_services set accepted_species='{}' where id='${service}';raise exception 'Empty active species accepted';
        exception when sqlstate '22023' then if sqlerrm<>'service_species_confirmation_required' then raise;end if;end;
        begin update public.groomer_services set accepted_species=null where id='${service}';raise exception 'Active species cleared to legacy null';
        exception when sqlstate '22023' then if sqlerrm<>'service_species_confirmation_required' then raise;end if;end;
        select source.* into strict r from public.grooming_requests source where source.id='${request}';
        r.id:=gen_random_uuid();r.terms_revision:=gen_random_uuid();r.address_location_id:=null;r.service_notes:='${marker} admission-db';
        insert into public.grooming_requests select r.*;
        verdict:=app_private.evaluate_match_eligibility(r.id,'${groomer}',statement_timestamp());
        if verdict->>'state'<>'excluded' or verdict->>'reason'<>'location_excluded' then raise exception 'Missing request coordinates advertised';end if;
        if app_private.score_match_evidence(r.id,'${groomer}',statement_timestamp())->>'distance_miles' is not null
          then raise exception 'Missing coordinates became a numeric distance';end if;
      end $$;rollback;`);
    return {rollback:true,explicitExclusions:4,emptyAndNullScopeRejected:true,missingCustomerCoordinatesExcluded:true};
  });
}

async function httpRanking() {
  const historical=process.env.TESTOPS_HISTORICAL_CLOCK==="1";
  assert.ok(!saved.matching.httpHistory || saved.matching.httpHistory.restored,"Restore prior historical-clock fixture first");
  const [config]=query("select enabled,validation_actor_ids from app_private.match_ranking_config where singleton;");
  const validation=[actors.C1.id,actors.G1.id,actors.G2.id];
  const validationPolicy=rankingValidationPlan(config,validation);
  const ids=saved.matching.httpRequests?.length ? saved.matching.httpRequests : Array.from({length:26},()=>randomUUID());
  const [existing]=query(`select count(*)::integer n,count(*) filter(where customer_id='${actors.C1.id}'
    and service_notes='${marker} http-ranking')::integer owned from public.grooming_requests where id in (${sqlIDs(ids)});`);
  assert.equal(existing.n,existing.owned,"HTTP fixture ownership changed");
  assert.ok(existing.n===0 || existing.n===26,"Partial HTTP fixture requires reconciliation");
  saved.matching.httpRequests=ids;
  saved.matching.rankingConfigBaseline=config;
  saved.matching.rankingValidationActors=validation;
  saved.matching.rankingValidationRestored=false;
  saveArtifact("recovery",saved);
  try {
    if(existing.n===0) query(`begin;set local lock_timeout='5s';set local statement_timeout='30s';
      do $$ declare r public.grooming_requests%rowtype; id uuid;begin
        select source.* into strict r from public.grooming_requests source where source.id='${saved.requests[0]}' and source.customer_id='${actors.C1.id}';
        r.status:='open';r.supersedes_request_id:=null;r.service_notes:='${marker} http-ranking';
        r.preferred_start:=r.preferred_start+interval '3 days';r.preferred_end:=r.preferred_end+interval '3 days';
        foreach id in array array[${sqlIDs(ids)}] loop
          r.id:=id;r.terms_revision:=gen_random_uuid();r.created_at:=clock_timestamp();r.updated_at:=r.created_at;
          insert into public.grooming_requests select r.*;
        end loop;
      end $$;
      ${validationPolicy.activateSQL ?? ""}
      commit;`);
    else if(validationPolicy.activateSQL) query(validationPolicy.activateSQL);
    if(historical) {
      const [history]=query(`select count(*)::integer n,min(c.service_at) minimum,max(c.service_at) maximum,
        ceil(extract(epoch from max(c.service_at)-statement_timestamp()+interval '1 day'))::integer shift_seconds
        from app_private.booking_review_contexts c join public.bookings b on b.id=c.booking_id
        join public.grooming_requests r on r.id=b.request_id where r.customer_id='${actors.C1.id}'
          and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';`);
      assert.equal(history.n,1000);assert.ok(history.shift_seconds>0);
      saved.matching.httpHistory={...history,restored:false};saveArtifact("recovery",saved);
      query(`begin;set local lock_timeout='5s';set local statement_timeout='60s';
        update app_private.booking_review_contexts c set service_at=c.service_at-make_interval(secs=>${history.shift_seconds})
          from public.bookings b,public.grooming_requests r where b.id=c.booking_id and r.id=b.request_id
            and r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';
        update app_private.review_evidence_projection e set service_at=c.service_at
          from public.reviews v,app_private.booking_review_contexts c,public.bookings b,public.grooming_requests r
          where v.id=e.review_id and c.booking_id=v.booking_id and b.id=c.booking_id and r.id=b.request_id
            and r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';commit;`);
    }
    query(`set statement_timeout='100s';do $$ declare i integer;begin
      for i in 1..12 loop perform app_private.drain_match_refresh_queue(250);
        exit when not exists(select 1 from app_private.match_refresh_queue where request_id in (${sqlIDs(ids)}));end loop;
      if exists(select 1 from app_private.match_refresh_queue where request_id in (${sqlIDs(ids)}))
        then raise exception 'HTTP fixture queue not drained';end if;end $$;`);
    if(process.argv.includes("--fixtures-only")) return;
    await check("MR06 ranking retains authenticated role boundaries",async()=>{
      const selected=await rpc("G1","get_ranked_matched_requests",{p_sort:"fit",p_limit:25,p_cursor:null});
      assert.equal(selected.effective_mode,"fit");
      const outside=await rpc("C2","get_ranked_matched_requests",{p_sort:"fit",p_limit:25,p_cursor:null}).then(()=>null,error=>error);
      assert.ok(outside && /not_allowed/.test(outside.serverMessage??outside.message));
      return {globalEnabled:config.enabled,validatedMode:selected.effective_mode,wrongRoleDenied:true};
    });
    if(historical) await check("MR05 historical 1000-review SQL 30-read budget",async()=>{
      const [row]=query(`begin;set local statement_timeout='60s';
        select set_config('request.jwt.claims','${JSON.stringify({sub:actors.G2.id,role:"authenticated",is_anonymous:false})}',true);
        set local role authenticated;
        do $$ declare i integer;t timestamptz;readings numeric[]:='{}';page jsonb;begin
          for i in 1..30 loop t:=clock_timestamp();page:=public.get_ranked_matched_requests('fit',25,null);
            readings:=array_append(readings,extract(epoch from clock_timestamp()-t)*1000);
            if page->>'effective_mode'<>'fit' then raise exception 'SQL probe measured fallback';end if;end loop;
          perform set_config('test.t390_sql_readings',to_jsonb(readings)::text,true);end $$;
        select current_setting('test.t390_sql_readings')::jsonb readings;rollback;`);
      const readings=row.readings.map(Number),p95=[...readings].sort((a,b)=>a-b)[28];
      const evidence={samples:readings,firstReadMs:readings[0],sqlP95:p95,reviewRows:1000};
      saveArtifact("sql-ranking-historical",evidence);
      assert.ok(p95<=1500,`SQL P95 ${p95.toFixed(1)}ms exceeds 1500ms`);return evidence;
    });
    for (const alias of historical ? ["G2"] : ["G1","G2"]) await check(`MR05 ${alias} full-scope HTTP paging and 30-read latency`,async()=>{
      const readings=[],all=[];let cursor=null,firstScopeReadMs=null;
      do {
        const started=performance.now();
        const page=await rpc(alias,"get_ranked_matched_requests",{p_sort:"fit",p_limit:25,p_cursor:cursor});
        firstScopeReadMs??=performance.now()-started;
        assert.equal(page.effective_mode,"fit");all.push(...page.items.map(item=>item.request.id));cursor=page.next_cursor;
      } while(cursor);
      assert.equal(new Set(all).size,all.length);
      for(const id of ids) assert.ok(all.includes(id),"A legal candidate is missing from the full scope");
      for(let i=0;i<30;i++) {
        const start=performance.now();
        const page=await rpc(alias,"get_ranked_matched_requests",{p_sort:"fit",p_limit:25,p_cursor:null});
        readings.push(performance.now()-start);assert.equal(page.effective_mode,"fit");
      }
      const p95=[...readings].sort((a,b)=>a-b)[Math.ceil(readings.length*.95)-1];
      const result={items:all.length,httpSamples:readings,firstScopeReadMs,firstMeasuredWarmSample:readings[0],httpP95:p95,
        reviewFixtureRows:saved.matching.evidenceCompleted,clock:historical
          ? "actual server clock; 1000 scoped synthetic contexts shifted into history; restoration tracked in recovery"
          : "actual server clock; future service evidence excluded"};
      saveArtifact(`http-ranking-${alias}${historical?"-historical":""}`,result);
      assert.ok(p95<=2500,`HTTP P95 ${p95.toFixed(1)}ms exceeds 2500ms`);return result;
    });
  } finally {
    try {
      if(historical && saved.matching.httpHistory && !saved.matching.httpHistory.restored) {
      const h=saved.matching.httpHistory;
      query(`begin;set local lock_timeout='5s';set local statement_timeout='60s';
        do $$ declare latest timestamptz;begin
          select max(c.service_at) into latest from app_private.booking_review_contexts c
            join public.bookings b on b.id=c.booking_id join public.grooming_requests r on r.id=b.request_id
            where r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';
          if latest='${h.maximum}'::timestamptz then return;end if;
          if latest is distinct from '${h.maximum}'::timestamptz-make_interval(secs=>${h.shift_seconds})
            then raise exception 'Historical fixture changed unexpectedly; preserve it';end if;
          update app_private.booking_review_contexts c set service_at=c.service_at+make_interval(secs=>${h.shift_seconds})
            from public.bookings b,public.grooming_requests r where b.id=c.booking_id and r.id=b.request_id
              and r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';
          update app_private.review_evidence_projection e set service_at=c.service_at
            from public.reviews v,app_private.booking_review_contexts c,public.bookings b,public.grooming_requests r
            where v.id=e.review_id and c.booking_id=v.booking_id and b.id=c.booking_id and r.id=b.request_id
              and r.customer_id='${actors.C1.id}' and b.groomer_id='${actors.G2.id}' and r.service_notes='${marker} evidence-db';
        end $$;commit;`);
        saved.matching.httpHistory.restored=true;saveArtifact("recovery",saved);
      }
    } finally {
    query(`begin;set local lock_timeout='5s';${validationPolicy.restoreSQL ?? validationPolicy.verifySQL}commit;`);
      saved.matching.rankingValidationRestored=true;saveArtifact("recovery",saved);
    }
  }
}

async function eventDatabase() {
  await check("M53/M54/M58 event interleaving, absent-match recovery and dismissal", async () => {
    const id=randomUUID(), groomer=actors.G1.id;
    query(`begin; set local lock_timeout='5s'; set local statement_timeout='60s';
      do $$ declare r public.grooming_requests%rowtype; begin
        if exists(select 1 from app_private.match_refresh_queue) then raise exception 'Event test requires idle queue'; end if;
        select * into strict r from public.grooming_requests where id='${saved.requests[0]}' and customer_id='${actors.C1.id}';
        r.id:='${id}';r.status:='open';r.terms_revision:=gen_random_uuid();r.supersedes_request_id:=null;
        r.preferred_start:=r.preferred_start+interval '2 days';r.preferred_end:=r.preferred_end+interval '2 days';
        r.service_notes:='${marker} event-db';insert into public.grooming_requests select r.*;
        delete from app_private.match_refresh_queue where request_id=r.id;
        delete from public.request_matches where request_id=r.id;
        delete from app_private.match_candidate_evaluations where request_id=r.id;
        insert into app_private.match_refresh_queue(request_id,groomer_id,reason) values(r.id,'${groomer}','hard_eligibility');
      end $$;
      -- Deterministic interleaving: a new hard event arrives after captured work, at consumption.
      create function pg_temp.t390_event_arrival() returns trigger language plpgsql as $$ begin
        if old.request_id='${id}' and old.groomer_id='${groomer}'
          and current_setting('test.t390_event_arrived',true) is distinct from 'yes' then
          perform set_config('test.t390_event_arrived','yes',true);
          insert into app_private.match_refresh_queue(request_id,groomer_id,reason)
            values(old.request_id,old.groomer_id,'hard_eligibility');
        end if;return old;end $$;
      create trigger t390_test_event_arrival before delete on app_private.match_refresh_queue
        for each row execute function pg_temp.t390_event_arrival();
      select app_private.drain_match_refresh_queue(2);
      do $$ begin
        if not exists(select 1 from app_private.match_refresh_queue where request_id='${id}' and groomer_id='${groomer}')
          then raise exception 'New event was lost during consumption'; end if;
        if app_private.read_candidate_evaluation('${id}','${groomer}',statement_timestamp())->>'state'<>'pending'
          then raise exception 'Old result advertised over a new event'; end if;
      end $$;
      drop trigger t390_test_event_arrival on app_private.match_refresh_queue;
      select app_private.drain_match_refresh_queue(100);
      do $$ begin
        if app_private.read_candidate_evaluation('${id}','${groomer}',statement_timestamp())->>'state'<>'estimated_fit'
          then raise exception 'New event did not recover eligibility'; end if;
        update public.groomer_services set accepted_species=array['cat'] where id='${saved.matching.services[0]}';
        delete from public.request_matches where request_id='${id}' and groomer_id='${groomer}';
        perform app_private.drain_match_refresh_queue(100);
        if exists(select 1 from public.request_matches where request_id='${id}' and groomer_id='${groomer}' and status='visible')
          then raise exception 'Excluded species was visible'; end if;
        update public.groomer_services set accepted_species=array['dog'] where id='${saved.matching.services[0]}';
        perform app_private.drain_match_refresh_queue(100);
        if not exists(select 1 from public.request_matches where request_id='${id}' and groomer_id='${groomer}' and status='visible')
          then raise exception 'Candidate without a match failed source-event recovery'; end if;
        update public.request_matches set status='dismissed',dismissed_at=statement_timestamp()
          where request_id='${id}' and groomer_id='${groomer}';
        insert into app_private.match_refresh_queue(request_id,groomer_id,reason) values('${id}','${groomer}','hard_eligibility');
        perform app_private.drain_match_refresh_queue(100);
        if exists(select 1 from public.request_matches where request_id='${id}' and groomer_id='${groomer}' and status<>'dismissed')
          then raise exception 'Dismissed match revived'; end if;
        if exists(select 1 from app_private.match_candidate_evaluations where request_id='${id}' and groomer_id='${groomer}')
          then raise exception 'Dismissed candidate retained proof'; end if;
      end $$; rollback;`);
    return {rollback:true,deterministicInterleaving:true,newEventRetained:true,missingMatchRecovered:true,dismissalPreserved:true};
  });
}

async function privacyDatabase() {
  for (const alias of ["C1", "G1"]) await check(`M15 ${alias} deployed anonymization rollback`, async () => {
    const actor = actors[alias].id;
    query(`begin; set local lock_timeout='5s'; set local statement_timeout='110s';
      select set_config('request.jwt.claims','${JSON.stringify({sub:actor,role:"authenticated",is_anonymous:false})}',true);
      create temporary table privacy_bookings on commit drop as
        select id,status,fulfillment_phase,scheduled_start,scheduled_end,price_estimate,customer_id,groomer_id
        from public.bookings where '${actor}' in (customer_id,groomer_id);
      create temporary table privacy_ratings on commit drop as
        select user_id,rating_sum,rating_count,rating_avg from public.groomer_profiles;
      set local role authenticated;
      select * from public.request_account_deletion();
      reset role;
      do $$ declare review_id uuid; begin
        if exists(select 1 from app_private.booking_review_contexts c join privacy_bookings b on b.id=c.booking_id
          where c.source_state<>'privacy_withheld' or c.service_at is not null or c.allowed_keys<>'[]'::jsonb) then
          raise exception 'privacy_context_not_cleared'; end if;
        for review_id in select r.id from public.reviews r join privacy_bookings b on b.id=r.booking_id loop
          perform app_private.rebuild_review_evidence(review_id);
        end loop;
        if exists(select 1 from app_private.review_evidence_projection e join public.reviews r on r.id=e.review_id
          join privacy_bookings b on b.id=r.booking_id) then raise exception 'privacy_evidence_rebuilt'; end if;
        if exists(select 1 from privacy_ratings old join public.groomer_profiles p using(user_id)
          where row(old.rating_sum,old.rating_count,old.rating_avg) is distinct from row(p.rating_sum,p.rating_count,p.rating_avg))
          then raise exception 'privacy_public_rating_changed'; end if;
        if exists(select 1 from privacy_bookings old join public.bookings b using(id)
          where row(old.scheduled_start,old.scheduled_end,old.price_estimate,old.customer_id,old.groomer_id)
            is distinct from row(b.scheduled_start,b.scheduled_end,b.price_estimate,b.customer_id,b.groomer_id))
          then raise exception 'privacy_commercial_terms_changed'; end if;
        if exists(select 1 from privacy_bookings old join public.bookings b using(id)
          where old.status='confirmed' and old.fulfillment_phase='scheduled' and old.scheduled_start>clock_timestamp()
            and (b.status<>case when b.customer_id='${actor}' then 'cancelled_by_customer'
              else 'cancelled_by_groomer' end
              or b.fulfillment_phase<>'cancelled' or b.cancelled_by is distinct from '${actor}'::uuid))
          then raise exception 'privacy_future_booking_not_cancelled'; end if;
        if exists(select 1 from privacy_bookings old join public.bookings b using(id)
          where old.status<>'confirmed' and old.status is distinct from b.status)
          then raise exception 'privacy_history_status_changed'; end if;
        if exists(select 1 from app_private.address_locations where owner_id='${actor}')
          then raise exception 'privacy_address_retained'; end if;
        if exists(select 1 from public.messages where sender_id='${actor}' and kind='booking_card' and body is not null)
          then raise exception 'privacy_booking_card_corrupted'; end if;
      end $$; rollback;`);
    return {rollback:true,authDeleted:false,storageDeleted:false,contextsWithheld:true,
      evidenceCannotRebuild:true,publicRatingsPreserved:true,commercialTermsPreserved:true};
  });
}

async function marketplaceDatabase() {
  assert.match(runID, /^TESTOPS-T391-/);
  assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED, "1");
  const phase=process.env.TESTOPS_MARKETPLACE_PHASE;
  assert.ok(["groomer","customer"].includes(phase),"Select one bounded marketplace phase");
  const batch=phase==="customer"?Number(process.env.TESTOPS_MARKETPLACE_BATCH):0;
  assert.ok(phase!=="customer" || [1,2,3].includes(batch),"Select customer snapshot batch 1, 2 or 3");
  const source = JSON.parse(readFileSync("tests/fixtures/matching-marketplace-la-synthetic.json", "utf8"));
  assert.equal(source.source_kind, "synthetic");
  assert.equal(source.human_labels, null);
  const seeds = [...parseCustomerProfiles().map(p => ({seed:p.seedID,email:p.email,role:"customer"})),
    ...parseGroomerProfiles().map(p => ({seed:p.seedID,email:p.email,role:"groomer"}))];
  const inventory = query(`select s.seed,s.role,u.id from jsonb_to_recordset(${sqlJSON(seeds)}) s(seed text,email text,role text)
    join auth.users u on u.email=s.email join public.profiles p on p.id=u.id and p.role::text=s.role
    where not exists(select 1 from public.grooming_requests r where r.customer_id=u.id
      and r.status in ('open','has_offers') and r.expires_at>now())
    and not exists(select 1 from public.bookings b where (b.customer_id=u.id or b.groomer_id=u.id) and b.scheduled_end>now())
    order by s.seed;`);
  const aliases = {customer:[...new Set(source.requests.map(r => r.customer_id))].sort(),
    groomer:source.groomers.map(g => g.id)};
  const actors = Object.entries(aliases).flatMap(([role, names]) => {
    const pool=inventory.filter(p => p.role===role);
    assert.ok(pool.length>=names.length, `Not enough existing idle ${role} seeds`);
    return names.map((alias,i) => ({alias,...pool[i]}));
  });
  const ids=sqlIDs(actors.map(a => a.id));
  const fingerprintSQL=`select
    ${["profiles","customer_profiles","groomer_profiles","groomer_services","groomer_availability_windows",
      "groomer_booking_preferences","groomer_time_off_windows","pets"].map(t => {
      const col=t==="profiles"?"id":t.endsWith("profiles")?"user_id":t==="pets"?"customer_id":"groomer_id";
      return `(select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb)::text)
        from public.${t} t where ${col} in (${ids})) ${t}`;
    }).join(",")},
    (select to_jsonb(c)-'signing_key' from app_private.match_ranking_config c where singleton) ranking_config,
    (select count(*) from public.grooming_requests where service_notes like '${marker}%') tagged_requests,
    (select count(*) from public.pets where grooming_notes='${marker}') tagged_pets;`;
  const [before]=query(fingerprintSQL);
  assert.equal(before.ranking_config.enabled,true);
  assert.equal(before.tagged_requests,0); assert.equal(before.tagged_pets,0);
  const template=readFileSync("tests/fixtures/matching-marketplace-replay.sql","utf8");
  assert.ok(template.trimEnd().endsWith("rollback;"));
  assert.doesNotMatch(template,/\bcommit\s*;/i);
  const capture=source.requests.filter(r=>phase==="groomer" || (batch===1?r.id<="R08":batch===2?r.id>="R09"&&r.id<="R17":r.id>="R18")).map(r=>r.id);
  const seedRequests=source.requests.filter(r=>capture.includes(r.id)||(phase==="customer"&&batch===2&&r.id==="R05"));
  const input={...source,actors,marker,phase,batch,capture_requests:capture,requests:seedRequests,
    auxiliary_request:source.requests.find(r=>r.id==="R04"),
    rejected_proposals:source.rejected_proposals.filter(x=>capture.includes(x.request_id))};
  const sql=template.replace("/* INPUT_JSON */",sqlJSON(input));
  const stamp=new Date().toISOString().replaceAll(/[:.]/g,"-");
  saveArtifact(`marketplace-manifest-${stamp}`,{source_hash:createHash("sha256").update(JSON.stringify(source)).digest("hex"),
    sql_hash:createHash("sha256").update(sql).digest("hex"),actors,before,source_kind:"synthetic",
    phase,batch,capture_requests:capture,seed_requests:seedRequests.map(r=>r.id),
    execution:"rollback-only SQL with authenticated role claims, not live user HTTP",human_labels:null,
    deviations:["Synthetic neighborhood coordinates replace approximate mile estimates",
      "Service dates move by whole weeks into the future; creation times are actual RPC time",
      "Public RPC owns expiry; expired history is checked with evaluate_quote at the deadline, not overwritten",
      "Existing controlled seed review evidence is retained; invented rating summaries are not imported"]});
  let output;
  try {
    output=query(sql,180000);
    saveArtifact(`marketplace-results-${stamp}`,output);
  } catch (error) {
    saveArtifact(`marketplace-failure-${stamp}`,{message:error.message,
      detail:JSON.parse(readFileSync(`artifacts/testops/${runID}/query-error.json`,"utf8")).message});
    throw error;
  } finally {
    const [after]=query(fingerprintSQL);
    saveArtifact(`marketplace-restoration-${stamp}`,{before,after,restored:JSON.stringify(before)===JSON.stringify(after)});
    assert.deepEqual(after,before,"Rollback restoration mismatch");
  }
  const result=output[0]?.result;
  assert.ok(result,"Missing marketplace result");
  console.log(JSON.stringify({requests:result.requests?.length,offers:result.offers?.length,
    negative:result.negative?.length,sequences:result.sequences?.length,restored:true}));
}

async function run() {
  const dates = query(`select jsonb_agg(timezone('America/Los_Angeles',
    (timezone('America/Los_Angeles',now())::date+d)+time '10:00') order by d) starts
    from generate_series(0,10) d;`)[0].starts;
  const add = (date, hours) => new Date(Date.parse(date)+hours*3600000).toISOString();
  for (const [weight,size] of [[2.5,"XS"],[100,"XXL"],[100.1,"Giant"],[100.001,"Giant"],[200,"Giant"],[null,null]]) {
    await check(`M33 weight ${weight}`, async () => {
      const [pet] = await rpc("C1", "save_my_pet_v2", {p_pet_id:null,
        p_facts:{name:"Matching test",species:"Dog",breed:"Unspecified",temperament:"Not Sure",weight_lbs:weight,grooming_notes:marker},p_coat_confirmed:false});
      saved.matching.pets.push(pet.id); saveArtifact("recovery",saved);
      assert.equal(pet.weight_lbs,weight); assert.equal(pet.size,size);
      return {weight:pet.weight_lbs,size:pet.size};
    });
  }
  for (const weight of [0,-1]) await check(`M33 invalid weight ${weight}`, () => denied("C1","save_my_pet_v2",
    {p_pet_id:null,p_facts:{name:"Matching test",species:"Dog",weight_lbs:weight},p_coat_confirmed:false},/invalid_pet_weight/));
  await check("wrong-role pet write", () => denied("G1","save_my_pet_v2",
    {p_pet_id:null,p_facts:{name:"Matching test",species:"Dog"},p_coat_confirmed:false},/customer_profile_required/));
  await check("foreign pet write", () => denied("X","save_my_pet_v2",
    {p_pet_id:saved.matching.pets[0],p_facts:{name:"Matching test",species:"Dog"},p_coat_confirmed:false},/pet_not_found/));
  for (const groomer of ["G1","G2"]) {
    const id=randomUUID(); saved.matching.services.push(id); saveArtifact("recovery",saved);
    query(`insert into public.groomer_services(id,groomer_id,title,description,base_price,duration_minutes,
      accepted_pet_sizes,is_active,service_type,accepted_species) values('${id}','${actors[groomer].id}',
      'Matching test','${marker}',100,60,array['XS','S','M','L','XL','XXL','Giant'],true,'nail_trim',array['dog']);`);
  }
  const address=actors.G1.address;
  const [receipt]=await rpc("C1","create_grooming_request_v4",{p_publish_operation_id:intent(saved,"publish"),
    p_preference_time_zone_identifier:"America/Los_Angeles",p_request:{pet_id:saved.matching.pets[0],
      service_type:"nail_trim",service_notes:marker,preferred_start:dates[3],preferred_end:add(dates[3],8),
      location_mode:"groomer_comes_to_customer",street_address:address.line_1,city:address.city,state:address.state,
      zip_code:address.zip_code,provider:address.provider,country_code:address.country_code,
      latitude:address.latitude,longitude:address.longitude,resolution_source:"manual_geocode",user_confirmed_at:new Date().toISOString()}});
  saved.requests.push(receipt.request_id); saveArtifact("recovery",saved);
  const [request]=await api.restSelect("grooming_requests",`select=*&id=eq.${receipt.request_id}`,actors.C1.token);
  await check("MR04 candidate worker",async()=>query("select app_private.drain_match_refresh_queue(100) result;"));
  await check("M26 discoverable new request",async()=>{
    const [config]=query("select enabled,validation_actor_ids from app_private.match_ranking_config where singleton;");
    const page=await rpc("G1","get_ranked_matched_requests",{p_sort:"fit",p_limit:25,p_cursor:null});
    assert.ok(page.items.some(item=>item.request.id===request.id));
    assert.equal(page.effective_mode,config.enabled || config.validation_actor_ids.includes(actors.G1.id) ? "fit" : "time_fallback");
    return {count:page.items.length,mode:page.effective_mode};
  });
  const offers=[];
  for (const groomer of ["G1","G2"]) {
    await check(`quote ${groomer}`,async()=>{
      const [offer]=await rpc(groomer,"create_groomer_offer_v3",{p_request_id:request.id,
        p_expected_request_revision:request.terms_revision,p_proposed_start:add(dates[3],1),p_proposed_end:add(dates[3],2),
        p_price_estimate:groomer==="G1"?120:80,p_message:marker,p_assessment_confirmations:[]});
      offers.push(offer); return {created:true};
    });
  }
  for(const sort of ["balanced","price","distance","earliest"]) await check(`M44 customer ${sort}`,async()=>{
    const page=await rpc("C1","get_ranked_customer_offers",{p_request_id:request.id,p_sort:sort,p_limit:1,p_cursor:null});
    assert.equal(page.items.length,1); assert.ok(page.next_cursor);
    if(sort==="price") assert.equal(page.items[0].offer.price_estimate,80);
    const second=await rpc("C1","get_ranked_customer_offers",{p_request_id:request.id,p_sort:sort,p_limit:1,p_cursor:page.next_cursor});
    assert.equal(second.items.length,1); assert.notEqual(page.items[0].offer.id,second.items[0].offer.id);
    assert.equal(second.next_cursor,null); return {pages:2,revision:page.ranking_revision};
  });
  await check("M49 foreign request read",()=>denied("X","get_ranked_customer_offers",
    {p_request_id:request.id,p_sort:"balanced",p_limit:25,p_cursor:null},/not_allowed/));
}
