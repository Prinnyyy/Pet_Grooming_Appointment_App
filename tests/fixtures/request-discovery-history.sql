begin;
set local lock_timeout='5s';
set local statement_timeout='150s';
select set_config('test.discovery_history_input',(/* INPUT_JSON */)::text,true);
do $$
declare d jsonb:=current_setting('test.discovery_history_input')::jsonb; item jsonb;
  source public.grooming_requests%rowtype; r public.grooming_requests%rowtype; b public.bookings%rowtype;
  customer uuid:=(d->>'customer')::uuid; groomer uuid; off uuid; revision uuid; proposal uuid;
  candidate jsonb; agreement jsonb; context jsonb; historical timestamptz; staged timestamptz;
begin
  select * into strict source from public.grooming_requests where id=(d->>'source')::uuid
    and customer_id=customer and service_notes=d->>'marker';
  if d->>'marker' !~ '^TESTOPS:TESTOPS-T399-' then raise exception 'Invalid history owner';end if;
  staged:=timezone('America/New_York',(timezone('America/New_York',now())::date+10)+time '10:00');
  for item in select value from jsonb_array_elements(d->'rows') loop
    groomer:=(item->>'groomer')::uuid;
    if not exists(select 1 from auth.users where id=groomer and raw_app_meta_data->>'beckon_seed_id' like 'BTG-%') then
      raise exception 'Only existing seed groomers are allowed';end if;
    r:=source;r.id:=(item->>'id')::uuid;r.terms_revision:=gen_random_uuid();r.status:='open';
    r.supersedes_request_id:=null;r.preferred_start:=staged;r.preferred_end:=staged+interval '1 hour';
    r.created_at:=statement_timestamp();r.updated_at:=r.created_at;r.expires_at:=r.created_at+interval '48 hours';
    r.distribution_version:='discovery_v1';r.pool_enabled:=true;r.distribution_revision:=gen_random_uuid();
    insert into public.grooming_requests select r.*;
    perform app_private.refresh_candidate_evaluation(r.id,groomer,statement_timestamp(),0);
    perform set_config('request.jwt.claim.sub',groomer::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',groomer,'role','authenticated','is_anonymous',false)::text,true);
    select offer_id into off from public.create_groomer_offer_v3(r.id,r.terms_revision,staged,staged+interval '1 hour',80,d->>'marker','{}');
    select quote_revision into strict revision from public.groomer_offers where id=off;
    perform set_config('request.jwt.claim.sub',customer::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
    perform public.accept_groomer_offer_v2(off,revision);
    select * into strict b from public.bookings where request_id=r.id;
    historical:=timezone('America/New_York',(timezone('America/New_York',now())::date-(1+(item->>'ordinal')::integer/6))
      +time '09:00'+make_interval(hours=>(item->>'ordinal')::integer%6));
    -- Synthetic historical setup uses the existing guarded reschedule allocation path.
    candidate:=app_private.validate_reschedule_candidate(b,historical,historical-interval '1 day');
    proposal:=gen_random_uuid();
    agreement:=b.agreement_snapshot||jsonb_build_object('scheduled_start',historical,
      'scheduled_end',(candidate->>'end')::timestamptz,'reschedule_id',proposal);
    insert into public.booking_reschedule_proposals(id,booking_id,base_revision,initiator_id,proposed_start,proposed_end,
      proposed_occupied_start,proposed_occupied_end,previous_agreement,proposed_agreement,status,created_at,expires_at,responded_by,responded_at)
      values(proposal,b.id,b.fulfillment_revision,customer,historical,(candidate->>'end')::timestamptz,
        (candidate->>'occupied_start')::timestamptz,(candidate->>'occupied_end')::timestamptz,b.agreement_snapshot,agreement,
        'accepted',historical-interval '1 day',historical-interval '5 minutes',groomer,historical-interval '1 hour');
    perform set_config('app.reschedule_proposal',proposal::text,true);
    perform set_config('app.fulfillment_write','1',true);
    update public.bookings set scheduled_start=historical,scheduled_end=(candidate->>'end')::timestamptz,
      occupied_start=(candidate->>'occupied_start')::timestamptz,occupied_end=(candidate->>'occupied_end')::timestamptz,
      agreement_snapshot=agreement,fulfillment_revision=gen_random_uuid() where id=b.id returning * into b;
    perform set_config('app.reschedule_proposal','',true);
    update public.booking_reschedule_proposals set result_revision=b.fulfillment_revision where id=proposal;
    update public.bookings set status='completed',fulfillment_phase='completed',fulfillment_basis='bilateral_retrospective',
      actual_started_at=scheduled_start,actual_ended_at=scheduled_end,pet_release_at=scheduled_end,resource_release_at=occupied_end,
      completed_at=scheduled_end,completed_by=groomer where id=b.id;
    perform set_config('app.fulfillment_write','',true);
    context:=public.get_booking_review_context(b.id);
    perform public.create_review_v2(b.id,(context->>'context_revision')::uuid,
      case when (item->>'ordinal')::integer%5=0 then 3 else 5 end,d->>'marker',
      '[{"trait_type":"service","trait_value":"full_groom","outcome":"positive"},{"trait_type":"size","trait_value":"M","outcome":"positive"}]');
  end loop;
end $$;
select count(*)::integer reviews from public.reviews v join public.bookings b on b.id=v.booking_id
  where b.request_id in(select (value->>'id')::uuid from jsonb_array_elements(current_setting('test.discovery_history_input')::jsonb->'rows'));
commit;
