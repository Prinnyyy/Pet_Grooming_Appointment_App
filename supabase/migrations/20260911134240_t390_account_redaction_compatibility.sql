-- MR-02: keep privacy deletion compatible with versioned marketplace records.
create function app_private.active_account_redaction()
returns uuid language sql stable set search_path='' as $$
  select d.user_id from public.account_deletion_requests d
  where d.user_id::text=current_setting('app.account_redaction_actor',true)
    and d.user_id=(select auth.uid()) and d.status='pending_auth_soft_delete';
$$;

create function app_private.redacted_request(p_row jsonb)
returns jsonb language sql stable set search_path='' as $$
  select p_row||jsonb_build_object(
    'pet_snapshot',jsonb_build_object('id',p_row->'pet_id','name','Deleted pet','species','pet'),
    'photo_snapshot','[]'::jsonb,'service_notes',null,'street_address','Address removed','address_line_2',null,
    'city','Deleted','state','NA','zip_code','00000','address_location_id',null,
    'status',case when p_row->>'status' in ('open','has_offers') then 'cancelled' else p_row->>'status' end);
$$;

create function app_private.redacted_agreement(p_snapshot jsonb,p_customer uuid,p_groomer uuid)
returns jsonb language plpgsql stable set search_path='' as $$
declare actor uuid:=app_private.active_account_redaction(); result jsonb:=p_snapshot;
begin
  if actor is null or actor not in (p_customer,p_groomer) or p_snapshot is null then return p_snapshot; end if;
  if actor=p_customer then
    result:=result||jsonb_build_object('pet_snapshot',
      jsonb_build_object('id',p_snapshot->'pet_id','name','Deleted pet','species','pet'),'service_notes',null);
  end if;
  if (actor=p_customer and p_snapshot->>'location_mode'='groomer_comes_to_customer')
    or (actor=p_groomer and p_snapshot->>'location_mode'='customer_comes_to_groomer') then
    result:=result||jsonb_build_object('address',jsonb_build_object('redacted',true,
      'street_address','Address removed','city','','state','','zip_code','','country_code',''));
  end if;
  return result;
end $$;
revoke all on function app_private.active_account_redaction(),app_private.redacted_request(jsonb),
  app_private.redacted_agreement(jsonb,uuid,uuid) from public,anon,authenticated,service_role;

create or replace function app_private.guard_request_agreement_terms()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if app_private.active_account_redaction()=old.customer_id
    and to_jsonb(new)-'updated_at'=app_private.redacted_request(to_jsonb(old))-'updated_at' then
    return new;
  end if;
  if row(new.customer_id,new.pet_id,new.pet_snapshot,new.service_type,new.service_notes,
    new.preferred_start,new.preferred_end,new.location_mode,new.street_address,new.address_line_2,
    new.city,new.state,new.zip_code,coalesce(new.address_location_id,old.address_location_id),new.travel_radius_miles,new.terms_revision,
    new.expires_at)
    is distinct from
    row(old.customer_id,old.pet_id,old.pet_snapshot,old.service_type,old.service_notes,
    old.preferred_start,old.preferred_end,old.location_mode,old.street_address,old.address_line_2,
    old.city,old.state,old.zip_code,old.address_location_id,old.travel_radius_miles,old.terms_revision,
    old.expires_at) then
    raise exception using errcode='23514',message='published_request_terms_are_immutable';
  end if;
  if new.address_location_id is null and old.address_location_id is not null
    and exists(select 1 from app_private.address_locations where id=old.address_location_id) then
    raise exception using errcode='23514',message='published_request_terms_are_immutable';
  end if;
  if old.supersedes_request_id is not null and new.supersedes_request_id is distinct from old.supersedes_request_id then
    raise exception using errcode='23514',message='request_lineage_is_immutable';
  end if;
  return new;
end $$;

create or replace function app_private.snapshot_offer_agreement()
returns trigger language plpgsql security definer set search_path='' as $$
declare r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype;
  a app_private.address_locations%rowtype; address jsonb; service_revision uuid; redacting boolean;
begin
  if tg_op='UPDATE' then
    redacting:=app_private.active_account_redaction() in (old.customer_id,old.groomer_id)
      and new.message is null
      and new.agreement_snapshot is not distinct from app_private.redacted_agreement(old.agreement_snapshot,old.customer_id,old.groomer_id);
    if row(new.quote_revision,new.price_estimate,new.expires_at,new.request_id,new.match_id,new.customer_id,new.groomer_id)
      is distinct from row(old.quote_revision,old.price_estimate,old.expires_at,old.request_id,old.match_id,old.customer_id,old.groomer_id)
      or (not coalesce(redacting,false) and row(new.agreement_snapshot,new.message) is distinct from row(old.agreement_snapshot,old.message)) then
      raise exception using errcode='23514',message='quote_terms_are_immutable';
    end if;
    if old.terms_invalid_reason is not null and new.terms_invalid_reason is distinct from old.terms_invalid_reason then
      raise exception using errcode='23514',message='quote_invalidity_is_terminal';
    end if;
    return new;
  end if;
  select * into strict r from public.grooming_requests where id=new.request_id and customer_id=new.customer_id for update;
  select * into strict g from public.groomer_profiles where user_id=new.groomer_id;
  select eligibility_revision into strict service_revision from app_private.offer_service_configuration(new.request_id,new.groomer_id,null);
  if r.location_mode='groomer_comes_to_customer' then
    select * into strict a from app_private.address_locations where id=r.address_location_id and owner_id=r.customer_id;
    address:=jsonb_build_object('street_address',r.street_address,'address_line_2',r.address_line_2,'city',r.city,'state',r.state,'zip_code',r.zip_code);
  else
    select * into strict a from app_private.address_locations where id=g.address_location_id and owner_id=g.user_id;
    address:=jsonb_build_object('street_address',g.base_street_address,'address_line_2',g.base_address_line_2,
      'city',g.base_city,'state',g.base_state,'zip_code',g.base_zip_code);
  end if;
  if nullif(btrim(address->>'street_address'),'') is null then
    raise exception using errcode='22023',message='agreement_address_required';
  end if;
  address:=address||jsonb_build_object('country_code',a.country_code,'latitude',a.latitude,'longitude',a.longitude,
    'source_location_id',a.id,'provider',a.provider,'confirmed_at',a.user_confirmed_at,'source_updated_at',a.updated_at);
  new.agreement_snapshot:=jsonb_build_object('schema_version',1,'request_revision',r.terms_revision,
    'quote_revision',new.quote_revision,'pet_id',r.pet_id,'pet_snapshot',r.pet_snapshot,
    'service_type',r.service_type,'service_notes',r.service_notes,'location_mode',r.location_mode,
    'address',address,'service_time_zone_identifier',new.service_time_zone_identifier,
    'scheduled_start',new.proposed_start,'scheduled_end',new.proposed_end,
    'price_estimate',new.price_estimate,'currency','USD','captured_at',statement_timestamp(),
    'source','quote_creation','groomer_eligibility_revision',g.eligibility_revision,
    'service_eligibility_revision',service_revision,
    'service_configuration_id',(select id from app_private.offer_service_configuration(new.request_id,new.groomer_id,service_revision)));
  return new;
end $$;

create or replace function app_private.snapshot_booking_agreement()
returns trigger language plpgsql security definer set search_path='' as $$
declare o public.groomer_offers%rowtype; r public.grooming_requests%rowtype; evaluation jsonb;
begin
  if tg_op='UPDATE' then
    if app_private.authorized_reschedule_change(new,old) then return new; end if;
    if new.price_estimate is not distinct from old.price_estimate
      and app_private.active_account_redaction() in (old.customer_id,old.groomer_id)
      and new.agreement_snapshot is not distinct from app_private.redacted_agreement(old.agreement_snapshot,old.customer_id,old.groomer_id) then
      return new;
    end if;
    if row(new.agreement_snapshot,new.price_estimate) is distinct from row(old.agreement_snapshot,old.price_estimate) then
      raise exception using errcode='23514',message='booking_agreement_is_immutable';
    end if;
    return new;
  end if;
  select * into strict r from public.grooming_requests where id=new.request_id for update;
  select * into strict o from public.groomer_offers where id=new.offer_id and request_id=new.request_id
    and customer_id=new.customer_id and groomer_id=new.groomer_id;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.groomer_id::text,71071));
  evaluation:=app_private.evaluate_quote(o.id);
  if evaluation->>'terms_valid' is distinct from 'true' then
    raise exception using errcode='22023',message='quote_terms_invalid',detail=evaluation->>'reason';
  end if;
  if o.agreement_snapshot is null then raise exception using errcode='22023',message='updated_agreement_offer_required'; end if;
  if o.terms_invalid_reason is not null or o.agreement_snapshot->>'request_revision'<>r.terms_revision::text
    or o.status<>'pending' or r.status not in ('open','has_offers') then
    raise exception using errcode='22023',message='quote_terms_invalid';
  end if;
  if least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')<=statement_timestamp() then
    raise exception using errcode='P0001',message='offer_expired';
  end if;
  if new.price_estimate is distinct from o.price_estimate then raise exception using errcode='23514',message='booking_offer_price_mismatch'; end if;
  new.agreement_snapshot:=o.agreement_snapshot;
  return new;
end $$;

create or replace function app_private.request_account_deletion()
returns table(deletion_request_id uuid,user_id uuid,role public.user_role,status text,requested_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); actor_role public.user_role; deletion uuid; requested timestamptz:=statement_timestamp();
  item record; previous_redaction text:=current_setting('app.account_redaction_actor',true);
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  -- Order existing marketplace locks before identity/FK locks, including review writers' booking lock.
  perform 1 from public.grooming_requests r where r.customer_id=actor
    or exists(select 1 from public.groomer_offers o where o.request_id=r.id and o.groomer_id=actor)
    order by r.id for update;
  perform 1 from public.bookings b where actor in (b.customer_id,b.groomer_id) order by b.id for update;
  for item in select groomer_id from (
    select b.groomer_id from public.bookings b where actor in (b.customer_id,b.groomer_id)
    union select o.groomer_id from public.groomer_offers o where actor in (o.customer_id,o.groomer_id)
    union select actor where exists(select 1 from public.groomer_profiles where public.groomer_profiles.user_id=actor)
  ) groomers order by groomer_id loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(item.groomer_id::text,71071));
  end loop;
  select p.role into actor_role from public.profiles p where p.id=actor for update;
  if not found then raise exception using errcode='P0001',message='profile_required'; end if;
  insert into public.account_deletion_requests as d(user_id,role,status,requested_at,last_error)
    values(actor,actor_role,'pending_auth_soft_delete',requested,null)
    on conflict on constraint account_deletion_requests_user_id_key do update
      set status='pending_auth_soft_delete',last_error=null returning d.id into deletion;
  perform set_config('app.account_redaction_actor',actor::text,true);

  for item in select b.id,b.fulfillment_revision from public.bookings b
    where actor in (b.customer_id,b.groomer_id) and b.status='confirmed'
      and b.fulfillment_phase='scheduled' and b.scheduled_start>clock_timestamp() order by b.id loop
    begin
      perform app_private.mutate_booking_fulfillment(item.id,item.fulfillment_revision,gen_random_uuid(),'cancel',null);
    exception when sqlstate 'P0001' then
      if sqlerrm<>'use_service_outcome_report' then raise; end if;
    end;
  end loop;
  -- Ongoing service retains its actual allocation/phase; account deletion is not an outcome report.
  update public.groomer_offers o set message=null,
    agreement_snapshot=app_private.redacted_agreement(o.agreement_snapshot,o.customer_id,o.groomer_id),
    status=case when o.status='pending' then case when actor=o.customer_id then 'declined_by_customer' else 'withdrawn_by_groomer' end else o.status end,
    withdrawn_at=case when o.status='pending' and actor=o.groomer_id then coalesce(o.withdrawn_at,statement_timestamp()) else o.withdrawn_at end
    where actor in (o.customer_id,o.groomer_id);
  update public.bookings b set agreement_snapshot=app_private.redacted_agreement(b.agreement_snapshot,b.customer_id,b.groomer_id)
    where actor in (b.customer_id,b.groomer_id);
  update public.request_matches m set status='hidden',match_reason=null,dismiss_reason='account_deleted',dismissed_at=null
    where actor in (m.customer_id,m.groomer_id) and m.status<>'hidden';
  update public.profiles p set display_name=case when actor_role='customer' then 'Deleted customer' else 'Deleted groomer' end,
    avatar_path=null where p.id=actor;
  update public.messages m set body='Message removed because this account was deleted.' where m.sender_id=actor;

  if actor_role='customer' then
    update public.grooming_requests r set
      pet_snapshot=jsonb_build_object('id',r.pet_id,'name','Deleted pet','species','pet'),photo_snapshot='[]',service_notes=null,
      street_address='Address removed',address_line_2=null,city='Deleted',state='NA',zip_code='00000',address_location_id=null,
      status=case when r.status in ('open','has_offers') then 'cancelled' else r.status end where r.customer_id=actor;
    update public.pets p set name='Deleted pet',species='pet',breed=null,coat_type=null,coat_type_source='unknown',matting_confirmed=null,
      size=null,weight_lbs=null,birthday=null,temperament=null,medical_notes=null,grooming_notes=null,is_active=false,
      deleted_at=coalesce(p.deleted_at,statement_timestamp()) where p.customer_id=actor;
    update public.customer_profiles p set street_address=null,address_line_2=null,city=null,state=null,zip_code=null,
      address_location_id=null,contact_email=null,phone_number=null where p.user_id=actor;
    update public.reviews r set content=null where r.customer_id=actor;
    delete from public.customer_notifications where customer_id=actor;
    delete from public.customer_push_tokens where customer_id=actor;
    delete from public.customer_booking_handoff_acknowledgements where customer_id=actor;
    delete from public.request_photos where customer_id=actor;
    delete from public.pet_photos where customer_id=actor;
  else
    update public.groomer_profiles p set business_name='Deleted groomer',bio=null,years_experience=null,
      base_street_address=null,base_address_line_2=null,base_city=null,base_state=null,base_zip_code=null,address_location_id=null,
      service_radius_miles=null,service_location_mode=null,service_location_modes=null,is_active=false,is_verified=false where p.user_id=actor;
    update public.groomer_services set title='Deleted service',description=null,accepted_pet_sizes='{}',is_active=false where groomer_id=actor;
    update public.groomer_fit_claims set is_active=false where groomer_id=actor;
    delete from public.groomer_portfolio_photos where groomer_id=actor;
    if not exists(select 1 from public.bookings b where b.groomer_id=actor and b.status='confirmed') then
      delete from public.groomer_availability_windows where groomer_id=actor;
      delete from public.groomer_booking_preferences where groomer_id=actor;
      delete from public.groomer_time_off_windows where groomer_id=actor;
    end if;
  end if;
  delete from app_private.address_locations where owner_id=actor;
  update public.account_deletion_requests d set anonymized_at=statement_timestamp(),last_error=null where d.id=deletion;
  perform set_config('app.account_redaction_actor',coalesce(previous_redaction,''),true);
  return query select deletion,actor,actor_role,'pending_auth_soft_delete'::text,requested;
end $$;
revoke all on function app_private.request_account_deletion(),app_private.guard_request_agreement_terms(),
  app_private.snapshot_offer_agreement(),app_private.snapshot_booking_agreement() from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
