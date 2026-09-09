-- Caller owns BEGIN/ROLLBACK, including all message-trigger effects.
create temporary table t380_summary_evidence(summary_rows integer, payload_bytes integer, latest_message_plan jsonb);
do $$
declare
  customer uuid; busy_groomer uuid; quiet_groomer uuid; foreign_customer uuid;
  busy uuid; quiet uuid; result jsonb; latest uuid; probe jsonb;
  at_time timestamptz := statement_timestamp() + interval '1 day';
begin
  select id into strict customer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict foreign_customer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-002';
  select id into strict busy_groomer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict quiet_groomer from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-002';
  insert into public.conversations(customer_id,groomer_id) values(customer,busy_groomer),(customer,quiet_groomer)
    on conflict(customer_id,groomer_id) do nothing;
  select id into strict busy from public.conversations where customer_id=customer and groomer_id=busy_groomer;
  select id into strict quiet from public.conversations where customer_id=customer and groomer_id=quiet_groomer;
  insert into public.messages(conversation_id,sender_id,body,created_at)
    select busy,busy_groomer,'T380 busy '||n,at_time from generate_series(1,1500) n;
  insert into public.messages(conversation_id,sender_id,body,created_at)
    values(quiet,quiet_groomer,'T380 quiet latest',at_time-interval '1 hour');
  select id into latest from public.messages where conversation_id=busy order by created_at desc,id desc limit 1;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  -- Installed PostgREST max_rows is 1000, verified through its config read API.
  if exists(select 1 from (select m.conversation_id from public.messages m
    where m.conversation_id in (busy,quiet) order by m.created_at desc,m.id desc limit 1000) capped
    where capped.conversation_id=quiet) then raise exception 'T380 old-query truncation not reproduced'; end if;
  select jsonb_agg(to_jsonb(s)) into result from public.get_conversation_summaries(array[busy,quiet]) s;
  if jsonb_array_length(result)<>2 then raise exception 'T380 wrong summary count'; end if;
  if not exists(select 1 from jsonb_array_elements(result) s where s->>'conversation_id'=busy::text
    and s->'latest_message'->>'id'=latest::text) then raise exception 'T380 unstable latest tie'; end if;
  if not exists(select 1 from jsonb_array_elements(result) s where s->>'conversation_id'=quiet::text
    and s->'latest_message'->>'body'='T380 quiet latest') then raise exception 'T380 quiet preview missing'; end if;
  execute format('explain (analyze, buffers, format json) select m.id from public.messages m where m.conversation_id=%L::uuid order by m.created_at desc,m.id desc limit 1',busy) into probe;
  if probe::text not like '%messages_conversation_created_idx%' then
    raise exception 'T380 latest read did not use conversation/time/ID index'; end if;
  if (select count(*) from public.get_conversation_summaries(array[busy,busy]))<>1 then
    raise exception 'T380 duplicate scope duplicated result'; end if;
  if (select count(*) from public.get_conversation_summaries('{}'::uuid[]))<>0 then
    raise exception 'T380 empty scope leaked rows'; end if;
  begin
    perform public.get_conversation_summaries(array_fill(busy,array[101]));
    raise exception 'T380 excessive scope accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.get_conversation_summaries(array[busy,gen_random_uuid()]);
    raise exception 'T380 missing mixed scope accepted';
  exception when insufficient_privilege then null; end;
  execute 'reset role';
  insert into t380_summary_evidence values(jsonb_array_length(result),octet_length(result::text),probe);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',foreign_customer,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  begin
    perform public.get_conversation_summaries(array[busy,quiet]);
    raise exception 'T380 foreign actor read summaries';
  exception when insufficient_privilege then null; end;
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',true)::text,true);
  execute 'set local role authenticated';
  begin
    perform public.get_conversation_summaries(array[busy]);
    raise exception 'T380 anonymous actor read summaries';
  exception when insufficient_privilege then null; end;
  execute 'reset role';
end $$;

select summary_rows,payload_bytes,latest_message_plan from t380_summary_evidence;
