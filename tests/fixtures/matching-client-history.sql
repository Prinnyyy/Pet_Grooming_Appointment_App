begin;
set local lock_timeout='5s';
set local statement_timeout='150s';
create temporary table t392_history_input(data jsonb) on commit drop;
insert into t392_history_input values (/* INPUT_JSON */);
create temporary table t392_history_receipts(id text primary key,data jsonb) on commit drop;

do $$
declare d jsonb; h jsonb; a jsonb; g jsonb; p jsonb; service uuid; pet uuid; req uuid; off uuid;
  customer uuid; groomer uuid; revision uuid; proposal uuid; result jsonb; candidate jsonb; agreement jsonb;
  b public.bookings%rowtype; context jsonb; confirmations text[]; start_at timestamptz; historical timestamptz;
begin
  select data into strict d from pg_temp.t392_history_input;
  for a in select value from jsonb_array_elements(d->'actors') order by value->>'id' loop
    perform 1 from public.profiles where id=(a->>'id')::uuid for update;
  end loop;
  for h in select value from jsonb_array_elements(d->'history') loop
    select (value->>'id')::uuid into strict customer from jsonb_array_elements(d->'actors') where value->>'alias'=h->>'customer';
    select (value->>'id')::uuid into strict groomer from jsonb_array_elements(d->'actors') where value->>'alias'=h->>'groomer';
    if exists(select 1 from public.grooming_requests where service_notes=(d->>'marker')||' '||(h->>'id')) then
      raise exception 'History identity already exists; reconcile rather than retry';
    end if;
    perform pg_advisory_xact_lock(hashtextextended(groomer::text,71071));
    select value into strict g from jsonb_array_elements(d->'groomers') where value->>'id'=h->>'groomer';
    select value into strict p from jsonb_array_elements(d->'positions') where value->>'alias'=h->>'groomer';
    start_at:=(d->>'staging_start')::timestamptz;
    historical:=(h->>'service_at')::timestamptz;
    -- Historical capability is setup only; the row is removed before commit.
    insert into public.groomer_services(groomer_id,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species)
      values(groomer,'Synthetic historical service',d->>'marker',100,60,
        array['XS','S','M','L','XL','XXL','Giant'],true,h->>'service',array[h->>'species']) returning id into service;

    perform set_config('request.jwt.claim.sub',customer::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
    perform set_config('role','authenticated',true);
    select id into pet from public.pets where customer_id=customer and grooming_notes=(d->>'marker')||' '||(h->>'pet_id');
    if pet is null then
      select id into pet from public.save_my_pet_v2(null,((h->'pet_snapshot')-'coat_type_source')||jsonb_build_object(
        'name',h->>'pet_id','breed',case when h->>'species'='dog' then 'Mixed Breed' else 'Domestic Shorthair' end,
        'grooming_notes',(d->>'marker')||' '||(h->>'pet_id')),h->'pet_snapshot'->>'coat_type_source'='explicit');
    end if;
    if not exists(select 1 from public.pets t where t.id=pet and to_jsonb(t) @> (h->'pet_snapshot')) then
      raise exception 'Historical pet facts changed; preserve and reconcile';end if;
    select request_id into req from public.create_grooming_request_v4((h->>'operation_id')::uuid,jsonb_build_object(
      'pet_id',pet,'service_type',h->>'service','service_notes',(d->>'marker')||' '||(h->>'id'),
      'preferred_start',start_at,'preferred_end',start_at+interval '1 hour','location_mode',g->>'location_mode',
      'travel_radius_miles',case when g->>'location_mode'='customer_comes_to_groomer' then 10 else null end,
      'street_address','TestOps synthetic historical location','city',g->>'neighborhood','state','CA','zip_code','90001',
      'provider','apple_maps','country_code','US','latitude',p->'latitude','longitude',p->'longitude',
      'resolution_source','manual_geocode','user_confirmed_at',now()),'America/Los_Angeles');
    perform set_config('role','none',true);
    select terms_revision into strict revision from public.grooming_requests where id=req;
    select app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes)
      into strict confirmations from public.grooming_requests r cross join lateral
        app_private.offer_service_configuration(req,groomer,null) s where r.id=req;
    perform set_config('request.jwt.claim.sub',groomer::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',groomer,'role','authenticated','is_anonymous',false)::text,true);
    perform set_config('role','authenticated',true);
    select offer_id into off from public.create_groomer_offer_v3(req,revision,start_at,start_at+interval '1 hour',100,
      (d->>'marker')||' '||(h->>'id'),confirmations);
    perform set_config('role','none',true);
    select quote_revision into strict revision from public.groomer_offers where id=off;
    perform set_config('request.jwt.claim.sub',customer::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated','is_anonymous',false)::text,true);
    perform set_config('role','authenticated',true);
    perform public.accept_groomer_offer_v2(off,revision);
    perform set_config('role','none',true);
    select * into strict b from public.bookings where request_id=req;

    -- Explicit historical setup context, never a client fulfillment claim.
    candidate:=app_private.validate_reschedule_candidate(b,historical,historical-interval '1 day');
    if (candidate->>'end')::timestamptz is distinct from (h->>'service_end')::timestamptz
      or (candidate->>'occupied_start')::timestamptz is distinct from (h->>'occupied_start')::timestamptz
      or (candidate->>'occupied_end')::timestamptz is distinct from (h->>'occupied_end')::timestamptz then
      raise exception 'Historical allocation differs from frozen source';end if;
    proposal:=gen_random_uuid();
    agreement:=b.agreement_snapshot||jsonb_build_object('scheduled_start',historical,'scheduled_end',(candidate->>'end')::timestamptz,'reschedule_id',proposal);
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
    perform set_config('role','authenticated',true);
    context:=public.get_booking_review_context(b.id);
    if (select array_agg(value->>'dimension'||':'||(value->>'value') order by value->>'dimension'||':'||(value->>'value'))
      from jsonb_array_elements(context->'allowed_keys')) is distinct from
      (select array_agg(value order by value) from jsonb_array_elements_text(h->'allowed_keys')) then
      raise exception 'Historical allowed keys differ from independent source';end if;
    result:=public.create_review_v2(b.id,(context->>'context_revision')::uuid,(h->>'rating')::integer,
      (d->>'marker')||' '||(h->>'id'),coalesce((select jsonb_agg(jsonb_build_object('trait_type',split_part(key,':',1),
        'trait_value',split_part(key,':',2),'outcome',value)) from jsonb_each_text(h->'answers')),'[]'));
    perform set_config('role','none',true);
    insert into pg_temp.t392_history_receipts values(h->>'id',jsonb_build_object('request_id',req,'pet_id',pet,'offer_id',off,
      'booking_id',b.id,'review_id',result->'review_id','context',context,'rating',h->'rating','source_pet_id',h->>'pet_id'));
    delete from public.groomer_services where id=service and groomer_id=groomer and description=d->>'marker';
  end loop;
end $$;
select jsonb_object_agg(id,data) receipts from pg_temp.t392_history_receipts;
/* END_TRANSACTION */;
