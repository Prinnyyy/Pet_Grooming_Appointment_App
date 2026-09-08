alter table public.grooming_requests
  add column terms_revision uuid not null default gen_random_uuid(),
  add column supersedes_request_id uuid references public.grooming_requests(id);
create unique index grooming_requests_one_replacement
  on public.grooming_requests(supersedes_request_id) where supersedes_request_id is not null;

alter table public.groomer_offers
  add column quote_revision uuid not null default gen_random_uuid(),
  add column agreement_snapshot jsonb,
  add column terms_invalid_reason text;
alter table public.bookings add column agreement_snapshot jsonb;
alter table public.groomer_services add column eligibility_revision uuid not null default gen_random_uuid();
alter table public.groomer_profiles add column eligibility_revision uuid not null default gen_random_uuid();

create function app_private.bump_quote_eligibility_revision()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op='INSERT' then
    new.eligibility_revision:=gen_random_uuid();
    return new;
  end if;
  if tg_table_name='groomer_services' then
    if row(new.is_active,new.accepted_pet_sizes,new.service_type,new.groomer_id)
      is distinct from row(old.is_active,old.accepted_pet_sizes,old.service_type,old.groomer_id) then
      new.eligibility_revision:=gen_random_uuid();
    else new.eligibility_revision:=old.eligibility_revision; end if;
  else
    if row(new.is_active,new.service_location_modes,new.service_location_mode,new.service_radius_miles,
      new.address_location_id,new.base_street_address,new.base_address_line_2,new.base_city,new.base_state,new.base_zip_code)
      is distinct from row(old.is_active,old.service_location_modes,old.service_location_mode,old.service_radius_miles,
      old.address_location_id,old.base_street_address,old.base_address_line_2,old.base_city,old.base_state,old.base_zip_code) then
      new.eligibility_revision:=gen_random_uuid();
    else new.eligibility_revision:=old.eligibility_revision; end if;
  end if;
  return new;
end $$;
revoke all on function app_private.bump_quote_eligibility_revision() from public,anon,authenticated,service_role;
create trigger groomer_services_quote_revision before insert or update on public.groomer_services
for each row execute function app_private.bump_quote_eligibility_revision();
create trigger groomer_profiles_quote_revision before insert or update on public.groomer_profiles
for each row execute function app_private.bump_quote_eligibility_revision();

create function app_private.guard_request_agreement_terms()
returns trigger language plpgsql set search_path = '' as $$
begin
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
  -- ON DELETE SET NULL may unlink a deleted source; agreed snapshots are separate.
  if new.address_location_id is null and old.address_location_id is not null
    and exists(select 1 from app_private.address_locations where id=old.address_location_id) then
    raise exception using errcode='23514',message='published_request_terms_are_immutable';
  end if;
  if old.supersedes_request_id is not null and new.supersedes_request_id is distinct from old.supersedes_request_id then
    raise exception using errcode='23514',message='request_lineage_is_immutable';
  end if;
  return new;
end $$;
revoke all on function app_private.guard_request_agreement_terms() from public,anon,authenticated,service_role;
create trigger grooming_requests_guard_agreement_terms before update on public.grooming_requests
for each row execute function app_private.guard_request_agreement_terms();

create function app_private.snapshot_offer_agreement()
returns trigger language plpgsql security definer set search_path = '' as $$
declare r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype;
  a app_private.address_locations%rowtype; address jsonb; service_revision uuid;
begin
  if tg_op='UPDATE' then
    if row(new.quote_revision,new.agreement_snapshot,new.price_estimate,new.message,new.expires_at,
      new.request_id,new.match_id,new.customer_id,new.groomer_id)
      is distinct from row(old.quote_revision,old.agreement_snapshot,old.price_estimate,old.message,old.expires_at,
      old.request_id,old.match_id,old.customer_id,old.groomer_id) then
      raise exception using errcode='23514',message='quote_terms_are_immutable';
    end if;
    if old.terms_invalid_reason is not null and new.terms_invalid_reason is distinct from old.terms_invalid_reason then
      raise exception using errcode='23514',message='quote_invalidity_is_terminal';
    end if;
    return new;
  end if;
  select * into strict r from public.grooming_requests where id=new.request_id and customer_id=new.customer_id for update;
  select * into strict g from public.groomer_profiles where user_id=new.groomer_id;
  select eligibility_revision into strict service_revision from public.groomer_services
    where groomer_id=new.groomer_id and service_type=r.service_type and is_active;
  if r.location_mode='groomer_comes_to_customer' then
    select * into strict a from app_private.address_locations where id=r.address_location_id and owner_id=r.customer_id;
    address:=jsonb_build_object('street_address',r.street_address,'address_line_2',r.address_line_2,
      'city',r.city,'state',r.state,'zip_code',r.zip_code);
  else
    select * into strict g from public.groomer_profiles where user_id=new.groomer_id;
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
    'service_eligibility_revision',service_revision);
  return new;
end $$;
revoke all on function app_private.snapshot_offer_agreement() from public,anon,authenticated,service_role;
-- Runs after the existing timing snapshot so one agreement carries its exact zone.
create trigger groomer_offers_zz_agreement before insert or update on public.groomer_offers
for each row execute function app_private.snapshot_offer_agreement();

create function app_private.snapshot_booking_agreement()
returns trigger language plpgsql security definer set search_path = '' as $$
declare o public.groomer_offers%rowtype; r public.grooming_requests%rowtype; evaluation jsonb;
begin
  if tg_op='UPDATE' then
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
  -- Existing admission/timing triggers own exact capacity errors and exclusions.
  if o.agreement_snapshot is null then
    raise exception using errcode='22023',message='updated_agreement_offer_required';
  end if;
  if o.terms_invalid_reason is not null or o.agreement_snapshot->>'request_revision'<>r.terms_revision::text
    or o.status<>'pending' or r.status not in ('open','has_offers') then
    raise exception using errcode='22023',message='quote_terms_invalid';
  end if;
  if least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')<=statement_timestamp() then
    raise exception using errcode='P0001',message='offer_expired';
  end if;
  if new.price_estimate is distinct from o.price_estimate then
    raise exception using errcode='23514',message='booking_offer_price_mismatch';
  end if;
  new.agreement_snapshot:=o.agreement_snapshot;
  return new;
end $$;
revoke all on function app_private.snapshot_booking_agreement() from public,anon,authenticated,service_role;
create trigger bookings_aaa_agreement before insert or update on public.bookings
for each row execute function app_private.snapshot_booking_agreement();

create function app_private.evaluate_quote(p_offer_id uuid,p_now timestamptz default statement_timestamp())
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare o public.groomer_offers%rowtype; r public.grooming_requests%rowtype;
  reason text; constraints jsonb; earliest timestamptz; notice integer; zone text;
  zone_count integer; window_count integer;
begin
  select * into o from public.groomer_offers where id=p_offer_id;
  if not found then return jsonb_build_object('terms_valid',false,'selectable',false,'reason','not_found'); end if;
  select * into strict r from public.grooming_requests where id=o.request_id;
  if o.terms_invalid_reason is not null then reason:=o.terms_invalid_reason;
  elsif o.status='withdrawn_by_groomer' then reason:='withdrawn';
  elsif o.status='expired' or least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')<=p_now then reason:='expired';
  elsif o.status<>'pending' or r.status not in ('open','has_offers') then reason:='superseded';
  elsif o.agreement_snapshot is null then reason:='legacy_unverified';
  elsif o.agreement_snapshot->>'request_revision' is distinct from r.terms_revision::text then reason:='superseded';
  elsif o.agreement_snapshot->>'groomer_eligibility_revision' is distinct from
    (select eligibility_revision::text from public.groomer_profiles where user_id=o.groomer_id)
    or o.agreement_snapshot->>'service_eligibility_revision' is distinct from
    (select eligibility_revision::text from public.groomer_services where groomer_id=o.groomer_id and service_type=r.service_type)
    or (o.agreement_snapshot->'address'->>'source_updated_at')::timestamptz is distinct from
    (select updated_at from app_private.address_locations where id=(o.agreement_snapshot->'address'->>'source_location_id')::uuid)
    then reason:='eligibility_revoked';
  else
    constraints:=app_private.evaluate_match_constraints(r.id,o.groomer_id,p_now);
    if constraints->>'state'='excluded' then reason:='eligibility_revoked'; end if;
  end if;
  if reason is not null then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason',reason);
  end if;
  select coalesce((select minimum_advance_notice_days from public.groomer_booking_preferences
    where groomer_id=o.groomer_id),0) into notice;
  select min(timezone),count(distinct timezone),count(*) into zone,zone_count,window_count
    from public.groomer_availability_windows where groomer_id=o.groomer_id;
  if zone_count<>1 or window_count<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=zone
  ) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  earliest:=app_private.service_timing_earliest_start(p_now,notice,zone);
  if o.proposed_start<earliest then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason','expired');
  end if;
  if not app_private.groomer_can_admit_service(o.groomer_id,o.proposed_start,o.proposed_end,p_now)
    or exists(select 1 from public.bookings b where b.pet_id=r.pet_id and b.status in ('confirmed','completed')
      and tstzrange(b.scheduled_start,b.scheduled_end,'[)') && tstzrange(o.proposed_start,o.proposed_end,'[)'))
    or exists(select 1 from public.bookings b where b.groomer_id=o.groomer_id and b.status in ('confirmed','completed')
      and tstzrange(coalesce(b.occupied_start,b.scheduled_start),coalesce(b.occupied_end,b.scheduled_end),'[)')
        && tstzrange(o.occupied_start,o.occupied_end,'[)'))
    or app_private.occupied_time_off_conflict(o.groomer_id,o.occupied_start,o.occupied_end)
    or not app_private.occupied_weekly_hours_covered(o.groomer_id,o.occupied_start,o.occupied_end) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  return jsonb_build_object('terms_valid',true,'selectable',true,'reason','available');
end $$;
revoke all on function app_private.evaluate_quote(uuid,timestamptz) from public,anon,authenticated,service_role;

create function app_private.get_quote_evaluations(p_offer_ids uuid[])
returns table(offer_id uuid,evaluation jsonb) language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_offer_ids is null or cardinality(p_offer_ids)>100 then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  return query select o.id,app_private.evaluate_quote(o.id) from public.groomer_offers o
    where o.id=any(p_offer_ids) and exists(select 1 from public.profiles p where p.id=actor
      and ((o.customer_id=actor and p.role='customer') or (o.groomer_id=actor and p.role='groomer')));
end $$;
create function public.get_quote_evaluations(p_offer_ids uuid[])
returns table(offer_id uuid,evaluation jsonb) language sql stable security invoker set search_path = '' as $$
  select * from app_private.get_quote_evaluations(p_offer_ids);
$$;
revoke all on function app_private.get_quote_evaluations(uuid[]),public.get_quote_evaluations(uuid[])
  from public,anon,authenticated,service_role;
grant execute on function app_private.get_quote_evaluations(uuid[]),public.get_quote_evaluations(uuid[]) to authenticated;

create function app_private.accept_groomer_offer_v2(p_offer_id uuid,p_expected_quote_revision uuid)
returns table(booking_id uuid,conversation_id uuid,request_id uuid,offer_id uuid,
  booking_status text,offer_status text,request_status text)
language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); parent uuid; revision uuid;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  select r.id into parent from public.grooming_requests r join public.groomer_offers o on o.request_id=r.id
    where o.id=p_offer_id and o.customer_id=actor and r.customer_id=actor for update of r;
  if not found then raise exception using errcode='P0001',message='offer_not_found'; end if;
  select o.quote_revision into revision from public.groomer_offers o where o.id=p_offer_id for update;
  if p_expected_quote_revision is distinct from revision then
    raise exception using errcode='22023',message='quote_revision_changed';
  end if;
  -- Original implementation owns idempotent receipts and atomic lifecycle events.
  return query select * from app_private.accept_groomer_offer(p_offer_id);
end $$;
create function public.accept_groomer_offer_v2(p_offer_id uuid,p_expected_quote_revision uuid)
returns table(booking_id uuid,conversation_id uuid,request_id uuid,offer_id uuid,
  booking_status text,offer_status text,request_status text)
language sql security invoker set search_path = '' as $$
  select * from app_private.accept_groomer_offer_v2(p_offer_id,p_expected_quote_revision);
$$;
revoke all on function app_private.accept_groomer_offer_v2(uuid,uuid),public.accept_groomer_offer_v2(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function app_private.accept_groomer_offer_v2(uuid,uuid),public.accept_groomer_offer_v2(uuid,uuid) to authenticated;
revoke execute on function app_private.accept_groomer_offer(uuid) from public,anon,authenticated,service_role;
create or replace function public.accept_groomer_offer(p_offer_id uuid)
returns table(booking_id uuid,conversation_id uuid,request_id uuid,offer_id uuid,
  booking_status text,offer_status text,request_status text)
language plpgsql security invoker set search_path = '' as $$
begin raise exception using errcode='22023',message='updated_agreement_client_required'; end $$;

create function app_private.create_groomer_offer_v2(p_request_id uuid,p_expected_request_revision uuid,
  p_proposed_start timestamptz,p_proposed_end timestamptz,p_price_estimate numeric,p_message text default null)
returns table(offer_id uuid,offer_status text,request_status text)
language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); revision uuid;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  select r.terms_revision into revision from public.grooming_requests r where r.id=p_request_id
    and exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=actor)
    for update;
  if not found then raise exception using errcode='P0001',message='match_not_found'; end if;
  if p_expected_request_revision is distinct from revision then
    raise exception using errcode='22023',message='request_revision_changed';
  end if;
  return query select * from app_private.create_groomer_offer(p_request_id,p_proposed_start,p_proposed_end,p_price_estimate,p_message);
end $$;
create function public.create_groomer_offer_v2(p_request_id uuid,p_expected_request_revision uuid,
  p_proposed_start timestamptz,p_proposed_end timestamptz,p_price_estimate numeric,p_message text default null)
returns table(offer_id uuid,offer_status text,request_status text)
language sql security invoker set search_path = '' as $$
  select * from app_private.create_groomer_offer_v2(p_request_id,p_expected_request_revision,p_proposed_start,p_proposed_end,p_price_estimate,p_message);
$$;
revoke all on function app_private.create_groomer_offer_v2(uuid,uuid,timestamptz,timestamptz,numeric,text),
  public.create_groomer_offer_v2(uuid,uuid,timestamptz,timestamptz,numeric,text) from public,anon,authenticated,service_role;
grant execute on function app_private.create_groomer_offer_v2(uuid,uuid,timestamptz,timestamptz,numeric,text),
  public.create_groomer_offer_v2(uuid,uuid,timestamptz,timestamptz,numeric,text) to authenticated;
revoke execute on function app_private.create_groomer_offer(uuid,timestamptz,timestamptz,numeric,text) from public,anon,authenticated,service_role;
create or replace function public.create_groomer_offer(p_request_id uuid,p_proposed_start timestamptz,
  p_proposed_end timestamptz,p_price_estimate numeric,p_message text default null)
returns table(offer_id uuid,offer_status text,request_status text)
language plpgsql security invoker set search_path = '' as $$
begin raise exception using errcode='22023',message='updated_agreement_client_required'; end $$;

drop trigger groomer_profiles_lock_match_change on public.groomer_profiles;
create trigger groomer_profiles_lock_match_change before update of is_active,address_location_id,
  service_location_mode,service_location_modes,service_radius_miles,base_street_address,base_address_line_2,
  base_city,base_state,base_zip_code on public.groomer_profiles
for each row execute function app_private.lock_match_constraint_change();

create function app_private.supersede_grooming_request(p_request_id uuid,p_expected_request_revision uuid,
  p_publish_operation_id uuid,p_request jsonb,p_preference_time_zone_identifier text)
returns table(request_id uuid,match_count integer)
language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); original public.grooming_requests%rowtype;
  replacement uuid; matches integer;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_publish_operation_id is null then raise exception using errcode='22023',message='invalid_publish_operation'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||':'||p_publish_operation_id::text,0));
  select o.request_id,o.match_count into replacement,matches from app_private.request_publish_operations o
    where o.customer_id=actor and o.operation_id=p_publish_operation_id;
  if found then
    if not exists(select 1 from public.grooming_requests r where r.id=replacement and r.customer_id=actor
      and r.supersedes_request_id=p_request_id) then
      raise exception using errcode='22023',message='publish_operation_intent_changed';
    end if;
    return query select replacement,matches;
    return;
  end if;
  select * into original from public.grooming_requests r where r.id=p_request_id and r.customer_id=actor for update;
  if not found then raise exception using errcode='P0001',message='request_not_found'; end if;
  if original.terms_revision is distinct from p_expected_request_revision then
    raise exception using errcode='22023',message='request_revision_changed';
  end if;
  if original.status not in ('open','has_offers') or original.expires_at<=statement_timestamp() then
    raise exception using errcode='P0001',message='request_not_cancellable';
  end if;
  select created.request_id,created.match_count into strict replacement,matches
    from app_private.create_grooming_request_v4(p_publish_operation_id,p_request,p_preference_time_zone_identifier) created;
  update public.grooming_requests set supersedes_request_id=original.id where id=replacement and customer_id=actor;
  perform app_private.cancel_grooming_request(original.id);
  return query select replacement,matches;
end $$;
create function public.supersede_grooming_request(p_request_id uuid,p_expected_request_revision uuid,
  p_publish_operation_id uuid,p_request jsonb,p_preference_time_zone_identifier text)
returns table(request_id uuid,match_count integer)
language sql security invoker set search_path = '' as $$
  select * from app_private.supersede_grooming_request(p_request_id,p_expected_request_revision,
    p_publish_operation_id,p_request,p_preference_time_zone_identifier);
$$;
revoke all on function app_private.supersede_grooming_request(uuid,uuid,uuid,jsonb,text),
  public.supersede_grooming_request(uuid,uuid,uuid,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function app_private.supersede_grooming_request(uuid,uuid,uuid,jsonb,text),
  public.supersede_grooming_request(uuid,uuid,uuid,jsonb,text) to authenticated;

notify pgrst, 'reload schema';
