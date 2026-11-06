-- T-466: durable automatic quote closure without cross-request lock inversion.
-- Booking admission already holds the groomer advisory lock. Record an immutable
-- reason there; normalize the old offer under its own parent-request lock only.
begin;
create table app_private.offer_booking_conflicts (
  offer_id uuid primary key, -- No FK: another acceptance may hold this offer while awaiting our advisory lock.
  booking_id uuid references public.bookings(id) on delete set null,
  recorded_at timestamptz not null default clock_timestamp()
);
alter table app_private.offer_booking_conflicts enable row level security;
revoke all on app_private.offer_booking_conflicts from public,anon,authenticated,service_role;
create function app_private.delete_offer_conflict_reason() returns trigger
language plpgsql security definer set search_path='' as $function$
begin
  delete from app_private.offer_booking_conflicts where offer_id=old.id;
  return old;
end $function$;
revoke all on function app_private.delete_offer_conflict_reason() from public,anon,authenticated,service_role;
create trigger t466_delete_offer_conflict_reason after delete on public.groomer_offers
for each row execute function app_private.delete_offer_conflict_reason();

create function app_private.record_offer_booking_conflicts() returns trigger
language plpgsql security definer set search_path='' as $function$
begin
  if new.status <> 'confirmed' then return new; end if;
  insert into app_private.offer_booking_conflicts(offer_id,booking_id)
    select o.id,new.id from public.groomer_offers o
    where o.groomer_id=new.groomer_id and o.id<>new.offer_id and o.status='pending'
      and tstzrange(o.proposed_start,o.proposed_end,'[)') && tstzrange(new.scheduled_start,new.scheduled_end,'[)')
    on conflict(offer_id) do nothing;
  return new;
end $function$;
revoke all on function app_private.record_offer_booking_conflicts() from public,anon,authenticated,service_role;
create trigger t466_record_offer_booking_conflicts after insert or update of scheduled_start,scheduled_end,status
on public.bookings for each row execute function app_private.record_offer_booking_conflicts();

create function app_private.close_conflicting_offers(p_request uuid,p_groomer uuid) returns void
language plpgsql security definer set search_path='' as $function$
begin
  -- All callers lock this request before entering. No groomer lock is taken here.
  update public.groomer_offers o set status='expired',terms_invalid_reason='time_slot_booked'
    where o.request_id=p_request and o.groomer_id=p_groomer and o.status='pending'
      and exists(select 1 from app_private.offer_booking_conflicts c where c.offer_id=o.id);
  update public.request_matches m set status='viewed'
    where m.request_id=p_request and m.groomer_id=p_groomer and m.status='offered'
      and exists(select 1 from public.groomer_offers o join app_private.offer_booking_conflicts c on c.offer_id=o.id
        where o.request_id=p_request and o.groomer_id=p_groomer)
      and not exists(select 1 from public.groomer_offers o where o.request_id=p_request and o.groomer_id=p_groomer and o.status='pending')
      and exists(select 1 from public.grooming_requests r where r.id=p_request and r.status in ('open','has_offers') and r.expires_at>statement_timestamp());
end $function$;
revoke all on function app_private.close_conflicting_offers(uuid,uuid) from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION app_private.evaluate_quote(p_offer_id uuid, p_now timestamp with time zone, p_valid_zones text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.groomer_offers%rowtype; r public.grooming_requests%rowtype;
  reason text; constraints jsonb; earliest timestamptz; notice integer; zone text;
  zone_count integer; window_count integer; required text[];
begin
  select * into o from public.groomer_offers where id=p_offer_id;
  if not found then return jsonb_build_object('terms_valid',false,'selectable',false,'reason','not_found'); end if;
  select * into strict r from public.grooming_requests where id=o.request_id;
  if exists(select 1 from app_private.offer_booking_conflicts c where c.offer_id=o.id) then reason:='time_slot_booked';
  elsif o.terms_invalid_reason is not null then reason:=o.terms_invalid_reason;
  elsif o.status='withdrawn_by_groomer' then reason:='withdrawn';
  elsif o.status='expired' or least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')<=p_now then reason:='expired';
  elsif o.status<>'pending' or r.status not in ('open','has_offers') then reason:='superseded';
  elsif o.agreement_snapshot is null then reason:='legacy_unverified';
  elsif o.applied_timing_buffers is distinct from '{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}'::jsonb
    or o.occupied_start is distinct from o.proposed_start or o.occupied_end is distinct from o.proposed_end
    then reason:='legacy_unverified'; -- Keep frozen quote facts; the existing replace-offer flow supplies new terms.

  elsif o.agreement_snapshot->>'request_revision' is distinct from r.terms_revision::text then reason:='superseded';
  elsif o.agreement_snapshot->>'groomer_eligibility_revision' is distinct from
    (select eligibility_revision::text from public.groomer_profiles where user_id=o.groomer_id)
    or o.agreement_snapshot->>'service_eligibility_revision' is distinct from
    (select eligibility_revision::text from app_private.offer_service_configuration(r.id,o.groomer_id,
      (o.agreement_snapshot->>'service_eligibility_revision')::uuid))
    or (o.agreement_snapshot->'address'->>'source_updated_at')::timestamptz is distinct from
    (select updated_at from app_private.address_locations where id=(o.agreement_snapshot->'address'->>'source_location_id')::uuid)
    then reason:='eligibility_revoked';
  else
    constraints:=app_private.evaluate_match_constraints(r.id,o.groomer_id,p_now);
    if constraints->>'state'='excluded' then reason:='eligibility_revoked'; end if;
  end if;
  if reason is null then
    select app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes)
      into required from app_private.offer_service_configuration(r.id,o.groomer_id,
        (o.agreement_snapshot->>'service_eligibility_revision')::uuid) s;
    if required is null or 'service_species_configuration'=any(required)
      or not (o.assessment_confirmations @> required and o.assessment_confirmations <@ ARRAY['pet_size','custom_service','pet_coat','pet_matting']::text[]) then
      reason:='assessment_confirmation_required';
    end if;
  end if;
  if reason is not null then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason',reason);
  end if;
  select coalesce((select minimum_advance_notice_days from public.groomer_booking_preferences
    where groomer_id=o.groomer_id),0) into notice;
  select min(timezone),count(distinct timezone),count(*) into zone,zone_count,window_count
    from public.groomer_availability_windows where groomer_id=o.groomer_id;
  if zone_count<>1 or window_count<>7 or not coalesce(zone=any(p_valid_zones),false) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  earliest:=app_private.service_timing_earliest_start_validated(p_now,notice,zone);
  if o.proposed_start<earliest then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason','expired');
  end if;
  if not app_private.groomer_can_admit_service(o.groomer_id,o.proposed_start,o.proposed_end,p_now,p_valid_zones)
    or exists(select 1 from public.bookings b where b.pet_id=r.pet_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(b.scheduled_start,app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at),'[)') && tstzrange(o.proposed_start,o.proposed_end,'[)'))
    or exists(select 1 from public.bookings b where b.groomer_id=o.groomer_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(b.scheduled_start,app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)')
        && tstzrange(o.occupied_start,o.occupied_end,'[)'))
    or app_private.occupied_time_off_conflict(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones)
    or not app_private.occupied_weekly_hours_covered(o.groomer_id,o.occupied_start,o.occupied_end,p_valid_zones) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  return jsonb_build_object('terms_valid',true,'selectable',true,'reason','available');
end $function$
;
CREATE OR REPLACE FUNCTION app_private.create_groomer_offer(p_request_id uuid, p_proposed_start timestamp with time zone, p_proposed_end timestamp with time zone, p_price_estimate numeric, p_message text, p_assessment_confirmations text[])
 RETURNS TABLE(offer_id uuid, offer_status text, request_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_message text := nullif(
    regexp_replace(coalesce(p_message, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g'),
    ''
  );
  v_match_id uuid;
  v_match_status text;
  v_customer_id uuid;
  v_request_status text;
  v_request_expires_at timestamptz;
  v_offer_id uuid;
  v_offer_status text;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  perform 1
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile
    on profile.id = groomer_profile.user_id
  where groomer_profile.user_id = v_user_id
    and profile.role = 'groomer'::public.user_role;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_profile_required';
  end if;

  if p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_request';
  end if;

  if p_proposed_start is null
    or p_proposed_end is null
    or p_proposed_start <= statement_timestamp()
    or p_proposed_end <= p_proposed_start
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_proposed_range';
  end if;

  if p_price_estimate is null
    or p_price_estimate < 0
    or p_price_estimate > 9999.99
    or p_price_estimate <> round(p_price_estimate, 2)
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_price_estimate';
  end if;

  if v_message is not null
    and char_length(v_message) > 200
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_message';
  end if;

  perform 1 from public.grooming_requests as parent_request
  where parent_request.id = p_request_id and exists (
      select 1 from public.request_matches m
      where m.request_id=parent_request.id and m.groomer_id=v_user_id
    )
  for update of parent_request;
  if not found then
    raise exception using errcode='P0001', message='match_not_found';
  end if;

  perform app_private.close_conflicting_offers(p_request_id,v_user_id);

  select
    request_match.id,
    request_match.status,
    request_match.customer_id,
    grooming_request.status,
    grooming_request.expires_at
  into
    v_match_id,
    v_match_status,
    v_customer_id,
    v_request_status,
    v_request_expires_at
  from public.request_matches as request_match
  join public.grooming_requests as grooming_request
    on grooming_request.id = request_match.request_id
   and grooming_request.customer_id = request_match.customer_id
  where request_match.request_id = p_request_id
    and request_match.groomer_id = v_user_id
  for update of request_match, grooming_request;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_found';
  end if;

  if v_match_status not in ('visible', 'viewed') then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_offerable';
  end if;

  if v_request_status not in ('open', 'has_offers')
    or v_request_expires_at <= statement_timestamp()
  then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_open';
  end if;

  if exists (
    select 1
    from public.groomer_offers as existing_offer
    where existing_offer.request_id = p_request_id
      and existing_offer.groomer_id = v_user_id
      and existing_offer.status = 'pending'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'active_offer_exists';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 71071)
  );

  if not app_private.groomer_can_admit_service(
    v_user_id,
    p_proposed_start,
    p_proposed_end
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_unavailable';
  end if;

  insert into public.groomer_offers (
    request_id,
    match_id,
    customer_id,
    groomer_id,
    proposed_start,
    proposed_end,
    price_estimate,
    message,
    status,
    expires_at,
    assessment_confirmations
  )
  values (
    p_request_id,
    v_match_id,
    v_customer_id,
    v_user_id,
    p_proposed_start,
    p_proposed_end,
    p_price_estimate,
    v_message,
    'pending',
    v_request_expires_at,
    p_assessment_confirmations
  )
  returning id, status
  into v_offer_id, v_offer_status;

  update public.request_matches as request_match
  set
    status = 'offered',
    viewed_at = coalesce(request_match.viewed_at, statement_timestamp())
  where request_match.id = v_match_id;

  update public.grooming_requests as grooming_request
  set status = 'has_offers'
  where grooming_request.id = p_request_id
    and grooming_request.status = 'open'
  returning grooming_request.status
  into v_request_status;

  if v_request_status is null then
    v_request_status := 'has_offers';
  end if;

  return query
  select v_offer_id, v_offer_status, v_request_status;
end;
$function$
;
CREATE OR REPLACE FUNCTION app_private.refresh_candidate_evaluation(p_request uuid, p_groomer uuid, p_now timestamp with time zone, p_source bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.grooming_requests%rowtype; result jsonb; future_result jsonb; witness jsonb;
  proof_clock timestamptz; deadline timestamptz; due timestamptz; zone text; notice integer;
begin
  if p_now is null or not isfinite(p_now) then raise exception using errcode='22023',message='invalid_clock'; end if;
  select * into r from public.grooming_requests where id=p_request for update;
  if not found then return; end if;
  perform app_private.close_conflicting_offers(p_request,p_groomer);
  if r.status not in ('open','has_offers') or r.expires_at<=p_now
    or not app_private.request_distribution_allows_new_quote(p_request,p_groomer,p_now)
    or not exists(select 1 from public.groomer_profiles where user_id=p_groomer)
    or exists(select 1 from public.request_matches where request_id=p_request and groomer_id=p_groomer and status='dismissed') then
    update public.request_matches set status='hidden' where request_id=p_request and groomer_id=p_groomer and status in ('visible','viewed');
    delete from app_private.match_candidate_evaluations where request_id=p_request and groomer_id=p_groomer;
    return;
  end if;
  result:=app_private.evaluate_match_eligibility(p_request,p_groomer,p_now);
  deadline:=least(r.expires_at,p_now+interval '60 seconds');
  due:=deadline;
  if result->>'state' in ('estimated_fit','assessment_required')
    and result ?& array['service_start','service_end','occupied_start','occupied_end'] then
    proof_clock:=least(p_now+interval '15 minutes',r.expires_at-interval '1 microsecond');
    if proof_clock>p_now then
      future_result:=app_private.evaluate_match_eligibility(p_request,p_groomer,proof_clock);
      if future_result->>'state'=result->>'state'
        and future_result ?& array['service_start','service_end','occupied_start','occupied_end'] then
        result:=future_result;
      end if;
    end if;
    select min(timezone) into zone from public.groomer_availability_windows where groomer_id=p_groomer;
    select minimum_advance_notice_days into notice from public.groomer_booking_preferences where groomer_id=p_groomer;
    deadline:=least(r.expires_at,(result->>'service_start')::timestamptz-interval '5 minutes');
    if notice>0 then deadline:=least(deadline,timezone(zone,(timezone(zone,p_now)::date+1)::timestamp)); end if;
    due:=deadline;
    witness:=jsonb_build_object('service_start',result->'service_start','service_end',result->'service_end',
      'occupied_start',result->'occupied_start','occupied_end',result->'occupied_end','kind',case when result->>'state'='assessment_required' then 'optimistic_source_interval'
        else 'fixed_source_interval' end);
  elsif result->>'state'='excluded' and result->>'reason' in (
    'no_continuous_opening','pet_species_excluded','pet_size_excluded','location_excluded',
    'service_unavailable','groomer_unavailable','request_species_confirmation_required',
    'schedule_confirmation_required','service_timezone_confirmation_required','request_unavailable') then
    deadline:=r.expires_at; due:=null;
    witness:=jsonb_build_object('kind','monotone_or_source_only_exclusion','reason',result->>'reason');
  end if;
  result:=result||jsonb_build_object('evaluated_at',p_now,'valid_until',deadline,'source_revision',p_source::text);
  insert into app_private.match_candidate_evaluations(request_id,groomer_id,result,witness,source_revision,evaluated_at,valid_until,next_evaluation_at)
    values(p_request,p_groomer,result,witness,p_source,p_now,deadline,due)
    on conflict(request_id,groomer_id) do update set result=excluded.result,witness=excluded.witness,
      source_revision=greatest(app_private.match_candidate_evaluations.source_revision,excluded.source_revision),
      evaluated_at=excluded.evaluated_at,valid_until=excluded.valid_until,next_evaluation_at=excluded.next_evaluation_at,
      ranking_revision=gen_random_uuid();
  if result->>'state'='excluded' then
    update public.request_matches set status=case when status in ('visible','viewed') then 'hidden' else status end,
      eligibility_evaluation=result where request_id=p_request and groomer_id=p_groomer and status in ('visible','viewed','offered','hidden');
  else
    insert into public.request_matches(request_id,groomer_id,customer_id,status,eligibility_evaluation)
      values(p_request,p_groomer,r.customer_id,'visible',result)
      on conflict on constraint request_matches_request_groomer_key do update set
        eligibility_evaluation=excluded.eligibility_evaluation,
        status=case when public.request_matches.status='hidden' then 'visible' else public.request_matches.status end
      where public.request_matches.status in ('visible','viewed','offered')
        or (public.request_matches.status='hidden' and public.request_matches.eligibility_evaluation->>'state'='excluded');
  end if;
end $function$;

CREATE OR REPLACE FUNCTION app_private.accept_groomer_offer(p_offer_id uuid)
 RETURNS TABLE(booking_id uuid, conversation_id uuid, request_id uuid, offer_id uuid, booking_status text, offer_status text, request_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_offer public.groomer_offers%rowtype;
  v_request public.grooming_requests%rowtype;
  v_match_status text;
  v_offer_status text;
  v_booking_id uuid;
  v_conversation_id uuid;
  v_event_created_at timestamptz;
begin
  if v_user_id is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean, false) then
    raise exception using errcode = '28000', message = 'authenticated_user_required';
  end if;
  if not exists (
    select 1 from public.customer_profiles cp join public.profiles p on p.id=cp.user_id
    where cp.user_id=v_user_id and p.role='customer'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'customer_profile_required';
  end if;
  if p_offer_id is null then
    raise exception using errcode = '22023', message = 'invalid_offer';
  end if;

  -- Lock the shared request first: competing offers must not each hold an
  -- offer lock while waiting for the other's request/decline work.
  select grooming_request.* into v_request
  from public.grooming_requests as grooming_request
  join public.groomer_offers as groomer_offer on groomer_offer.request_id=grooming_request.id
  where groomer_offer.id=p_offer_id and groomer_offer.customer_id = v_user_id
    and grooming_request.customer_id=v_user_id
  for update of grooming_request;
  if not found then
    raise exception using errcode = 'P0001', message = 'offer_not_found';
  end if;
  select * into v_offer from public.groomer_offers
  where id=p_offer_id and customer_id=v_user_id for update;
  v_offer_status := v_offer.status;

  if v_offer_status = 'accepted_by_customer' then
    return query
    select existing_booking.id, conversation.id, existing_booking.request_id,
      existing_booking.offer_id, existing_booking.status, v_offer.status, v_request.status
    from public.bookings as existing_booking
    join public.conversations as conversation
      on conversation.customer_id=existing_booking.customer_id
      and conversation.groomer_id=existing_booking.groomer_id
    where existing_booking.offer_id=p_offer_id and existing_booking.customer_id=v_user_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'acceptance_receipt_missing';
    end if;
    return;
  end if;
  if v_offer_status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'offer_not_pending';
  end if;
  if v_offer.expires_at <= statement_timestamp() then
    raise exception using errcode = 'P0001', message = 'offer_expired';
  end if;
  select match.status into v_match_status from public.request_matches as match
  where match.id=v_offer.match_id and match.request_id=v_request.id
    and match.customer_id=v_user_id and match.groomer_id=v_offer.groomer_id for update;
  if v_match_status is distinct from 'offered' then
    raise exception using errcode = 'P0001', message = 'match_not_offerable';
  end if;
  if v_request.status not in ('open','has_offers') or v_request.expires_at <= statement_timestamp() then
    raise exception using errcode = 'P0001', message = 'request_not_open';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_offer.groomer_id::text,71071));
  if exists(select 1 from app_private.offer_booking_conflicts conflict where conflict.offer_id=p_offer_id) then
    raise exception using errcode='P0001',message='offer_expired';
  end if;

  -- The trigger serializes every admission writer with availability Save;
  -- database exclusions enforce both groomer and pet occupancy.
  begin
    insert into public.bookings(request_id,offer_id,customer_id,groomer_id,
      scheduled_start,scheduled_end,price_estimate,status)
    values(v_request.id,v_offer.id,v_user_id,v_offer.groomer_id,
      v_offer.proposed_start,v_offer.proposed_end,v_offer.price_estimate,'confirmed')
    returning id into v_booking_id;
  exception
    when unique_violation then
      raise exception using errcode = 'P0001', message = 'booking_already_exists';
    when exclusion_violation then
      raise exception using errcode = 'P0001', message = 'booking_conflict';
  end;

  insert into public.conversations(customer_id,groomer_id)
  values(v_user_id,v_offer.groomer_id)
  on conflict(customer_id,groomer_id) do update
    set updated_at=greatest(public.conversations.updated_at,excluded.updated_at)
  returning id into v_conversation_id;
  update public.groomer_offers set status='accepted_by_customer' where id=v_offer.id;
  update public.groomer_offers set status='declined_by_customer'
    where groomer_offers.request_id=v_request.id and id<>v_offer.id and status='pending';
  update public.request_matches set status='hidden'
    where request_matches.request_id=v_request.id and status in ('visible','viewed','offered');
  update public.grooming_requests set status='booked' where id=v_request.id;
  v_event_created_at := clock_timestamp();
  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at,booking_event)
    values(v_conversation_id,v_user_id,'booking_card',v_booking_id,v_event_created_at,app_private.booking_chat_event(v_booking_id,'confirmed',v_user_id));
  return query select v_booking_id,v_conversation_id,v_request.id,v_offer.id,
    'confirmed'::text,'accepted_by_customer'::text,'booked'::text;
end;
$function$
;
commit;
