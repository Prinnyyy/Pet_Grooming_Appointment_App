begin;
set local lock_timeout='5s';
set local statement_timeout='150s';
select set_config('test.discovery_compatibility',(/* INPUT_JSON */)::text,true);
do $$
declare d jsonb:=current_setting('test.discovery_compatibility')::jsonb; input jsonb:=d->'input';
  customer uuid:=(d->'actors'->>'C1')::uuid; groomer uuid:=(d->'actors'->>'G1')::uuid;
  other uuid:=(d->'actors'->>'G2')::uuid; legacy_op uuid:=gen_random_uuid(); legacy_id uuid;
  new_op uuid:=gen_random_uuid(); session jsonb; receipt jsonb; progress jsonb; replacement jsonb;
  req uuid; offer uuid; old_count integer; match_count integer; assertions integer:=0; eval jsonb;
begin
  if d->>'run_id' !~ '^TESTOPS-T399-' then raise exception 'Invalid fixture scope';end if;
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  select x.request_id,x.match_count into strict legacy_id,old_count
    from public.create_grooming_request_v4(legacy_op,input,'America/New_York') x;
  perform public.cancel_grooming_request(legacy_id);
  perform set_config('role','none',true);
  update app_private.match_ranking_config set legacy_publish_retired=true where singleton;
  perform set_config('role','authenticated',true);
  select x.match_count into strict match_count from public.create_grooming_request_v4(legacy_op,input,'America/New_York') x
    where x.request_id=legacy_id;
  if match_count is distinct from old_count then raise exception 'Legacy receipt changed after retirement';end if;
  begin
    perform public.create_grooming_request_v4(gen_random_uuid(),input,'America/New_York');
    raise exception 'Unsafe legacy write was accepted';
  exception when sqlstate 'PT409' then if sqlerrm<>'client_update_required' then raise;end if;end;
  assertions:=assertions+2;

  session:=public.prepare_request_discovery_v1(gen_random_uuid(),input);
  receipt:=public.publish_request_with_distribution_v1(new_op,(session->>'session_id')::uuid,
    session->>'input_digest',false,array[groomer]);
  req:=(receipt->>'request_id')::uuid;
  begin
    perform public.create_grooming_request_v4(new_op,input,'America/New_York');
    raise exception 'Discovery receipt masqueraded as legacy';
  exception when invalid_parameter_value then if sqlerrm<>'publish_operation_intent_changed' then raise;end if;end;
  begin
    perform public.publish_request_with_distribution_v1(legacy_op,(session->>'session_id')::uuid,
      session->>'input_digest',false,array[groomer]);
    raise exception 'Legacy receipt masqueraded as discovery';
  exception when sqlstate 'PT409' then if sqlerrm<>'operation_intent_changed' then raise;end if;end;
  assertions:=assertions+2;

  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',groomer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',groomer,'role','authenticated','is_anonymous',false)::text,true);
  eval:=app_private.evaluate_match_eligibility(req,groomer,statement_timestamp());
  perform set_config('role','authenticated',true);
  if public.get_groomer_request_detail_v1(req)->>'pool_enabled'<>'false' then raise exception 'Incorrect directed source';end if;
  select offer_id into offer from public.create_groomer_offer_v3(req,(receipt->>'terms_revision')::uuid,
    (eval->>'service_start')::timestamptz,(eval->>'service_end')::timestamptz,80,d->>'marker','{}');
  perform set_config('role','none',true);
  update app_private.match_ranking_config set discovery_enabled=false,discovery_validation_actor_ids='{}' where singleton;
  perform set_config('role','authenticated',true);
  if public.get_groomer_request_detail_v1(req) is null then raise exception 'Rollback lost existing offer detail';end if;
  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',other::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  if exists(select 1 from public.grooming_requests where id=req)
    or exists(select 1 from public.get_groomer_request_summaries_v1(array[req])) then raise exception 'Rollback broadcast directed request';end if;
  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  progress:=public.get_customer_request_progress_v1(array[req]);
  if jsonb_array_length(progress)<>1 then raise exception 'Rollback lost owner progress';end if;
  if public.publish_request_with_distribution_v1(new_op,(session->>'session_id')::uuid,
      session->>'input_digest',false,array[groomer])<>receipt then raise exception 'Rollback lost accepted receipt';end if;
  begin
    perform public.prepare_request_discovery_v1(gen_random_uuid(),input);
    raise exception 'New discovery did not close on rollback';
  exception when raise_exception then if sqlerrm<>'discovery_unavailable' then raise;end if;end;
  assertions:=assertions+5;
  perform set_config('role','none',true);
  update app_private.match_ranking_config set discovery_validation_actor_ids=array[customer] where singleton;
  perform set_config('role','authenticated',true);

  input:=input||jsonb_build_object('superseding_request_id',req,'expected_request_revision',receipt->>'terms_revision');
  session:=public.prepare_request_discovery_v1(gen_random_uuid(),input);
  begin
    perform public.publish_request_with_distribution_v1(gen_random_uuid(),(session->>'session_id')::uuid,
      session->>'input_digest',false,array[gen_random_uuid()]);
    raise exception 'Invalid replacement succeeded';
  exception when sqlstate 'PT409' then if sqlerrm<>'groomer_unavailable' then raise;end if;end;
  perform set_config('role','none',true);
  if (select status from public.grooming_requests where id=req)<>'has_offers'
    or app_private.evaluate_quote(offer)->>'selectable'<>'true' then raise exception 'Failed replacement retired original';end if;
  perform set_config('role','authenticated',true);
  replacement:=public.publish_request_with_distribution_v1(gen_random_uuid(),(session->>'session_id')::uuid,
    session->>'input_digest',false,array[other]);
  perform set_config('role','none',true);
  if (select status from public.grooming_requests where id=req)<>'cancelled'
    or app_private.request_invitation_state(req,groomer)<>'closed'
    or app_private.evaluate_quote(offer)->>'selectable'<>'false'
    or (select supersedes_request_id from public.grooming_requests where id=(replacement->>'request_id')::uuid)<>req then
    raise exception 'Replacement did not atomically close original';end if;
  assertions:=assertions+2;
  perform set_config('test.compatibility_result',jsonb_build_object('assertions',assertions,'rollback',true,
    'legacy_retirement',true,'receipt_protocol_isolation',true,'safe_rollout_rollback',true,'atomic_replacement',true)::text,true);
end $$;
select current_setting('test.compatibility_result')::jsonb result;
rollback;
