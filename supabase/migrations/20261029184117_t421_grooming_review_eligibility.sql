-- T-421: the customer journey can finish by time without asserting verified service completion.
-- Fourteen days is a UI retention rule, not a review expiry. Never change fulfillment here.
create function app_private.grooming_finished_at(b public.bookings)
returns timestamptz language plpgsql stable set search_path = '' as $$
declare zone text; day_end timestamptz;
begin
  if b.status='completed' then
    return coalesce(b.completed_at,b.actual_ended_at,b.scheduled_end);
  end if;
  if b.status<>'confirmed' or b.fulfillment_phase='outcome_reported'
    or b.scheduled_start is null or b.scheduled_end is null
    or not isfinite(b.scheduled_start) or not isfinite(b.scheduled_end)
    or b.scheduled_end<=b.scheduled_start then return null; end if;
  zone:=coalesce(b.agreement_snapshot->>'service_time_zone_identifier',b.service_time_zone_identifier);
  if zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=zone) then return null; end if;
  day_end:=(((b.scheduled_start at time zone zone)::date+1)::timestamp at time zone zone);
  return greatest(day_end,b.scheduled_end);
end $$;
revoke all on function app_private.grooming_finished_at(public.bookings) from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION app_private.freeze_booking_review_context(p_booking uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare b public.bookings%rowtype; snapshot jsonb; service text; service_at timestamptz; source text;
begin
  select * into b from public.bookings where id=p_booking;
  if not found or app_private.grooming_finished_at(b) is null
    or app_private.grooming_finished_at(b)>statement_timestamp() then return; end if;
  if exists(select 1 from public.account_deletion_requests where user_id in (b.customer_id,b.groomer_id) and anonymized_at is not null) then
    insert into app_private.booking_review_contexts(booking_id,allowed_keys,source_state)
      values(b.id,'[]','privacy_withheld') on conflict(booking_id) do nothing;
    return;
  end if;
  if exists(select 1 from app_private.booking_review_contexts where booking_id=p_booking) then return; end if;
  -- An elapsed appointment can receive ordinary feedback but proves no service/trait evidence.
  -- The frozen context remains conservative even if completion is recorded later.
  if b.status<>'completed' then
    insert into app_private.booking_review_contexts(booking_id,allowed_keys,source_state)
      values(b.id,'[]','elapsed_unverified') on conflict(booking_id) do nothing;
    return;
  end if;
  if b.agreement_snapshot is not null then
    snapshot:=b.agreement_snapshot->'pet_snapshot'; service:=b.agreement_snapshot->>'service_type';
    source:='booking_agreement';
  else
    select pet_snapshot,service_type into snapshot,service from public.grooming_requests where id=b.request_id;
    source:='legacy_request_snapshot';
  end if;
  -- scheduled_start incorporates accepted rescheduling, never late completion/review time.
  service_at:=case when isfinite(b.scheduled_start) then b.scheduled_start end;
  insert into app_private.booking_review_contexts(booking_id,service_at,service_time_zone_identifier,
    species,service_type,allowed_keys,source_state)
  values(b.id,service_at,b.service_time_zone_identifier,lower(snapshot->>'species'),service,
    app_private.review_allowed_keys(snapshot,service,service_at,b.service_time_zone_identifier),source)
  on conflict (booking_id) do nothing;
end $function$;

CREATE OR REPLACE FUNCTION app_private.get_booking_review_context(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype; result jsonb;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  select * into b from public.bookings where id=p_booking_id and customer_id=actor for update;
  if not exists(select 1 from public.profiles where id=actor and role='customer')
    or exists(select 1 from public.account_deletion_requests where user_id=actor and anonymized_at is not null) then
    raise exception using errcode='42501',message='customer_profile_required';
  end if;
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  if app_private.grooming_finished_at(b) is null or app_private.grooming_finished_at(b)>statement_timestamp() then
    raise exception using errcode='P0001',message='booking_not_completed'; end if;
  if exists(select 1 from public.reviews where booking_id=b.id) then
    raise exception using errcode='P0001',message='review_already_exists';
  end if;
  perform app_private.freeze_booking_review_context(b.id);
  select jsonb_build_object('booking_id',booking_id,'context_revision',context_revision,
    'evidence_context_version',evidence_context_version,'service_at',service_at,'allowed_keys',allowed_keys)
    into result from app_private.booking_review_contexts where booking_id=b.id;
  return result;
end $function$;

CREATE OR REPLACE FUNCTION app_private.write_verified_review(p_booking uuid, p_revision uuid, p_rating integer, p_content text, p_outcomes jsonb, p_legacy boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype; c app_private.booking_review_contexts%rowtype;
  r public.reviews%rowtype; body text:=nullif(btrim(p_content),''); item jsonb; key jsonb; seen jsonb:='[]';
  normalized jsonb:='[]'; avg numeric; n integer; total bigint;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if not exists(select 1 from public.profiles where id=actor and role='customer')
    or exists(select 1 from public.account_deletion_requests where user_id=actor and anonymized_at is not null) then
    raise exception using errcode='42501',message='customer_profile_required';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception using errcode='22023',message='invalid_rating';
  end if;
  if char_length(body)>2000 then raise exception using errcode='22023',message='invalid_review_content'; end if;
  if p_outcomes is null or jsonb_typeof(p_outcomes)<>'array' then
    raise exception using errcode='22023',message='invalid_review_outcomes';
  end if;
  select * into b from public.bookings where id=p_booking and customer_id=actor for update;
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  if app_private.grooming_finished_at(b) is null or app_private.grooming_finished_at(b)>statement_timestamp() then
    raise exception using errcode='P0001',message='booking_not_completed'; end if;
  perform app_private.freeze_booking_review_context(b.id);
  select * into strict c from app_private.booking_review_contexts where booking_id=b.id;
  if not p_legacy and p_revision is distinct from c.context_revision then
    raise exception using errcode='22023',message='review_context_changed';
  end if;
  if jsonb_array_length(p_outcomes)>least(20,jsonb_array_length(c.allowed_keys)) then
    raise exception using errcode='22023',message='invalid_pet_fit_context';
  end if;
  for item in select value from jsonb_array_elements(p_outcomes) loop
    if jsonb_typeof(item)<>'object' or item->>'outcome' is null or item->>'outcome' not in ('positive','negative') then
      raise exception using errcode='22023',message='invalid_review_outcome_value';
    end if;
    if p_legacy then key:=app_private.canonical_review_key(item->>'trait_type',item->>'trait_value',c.service_type);
    else key:=jsonb_build_object('dimension',item->>'trait_type','value',item->>'trait_value'); end if;
    if key is null or not c.allowed_keys @> jsonb_build_array(key) then
      raise exception using errcode='22023',message='invalid_pet_fit_context';
    end if;
    if seen @> jsonb_build_array(key) then
      raise exception using errcode='22023',message='duplicate_review_outcome';
    end if;
    seen:=seen||jsonb_build_array(key);
    normalized:=normalized||jsonb_build_array(key||jsonb_build_object('outcome',item->>'outcome'));
  end loop;
  begin
    insert into public.reviews(booking_id,customer_id,groomer_id,rating,content,evidence_context_revision,evidence_context_version)
      values(b.id,actor,b.groomer_id,p_rating,body,c.context_revision,c.evidence_context_version) returning * into r;
  exception when unique_violation then raise exception using errcode='P0001',message='review_already_exists'; end;
  -- Rating/FK writes may wait behind anonymization. Recheck after those locks, before outcomes.
  if exists(select 1 from public.account_deletion_requests where user_id=actor and anonymized_at is not null) then
    raise exception using errcode='42501',message='customer_profile_required';
  end if;
  if (select context_revision from app_private.booking_review_contexts where booking_id=b.id) is distinct from c.context_revision then
    raise exception using errcode='22023',message='review_context_changed';
  end if;
  insert into public.review_pet_fit_outcomes(review_id,booking_id,customer_id,groomer_id,trait_type,trait_value,outcome)
    select r.id,b.id,actor,b.groomer_id,value->>'dimension',value->>'value',value->>'outcome'
    from jsonb_array_elements(normalized);
  select rating_avg,rating_count,rating_sum into avg,n,total from public.groomer_profiles where user_id=b.groomer_id;
  return jsonb_build_object('review_id',r.id,'booking_id',r.booking_id,'customer_id',r.customer_id,
    'groomer_id',r.groomer_id,'rating',r.rating,'content',r.content,'created_at',r.created_at,
    'groomer_rating_avg',avg,'groomer_rating_count',n,'groomer_rating_sum',total,
    'context_revision',c.context_revision);
end $function$;

revoke all on function app_private.freeze_booking_review_context(uuid),
  app_private.write_verified_review(uuid,uuid,integer,text,jsonb,boolean),
  app_private.get_booking_review_context(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.get_booking_review_context(uuid) to authenticated;
