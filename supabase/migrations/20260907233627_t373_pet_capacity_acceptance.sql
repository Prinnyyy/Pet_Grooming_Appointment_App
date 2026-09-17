-- Never infer a pet identity from names or a mutable JSON snapshot.
do $$
begin
  if exists (select 1 from public.grooming_requests where pet_id is null) then
    raise exception 'legacy_pet_identity_unresolved';
  end if;
end;
$$;

alter table public.grooming_requests alter column pet_id set not null;
alter table public.grooming_requests
  add constraint grooming_requests_pet_identity_key unique (id, customer_id, pet_id);
alter table public.bookings add column pet_id uuid;
update public.bookings as booking
set pet_id = request.pet_id
from public.grooming_requests as request
where request.id = booking.request_id and request.customer_id = booking.customer_id;
alter table public.bookings alter column pet_id set not null;
alter table public.bookings
  add constraint bookings_request_pet_identity_fkey
  foreign key (request_id, customer_id, pet_id)
  references public.grooming_requests (id, customer_id, pet_id) on delete cascade;
alter table public.bookings
  add constraint bookings_no_pet_time_overlap
  exclude using gist (
    pet_id with =,
    tstzrange(scheduled_start, scheduled_end, '[)') with &&
  ) where (status in ('confirmed', 'completed'));

create function app_private.guard_booking_admission()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_pet_id uuid;
begin
  if tg_op = 'UPDATE' then
    if (new.request_id, new.offer_id, new.customer_id, new.groomer_id,
        new.pet_id, new.scheduled_start, new.scheduled_end)
      is distinct from
       (old.request_id, old.offer_id, old.customer_id, old.groomer_id,
        old.pet_id, old.scheduled_start, old.scheduled_end) then
      raise exception using errcode = 'P0001', message = 'booking_allocation_immutable';
    end if;
    -- Cancellation/completion preserve the original allocation and receipt.
    if new.status <> 'confirmed' or old.status = 'confirmed' then
      return new;
    end if;
    raise exception using errcode = 'P0001', message = 'booking_not_reactivatable';
  end if;

  select request.pet_id into v_pet_id
  from public.grooming_requests as request
  where request.id = new.request_id and request.customer_id = new.customer_id;
  if v_pet_id is null or (new.pet_id is not null and new.pet_id <> v_pet_id) then
    raise exception using errcode = 'P0001', message = 'booking_pet_identity_required';
  end if;
  new.pet_id := v_pet_id;
  if new.status <> 'confirmed' then
    raise exception using errcode = 'P0001', message = 'booking_must_start_confirmed';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.groomer_id::text, 71071)
  );
  if not app_private.groomer_is_available_for_range(
    new.groomer_id, new.scheduled_start, new.scheduled_end
  ) then
    raise exception using errcode = 'P0001', message = 'booking_conflict';
  end if;
  return new;
end;
$$;
revoke all on function app_private.guard_booking_admission()
from public, anon, authenticated, service_role;
create trigger bookings_guard_admission
before insert or update on public.bookings
for each row execute function app_private.guard_booking_admission();

create or replace function app_private.accept_groomer_offer(p_offer_id uuid)
returns table (
  booking_id uuid, conversation_id uuid, request_id uuid, offer_id uuid,
  booking_status text, offer_status text, request_status text
)
language plpgsql security definer set search_path = ''
as $$
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
  insert into public.messages(conversation_id,sender_id,body,kind,booking_id,created_at)
  values(v_conversation_id,v_user_id,null,'booking_card',v_booking_id,v_event_created_at),
    (v_conversation_id,v_user_id,
      'Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!',
      'text',null,v_event_created_at + interval '1 microsecond');
  return query select v_booking_id,v_conversation_id,v_request.id,v_offer.id,
    'confirmed'::text,'accepted_by_customer'::text,'booked'::text;
end;
$$;

comment on function app_private.accept_groomer_offer(uuid) is
  'Owned idempotent acceptance: one original booking/conversation receipt with current lifecycle state.';
revoke all on function app_private.accept_groomer_offer(uuid) from public, anon, authenticated, service_role;
grant execute on function app_private.accept_groomer_offer(uuid) to authenticated;

-- A lookup must never create a booking, including when the original request
-- did not reach the server. The client can then ask for an explicit retry.
create function app_private.get_offer_acceptance(p_offer_id uuid)
returns table (
  booking_id uuid, conversation_id uuid, request_id uuid, offer_id uuid,
  booking_status text, offer_status text, request_status text
)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_offer_status text;
  v_offer_expiry timestamptz;
  v_request_status text;
  v_request_expiry timestamptz;
begin
  if v_user_id is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000', message='authenticated_user_required';
  end if;
  perform 1 from public.grooming_requests r join public.groomer_offers o on o.request_id=r.id
  where o.id=p_offer_id and o.customer_id=v_user_id and r.customer_id=v_user_id
  for update of r;
  if not found then
    raise exception using errcode='P0001', message='offer_not_found';
  end if;
  select o.status,o.expires_at,r.status,r.expires_at
    into v_offer_status,v_offer_expiry,v_request_status,v_request_expiry
  from public.groomer_offers o join public.grooming_requests r on r.id=o.request_id
  where o.id=p_offer_id and o.customer_id=v_user_id;
  if v_offer_status <> 'accepted_by_customer' then
    if v_offer_status <> 'pending' or v_offer_expiry <= statement_timestamp() then
      raise exception using errcode='P0001', message='offer_not_pending';
    end if;
    if v_request_status not in ('open','has_offers') or v_request_expiry <= statement_timestamp() then
      raise exception using errcode='P0001', message='request_not_open';
    end if;
    return;
  end if;
  return query
  select b.id,c.id,b.request_id,b.offer_id,b.status,o.status,r.status
  from public.bookings b join public.groomer_offers o on o.id=b.offer_id
  join public.grooming_requests r on r.id=b.request_id
  join public.conversations c on c.customer_id=b.customer_id and c.groomer_id=b.groomer_id
  where b.offer_id=p_offer_id and b.customer_id=v_user_id;
  if not found then
    raise exception using errcode='P0001', message='acceptance_receipt_missing';
  end if;
end;
$$;
revoke all on function app_private.get_offer_acceptance(uuid) from public, anon, authenticated, service_role;
grant execute on function app_private.get_offer_acceptance(uuid) to authenticated;
create function public.get_offer_acceptance(p_offer_id uuid)
returns table (
  booking_id uuid, conversation_id uuid, request_id uuid, offer_id uuid,
  booking_status text, offer_status text, request_status text
)
language sql security invoker set search_path = ''
as $$ select * from app_private.get_offer_acceptance(p_offer_id); $$;
revoke all on function public.get_offer_acceptance(uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_offer_acceptance(uuid) to authenticated;
notify pgrst, 'reload schema';

-- Request-first serialization across the interacting offer/match writers.
CREATE OR REPLACE FUNCTION app_private.create_groomer_offer(p_request_id uuid, p_proposed_start timestamp with time zone, p_proposed_end timestamp with time zone, p_price_estimate numeric, p_message text DEFAULT NULL::text)
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
    or p_price_estimate > 100000
    or p_price_estimate <> round(p_price_estimate, 2)
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_price_estimate';
  end if;

  if v_message is not null
    and char_length(v_message) > 2000
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

  if not app_private.groomer_is_available_for_range(
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
    expires_at
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
    v_request_expires_at
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
$function$;

CREATE OR REPLACE FUNCTION app_private.dismiss_request_match(p_match_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS TABLE(match_id uuid, status text, dismissed_at timestamp with time zone)
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
  v_dismiss_reason text := nullif(btrim(p_reason), '');
  v_match_id uuid;
  v_match_status text;
  v_match_dismissed_at timestamptz;
  v_request_status text;
  v_request_expires_at timestamptz;
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

  if p_match_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_match';
  end if;

  if v_dismiss_reason is not null
    and char_length(v_dismiss_reason) > 500
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_dismiss_reason';
  end if;

  perform 1 from public.grooming_requests as parent_request
  where exists (
      select 1 from public.request_matches m
      where m.id=p_match_id and m.request_id=parent_request.id and m.groomer_id=v_user_id
    )
  for update of parent_request;
  if not found then
    raise exception using errcode='P0001', message='match_not_found';
  end if;

  select
    request_match.id,
    request_match.status,
    request_match.dismissed_at,
    request.status,
    request.expires_at
  into
    v_match_id,
    v_match_status,
    v_match_dismissed_at,
    v_request_status,
    v_request_expires_at
  from public.request_matches as request_match
  join public.grooming_requests as request
    on request.id = request_match.request_id
  where request_match.id = p_match_id
    and request_match.groomer_id = v_user_id
  for update of request_match;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_found';
  end if;

  if v_match_status = 'dismissed' then
    return query
    select v_match_id, v_match_status, v_match_dismissed_at;
    return;
  end if;

  if v_match_status not in ('visible', 'viewed') then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_dismissible';
  end if;

  if v_request_status not in ('open', 'has_offers')
    or v_request_expires_at <= statement_timestamp()
  then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_open';
  end if;

  return query
  update public.request_matches as request_match
  set
    status = 'dismissed',
    viewed_at = coalesce(request_match.viewed_at, statement_timestamp()),
    dismissed_at = statement_timestamp(),
    dismiss_reason = v_dismiss_reason
  where request_match.id = v_match_id
  returning
    request_match.id,
    request_match.status,
    request_match.dismissed_at;
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.withdraw_groomer_offer(p_offer_id uuid)
 RETURNS TABLE(offer_id uuid, offer_status text, withdrawn_timestamp timestamp with time zone, request_status text)
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
  v_offer_id uuid;
  v_offer_status text;
  v_withdrawn_at timestamptz;
  v_request_id uuid;
  v_match_id uuid;
  v_request_status text;
  v_request_expires_at timestamptz;
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

  if p_offer_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_offer';
  end if;

  perform 1 from public.grooming_requests as parent_request
  where exists (
      select 1 from public.groomer_offers o
      where o.id=p_offer_id and o.request_id=parent_request.id and o.groomer_id=v_user_id
    )
  for update of parent_request;
  if not found then
    raise exception using errcode='P0001', message='offer_not_found';
  end if;

  select
    groomer_offer.id,
    groomer_offer.status,
    groomer_offer.withdrawn_at,
    groomer_offer.request_id,
    groomer_offer.match_id,
    grooming_request.status,
    grooming_request.expires_at
  into
    v_offer_id,
    v_offer_status,
    v_withdrawn_at,
    v_request_id,
    v_match_id,
    v_request_status,
    v_request_expires_at
  from public.groomer_offers as groomer_offer
  join public.grooming_requests as grooming_request
    on grooming_request.id = groomer_offer.request_id
   and grooming_request.customer_id = groomer_offer.customer_id
  join public.request_matches as request_match
    on request_match.id = groomer_offer.match_id
  where groomer_offer.id = p_offer_id
    and groomer_offer.groomer_id = v_user_id
  for update of groomer_offer, grooming_request, request_match;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'offer_not_found';
  end if;

  if v_offer_status = 'withdrawn_by_groomer' then
    return query
    select v_offer_id, v_offer_status, v_withdrawn_at, v_request_status;
    return;
  end if;

  if v_offer_status <> 'pending' then
    raise exception using
      errcode = 'P0001',
      message = 'offer_not_withdrawable';
  end if;

  if v_request_status not in ('open', 'has_offers')
    or v_request_expires_at <= statement_timestamp()
  then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_open';
  end if;

  update public.groomer_offers as groomer_offer
  set
    status = 'withdrawn_by_groomer',
    withdrawn_at = statement_timestamp()
  where groomer_offer.id = v_offer_id
  returning groomer_offer.status, groomer_offer.withdrawn_at
  into v_offer_status, v_withdrawn_at;

  update public.request_matches as request_match
  set status = 'viewed'
  where request_match.id = v_match_id
    and request_match.status = 'offered';

  if not exists (
    select 1
    from public.groomer_offers as pending_offer
    where pending_offer.request_id = v_request_id
      and pending_offer.status = 'pending'
  ) then
    update public.grooming_requests as grooming_request
    set status = 'open'
    where grooming_request.id = v_request_id
      and grooming_request.status = 'has_offers'
    returning grooming_request.status
    into v_request_status;
  end if;

  return query
  select v_offer_id, v_offer_status, v_withdrawn_at, v_request_status;
end;
$function$;
