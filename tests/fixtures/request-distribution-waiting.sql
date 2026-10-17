begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
select set_config('app.testops_waiting_input',(/* INPUT_JSON */)::text,true);
do $$
declare d jsonb:=current_setting('app.testops_waiting_input')::jsonb;
  req uuid:=(d->>'request_id')::uuid; customer uuid:=(d->>'customer_id')::uuid;
  groomer uuid:=(d->>'groomer_id')::uuid; progress jsonb;
begin
  if d->>'run_id' !~ '^TESTOPS-T399-[A-Z0-9-]+$' or not exists(
    select 1 from public.grooming_requests where id=req and customer_id=customer
      and service_notes='TESTOPS:'||(d->>'run_id') and pool_enabled and status='open' and expires_at>now()) then
    raise exception 'Owned active pool fixture required';
  end if;
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  delete from app_private.match_refresh_queue where request_id=req;
  delete from app_private.match_candidate_evaluations where request_id=req;
  perform set_config('role','authenticated',true);
  progress:=public.get_customer_request_progress_v1(array[req])->0;
  if progress->>'pool_candidate_count' is distinct from '0' or progress->>'evaluation_pending'<>'false' then
    raise exception 'No completed candidates must be explicit zero';
  end if;
  perform set_config('role','none',true);
  perform app_private.refresh_candidate_evaluation(req,groomer,now(),0);
  perform set_config('role','authenticated',true);
  progress:=public.get_customer_request_progress_v1(array[req])->0;
  if progress->>'pool_candidate_count'<>'1' or progress->>'evaluation_pending'<>'false' then
    raise exception 'One fresh candidate must remain distinct from pending';
  end if;
  perform set_config('role','none',true);
  update app_private.match_candidate_evaluations set valid_until=now()-interval '1 second' where request_id=req;
  perform set_config('role','authenticated',true);
  progress:=public.get_customer_request_progress_v1(array[req])->0;
  if progress->>'pool_candidate_count'<>'0' or progress->>'evaluation_pending'<>'true' then
    raise exception 'Stale evaluation must not become completed zero';
  end if;
  perform set_config('role','none',true);
  update public.request_matches set status='dismissed',dismissed_at=now() where request_id=req and groomer_id=groomer;
  delete from app_private.match_refresh_queue where request_id=req;
  perform set_config('role','authenticated',true);
  progress:=public.get_customer_request_progress_v1(array[req])->0;
  if progress->>'pool_candidate_count'<>'0' or progress->>'evaluation_pending'<>'false' then
    raise exception 'Dismissed stale candidate must not leave checking forever';
  end if;
  perform set_config('role','none',true);
  perform set_config('app.testops_waiting_result','{"assertions":4,"rollback":true}',true);
end $$;
select current_setting('app.testops_waiting_result')::jsonb result;
rollback;
