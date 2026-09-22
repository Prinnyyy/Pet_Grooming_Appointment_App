begin;
set local lock_timeout='5s';
set local statement_timeout='90s';
select set_config('app.testops_favorites_input',(/* INPUT_JSON */)::text,true);
do $$
declare d jsonb:=current_setting('app.testops_favorites_input')::jsonb;
  customer uuid:=(d->'actors'->>'C1')::uuid; other uuid:=(d->'actors'->>'C2')::uuid;
  groomer uuid:=(d->'groomers'->>0)::uuid; paused uuid:=(d->'groomers'->>25)::uuid; gid uuid;
  first_state jsonb; state jsonb; page jsonb; second_page jsonb; entry jsonb; before_counts bigint[];
  assertions integer:=0; signed_cursor text;
begin
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  before_counts:=array[(select count(*) from public.grooming_requests where customer_id=customer),
    (select count(*) from public.request_matches where customer_id=customer),
    (select count(*) from public.groomer_notifications where related_request_id in(select id from public.grooming_requests where customer_id=customer))];
  perform set_config('role','authenticated',true);
  first_state:=public.set_groomer_favorite_v1(groomer,true,null);
  if first_state->>'is_favorite'<>'true' or first_state->>'revision' is null
    or public.set_groomer_favorite_v1(groomer,true,null)<>first_state then raise exception 'favorite is not idempotent';end if;
  begin perform public.set_groomer_favorite_v1(groomer,false,null);raise exception 'stale opposite write accepted';
    exception when sqlstate 'PT409' then if sqlerrm<>'favorite_changed' then raise;end if;end;
  state:=public.set_groomer_favorite_v1(groomer,false,(first_state->>'revision')::uuid);
  if state->>'is_favorite'<>'false' or state->>'revision'=first_state->>'revision' then raise exception 'tombstone has no revision';end if;
  begin perform public.set_groomer_favorite_v1(groomer,true,(first_state->>'revision')::uuid);raise exception 'old add reversed removal';
    exception when sqlstate 'PT409' then if sqlerrm<>'favorite_changed' then raise;end if;end;
  assertions:=assertions+4;
  state:=public.set_groomer_favorite_v1(groomer,true,(state->>'revision')::uuid);
  for gid in select value::uuid from jsonb_array_elements_text(d->'groomers') where value::uuid<>groomer loop
    perform public.set_groomer_favorite_v1(gid,true,null);
  end loop;
  page:=public.get_my_favorite_groomers_v1(null,25,null);
  signed_cursor:=page->>'next_cursor';
  second_page:=public.get_my_favorite_groomers_v1(null,25,page->>'next_cursor');
  if jsonb_array_length(page->'items')<>25 or jsonb_array_length(second_page->'items')<>1
    or (select count(distinct x->>'groomer_id') from jsonb_array_elements((page->'items')||(second_page->'items')) x)<>26 then
    raise exception 'favorite keyset missed or duplicated a member';end if;
  if exists(select 1 from jsonb_array_elements(page->'items') x where x->'safe_profile' ?| array['street_address','email','phone']) then
    raise exception 'favorite leaked private profile';end if;
  begin perform 1 from app_private.customer_groomer_favorites;raise exception 'favorite table exposed';
    exception when insufficient_privilege then null;end;
  perform public.set_groomer_favorite_v1(groomer,false,(state->>'revision')::uuid);
  begin perform public.get_my_favorite_groomers_v1(null,25,page->>'next_cursor');raise exception 'changed membership cursor accepted';
    exception when sqlstate 'PT409' then if sqlerrm<>'list_changed' then raise;end if;end;
  assertions:=assertions+4;
  perform set_config('role','none',true);
  if before_counts is distinct from array[(select count(*) from public.grooming_requests where customer_id=customer),
    (select count(*) from public.request_matches where customer_id=customer),
    (select count(*) from public.groomer_notifications where related_request_id in(select id from public.grooming_requests where customer_id=customer))] then
    raise exception 'favorites changed distribution';end if;
  update public.groomer_profiles set is_active=false where user_id=paused;
  perform set_config('role','authenticated',true);
  page:=public.get_my_favorite_groomers_v1(null,50,null);
  select x into entry from jsonb_array_elements(page->'items') x where x->>'groomer_id'=paused::text;
  if entry->>'availability'<>'paused' or entry->'safe_profile'<>'null'::jsonb then raise exception 'paused favorite lost or still exposes media';end if;
  perform set_config('role','none',true);
  update app_private.customer_groomer_favorites set updated_at=now()-interval '31 days' where customer_id=customer and groomer_id=groomer;
  select app_private.groomer_favorite_state(customer,groomer) into state;
  perform app_private.cleanup_favorite_tombstones();
  perform set_config('role','authenticated',true);
  begin perform public.set_groomer_favorite_v1(groomer,true,(state->>'revision')::uuid);raise exception 'deleted tombstone accepted stale revision';
    exception when sqlstate 'PT409' then if sqlerrm<>'favorite_changed' then raise;end if;end;
  assertions:=assertions+3;
  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',other::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  if public.get_my_favorite_groomers_v1(null,50,null)->'items'<>'[]'::jsonb then raise exception 'foreign favorites leaked';end if;
  begin perform public.get_my_favorite_groomers_v1(null,25,signed_cursor);raise exception 'cross-actor cursor accepted';
    exception when invalid_parameter_value then if sqlerrm<>'invalid_cursor' then raise;end if;end;
  perform public.set_groomer_favorite_v1(groomer,true,null);
  perform set_config('role','none',true);
  perform set_config('request.jwt.claim.sub',groomer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',groomer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  begin perform public.get_my_favorite_groomers_v1(null,25,null);raise exception 'groomer read favorites';
    exception when insufficient_privilege then null;end;
  assertions:=assertions+3;
  -- Database-only account redaction, including its real marketplace locks; always rolled back.
  perform public.request_account_deletion();
  perform set_config('role','none',true);
  if exists(select 1 from app_private.customer_groomer_favorites where groomer_id=groomer)
    or exists(select 1 from app_private.request_invitations where groomer_id=groomer) then raise exception 'groomer redaction left discovery identity';end if;
  perform set_config('request.jwt.claim.sub',customer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  perform public.request_account_deletion();
  begin perform public.get_my_favorite_groomers_v1(null,25,null);raise exception 'redacted token still authorized';
    exception when insufficient_privilege then null;end;
  perform set_config('role','none',true);
  if exists(select 1 from app_private.customer_groomer_favorites where customer_id=customer)
    or exists(select 1 from app_private.request_discovery_sessions where customer_id=customer)
    or exists(select 1 from app_private.request_distribution_operations where customer_id=customer)
    or exists(select 1 from app_private.request_publish_operations where customer_id=customer) then raise exception 'customer redaction left private records';end if;
  assertions:=assertions+3;
  perform set_config('app.testops_favorites_result',jsonb_build_object('assertions',assertions,'rollback',true)::text,true);
end $$;
select current_setting('app.testops_favorites_result')::jsonb result;
rollback;
