import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { parseArgs } from "node:util";
import {spawn} from "node:child_process";
import { parseCustomerProfiles, parseGroomerProfiles } from "./testops-core.mjs";

const {values} = parseArgs({options:{"run-id":{type:"string"},phase:{type:"string"},
  "allow-remote-write":{type:"boolean"},"allow-restore":{type:"boolean"},"presentation-state":{type:"string"},"request-id":{type:"string"},help:{type:"boolean"}}});
if (values.help) {
  console.log("--run-id TESTOPS-T399-... --phase prepare|discovery|distribution|favorites|races|client|presentation|legacy|rollback|expiry|performance|performance-cleanup|compatibility|verify|restore --allow-remote-write [--allow-restore]");
  process.exit(0);
}
assert.match(values["run-id"] ?? "", /^TESTOPS-T399-[A-Z0-9-]{1,70}$/);
assert.ok(["prepare","discovery","distribution","favorites","races","client","presentation","legacy","rollback","expiry","performance","performance-cleanup","compatibility","verify","restore"].includes(values.phase));
assert.equal(values["allow-remote-write"],true,"Explicit operation approval is required, including authenticated fixture reads");
if(["restore","performance-cleanup"].includes(values.phase)) assert.equal(values["allow-restore"],true);
process.env.TESTOPS_RUN_ID=values["run-id"];
process.env.TESTOPS_REMOTE_WRITE_APPROVED="1";
const {connect,query,saveArtifact,runID,marker,directory,sqlJSON,sqlIDs}=await import("./test-t387-booking-fixture.mjs");
const manifestPath=`${directory}/distribution-manifest.json`;
const aliases=["C1","C2","G1","G2"];
const context=await connect(aliases);
const {api,actors}=context;
const rpc=(actor,name,params)=>api.rpc(name,params,actors[actor].token);
const save=manifest=>saveArtifact("distribution-manifest",manifest);
const read=()=>{
  const result=JSON.parse(readFileSync(manifestPath,"utf8"));
  assert.equal(result.runID,runID);
  for(const alias of aliases) assert.equal(result.actors[alias],actors[alias].id);
  assert.notEqual(result.restored,true,"Fixture already restored");
  return result;
};
const config=()=>query("select discovery_enabled,discovery_validation_actor_ids from app_private.match_ranking_config where singleton;")[0];
const counts=()=>query(`select
  (select count(*) from public.grooming_requests where customer_id in (${sqlIDs([actors.C1.id,actors.C2.id])})) requests,
  (select count(*) from public.request_matches where customer_id in (${sqlIDs([actors.C1.id,actors.C2.id])})) matches,
  (select count(*) from public.groomer_notifications where groomer_id in (${sqlIDs([actors.G1.id,actors.G2.id])})) notifications;`)[0];
function fingerprint(manifest) {
  const ids=sqlIDs([...manifest.cohort,...manifest.groomerIDs]);
  return query(`select ${["profiles","groomer_profiles","groomer_services","groomer_availability_windows",
    "groomer_booking_preferences","groomer_time_off_windows","pets"].map(t=>{
      const column=t==="profiles"?"id":t==="groomer_profiles"?"user_id":t==="pets"?"customer_id":"groomer_id";
      return `(select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]')::text)
        from public.${t} t where ${column} in (${ids})) ${t}`;
    }).join(",")};`)[0];
}
function rollbackFixture(name,manifest) {
  const template=readFileSync(`tests/fixtures/${name==="favorites"?"groomer-favorites":`request-${name}`}.sql`,"utf8");
  assert.ok(template.trimEnd().endsWith("rollback;"));
  const before={settings:fingerprint(manifest),counts:counts()};let result;
  try {result=query(template.replace("/* INPUT_JSON */",sqlJSON({run_id:runID,marker,actors:manifest.actors,groomers:manifest.groomerIDs,input:manifest.live?.input})),180000);}
  finally {
    const after={settings:fingerprint(manifest),counts:counts()};
    saveArtifact(`${name}-rollback-restoration`,{before,after});assert.deepEqual(after,before);
  }
  return result;
}
async function denied(actor,name,params,expected) {
  await assert.rejects(()=>rpc(actor,name,params),error=>{
    assert.match(error.serverMessage??error.message,expected);
    assert.ok(error.httpStatus>=400&&error.httpStatus<500);
    return true;
  });
}
const resultPath=`${directory}/distribution-${values.phase}.json`;
const results=existsSync(resultPath)?JSON.parse(readFileSync(resultPath,"utf8")):[];
async function check(name,action) {
  const start=Date.now();
  const previous=results.findIndex(item=>item.name===name);if(previous>=0) results.splice(previous,1);
  try { const detail=await action(); results.push({name,passed:true,ms:Date.now()-start,detail}); console.log(`PASS ${name}`); }
  catch(error) {results.push({name,passed:false,ms:Date.now()-start,reason:error.serverMessage??error.message});throw error;}
  finally {saveArtifact(`distribution-${values.phase}`,results);}
}

const liveTables=["groomer_profiles","groomer_services","groomer_availability_windows","groomer_booking_preferences","groomer_time_off_windows"];
function liveRows(manifest) {
  const ids=sqlIDs(manifest.groomerIDs);
  return query(`select ${liveTables.map(t=>`(select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]')
    from public.${t} t where ${t==="groomer_profiles"?"user_id":"groomer_id"} in (${ids})) ${t}`).join(",")};`)[0];
}
async function ensureLive(manifest) {
  if(manifest.live?.ready) return;
  assert.ok(!manifest.live,"Interrupted preparation requires recovery from the saved baseline, not another seed");
  const customers=sqlIDs(manifest.cohort),groomers=sqlIDs(manifest.groomerIDs);
  const idle=query(`select (select count(*) from public.grooming_requests where customer_id in (${customers})
    and status in ('open','has_offers') and expires_at>now()) requests,
    (select count(*) from public.bookings where (customer_id in (${customers}) or groomer_id in (${groomers})) and scheduled_end>now()) bookings,
    (select count(*) from public.conversations where customer_id in (${customers}) and groomer_id in (${groomers})) conversations;`)[0];
  assert.deepEqual(idle,{requests:0,bookings:0,conversations:0},"Do not replace an occupied test cohort");
  manifest.live={backup:liveRows(manifest),ready:false};save(manifest);
  const template=readFileSync("tests/fixtures/request-distribution-live.sql","utf8");
  const [{result}]=query(template.replace("/* INPUT_JSON */",sqlJSON({run_id:runID,marker,actors:manifest.actors,groomers:manifest.groomerIDs})),180000);
  manifest.live={...manifest.live,...result,configured:liveRows(manifest),ready:true};save(manifest);
}
async function liveRequest(manifest,poolEnabled,groomerIDs,input=manifest.live.input) {
  const draftID=randomUUID(),op=randomUUID();manifest.draftIDs.push(draftID);
  manifest.operations??=[];manifest.operations.push({id:op,draftID});save(manifest);
  const session=await rpc("C1","prepare_request_discovery_v1",{p_draft_id:draftID,p_input:input});
  const params={p_operation_id:op,p_session_id:session.session_id,p_input_digest:session.input_digest,
    p_pool_enabled:poolEnabled,p_groomer_ids:groomerIDs};
  const receipt=await rpc("C1","publish_request_with_distribution_v1",params);
  manifest.requests.push(receipt.request_id);save(manifest);
  return {receipt,params,session};
}
async function cancelRequest(request) {
  await rpc("C1","cancel_grooming_request",{p_request_id:request});
}

async function requestRace(requestID,firstRPC,first,second,sessionID=null,customerID=null) {
  const locked=customerID
    ? `select user_id from public.customer_profiles where user_id in (${sqlIDs([customerID])}) for update`
    : sessionID
    ? `select id from app_private.request_discovery_sessions where id in (${sqlIDs([sessionID])}) and normalized_input->>'service_notes'='${marker}' for update`
    : `select id from public.grooming_requests where id in (${sqlIDs([requestID])}) and service_notes='${marker}' for update`;
  const holderSQL=`begin;set local statement_timeout='25s';set local lock_timeout='5s';
    ${locked};
    select pg_sleep(2);
    do $$ declare proof jsonb; first_seen boolean:=false; begin
      for attempt in 1..180 loop
        perform pg_stat_clear_snapshot();
        with recursive blocked(pid) as (
          select pid from pg_stat_activity where pg_backend_pid()=any(pg_blocking_pids(pid))
          union select a.pid from pg_stat_activity a join blocked b on b.pid=any(pg_blocking_pids(a.pid))
        ) select jsonb_build_object('blocked_sessions',count(*),'first_rpc_verified',
            coalesce((array_agg(position('${firstRPC}' in a.query)>0 order by a.query_start))[1],false)) into proof
          from blocked b join pg_stat_activity a on a.pid=b.pid
          where a.application_name like 'PostgREST %' and a.state='active';
        if (proof->>'blocked_sessions')::integer>=1 then
          if not (proof->>'first_rpc_verified')::boolean then raise exception 'Unexpected first lock contender';end if;
          first_seen:=true;
        end if;
        exit when (proof->>'blocked_sessions')::integer>=2;
        perform pg_sleep(0.05);
      end loop;
      if not first_seen or (proof->>'blocked_sessions')::integer<2 then raise exception 'Two blocked HTTP sessions not observed';end if;
      perform set_config('app.testops_race_proof',proof::text,true);
    end $$;
    select current_setting('app.testops_race_proof')::jsonb proof;commit;`;
  const child=spawn("supabase",["db","query","--linked","--output","json",holderSQL],
    {env:{...process.env,SUPABASE_TELEMETRY_DISABLED:"1"}});
  let stdout="",stderr="";child.stdout.on("data",x=>stdout+=x);child.stderr.on("data",x=>stderr+=x);
  const finished=new Promise((resolve,reject)=>{child.on("error",reject);child.on("close",resolve);});
  await new Promise(resolve=>setTimeout(resolve,2000));
  const settle=action=>action().then(value=>({ok:true,value}),error=>({ok:false,code:error.code,message:error.serverMessage??error.message}));
  const a=settle(first);
  await new Promise(resolve=>setTimeout(resolve,350));
  const b=settle(second);
  const outcomes=await Promise.all([a,b]);const code=await finished;
  if(code!==0) saveArtifact("distribution-race-barrier-error",{stderr,outcomes});
  assert.equal(code,0,"Independent sessions did not meet the request-lock barrier");
  const proof=JSON.parse(stdout).rows[0].proof;
  assert.ok(proof.blocked_sessions>=2&&proof.first_rpc_verified);
  return {outcomes,proof};
}

async function testActor(id) {
  const [{email}]=query(`select email from auth.users where id in (${sqlIDs([id])});`);
  const seed=[...parseCustomerProfiles(),...parseGroomerProfiles()].find(x=>x.email===email);
  assert.ok(seed,"Only existing TestOps identities may authenticate");
  const session=await api.signIn(seed.email,seed.password);
  assert.equal(session.user.id,id);
  return {id,token:session.accessToken};
}
async function storage(actor,bucket,path,{method="GET",body=null}={}) {
  const suffix=method==="GET"?`object/authenticated/${bucket}/${path}?cacheNonce=${randomUUID()}`:
    method==="DELETE"?`object/${bucket}`:`object/${bucket}/${path}`;
  const response=await fetch(`${api.url}/storage/v1/${suffix}`,{method,
    headers:api.headers(actor?.token??api.publishableKey,{"Content-Type":method==="POST"?"image/png":"application/json"}),
    body:method==="DELETE"?JSON.stringify({prefixes:[path]}):body});
  const data=Buffer.from(await response.arrayBuffer());
  return {ok:response.ok,status:response.status,data,headers:Object.fromEntries(response.headers)};
}
async function restoreMedia(manifest) {
  const media=manifest.media;if(!media||media.restored) return;
  const groomer=await testActor(media.groomerID);
  const [current]=query(`select p.avatar_path,g.is_active from public.profiles p join public.groomer_profiles g on g.user_id=p.id
    where p.id in (${sqlIDs([media.groomerID])});`);
  assert.ok([media.avatarBefore,media.avatarPath].includes(current.avatar_path),"Preserve an externally changed avatar");
  query(`begin;update public.profiles set avatar_path=${media.avatarBefore===null?"null":sqlJSON(media.avatarBefore)+"#>>'{}'"}
      where id in (${sqlIDs([media.groomerID])});
    update public.groomer_profiles set is_active=${media.activeBefore} where user_id in (${sqlIDs([media.groomerID])});commit;`);
  for(const object of media.objects) {
    assert.equal(manifest.runID,runID);
    assert.ok(object.path.startsWith(`${object.ownerID}/`));
    const actor=object.ownerID===actors.C1.id?actors.C1:groomer;
    const removed=await storage(actor,object.bucket,object.path,{method:"DELETE"});
    assert.ok(removed.ok,"Exact run-owned Storage deletion failed");
  }
  const remains=query(`select count(*) total from storage.objects where ${media.objects.map(o=>
    `(bucket_id=${sqlJSON(o.bucket)}#>>'{}' and name=${sqlJSON(o.path)}#>>'{}')`).join(" or ")||"false"};`)[0];
  assert.equal(remains.total,0);
  const normalized=value=>JSON.stringify(value, (key,item)=>["updated_at","eligibility_revision"].includes(key)?undefined:item);
  const currentRows=liveRows(manifest);
  assert.equal(normalized(currentRows),normalized(manifest.live.configured),"Preserve unrelated business configuration changes");
  manifest.live.configured=currentRows;media.restored=true;save(manifest);
}

async function restorePresentation(manifest) {
  const p=manifest.presentation;if(!p||p.restored) return;
  assert.deepEqual(liveRows(manifest),manifest.live.configured,"Preserve external presentation fixture changes");
  if(p.requestPhoto&&!p.requestPhoto.restored) {
    const photo=p.requestPhoto;
    const rows=query(`select id,storage_path from public.request_photos where storage_path='${photo.path}' and request_id='${photo.requestID}' and customer_id='${actors.C1.id}';`);
    assert.ok(rows.length===0||(rows.length===1&&rows[0].storage_path===photo.path));
    if(rows.length) await api.request(`/rest/v1/request_photos?id=eq.${rows[0].id}`,{method:"DELETE",headers:api.headers(actors.C1.token)},"rest");
    assert.ok((await storage(actors.C1,"request-photos",photo.path,{method:"DELETE"})).ok);
    assert.equal(query(`select count(*) total from storage.objects where bucket_id='request-photos' and name='${photo.path}';`)[0].total,0);
    photo.restored=true;save(manifest);
  }
  const [current]=query(`select avatar_path from public.profiles where id='${p.groomerID}';`);
  assert.ok([p.avatarPath,p.before.avatar_path].includes(current.avatar_path));
  assert.deepEqual(query(`select * from app_private.customer_groomer_favorites where customer_id='${actors.C1.id}' and groomer_id='${p.groomerID}';`),p.favoritesAfter??p.favoritesBefore);
  query(`begin;update public.profiles set avatar_path=${sqlJSON(p.before.avatar_path)}#>>'{}' where id='${p.groomerID}';
    update public.groomer_profiles set business_name=${sqlJSON(p.before.business_name)}#>>'{}',is_active=${p.before.is_active} where user_id='${p.groomerID}';
    delete from app_private.customer_groomer_favorites where customer_id='${actors.C1.id}' and groomer_id='${p.groomerID}';
    insert into app_private.customer_groomer_favorites select * from jsonb_populate_recordset(null::app_private.customer_groomer_favorites,${sqlJSON(p.favoritesBefore)});commit;`);
  const removed=await storage(await testActor(p.groomerID),"groomer-avatars",p.avatarPath,{method:"DELETE"});
  assert.ok(removed.ok);
  assert.deepEqual(query(`select g.business_name,g.is_active,p.avatar_path from public.groomer_profiles g join public.profiles p on p.id=g.user_id
    where g.user_id='${p.groomerID}';`),[p.before]);
  assert.equal(query(`select count(*) total from storage.objects where bucket_id='groomer-avatars' and name='${p.avatarPath}';`)[0].total,0);
  manifest.live.configured=liveRows(manifest);p.restored=true;save(manifest);
}

async function favoritesHTTP(manifest) {
  const groomer=manifest.groomerIDs[25],customer=actors.C1.id;
  const predicate=`customer_id in (${sqlIDs([customer])}) and groomer_id in (${sqlIDs([groomer])})`;
  manifest.favoriteHTTP??={before:query(`select * from app_private.customer_groomer_favorites where ${predicate};`),groomer};save(manifest);
  assert.deepEqual(manifest.favoriteHTTP.before,[],"Preserve existing favorites; choose an unused test pair");
  try {
    const params={p_groomer_id:groomer,p_is_favorite:true,p_expected_revision:null};
    const result=await requestRace(null,"set_groomer_favorite_v1",()=>rpc("C1","set_groomer_favorite_v1",params),
      ()=>rpc("C1","set_groomer_favorite_v1",{...params,p_is_favorite:false}),null,customer);
    assert.equal(result.outcomes[0].ok,true);assert.equal(result.outcomes[1].message,"favorite_changed");
    manifest.favoriteHTTP.revision=result.outcomes[0].value.revision;save(manifest);
    assert.deepEqual(await rpc("C1","set_groomer_favorite_v1",params),result.outcomes[0].value);
    const page=await rpc("C1","get_my_favorite_groomers_v1",{p_scope:null,p_limit:25,p_cursor:null});
    assert.ok(page.items.some(x=>x.groomer_id===groomer));
    assert.equal((await rpc("C2","get_my_favorite_groomers_v1",{p_scope:null,p_limit:25,p_cursor:null})).items.length,0);
    await denied("G1","get_my_favorite_groomers_v1",{p_scope:null,p_limit:25,p_cursor:null},/not_allowed/);
    return result;
  } finally {
    if(manifest.favoriteHTTP.revision) {
      const rows=query(`select revision from app_private.customer_groomer_favorites where ${predicate};`);
      assert.deepEqual(rows,[{revision:manifest.favoriteHTTP.revision}],"Preserve a concurrent external favorite change");
      query(`delete from app_private.customer_groomer_favorites where ${predicate} and revision in (${sqlIDs([manifest.favoriteHTTP.revision])});`);
      manifest.favoriteHTTP.restored=true;save(manifest);
    }
  }
}

async function mediaHTTP(manifest) {
  assert.ok(!manifest.media||manifest.media.restored,"Restore an interrupted media fixture before reseeding");
  const seeds=[...parseCustomerProfiles(),...parseGroomerProfiles()].map(x=>({email:x.email}));
  const [source]=query(`select o.bucket_id,o.name,u.id from storage.objects o join auth.users u on u.id::text=split_part(o.name,'/',1)
    join jsonb_to_recordset(${sqlJSON(seeds)}) s(email text) on s.email=u.email
    where o.bucket_id in ('groomer-avatars','pet-photos') order by o.bucket_id limit 1;`);
  // Existing remote images belong to other users on some environments. A valid
  // one-pixel PNG is sufficient to exercise real Storage authorization.
  const bytes=source?await storage(await testActor(source.id),source.bucket_id,source.name):{ok:true,
    data:Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5S8AAAAASUVORK5CYII=","base64")};
  assert.ok(bytes.ok&&bytes.data.length>0);
  const groomerID=manifest.groomerIDs[25],groomer=await testActor(groomerID);
  const [original]=query(`select p.avatar_path,g.is_active from public.profiles p join public.groomer_profiles g on g.user_id=p.id
    where p.id in (${sqlIDs([groomerID])});`);
  const media={groomerID,avatarBefore:original.avatar_path,activeBefore:original.is_active,
    avatarPath:`${groomerID}/${randomUUID()}.png`,objects:[],restored:false};manifest.media=media;save(manifest);
  const upload=async(actor,bucket,path)=>{
    media.objects.push({ownerID:actor.id,bucket,path});save(manifest);
    const response=await storage(actor,bucket,path,{method:"POST",body:bytes.data});
    assert.ok(response.ok,`Test image upload failed (${response.status}): ${response.ok?"":response.data.toString()}`);
  };
  const allowed=async(actor,bucket,path)=>{
    const result=await storage(actor,bucket,path);
    assert.ok(result.ok,`Expected image authorization: ${actor.id}/${bucket}: ${result.data.toString()}`);
    assert.deepEqual(result.data,bytes.data);
  };
  const forbidden=async(actor,bucket,path)=>{
    const response=await storage(actor,bucket,path);
    if(response.ok) saveArtifact("media-unexpected-access",{actor:actor?.id,bucket,path,status:response.status,
      headers:{cacheControl:response.headers["cache-control"],cdnStatus:response.headers["cf-cache-status"]},
      predicate:query(`begin;select set_config('request.jwt.claim.sub','${actors.C1.id}',true);
        select app_private.customer_can_read_marketplace_avatar(${sqlJSON(media.avatarPath)}#>>'{}') discovery,
          app_private.customer_can_view_groomer_avatar('${groomerID}') participant,
          (select is_active from public.groomer_profiles where user_id='${groomerID}') active;rollback;`)});
    assert.equal(response.ok,false);assert.ok(response.status>=400&&response.status<500);
  };
  try {
    await upload(groomer,"groomer-avatars",media.avatarPath);
    const oldPath=`${groomerID}/${randomUUID()}.png`;await upload(groomer,"groomer-avatars",oldPath);
    await api.request(`/rest/v1/profiles?id=eq.${groomerID}`,{method:"PATCH",headers:api.headers(groomer.token),
      body:JSON.stringify({avatar_path:media.avatarPath})},"rest");
    await allowed(actors.C1,"groomer-avatars",media.avatarPath);await allowed(actors.C2,"groomer-avatars",media.avatarPath);
    await forbidden(actors.G2,"groomer-avatars",media.avatarPath);await forbidden(null,"groomer-avatars",media.avatarPath);
    await forbidden(actors.C1,"groomer-avatars",oldPath);
    const listed=await api.request("/storage/v1/object/list/groomer-avatars",{method:"POST",headers:api.headers(actors.C1.token),
      body:JSON.stringify({prefix:groomerID,limit:100,offset:0})},"storage");
    assert.deepEqual(listed,[],"Discovery must not authorize bucket enumeration");
    query(`update public.groomer_profiles set is_active=false where user_id in (${sqlIDs([groomerID])});`);
    await forbidden(actors.C1,"groomer-avatars",media.avatarPath);await allowed(groomer,"groomer-avatars",media.avatarPath);
    query(`update public.groomer_profiles set is_active=true where user_id in (${sqlIDs([groomerID])});`);
    const {receipt:r}=await liveRequest(manifest,true,[actors.G1.id]);
    media.requestID=r.request_id;save(manifest);
    const path=`${actors.C1.id}/${r.request_id}/${randomUUID()}.png`;
    await upload(actors.C1,"request-photos",path);
    await api.request("/rest/v1/request_photos",{method:"POST",headers:api.headers(actors.C1.token),body:JSON.stringify({
      request_id:r.request_id,customer_id:actors.C1.id,storage_bucket:"request-photos",storage_path:path,caption:marker})},"rest");
    // Photo insertion advances the request's eligibility source. Await the normal
    // worker before asserting access; pending evaluation is not permission.
    for(let attempt=0;attempt<20;attempt++) {
      const ready=query(`select count(*) ready from public.request_matches m where m.request_id='${r.request_id}'
        and m.groomer_id in (${sqlIDs([actors.G1.id,actors.G2.id])})
        and app_private.read_candidate_evaluation(m.request_id,m.groomer_id,now())->>'state' in ('estimated_fit','assessment_required');`)[0].ready;
      if(ready===2) break;
      assert.ok(attempt<19,"Match worker did not refresh after request photo insertion");
      await new Promise(resolve=>setTimeout(resolve,750));
    }
    await allowed(actors.G1,"request-photos",path);await allowed(actors.G2,"request-photos",path);
    await forbidden(actors.C2,"request-photos",path);await forbidden(null,"request-photos",path);
    let receipt=await rpc("C1","set_request_pool_v1",{p_operation_id:randomUUID(),p_request_id:r.request_id,
      p_expected_distribution_revision:r.distribution_revision,p_enabled:false});
    await forbidden(actors.G2,"request-photos",path);await allowed(actors.G1,"request-photos",path);await allowed(actors.C1,"request-photos",path);
    receipt=await rpc("C1","set_request_pool_v1",{p_operation_id:randomUUID(),p_request_id:r.request_id,
      p_expected_distribution_revision:receipt.distribution_revision,p_enabled:true});
    query(`select app_private.refresh_candidate_evaluation('${r.request_id}','${actors.G2.id}',now(),0);`);
    const [quote]=await rpc("G2","create_groomer_offer_v3",{p_request_id:r.request_id,p_expected_request_revision:r.terms_revision,
      p_proposed_start:new Date(Date.parse(manifest.live.input.preferred_start)+4*3600000).toISOString(),
      p_proposed_end:new Date(Date.parse(manifest.live.input.preferred_start)+5*3600000).toISOString(),
      p_price_estimate:80,p_message:marker,p_assessment_confirmations:[]});
    await rpc("C1","set_request_pool_v1",{p_operation_id:randomUUID(),p_request_id:r.request_id,
      p_expected_distribution_revision:receipt.distribution_revision,p_enabled:false});
    await allowed(actors.G2,"request-photos",path);
    const [offer]=await api.restSelect("groomer_offers",`select=quote_revision&id=eq.${quote.offer_id}`,actors.C1.token);
    await rpc("C1","accept_groomer_offer_v2",{p_offer_id:quote.offer_id,p_expected_quote_revision:offer.quote_revision});
    await allowed(actors.G2,"request-photos",path);await allowed(actors.C1,"request-photos",path);
    await forbidden(actors.G1,"request-photos",path);
    return {avatarChecks:9,requestPhotoChecks:12,requestID:r.request_id,sourceReused:Boolean(source),
      syntheticImage:!source};
  } finally {
    await restoreMedia(manifest);
    if(media.requestID) {
      const [r]=await api.restSelect("grooming_requests",`select=status&id=eq.${media.requestID}`,actors.C1.token);
      if(["open","has_offers"].includes(r?.status)) await cancelRequest(media.requestID);
    }
  }
}

function restoreLive(manifest) {
  if(!manifest.live||manifest.live.restored) return;
  assert.ok(manifest.live.ready,"Resolve interrupted preparation before restoration");
  assert.deepEqual(liveRows(manifest),manifest.live.configured,"Test settings changed outside the recorded operations");
  const customers=sqlIDs(manifest.cohort),groomers=sqlIDs(manifest.groomerIDs);
  const owned=query(`select id from public.grooming_requests where customer_id in (${customers}) and service_notes='${marker}'
    and pet_id='${manifest.live.pet_id}' and created_at>='${manifest.startedAt}';`).map(x=>x.id);
  assert.ok(manifest.requests.every(id=>owned.includes(id)),"Manifest has a foreign or modified request");
  const requests=owned.length?sqlIDs(owned):"null::uuid";
  const conversations=`select id from public.conversations where customer_id in (${customers}) and groomer_id in (${groomers})`;
  const backup=manifest.live.backup;
  const grandfathered=backup.groomer_services.filter(s=>s.is_active&&!s.accepted_species?.length).map(s=>s.id);
  const legacyIDs=grandfathered.length?sqlIDs(grandfathered):"null::uuid";
  // These pre-existing active rows predate species confirmation. Restore only their
  // saved state under an exclusive transaction lock; no concurrent write can bypass the guard.
  const restoreLegacy=grandfathered.length?`
    alter table public.groomer_services disable trigger groomer_services_species;
    update public.groomer_services s set is_active=b.is_active
      from jsonb_populate_recordset(null::public.groomer_services,${sqlJSON(backup.groomer_services)}) b
      where s.id=b.id and s.groomer_id=b.groomer_id and s.id in (${legacyIDs});
    alter table public.groomer_services enable trigger groomer_services_species;`:"";
  query(`begin;set local lock_timeout='5s';select set_config('app.availability_batch','1',true);
    lock table public.groomer_services in access exclusive mode;
    do $$ begin
      if not exists(select 1 from pg_trigger where tgrelid='public.groomer_services'::regclass
        and tgname='groomer_services_species' and tgenabled='O'
        and tgfoid='app_private.guard_service_species()'::regprocedure) then
        raise exception 'Unexpected species guard state';end if;
      if (select coalesce(jsonb_agg(to_jsonb(s) order by to_jsonb(s)::text),'[]')
          from public.groomer_services s where groomer_id in (${groomers}))
        is distinct from ${sqlJSON(manifest.live.configured.groomer_services)} then
        raise exception 'Service rows changed before restoration lock';end if;
      if exists(select 1 from public.bookings where customer_id in (${customers}) and groomer_id in (${groomers}) and request_id not in (${requests})) then
        raise exception 'Foreign booking in fixture conversations';end if;
      if exists(select 1 from public.messages m where m.conversation_id in (${conversations})
        and not (m.kind='booking_card' and m.booking_id in(select id from public.bookings where request_id in (${requests})))
        and not (m.kind='text' and m.body='${marker}')
        and not (m.kind='text' and m.body='Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!'
          and exists(select 1 from public.messages card join public.bookings b on b.id=card.booking_id
            where b.request_id in (${requests}) and card.conversation_id=m.conversation_id
              and card.sender_id=m.sender_id and m.created_at=card.created_at+interval '1 microsecond'))) then
        raise exception 'Unrelated conversation message; preserve it';end if;
    end $$;
    delete from public.customer_notifications where related_request_id in (${requests}) or related_conversation_id in (${conversations})
      or related_booking_id in(select id from public.bookings where request_id in (${requests}));
    delete from public.groomer_notifications where related_request_id in (${requests}) or related_conversation_id in (${conversations})
      or related_booking_id in(select id from public.bookings where request_id in (${requests}));
    delete from public.conversations where id in (${conversations});
    select app_private.cleanup_testops_request_address_location(id,'${runID}') from public.grooming_requests where id in (${requests});
    delete from public.grooming_requests where id in (${requests}) and service_notes='${marker}';
    delete from public.pets where id='${manifest.live.pet_id}' and customer_id='${manifest.actors.C1}' and grooming_notes='${marker}';
    update public.groomer_profiles g set address_location_id=b.address_location_id,is_active=b.is_active,
      base_street_address=b.base_street_address,base_city=b.base_city,base_state=b.base_state,base_zip_code=b.base_zip_code,
      service_location_mode=b.service_location_mode,service_location_modes=b.service_location_modes,service_radius_miles=b.service_radius_miles
      from jsonb_populate_recordset(null::public.groomer_profiles,${sqlJSON(backup.groomer_profiles)}) b where g.user_id=b.user_id;
    delete from public.groomer_services where groomer_id in (${groomers}) and description='${marker}';
    update public.groomer_services s set is_active=b.is_active
      from jsonb_populate_recordset(null::public.groomer_services,${sqlJSON(backup.groomer_services)}) b
      where s.id=b.id ${grandfathered.length?`and s.id not in (${legacyIDs})`:""};
    ${restoreLegacy}
    ${["groomer_availability_windows","groomer_time_off_windows"].map(t=>`delete from public.${t} where groomer_id in (${groomers});
      insert into public.${t} select * from jsonb_populate_recordset(null::public.${t},${sqlJSON(backup[t])});`).join("\n")}
    insert into public.groomer_booking_preferences select * from jsonb_populate_recordset(null::public.groomer_booking_preferences,${sqlJSON(backup.groomer_booking_preferences)})
      on conflict(groomer_id) do update set max_appointments_per_day=excluded.max_appointments_per_day,
      minimum_advance_notice_days=excluded.minimum_advance_notice_days,auto_accept_bookings=excluded.auto_accept_bookings,timing_buffers=excluded.timing_buffers;
    delete from public.groomer_booking_preferences p where groomer_id in (${groomers}) and not exists(
      select 1 from jsonb_populate_recordset(null::public.groomer_booking_preferences,${sqlJSON(backup.groomer_booking_preferences)}) b where b.groomer_id=p.groomer_id);
    delete from app_private.address_locations where id in (${sqlIDs(manifest.live.address_ids)}) and owner_id in (${groomers});
    commit;`,180000);
  const normalize=value=>Object.fromEntries(Object.entries(value).map(([table,rows])=>[table,rows.map(({updated_at,eligibility_revision,...row})=>row)
    .sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)))]));
  const restored=liveRows(manifest);
  const [guard]=query(`select tgenabled,pg_get_triggerdef(oid) definition from pg_trigger
    where tgrelid='public.groomer_services'::regclass and tgname='groomer_services_species';`);
  assert.equal(guard?.tgenabled,"O");
  saveArtifact("distribution-live-restoration",{removedRequestIDs:owned,before:normalize(backup),after:normalize(restored),
    timestampsAndEligibilityRevisionsAdvance:true,grandfatheredServiceIDs:grandfathered,serviceSpeciesGuard:guard});
  assert.deepEqual(normalize(restored),normalize(backup));
  manifest.live.restored=true;manifest.requests=[];save(manifest);
}

function restoreClient(manifest) {
  const client=manifest.client;
  if(!client||client.restored) return;
  const [current]=query(`select to_jsonb(c)-'updated_at' data from public.customer_profiles c where user_id='${actors.C1.id}';`);
  assert.deepEqual(current.data,client.configured,"Customer profile changed outside this fixture");
  const favorites=query(`select * from app_private.customer_groomer_favorites where customer_id='${actors.C1.id}' and groomer_id='${actors.G1.id}';`);
  assert.deepEqual(favorites,client.favoritesAfter??client.favoritesBefore,"Preserve an external favorite edit");
  query(`begin;
    delete from app_private.customer_groomer_favorites where customer_id='${actors.C1.id}' and groomer_id='${actors.G1.id}';
    insert into app_private.customer_groomer_favorites select * from jsonb_populate_recordset(null::app_private.customer_groomer_favorites,${sqlJSON(client.favoritesBefore)});
    update public.customer_profiles c set street_address=b.street_address,address_line_2=b.address_line_2,
      city=b.city,state=b.state,zip_code=b.zip_code,address_location_id=b.address_location_id
      from jsonb_populate_record(null::public.customer_profiles,${sqlJSON(client.before)}) b where c.user_id=b.user_id;
    delete from app_private.address_locations where id='${client.locationID}' and owner_id='${actors.C1.id}';commit;`);
  assert.deepEqual(query(`select to_jsonb(c)-'updated_at' data from public.customer_profiles c where user_id='${actors.C1.id}';`)[0].data,client.before);
  client.restored=true;save(manifest);
}

if(values.phase==="prepare") {
  assert.ok(!existsSync(manifestPath),"Do not overwrite a recovery manifest");
  const before=config();
  assert.deepEqual(before,{discovery_enabled:false,discovery_validation_actor_ids:[]},"Preserve an existing rollout cohort");
  const seeds=parseGroomerProfiles().map(({seedID,email})=>({seed:seedID,email}));
  const inventory=query(`select s.seed,p.id from jsonb_to_recordset(${sqlJSON(seeds)}) s(seed text,email text)
    join auth.users u on u.email=s.email join public.profiles p on p.id=u.id and p.role='groomer'
    where not exists(select 1 from public.bookings b where b.groomer_id=p.id and b.scheduled_end>now()) order by s.seed;`);
  const groomerIDs=[...new Set([actors.G1.id,actors.G2.id,...inventory.map(x=>x.id)])].slice(0,26);
  assert.equal(groomerIDs.length,26,"Need 26 existing test identities, never create Auth accounts");
  const manifest={runID,startedAt:new Date().toISOString(),actors:Object.fromEntries(aliases.map(a=>[a,actors[a].id])),
    groomerIDs,configBefore:before,cohort:[actors.C1.id,actors.C2.id],draftIDs:[],requests:[],countsBefore:counts()};
  save(manifest);
  query(`do $$ begin update app_private.match_ranking_config
    set discovery_validation_actor_ids=array[${sqlIDs(manifest.cohort)}]
    where singleton and not discovery_enabled and discovery_validation_actor_ids='{}';
    if not found then raise exception 'Rollout changed concurrently';end if;end $$;`);
  console.log("Prepared existing identity manifest and private discovery cohort; no public request created.");
} else if(values.phase==="discovery") {
  const manifest=read();
  await check("A01-A09 rollback-only qualification and paging",async()=>{
    return rollbackFixture("discovery",manifest);
  });
  const [clock]=query("select timezone('America/Los_Angeles',(timezone('America/Los_Angeles',now())::date+3)+time '10:00') start;");
  const address=actors.G1.address;
  const input={pet_id:actors.C1.pet.id,service_type:"full_groom",service_notes:marker,
    preferred_start:clock.start,preferred_end:new Date(Date.parse(clock.start)+8*3600000).toISOString(),
    location_mode:"groomer_comes_to_customer",street_address:"399 TestOps Synthetic Way",city:address.city,
    state:address.state,zip_code:address.zip_code,provider:"apple_maps",country_code:"US",
    latitude:address.latitude,longitude:address.longitude,resolution_source:"manual_geocode",
    user_confirmed_at:new Date().toISOString(),preference_time_zone_identifier:"America/Los_Angeles"};
  const draftID=randomUUID();manifest.draftIDs.push(draftID);save(manifest);
  const before=counts();let session;
  await check("A01 HTTP private preview and identical retry",async()=>{
    session=await rpc("C1","prepare_request_discovery_v1",{p_draft_id:draftID,p_input:input});
    const retry=await rpc("C1","prepare_request_discovery_v1",{p_draft_id:draftID,p_input:input});
    assert.equal(retry.session_id,session.session_id);assert.equal(retry.input_digest,session.input_digest);
    assert.deepEqual(counts(),before);return {session:session.session_id,publicWrites:0};
  });
  const scope={kind:"preview",id:session.session_id,input_digest:session.input_digest};
  const pageParams={p_scope:scope,p_sort:"fit",p_limit:25,p_cursor:null};
  await check("A02 HTTP role, owner and digest isolation",async()=>{
    await denied("G1","prepare_request_discovery_v1",{p_draft_id:randomUUID(),p_input:input},/not_allowed/);
    await denied("C2","get_request_groomer_candidates_v1",pageParams,/discovery_expired|not_allowed/);
    await denied("C1","get_request_groomer_candidates_v1",{...pageParams,p_scope:{...scope,input_digest:"bad"}},/discovery_changed/);
    await denied("C1","get_request_groomer_candidates_v1",{...pageParams,p_scope:{...scope,terms_revision:randomUUID()}},/invalid_discovery_scope/);
  });
  await check("A05/A21 HTTP safe candidate and profile read",async()=>{
    const page=await rpc("C1","get_request_groomer_candidates_v1",pageParams);
    assert.equal(page.requested_mode,"fit");assert.ok(Array.isArray(page.items));
    for(const item of page.items) {
      assert.equal(item.groomer_id,item.safe_profile.id);
      assert.ok(["estimated_fit","assessment_required"].includes(item.eligibility.state));
      for(const key of ["street_address","base_street_address","latitude","longitude","email","phone"]) assert.ok(!(key in item.safe_profile));
    }
    if(page.items.length) {
      const detail=await rpc("C1","get_discovery_groomer_profile_v1",{p_scope:scope,p_groomer_id:page.items[0].groomer_id});
      assert.equal(detail.groomer_id,page.items[0].groomer_id);
    }
    assert.deepEqual(counts(),before);return {candidates:page.items.length,pending:page.pending_count};
  });
} else if(values.phase==="distribution") {
  const manifest=read();
  const rollbackName="A10-A25 rollback publication, distribution and read isolation";
  if(!manifest.live&&!results.some(x=>x.name===rollbackName&&x.passed)) await check(rollbackName,async()=>rollbackFixture("distribution",manifest));
  await ensureLive(manifest);
  await check("A10/A12/A18/A21 HTTP publication and privacy",async()=>{
    const sent=await liveRequest(manifest,false,[actors.G1.id]);const id=sent.receipt.request_id;
    assert.deepEqual(await rpc("C1","publish_request_with_distribution_v1",sent.params),sent.receipt);
    await denied("C2","get_customer_request_progress_v1",{p_request_ids:[id]},/not_allowed/);
    await denied("G2","get_groomer_request_detail_v1",{p_request_id:id},/not_allowed/);
    assert.deepEqual(await api.restSelect("grooming_requests",`select=id,street_address&id=eq.${id}`,actors.G1.token),[]);
    const detail=await rpc("G1","get_groomer_request_detail_v1",{p_request_id:id});
    assert.equal(detail.id,id);assert.ok(!("street_address" in detail));
    const progress=await rpc("C1","get_customer_request_progress_v1",{p_request_ids:[id]});
    assert.equal(progress[0].invitations[0].state,"awaiting_response");
    await cancelRequest(id);return {requestID:id,duplicateWrites:0,ownerAndRoleIsolation:true};
  });
} else if(values.phase==="races") {
  const manifest=read();assert.ok(manifest.live?.ready);
  const raceCheck=async(name,action)=>{
    if(results.some(x=>x.name===name&&x.passed)) return;
    return check(name,action);
  };
  const groomers=manifest.groomerIDs;
  const pool=(r,enabled)=>rpc("C1","set_request_pool_v1",{p_operation_id:randomUUID(),p_request_id:r.request_id,
    p_expected_distribution_revision:r.distribution_revision,p_enabled:enabled});
  const quote=(r,hours=0)=>rpc("G1","create_groomer_offer_v3",{p_request_id:r.request_id,p_expected_request_revision:r.terms_revision,
    p_proposed_start:new Date(Date.parse(manifest.live.input.preferred_start)+hours*3600000).toISOString(),
    p_proposed_end:new Date(Date.parse(manifest.live.input.preferred_start)+(hours+1)*3600000).toISOString(),
    p_price_estimate:80,p_message:marker,p_assessment_confirmations:[]});
  const invite=(r,ids)=>rpc("C1","invite_request_groomers_v1",{p_operation_id:randomUUID(),p_request_id:r.request_id,
    p_expected_terms_revision:r.terms_revision,p_groomer_ids:ids});
  for(const first of ["pool","quote"]) await raceCheck(`A19 independent sessions: ${first} commits first`,async()=>{
    const {receipt:r}=await liveRequest(manifest,true,[]);
    query(`select app_private.refresh_candidate_evaluation('${r.request_id}','${actors.G1.id}',now(),0);`);
    const close=()=>pool(r,false),send=()=>quote(r);
    const result=await requestRace(r.request_id,first==="pool"?"set_request_pool_v1":"create_groomer_offer_v3",
      first==="pool"?close:send,first==="pool"?send:close);
    assert.equal(result.outcomes[0].ok,true);
    if(first==="pool") {
      assert.equal(result.outcomes[1].ok,false);
      assert.ok(["request_distribution_closed","match_not_offerable","match_not_found"].includes(result.outcomes[1].message));
    } else assert.equal(result.outcomes[1].ok,true);
    const progress=await rpc("C1","get_customer_request_progress_v1",{p_request_ids:[r.request_id]});
    assert.equal(progress[0].pool_enabled,false);assert.equal(progress[0].valid_offer_count,first==="quote"?1:0);
    await cancelRequest(r.request_id);return result;
  });
  await raceCheck("A16 independent concurrent append preserves five-counterpart cap",async()=>{
    const {receipt:r}=await liveRequest(manifest,false,groomers.slice(0,4));
    const result=await requestRace(r.request_id,"invite_request_groomers_v1",
      ()=>invite(r,[groomers[4]]),()=>invite(r,[groomers[5]]));
    assert.equal(result.outcomes.filter(x=>x.ok).length,1);
    assert.equal(result.outcomes.find(x=>!x.ok).message,"invitation_limit_reached");
    assert.equal((await rpc("C1","get_customer_request_progress_v1",{p_request_ids:[r.request_id]}))[0].invitations.length,5);
    await cancelRequest(r.request_id);return result;
  });
  for(const first of ["cancel","invite"]) await raceCheck(`A23 independent sessions: ${first} commits first`,async()=>{
    const {receipt:r}=await liveRequest(manifest,false,[actors.G1.id]);
    const cancel=()=>cancelRequest(r.request_id),append=()=>invite(r,[actors.G2.id]);
    const result=await requestRace(r.request_id,first==="cancel"?"cancel_grooming_request":"invite_request_groomers_v1",
      first==="cancel"?cancel:append,first==="cancel"?append:cancel);
    assert.equal(result.outcomes[0].ok,true);
    if(first==="cancel") {assert.equal(result.outcomes[1].ok,false);assert.equal(result.outcomes[1].message,"request_changed");}
    else assert.equal(result.outcomes[1].ok,true);
    const progress=(await rpc("C1","get_customer_request_progress_v1",{p_request_ids:[r.request_id]}))[0];
    assert.equal(progress.status,"cancelled");assert.ok(progress.invitations.every(x=>x.state==="closed"));return result;
  });
  for(const sameOperation of [false,true]) await raceCheck(`A12/A13 independent first publication: ${sameOperation?"same":"different"} operation`,async()=>{
    const draftID=randomUUID();manifest.draftIDs.push(draftID);save(manifest);
    const session=await rpc("C1","prepare_request_discovery_v1",{p_draft_id:draftID,p_input:manifest.live.input});
    const op=randomUUID(),secondOp=sameOperation?op:randomUUID();
    manifest.operations.push({id:op,draftID},{id:secondOp,draftID});save(manifest);
    const params={p_operation_id:op,p_session_id:session.session_id,p_input_digest:session.input_digest,
      p_pool_enabled:false,p_groomer_ids:[actors.G1.id]};
    const result=await requestRace(null,"publish_request_with_distribution_v1",
      ()=>rpc("C1","publish_request_with_distribution_v1",params),
      ()=>rpc("C1","publish_request_with_distribution_v1",{...params,p_operation_id:secondOp}),session.session_id);
    const accepted=result.outcomes.filter(x=>x.ok);assert.equal(accepted.length,sameOperation?2:1);
    const receipt=accepted[0].value;manifest.requests.push(receipt.request_id);save(manifest);
    if(sameOperation) assert.deepEqual(accepted[0].value,accepted[1].value);
    else assert.equal(result.outcomes.find(x=>!x.ok).message,"already_published");
    query(`update app_private.request_discovery_sessions set created_at=now()-interval '31 minutes',expires_at=now()-interval '1 minute'
      where id='${session.session_id}' and customer_id='${actors.C1.id}';`);
    assert.deepEqual(await rpc("C1","publish_request_with_distribution_v1",params),receipt);
    await cancelRequest(receipt.request_id);return result;
  });
  for(const [index,first] of ["accept","invite"].entries()) await raceCheck(`A23 independent acceptance: ${first} commits first`,async()=>{
    const {receipt:r}=await liveRequest(manifest,false,[actors.G1.id]);
    const [sent]=await quote(r,index*2);
    const [offer]=await api.restSelect("groomer_offers",`select=quote_revision&id=eq.${sent.offer_id}`,actors.C1.token);
    const accept=()=>rpc("C1","accept_groomer_offer_v2",{p_offer_id:sent.offer_id,p_expected_quote_revision:offer.quote_revision});
    const append=()=>invite(r,[actors.G2.id]);
    const result=await requestRace(r.request_id,first==="accept"?"accept_groomer_offer_v2":"invite_request_groomers_v1",
      first==="accept"?accept:append,first==="accept"?append:accept);
    assert.equal(result.outcomes[0].ok,true);
    if(first==="accept") {assert.equal(result.outcomes[1].ok,false);assert.equal(result.outcomes[1].message,"request_changed");}
    else assert.equal(result.outcomes[1].ok,true);
    const progress=(await rpc("C1","get_customer_request_progress_v1",{p_request_ids:[r.request_id]}))[0];
    assert.equal(progress.status,"booked");assert.ok(progress.invitations.every(x=>x.state==="closed"));return result;
  });
} else if(values.phase==="favorites") {
  const manifest=read();
  if(!results.some(x=>x.name==="A26-A29/A45 rollback favorites, privacy and redaction"&&x.passed))
    await check("A26-A29/A45 rollback favorites, privacy and redaction",async()=>rollbackFixture("favorites",manifest));
  if(!results.some(x=>x.name==="A27 HTTP favorite opposite-write race and isolation"&&x.passed))
    await check("A27 HTTP favorite opposite-write race and isolation",()=>favoritesHTTP(manifest));
  if(!results.some(x=>x.name==="A18/A22/A28-A31 real Storage authorization"&&x.passed))
    await check("A18/A22/A28-A31 real Storage authorization",()=>mediaHTTP(manifest));
} else if(values.phase==="client") {
  const manifest=read();assert.ok(manifest.live?.ready&&!manifest.live.restored);
  if(!manifest.client) {
    const [before]=query(`select to_jsonb(c)-'updated_at' data from public.customer_profiles c where user_id='${actors.C1.id}';`);
    manifest.client={before:before.data,locationID:randomUUID(),configured:null};save(manifest);
    query(`begin;
      insert into app_private.address_locations(id,owner_id,provider,country_code,latitude,longitude,
        resolution_source,user_confirmed_at,time_zone_identifier) values('${manifest.client.locationID}','${actors.C1.id}',
        'apple_maps','US',24.5551,-81.78,'manual_geocode',now(),'America/New_York');
      update public.customer_profiles set street_address='399 TestOps Synthetic Way',address_line_2=null,
        city='Key West',state='FL',zip_code='33040',address_location_id='${manifest.client.locationID}' where user_id='${actors.C1.id}';commit;`);
    manifest.client.configured=query(`select to_jsonb(c)-'updated_at' data from public.customer_profiles c where user_id='${actors.C1.id}';`)[0].data;
    save(manifest);
  }
  const [pet]=query(`select name from public.pets where id='${manifest.live.pet_id}' and customer_id='${actors.C1.id}';`);
  if(!manifest.client.favoritesBefore) {
    manifest.client.favoritesBefore=query(`select * from app_private.customer_groomer_favorites where customer_id='${actors.C1.id}' and groomer_id='${actors.G1.id}';`);
    assert.deepEqual(manifest.client.favoritesBefore,[],"Private-preview test must start with an unused favorite pair");
    save(manifest);
  }
  saveArtifact("ui-input-discovery",{runID,petName:pet.name,groomerID:actors.G1.id.toUpperCase(),poolGroomerID:actors.G2.id.toUpperCase(),marker});
  console.log("Client fixture prepared with a separate owned customer address; original address untouched and restoration recorded.");
} else if(values.phase==="presentation") {
  const manifest=read();assert.ok(manifest.client&&!manifest.client.restored);
  if(values["allow-restore"]) {await restorePresentation(manifest);console.log("Presentation identity and exact Storage object restored.");}
  else if(values["presentation-state"]==="request-image") {
    const p=manifest.presentation,id=values["request-id"];
    assert.ok(p&&!p.restored&&!p.requestPhoto&&manifest.requests.includes(id));
    assert.deepEqual(query(`select customer_id,service_notes from public.grooming_requests where id in (${sqlIDs([id])});`),
      [{customer_id:actors.C1.id,service_notes:marker}]);
    const photo={requestID:id,path:`${actors.C1.id}/${id}/${randomUUID()}.png`};
    p.requestPhoto=photo;save(manifest);
    const bytes=Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5S8AAAAASUVORK5CYII=","base64");
    assert.ok((await storage(actors.C1,"request-photos",photo.path,{method:"POST",body:bytes})).ok);
    const rows=await api.request("/rest/v1/request_photos",{method:"POST",headers:api.headers(actors.C1.token,{Prefer:"return=representation"}),body:JSON.stringify({
      request_id:id,customer_id:actors.C1.id,storage_bucket:"request-photos",storage_path:photo.path,caption:marker})},"rest");
    assert.equal(rows.length,1);photo.id=rows[0].id;save(manifest);
    assert.deepEqual((await storage(actors.C1,"request-photos",photo.path)).data,bytes);
    console.log("One exact request image uploaded and authenticated read verified for P03.");
  }
  else if(values["presentation-state"]==="paused") {
    const p=manifest.presentation;assert.ok(p&&!p.restored);
    assert.deepEqual(liveRows(manifest),manifest.live.configured);
    query(`update public.groomer_profiles set is_active=false where user_id='${p.groomerID}';`);
    manifest.live.configured=liveRows(manifest);p.paused=true;save(manifest);
    console.log("Only the presentation fixture groomer is paused.");
  }
  else {
    assert.ok(!manifest.presentation,"Presentation fixture already recorded; restore before another run");
    assert.deepEqual(liveRows(manifest),manifest.live.configured);
    const groomerID=manifest.groomerIDs[25],groomer=await testActor(groomerID);
    const [before]=query(`select g.business_name,g.is_active,p.avatar_path from public.groomer_profiles g join public.profiles p on p.id=g.user_id where g.user_id='${groomerID}';`);
    const p={groomerID,before,avatarPath:`${groomerID}/${randomUUID()}.png`,businessName:"TestOps Riverside Companion Care and Professional Grooming Appointment Studio",restored:false};
    p.favoritesBefore=query(`select * from app_private.customer_groomer_favorites where customer_id='${actors.C1.id}' and groomer_id='${groomerID}';`);
    assert.deepEqual(p.favoritesBefore,[]);
    manifest.presentation=p;save(manifest);
    const bytes=Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5S8AAAAASUVORK5CYII=","base64");
    const uploaded=await storage(groomer,"groomer-avatars",p.avatarPath,{method:"POST",body:bytes});assert.ok(uploaded.ok);
    query(`begin;update public.profiles set avatar_path='${p.avatarPath}' where id='${groomerID}';
      update public.groomer_profiles set business_name=${sqlJSON(p.businessName)}#>>'{}' where user_id='${groomerID}';commit;`);
    manifest.live.configured=liveRows(manifest);save(manifest);
    await rpc("C1","set_groomer_favorite_v1",{p_groomer_id:groomerID,p_is_favorite:true,p_expected_revision:null});
    p.favoritesAfter=query(`select * from app_private.customer_groomer_favorites where customer_id='${actors.C1.id}' and groomer_id='${groomerID}';`);save(manifest);
    console.log("One scoped long-name and real private Storage image fixture prepared; image is a transport probe, not photography.");
  }
} else if(values.phase==="legacy") {
  const manifest=read();assert.ok(manifest.client&&!manifest.client.restored&&!manifest.legacy);
  const i={...manifest.live.input,address_line_2:"",place_id:null,travel_radius_miles:null};
  delete i.preference_time_zone_identifier;
  for(const key of ["preferred_start","preferred_end","user_confirmed_at"]) i[key]=new Date(i[key]).toISOString().replace(/\.\d{3}Z$/,"Z");
  const operationID=randomUUID();manifest.legacy={operationID,input:i};save(manifest);
  const [receipt]=await rpc("C1","create_grooming_request_v4",{p_publish_operation_id:operationID,p_request:i,p_preference_time_zone_identifier:"America/New_York"});
  manifest.requests.push(receipt.request_id);manifest.legacy.receipt=receipt;save(manifest);
  await cancelRequest(receipt.request_id);
  const date=value=>(Date.parse(value)-Date.UTC(2001,0,1))/1000;
  const address={line1:i.street_address,line2:"",city:i.city,stateCode:i.state,postalCode:i.zip_code,countryCode:i.country_code};
  saveArtifact("legacy-pending",{customerID:actors.C1.id,draft:{petID:i.pet_id,serviceType:i.service_type,
    serviceNotes:i.service_notes,preferredStart:date(i.preferred_start),preferredEnd:date(i.preferred_end),
    locationMode:i.location_mode,streetAddress:i.street_address,addressLine2:"",city:i.city,stateCode:i.state,
    zipCode:i.zip_code,travelRadiusMiles:null,publishOperationID:operationID,
    confirmedAddress:{entered:address,accepted:address,provider:i.provider,placeID:null,
      coordinate:{latitude:i.latitude,longitude:i.longitude},resolutionSource:i.resolution_source,
      confirmedAt:date(i.user_confirmed_at),timeZoneIdentifier:"America/New_York"}},photos:[]});
  console.log("Accepted legacy receipt and exact unversioned pending file prepared; request already cancelled.");
} else if(values.phase==="rollback") {
  const manifest=read();
  const before=values["allow-restore"]?[]:manifest.cohort;
  const after=values["allow-restore"]?manifest.cohort:[];
  assert.deepEqual(config(),{discovery_enabled:false,discovery_validation_actor_ids:before});
  if(!values["allow-restore"]) {assert.ok(!manifest.rollbackUI);manifest.rollbackUI={active:true};save(manifest);}
  else assert.ok(manifest.rollbackUI?.active);
  const array=ids=>ids.length?`array[${sqlIDs(ids)}]`:"'{}'::uuid[]";
  query(`do $$ begin update app_private.match_ranking_config set discovery_validation_actor_ids=${array(after)}
    where singleton and not discovery_enabled and discovery_validation_actor_ids=${array(before)};
    if not found then raise exception 'Rollout changed; preserve it';end if;end $$;`);
  assert.deepEqual(config(),{discovery_enabled:false,discovery_validation_actor_ids:after});
  manifest.rollbackUI.active=!values["allow-restore"];save(manifest);
  console.log(values["allow-restore"]?"Validation cohort restored.":"Discovery disabled for validation cohort; existing order rights unchanged.");
} else if(values.phase==="expiry") {
  const manifest=read();assert.ok(manifest.client&&!manifest.client.restored);
  const now=Date.now();
  const input={...manifest.live.input,preferred_start:new Date(now+6*60000).toISOString(),
    preferred_end:new Date(now+7.5*60000).toISOString()};
  const request=await liveRequest(manifest,true,[],input);
  manifest.expiry=request;save(manifest);
  console.log(`Natural request expiry fixture: ${request.receipt.request_id}`);
} else if(values.phase==="performance") {
  const manifest=read();assert.ok(manifest.live?.ready);
  manifest.performance??={history:Array.from({length:1200},(_,ordinal)=>({id:randomUUID(),ordinal,
    groomer:manifest.groomerIDs[ordinal%manifest.groomerIDs.length]})),completed:0};save(manifest);
  const performance=manifest.performance;
  assert.notEqual(performance.restored,true,"Historical load was removed; do not reuse its completion counter as live performance evidence");
  await check("P01 guarded 1200 historical reviews on 26 existing groomers",async()=>{
    const template=readFileSync("tests/fixtures/request-discovery-history.sql","utf8");
    for(let offset=performance.completed;offset<performance.history.length;offset+=25) {
      const rows=performance.history.slice(offset,offset+25);
      const found=query(`select id from public.grooming_requests where id in (${sqlIDs(rows.map(r=>r.id))});`);
      assert.equal(found.length,0,"Reconcile interrupted history batch before retry");
      const [result]=query(template.replace("/* INPUT_JSON */",sqlJSON({customer:actors.C1.id,
        source:manifest.requests[0],marker,rows})),180000);
      assert.equal(result.reviews,rows.length);
      manifest.requests.push(...rows.map(r=>r.id));performance.completed=offset+rows.length;
      manifest.live.configured=liveRows(manifest);save(manifest);
      console.log(`History fixture ${performance.completed}/1200`);
    }
    return {reviews:performance.completed,groomers:26,syntheticHistoricalSetup:true};
  });
  if(!performance.request) {performance.request=await liveRequest(manifest,true,[]);save(manifest);}
  const receipt=performance.request.receipt;
  await check("P01 quote data on the same request",async()=>{
    const [result]=query(`begin;set local statement_timeout='150s';do $$ declare gid uuid;eligible jsonb;begin
      for gid in select value::uuid from jsonb_array_elements_text(${sqlJSON(manifest.groomerIDs)}) loop
        if exists(select 1 from public.groomer_offers where request_id='${receipt.request_id}' and groomer_id=gid) then continue;end if;
        perform set_config('request.jwt.claim.sub',gid::text,true);
        perform set_config('request.jwt.claims',jsonb_build_object('sub',gid,'role','authenticated','is_anonymous',false)::text,true);
        perform app_private.refresh_candidate_evaluation('${receipt.request_id}',gid,statement_timestamp(),0);
        eligible:=app_private.evaluate_match_eligibility('${receipt.request_id}',gid,statement_timestamp());
        perform public.create_groomer_offer_v3('${receipt.request_id}','${receipt.terms_revision}',
          (eligible->>'service_start')::timestamptz,(eligible->>'service_end')::timestamptz,80,'${marker}','{}');
      end loop;end $$;
      select count(*)::integer offers from public.groomer_offers where request_id='${receipt.request_id}';commit;`,180000);
    assert.equal(result.offers,26);return result;
  });
  const scope={kind:"request",id:receipt.request_id,terms_revision:receipt.terms_revision};
  const pageParams={p_scope:scope,p_sort:"fit",p_limit:25,p_cursor:null};
  const offerParams={p_request_id:receipt.request_id,p_sort:"balanced",p_limit:25,p_cursor:null};
  const percentile=values=>[...values].sort((a,b)=>a-b)[Math.ceil(values.length*.95)-1];
  await check("P01 SQL first/continuation/legacy offers 30 samples each",async()=>{
    const [row]=query(`begin;set local statement_timeout='150s';
      select set_config('request.jwt.claim.sub','${actors.C1.id}',true);
      select set_config('request.jwt.claims','{"sub":"${actors.C1.id}","role":"authenticated","is_anonymous":false}',true);
      set local role authenticated;
      do $$ declare i integer;t timestamptz;p jsonb;q jsonb;first_ms jsonb:='[]';next_ms jsonb:='[]';offers_ms jsonb:='[]';begin
        for i in 1..30 loop
          t:=clock_timestamp();p:=public.get_request_groomer_candidates_v1(${sqlJSON(scope)},'fit',25,null);
          first_ms:=first_ms||to_jsonb(extract(epoch from clock_timestamp()-t)*1000);
          t:=clock_timestamp();q:=public.get_request_groomer_candidates_v1(${sqlJSON(scope)},'fit',25,p->>'next_cursor');
          next_ms:=next_ms||to_jsonb(extract(epoch from clock_timestamp()-t)*1000);
          if jsonb_array_length(p->'items')<>25 or jsonb_array_length(q->'items')<>1 then raise exception 'Candidate truncation';end if;
          t:=clock_timestamp();q:=public.get_ranked_customer_offers('${receipt.request_id}','balanced',25,null);
          offers_ms:=offers_ms||to_jsonb(extract(epoch from clock_timestamp()-t)*1000);
          if jsonb_array_length(q->'items')<>25 then raise exception 'Offer truncation';end if;
        end loop;
        perform set_config('test.p01',jsonb_build_object('first',first_ms,'continuation',next_ms,'offers',offers_ms)::text,true);
      end $$;select current_setting('test.p01')::jsonb samples;commit;`,180000);
    const p95=Object.fromEntries(Object.entries(row.samples).map(([name,values])=>[name,percentile(values)]));
    saveArtifact("performance-sql",{samples:row.samples,p95});
    for(const value of Object.values(p95)) assert.ok(value<=1500,`SQL P95 ${value}ms exceeds 1500ms`);
    return p95;
  });
  await check("P01 HTTP first/continuation/legacy offers 30 samples each",async()=>{
    const samples={first:[],continuation:[],offers:[]};
    for(let i=0;i<30;i++) {
      let t=Date.now();const first=await rpc("C1","get_request_groomer_candidates_v1",pageParams);samples.first.push(Date.now()-t);
      t=Date.now();const next=await rpc("C1","get_request_groomer_candidates_v1",{...pageParams,p_cursor:first.next_cursor});samples.continuation.push(Date.now()-t);
      assert.equal(first.items.length,25);assert.equal(next.items.length,1);
      assert.equal(new Set([...first.items,...next.items].map(x=>x.groomer_id)).size,26);
      t=Date.now();const offers=await rpc("C1","get_ranked_customer_offers",offerParams);samples.offers.push(Date.now()-t);
      assert.equal(offers.items.length,25);
    }
    const p95=Object.fromEntries(Object.entries(samples).map(([name,values])=>[name,percentile(values)]));
    saveArtifact("performance-http",{samples,p95});
    for(const value of Object.values(p95)) assert.ok(value<=2500,`HTTP P95 ${value}ms exceeds 2500ms`);
    return p95;
  });
  await check("P02 static/soft/hard two-page HTTP traversal, ten each",async()=>{
    const groomer=manifest.groomerIDs[0];
    const [baseline]=query(`select rating_sum,rating_count,is_active from public.groomer_profiles where user_id='${groomer}';`);
    const details=[];
    for(const mode of ["static","soft","hard"]) {
      for(let i=0;i<10;i++) {
        const first=await rpc("C1","get_request_groomer_candidates_v1",pageParams);
        assert.equal(first.items.length,25);assert.ok(first.next_cursor);
        try {
          if(mode==="soft") query(`update public.groomer_profiles set rating_sum=rating_sum+5,rating_count=rating_count+1 where user_id='${groomer}';`);
          if(mode==="hard") query(`update public.groomer_profiles set is_active=false where user_id='${groomer}';`);
          if(mode==="hard") {
            await denied("C1","get_request_groomer_candidates_v1",{...pageParams,p_cursor:first.next_cursor},/list_changed/);
            const fresh=await rpc("C1","get_request_groomer_candidates_v1",pageParams);
            assert.equal(fresh.items.length,25);assert.equal(fresh.next_cursor,null);
            assert.ok(fresh.items.every(x=>x.groomer_id!==groomer));
          } else {
            const next=await rpc("C1","get_request_groomer_candidates_v1",{...pageParams,p_cursor:first.next_cursor});
            assert.equal(new Set([...first.items,...next.items].map(x=>x.groomer_id)).size,26);
            assert.equal(next.ranking_revision,first.ranking_revision);
          }
        } finally {
          if(mode!=="static") query(`update public.groomer_profiles set rating_sum=${baseline.rating_sum},rating_count=${baseline.rating_count},is_active=${baseline.is_active}
            where user_id='${groomer}';`);
          manifest.live.configured=liveRows(manifest);save(manifest);
        }
      }
      details.push({mode,passed:10,attempts:10});
    }
    return details;
  });
} else if(values.phase==="performance-cleanup") {
  const manifest=read();
  const performance=manifest.performance;
  assert.equal(performance?.completed,1200);
  assert.notEqual(performance.restored,true);
  assert.deepEqual(liveRows(manifest),manifest.live.configured,"Preserve external profile changes");
  const ids=performance.history.map(row=>row.id),requests=sqlIDs(ids);
  const owned=query(`select id from public.grooming_requests where id in (${requests})
    and customer_id='${actors.C1.id}' and pet_id='${manifest.live.pet_id}' and service_notes='${marker}';`).map(row=>row.id);
  assert.deepEqual(new Set(owned),new Set(ids));
  query(`begin;set local statement_timeout='150s';set local lock_timeout='5s';
    create temporary table history_bookings as select id from public.bookings where request_id in (${requests});
    delete from public.customer_notifications where related_request_id in (${requests}) or related_booking_id in(select id from history_bookings);
    delete from public.groomer_notifications where related_request_id in (${requests}) or related_booking_id in(select id from history_bookings);
    delete from public.messages m where m.kind='text'
      and m.body='Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!'
      and exists(select 1 from public.messages card where card.booking_id in(select id from history_bookings)
        and card.kind='booking_card' and card.conversation_id=m.conversation_id and card.sender_id=m.sender_id
        and m.created_at=card.created_at+interval '1 microsecond');
    delete from public.messages where booking_id in(select id from history_bookings);
    delete from public.grooming_requests where id in (${requests}) and service_notes='${marker}';
    commit;`,180000);
  assert.equal(query(`select count(*)::integer n from public.grooming_requests where id in (${requests});`)[0].n,0);
  manifest.requests=manifest.requests.filter(id=>!ids.includes(id));
  performance.restored=true;manifest.live.configured=liveRows(manifest);save(manifest);
  if(performance.request) await cancelRequest(performance.request.receipt.request_id);
  console.log("Performance-only history removed; original fixture addresses and conversations retained.");
} else if(values.phase==="compatibility") {
  const manifest=read();
  await check("A24/A46/A47 receipt isolation, retirement, replacement and rollback",async()=>rollbackFixture("discovery-compatibility",manifest));
} else if(values.phase==="verify") {
  const manifest=read();assert.deepEqual(config(),{discovery_enabled:false,discovery_validation_actor_ids:manifest.cohort});
  if(manifest.live?.ready&&!manifest.live.restored) {
    assert.deepEqual(liveRows(manifest),manifest.live.configured);
    const requests=query(`select id from public.grooming_requests where customer_id in (${sqlIDs(manifest.cohort)})
      and service_notes='${marker}' and pet_id='${manifest.live.pet_id}';`).map(x=>x.id);
    assert.deepEqual(new Set(requests),new Set(manifest.requests));
    console.log("Active fixture ownership and unchanged configured business data verified; restoration still pending.");
  } else {
    assert.deepEqual(counts(),manifest.countsBefore);
    console.log("No run-owned public business data remains; feature acceptance is tracked separately.");
  }
} else if(values.phase==="restore") {
  const manifest=read();
  assert.deepEqual(config(),{discovery_enabled:false,discovery_validation_actor_ids:manifest.cohort},"Preserve an externally changed rollout");
  const drafts=manifest.draftIDs.length?`draft_id in (${sqlIDs(manifest.draftIDs)})`:"false";
  const owned=`customer_id in (${sqlIDs(manifest.cohort)}) and ${drafts}`;
  const requestIDs=manifest.requests.length?sqlIDs(manifest.requests):"null::uuid";
  // Remove exact browse scopes before Request/address cascades remove their identity rows.
  const removedSnapshots=query(`delete from app_private.match_browse_snapshots b
    where b.viewer_id in (${sqlIDs(manifest.cohort)}) and b.captured_at>='${manifest.startedAt}'
      and (b.scope in (select r.id::text from public.grooming_requests r where r.id in (${requestIDs})
          and r.customer_id=b.viewer_id and r.service_notes='${marker}')
        or b.scope in (select 'groomer_discovery:'||jsonb_build_object('kind','request','id',r.id,'terms_revision',r.terms_revision)::text
          from public.grooming_requests r where r.id in (${requestIDs}) and r.customer_id=b.viewer_id and r.service_notes='${marker}')
        or b.scope in (select 'groomer_discovery:'||jsonb_build_object('kind','preview','id',s.id,'input_digest',s.input_digest)::text
          from app_private.request_discovery_sessions s where ${owned} and s.customer_id=b.viewer_id)) returning b.id;`);
  saveArtifact("distribution-browse-restoration",{removedSnapshotIDs:removedSnapshots.map(row=>row.id)});
  await restorePresentation(manifest);await restoreMedia(manifest);restoreLive(manifest);restoreClient(manifest);
  assert.equal(manifest.requests.length,0);
  query(`begin;set local lock_timeout='5s';
    do $$ begin if not exists(select 1 from app_private.match_ranking_config where singleton and not discovery_enabled
      and discovery_validation_actor_ids=array[${sqlIDs(manifest.cohort)}]) then raise exception 'Rollout changed; preserve it';end if;end $$;
    create temporary table discovery_cleanup as select id,address_location_id from app_private.request_discovery_sessions where ${owned};
    delete from app_private.match_browse_snapshots where viewer_id in (${sqlIDs(manifest.cohort)})
      and scope in (select 'groomer_discovery:'||jsonb_build_object('kind','preview','id',s.id,'input_digest',s.input_digest)::text
        from app_private.request_discovery_sessions s where ${owned});
    delete from app_private.request_discovery_sessions where id in(select id from pg_temp.discovery_cleanup);
    delete from app_private.address_locations a where id in(select address_location_id from pg_temp.discovery_cleanup)
      and owner_id in (${sqlIDs(manifest.cohort)}) and not exists(select 1 from public.grooming_requests where address_location_id=a.id)
      and not exists(select 1 from public.customer_profiles where address_location_id=a.id)
      and not exists(select 1 from public.groomer_profiles where address_location_id=a.id);
    update app_private.match_ranking_config set discovery_validation_actor_ids='{}' where singleton;
    commit;`);
  assert.deepEqual(config(),manifest.configBefore);assert.deepEqual(counts(),manifest.countsBefore);
  manifest.restored=true;save(manifest);console.log("Exact discovery fixture cleanup and rollout restoration passed.");
} else throw Error(`Phase ${values.phase} is not implemented yet; no acceptance claimed.`);
