// Authorized T-466 HTTP acceptance using disposable actors, existing RPCs and scoped cleanup.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {spawnSync,spawn} from 'node:child_process';
import {randomUUID,randomBytes} from 'node:crypto';
import {parseEnv} from 'node:util';
import {SupabaseREST} from './testops-core.mjs';
assert.equal(process.env.TESTOPS_REMOTE_WRITE_APPROVED,'1');
assert.equal(readFileSync('supabase/.temp/project-ref','utf8').trim(),'lqmasbuqzvcvtawonjlb');
const dir='artifacts/evidence/T-466', recovery=`${dir}/http-recovery.json`;
const env=parseEnv(readFileSync('supabase_environment_variables','utf8'));
assert.equal(env.SUPABASE_URL,'https://lqmasbuqzvcvtawonjlb.supabase.co');
const api=new SupabaseREST(env.SUPABASE_URL,env.SUPABASE_PUBLISHABLE_KEY,env.SUPABASE_SECRET_KEY??env.SUPABASE_SERVICE_ROLE_KEY);
const secret=api.requireServiceRole();
const save=(name,data)=>writeFileSync(`${dir}/${name}.json`,JSON.stringify(data,null,2),{mode:0o600});
function query(sql) {
 writeFileSync(`${dir}/http-scoped.sql`,sql,{mode:0o600});
 const r=spawnSync('supabase',['db','query','--linked','--file',`${dir}/http-scoped.sql`,'-o','json'],
  {encoding:'utf8',timeout:120000,maxBuffer:8*1024*1024,env:{...process.env,SUPABASE_TELEMETRY_DISABLED:'1'}});
 if(r.status!==0){writeFileSync(`${dir}/http-query-error.log`,r.stderr);throw Error('Scoped SQL failed; see http-query-error.log');}
 return JSON.parse(r.stdout).rows;
}
const sqlID=id=>{assert.match(id,/^[a-f0-9-]{36}$/);return `'${id}'::uuid`;};
const admin=(path,method,body)=>api.request(`/auth/v1/admin/users${path}`,{method,headers:api.headers(secret),...(body?{body:JSON.stringify(body)}:{})},'admin');
async function cleanup(saved) {
 if(!saved.actors.length)return;
 const ids=saved.actors.map(a=>sqlID(a.id)).join(',');
 query(`begin;
 do $$ begin if exists(select 1 from auth.users where id in (${ids}) and raw_app_meta_data->>'t466_run' is distinct from '${saved.run}') then raise exception 'Cohort ownership mismatch'; end if; end $$;
 delete from public.conversations where customer_id in (${ids}) or groomer_id in (${ids});
 select app_private.cleanup_testops_request_address_location(id,'T466') from public.grooming_requests where customer_id in (${ids}) and service_notes='TESTOPS:T466';
 delete from public.grooming_requests where customer_id in (${ids}) and service_notes='TESTOPS:T466';
 delete from public.pets where customer_id in (${ids});
 commit;`);
 for(const a of saved.actors) { try {await admin(`/${a.id}`,'DELETE');} catch(e){if(e.httpStatus!==404)throw e;} }
 const [remaining]=query(`select (select count(*) from auth.users where id in (${ids})) users,
 (select count(*) from public.profiles where id in (${ids})) profiles,
 (select count(*) from public.grooming_requests where customer_id in (${ids})) requests,
 (select count(*) from public.bookings where customer_id in (${ids}) or groomer_id in (${ids})) bookings,
 (select count(*) from public.conversations where customer_id in (${ids}) or groomer_id in (${ids})) conversations,
 (select count(*) from app_private.address_locations where owner_id in (${ids})) locations;`);
 assert.ok(Object.values(remaining).every(n=>n===0),JSON.stringify(remaining));
 saved.cleaned=true;save('http-recovery',saved);save('http-cleanup',{remaining,scope:'Only disposable T466 actors; existing account settings untouched'});
}
if(process.argv[2]==='cleanup') {await cleanup(JSON.parse(readFileSync(recovery)));process.exit(0);}
assert.ok(!existsSync(recovery)||JSON.parse(readFileSync(recovery)).cleaned,'Unfinished cohort requires cleanup first');
const saved={run:randomUUID(),actors:[],cleaned:false}, actors={}, results=[];
save('http-recovery',saved);
const rpc=(actor,name,params)=>api.rpc(name,params,actors[actor].token);
async function reject(action,pattern){let e;try{await action();}catch(error){e=error;}assert.ok(e?.httpStatus>=400&&e.httpStatus<500, 'Expected business rejection');assert.match(e.serverMessage,pattern);return e.serverMessage;}
try {
 for(const alias of ['customer','other_customer','groomer','stranger']) {
  const email=`t466-${randomUUID()}@example.invalid`, password=randomBytes(24).toString('base64url');
  const user=await admin('','POST',{email,password,email_confirm:true,app_metadata:{t466_run:saved.run}});
  saved.actors.push({alias,id:user.id});save('http-recovery',saved);
  const session=await api.signIn(email,password);actors[alias]={id:user.id,token:session.accessToken};
 }
 let fixture=readFileSync('tests/fixtures/grooming-adoption.sql','utf8');
 const prefix=fixture.slice(0,fixture.indexOf('do $$\ndeclare customer'));
 let setup=fixture.slice(fixture.indexOf('do $$\ndeclare customer'),fixture.indexOf("  perform pg_temp.assume(customer); req_a:="));
 for(const alias of Object.keys(actors))setup=setup.replace(`${alias} uuid:=gen_random_uuid()`,`${alias} uuid:=${sqlID(actors[alias].id)}`);
 setup=setup.replace(/^    insert into auth.users.*\n/m,'');
 const rows=query(prefix+`create temporary table t466_http_fixture(data jsonb);\n`+setup+`
  perform pg_temp.assume(customer); req_a:=pg_temp.new_request(groomer,start_at,'T466 race A');
  perform pg_temp.assume(other_customer); req_b:=pg_temp.new_request(groomer,start_at,'T466 race B');
  perform set_config('role','none',true); select terms_revision into revision from public.grooming_requests where id=req_a;
  perform pg_temp.assume(groomer);
  select offer_id into offer_a from public.create_groomer_offer_v3(req_a,revision,start_at,start_at+interval '1 hour',95,null,'{}');
  perform set_config('role','none',true); select terms_revision into revision from public.grooming_requests where id=req_b;
  perform pg_temp.assume(groomer);
  select offer_id into offer_b from public.create_groomer_offer_v3(req_b,revision,start_at+interval '30 minutes',start_at+interval '90 minutes',85,null,'{}');
  perform pg_temp.assume(customer); req_c:=pg_temp.new_request(groomer,start_at+interval '4 hours','T466 contact');
  perform set_config('role','none',true); select terms_revision into revision from public.grooming_requests where id=req_c;
  perform pg_temp.assume(groomer);
  select offer_id into offer_c from public.create_groomer_offer_v3(req_c,revision,start_at+interval '4 hours',start_at+interval '5 hours',75,null,'{}');
  perform set_config('role','none',true);
  insert into t466_http_fixture values(jsonb_build_object('a',(select to_jsonb(o) from public.groomer_offers o where id=offer_a),
   'b',(select to_jsonb(o) from public.groomer_offers o where id=offer_b),'c',(select to_jsonb(o) from public.groomer_offers o where id=offer_c),
   'c_request_revision',revision));
 end $$;
 select data from t466_http_fixture;commit;`);
 const f=rows[0].data;
 const accept=(alias,offer)=>rpc(alias,'accept_groomer_offer_v2',{p_offer_id:offer.id,p_expected_quote_revision:offer.quote_revision});
 // Hold both request rows, wait until both HTTP transactions are blocked, then
 // release them together. The holder itself verifies overlap; no parallel CLI.
 const barrierSQL=`begin;
 select id from public.grooming_requests where id in (${sqlID(f.a.request_id)},${sqlID(f.b.request_id)}) order by id for update;
 do $$ declare deadline timestamptz:=clock_timestamp()+interval '20 seconds'; n integer; begin loop
 perform pg_stat_clear_snapshot();
 select count(*) into n from pg_stat_activity a where pg_backend_pid()=any(pg_blocking_pids(a.pid));
 exit when n>=2;
 if clock_timestamp()>deadline then raise exception 'Two HTTP acceptance transactions did not reach barrier'; end if;
 perform pg_sleep(0.1); end loop; end $$;
 commit;select 'Two concurrent HTTP transactions observed at request locks' as proof;`;
 writeFileSync(`${dir}/http-race-barrier.sql`,barrierSQL);
 const barrier=spawn('supabase',['db','query','--linked','--file',`${dir}/http-race-barrier.sql`,'-o','json'],
 {env:{...process.env,SUPABASE_TELEMETRY_DISABLED:'1'},stdio:['ignore','pipe','pipe']});
 let barrierOutput='',barrierError='';barrier.stdout.on('data',v=>barrierOutput+=v);barrier.stderr.on('data',v=>barrierError+=v);
 const finished=new Promise(resolve=>barrier.on('close',code=>resolve(code)));
 await new Promise(resolve=>setTimeout(resolve,2000));
 const race=await Promise.allSettled([accept('customer',f.a),accept('other_customer',f.b)]);
 save('http-race-outcomes',race.map(r=>r.status==='fulfilled'?{status:r.status,value:r.value}:{status:r.status,http:r.reason.httpStatus,code:r.reason.code,message:r.reason.serverMessage}));
 const barrierCode=await finished;
 writeFileSync(`${dir}/http-race-barrier.log`,barrierOutput+barrierError);
 assert.equal(barrierCode,0,'Concurrency barrier failed');
 assert.equal(race.filter(r=>r.status==='fulfilled').length,1);
 const loss=race.find(r=>r.status==='rejected').reason;
 assert.ok(loss.httpStatus>=400&&loss.httpStatus<500);assert.match(loss.serverMessage,/offer|conflict|available|overlap/);
 const winner=race[0].status==='fulfilled'?'a':'b', alias=winner==='a'?'customer':'other_customer';
 const replay=await Promise.all([accept(alias,f[winner]),accept(alias,f[winner]),accept(alias,f[winner])]);
 assert.deepEqual(replay[0],replay[1]);assert.deepEqual(replay[1],replay[2]);
 const [count]=query(`select count(*) n from public.bookings where offer_id in (${sqlID(f.a.id)},${sqlID(f.b.id)});`);assert.equal(count.n,1);
 results.push({case:'Overlapping accepts + same-offer concurrent replay',result:'PASS',bookings:count.n,loser:loss.serverMessage});
 const contact={p_request_id:f.c.request_id,p_groomer_id:actors.groomer.id};
 await reject(()=>rpc('stranger','get_request_chat_contact',contact),/request_contact_unavailable/);
 const conversation=await rpc('customer','open_request_conversation',contact);
 await rpc('groomer','withdraw_groomer_offer',{p_offer_id:f.c.id});
 const post=(body)=>api.request('/rest/v1/messages',{method:'POST',headers:api.headers(actors.customer.token,{Prefer:'return=representation'}),
  body:JSON.stringify({id:randomUUID(),conversation_id:conversation,sender_id:actors.customer.id,body})},'message');
 await reject(()=>post('TESTOPS:T466 revoked'),/request_contact_unavailable/);
 await reject(()=>rpc('customer','open_request_conversation',contact),/request_contact_unavailable/);
 const closed=await rpc('groomer','get_grooming_offers',{p_group:'closed',p_limit:20,p_offset:0});assert.ok(!closed.some(o=>o.id===f.c.id));
 const [fresh]=await rpc('groomer','create_groomer_offer_v3',{p_request_id:f.c.request_id,p_expected_request_revision:f.c_request_revision,
 p_proposed_start:f.c.proposed_start,p_proposed_end:f.c.proposed_end,p_price_estimate:70,p_message:null,p_assessment_confirmations:[]});
 assert.notEqual(fresh.offer_id,f.c.id);
 await post('TESTOPS:T466 started');
 await rpc('groomer','withdraw_groomer_offer',{p_offer_id:fresh.offer_id});
 await post('TESTOPS:T466 established conversation');
 results.push({case:'Withdraw/reoffer identity + revoked first-message + established chat + outsider',result:'PASS'});
 save('http-acceptance',{results});console.log(JSON.stringify(results));
} finally {await cleanup(saved);}
