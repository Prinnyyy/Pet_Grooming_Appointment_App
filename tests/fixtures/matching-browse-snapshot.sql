-- Rollback-only T-392 boundary checks. Input identities come from immutable receipts.
do $$
declare input jsonb:=current_setting('app.testops_browse')::jsonb;
  actor uuid:=(input->>'groomer')::uuid; review uuid:=(input->>'review')::uuid;
  first_page jsonb; next_page jsonb; fresh_page jsonb; changed_page jsonb;
  snapshot_id uuid; candidate uuid; original_privacy uuid; hard_event bigint; affected integer; i integer;
begin
  if input->>'run_id' !~ '^TESTOPS-T392-[A-Z0-9-]+$' then raise exception 'invalid run'; end if;
  if not exists(select 1 from public.reviews v join public.bookings b on b.id=v.booking_id
    join public.grooming_requests r on r.id=b.request_id where v.id=review and b.groomer_id=actor
      and b.id=(input->>'booking')::uuid and r.id=(input->>'request')::uuid
      and r.service_notes like 'TESTOPS:'||(input->>'run_id')||' history%') then
    raise exception 'owned history missing';
  end if;
  perform set_config('request.jwt.claim.sub',actor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
  perform set_config('role','authenticated',true);
  first_page:=public.get_ranked_matched_requests_v2('fit',1,null);
  if first_page->>'next_cursor' is null then raise exception 'paging pool too small'; end if;
  begin
    perform 1 from app_private.match_browse_snapshots;
    raise exception 'private snapshot exposed';
  exception when insufficient_privilege then null;
  end;
  perform set_config('role','none',true);
  select (app_private.match_cursor_decode(first_page->>'next_cursor',signing_key)->>'snapshot_id')::uuid,
    privacy_revision into snapshot_id,original_privacy from app_private.match_ranking_config where singleton;
  update public.review_pet_fit_outcomes set outcome=case when outcome='positive' then 'negative' else 'positive' end
    where review_id=review and groomer_id=actor and trait_type='service' and trait_value='full_groom';
  get diagnostics affected=row_count;
  if affected<>1 then raise exception 'expected one owned professional update'; end if;
  perform set_config('role','authenticated',true);
  next_page:=public.get_ranked_matched_requests_v2('fit',1,first_page->>'next_cursor');
  fresh_page:=public.get_ranked_matched_requests_v2('fit',50,null);
  if next_page->>'ranking_revision' is distinct from first_page->>'ranking_revision'
    or fresh_page->>'ranking_revision'=first_page->>'ranking_revision'
    or next_page->'items'->0->'request'->>'id'=first_page->'items'->0->'request'->>'id' then
    raise exception 'soft evidence must freeze only for continuation';
  end if;
  perform set_config('role','none',true);
  candidate:=(first_page->'items'->0->'request'->>'id')::uuid;
  insert into app_private.match_refresh_queue(request_id,groomer_id,reason) values(candidate,actor,'hard_eligibility')
    returning id into hard_event;
  perform set_config('role','authenticated',true);
  begin
    perform public.get_ranked_matched_requests_v2('fit',1,first_page->>'next_cursor');
    raise exception 'hard change was hidden';
  exception when sqlstate 'PT409' then if sqlerrm<>'list_changed' then raise; end if;
  end;
  perform set_config('role','none',true);
  delete from app_private.match_refresh_queue where id=hard_event and request_id=candidate and groomer_id=actor;
  perform set_config('role','authenticated',true);
  next_page:=public.get_ranked_matched_requests_v2('fit',1,first_page->>'next_cursor');
  perform set_config('role','none',true);
  update app_private.match_ranking_config set privacy_revision=gen_random_uuid() where singleton;
  perform set_config('role','authenticated',true);
  begin
    perform public.get_ranked_matched_requests_v2('fit',1,first_page->>'next_cursor');
    raise exception 'privacy invalidation was hidden';
  exception when sqlstate 'PT409' then if sqlerrm<>'list_changed' then raise; end if;
  end;
  perform set_config('role','none',true);
  update app_private.match_ranking_config set privacy_revision=original_privacy where singleton;
  perform set_config('role','authenticated',true);
  next_page:=public.get_ranked_matched_requests_v2('fit',1,first_page->>'next_cursor');
  perform set_config('role','none',true);
  update app_private.match_browse_snapshots set captured_at=statement_timestamp()-interval '6 minutes',
    valid_until=statement_timestamp()-interval '1 minute' where id=snapshot_id and viewer_id=actor;
  perform set_config('role','authenticated',true);
  begin
    perform public.get_ranked_matched_requests_v2('fit',1,first_page->>'next_cursor');
    raise exception 'expired snapshot was returned';
  exception when sqlstate 'PT409' then if sqlerrm<>'list_changed' then raise; end if;
  end;
  for i in 1..34 loop changed_page:=public.get_ranked_matched_requests_v2('fit',1,null); end loop;
  perform set_config('role','none',true);
  if (select count(*) from app_private.match_browse_snapshots where viewer_id=actor)>32 then
    raise exception 'viewer storage cap exceeded';
  end if;
  if exists(select 1 from app_private.match_browse_snapshots where viewer_id=actor
    and (octet_length(soft_evidence::text)>262144 or valid_until>captured_at+interval '5 minutes')) then
    raise exception 'snapshot bounds violated';
  end if;
  perform set_config('app.testops_browse_result',jsonb_build_object('soft_continuation',true,'fresh_soft_visible',true,
    'hard_invalidates',true,'privacy_invalidates',true,'expiry_invalidates',true,'private_access_denied',true,
    'viewer_cap',32,'rolled_back',true)::text,true);
end $$;
select current_setting('app.testops_browse_result')::jsonb result;
