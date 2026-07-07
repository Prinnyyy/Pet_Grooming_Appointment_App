create or replace function app_private.accept_groomer_offer(
  p_offer_id uuid
)
returns table (
  booking_id uuid,
  conversation_id uuid,
  request_id uuid,
  offer_id uuid,
  booking_status text,
  offer_status text,
  request_status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_offer_id uuid;
  v_request_id uuid;
  v_customer_id uuid;
  v_groomer_id uuid;
  v_scheduled_start timestamptz;
  v_scheduled_end timestamptz;
  v_price_estimate numeric(10, 2);
  v_offer_status text;
  v_offer_expires_at timestamptz;
  v_match_status text;
  v_request_status text;
  v_request_expires_at timestamptz;
  v_booking_id uuid;
  v_conversation_id uuid;
  v_booking_status text;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  perform 1
  from public.customer_profiles as customer_profile
  join public.profiles as profile
    on profile.id = customer_profile.user_id
  where customer_profile.user_id = v_user_id
    and profile.role = 'customer'::public.user_role;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'customer_profile_required';
  end if;

  if p_offer_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_offer';
  end if;

  select
    groomer_offer.id,
    groomer_offer.request_id,
    groomer_offer.customer_id,
    groomer_offer.groomer_id,
    groomer_offer.proposed_start,
    groomer_offer.proposed_end,
    groomer_offer.price_estimate,
    groomer_offer.status,
    groomer_offer.expires_at,
    request_match.status,
    grooming_request.status,
    grooming_request.expires_at
  into
    v_offer_id,
    v_request_id,
    v_customer_id,
    v_groomer_id,
    v_scheduled_start,
    v_scheduled_end,
    v_price_estimate,
    v_offer_status,
    v_offer_expires_at,
    v_match_status,
    v_request_status,
    v_request_expires_at
  from public.groomer_offers as groomer_offer
  join public.grooming_requests as grooming_request
    on grooming_request.id = groomer_offer.request_id
   and grooming_request.customer_id = groomer_offer.customer_id
  join public.request_matches as request_match
    on request_match.id = groomer_offer.match_id
   and request_match.request_id = groomer_offer.request_id
   and request_match.customer_id = groomer_offer.customer_id
   and request_match.groomer_id = groomer_offer.groomer_id
  where groomer_offer.id = p_offer_id
    and groomer_offer.customer_id = v_user_id
  for update of groomer_offer, grooming_request, request_match;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'offer_not_found';
  end if;

  if v_offer_status <> 'pending' then
    raise exception using
      errcode = 'P0001',
      message = 'offer_not_pending';
  end if;

  if v_offer_expires_at <= statement_timestamp() then
    raise exception using
      errcode = 'P0001',
      message = 'offer_expired';
  end if;

  if v_match_status <> 'offered' then
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
    from public.bookings as existing_booking
    where existing_booking.request_id = v_request_id
       or existing_booking.offer_id = v_offer_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'booking_already_exists';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_groomer_id::text, 71071)
  );

  if not app_private.groomer_is_available_for_range(
    v_groomer_id,
    v_scheduled_start,
    v_scheduled_end
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'booking_conflict';
  end if;

  perform 1
  from public.bookings as existing_booking
  where existing_booking.groomer_id = v_groomer_id
    and existing_booking.status = 'confirmed'
    and existing_booking.scheduled_start < v_scheduled_end
    and v_scheduled_start < existing_booking.scheduled_end
  for update;

  if found then
    raise exception using
      errcode = 'P0001',
      message = 'booking_conflict';
  end if;

  begin
    insert into public.bookings (
      request_id,
      offer_id,
      customer_id,
      groomer_id,
      scheduled_start,
      scheduled_end,
      price_estimate,
      status
    )
    values (
      v_request_id,
      v_offer_id,
      v_customer_id,
      v_groomer_id,
      v_scheduled_start,
      v_scheduled_end,
      v_price_estimate,
      'confirmed'
    )
    returning id, status
    into v_booking_id, v_booking_status;
  exception
    when unique_violation then
      raise exception using
        errcode = 'P0001',
        message = 'booking_already_exists';
    when exclusion_violation then
      raise exception using
        errcode = 'P0001',
        message = 'booking_conflict';
  end;

  insert into public.conversations (
    booking_id,
    request_id,
    customer_id,
    groomer_id
  )
  values (
    v_booking_id,
    v_request_id,
    v_customer_id,
    v_groomer_id
  )
  returning id
  into v_conversation_id;

  update public.groomer_offers as accepted_offer
  set status = 'accepted_by_customer'
  where accepted_offer.id = v_offer_id
  returning accepted_offer.status
  into v_offer_status;

  update public.groomer_offers as competing_offer
  set status = 'declined_by_customer'
  where competing_offer.request_id = v_request_id
    and competing_offer.id <> v_offer_id
    and competing_offer.status = 'pending';

  update public.request_matches as request_match
  set status = 'hidden'
  where request_match.request_id = v_request_id
    and request_match.status in ('visible', 'viewed', 'offered');

  update public.grooming_requests as grooming_request
  set status = 'booked'
  where grooming_request.id = v_request_id
  returning grooming_request.status
  into v_request_status;

  return query
  select
    v_booking_id,
    v_conversation_id,
    v_request_id,
    v_offer_id,
    v_booking_status,
    v_offer_status,
    v_request_status;
end;
$$;

comment on function app_private.accept_groomer_offer(uuid) is
  'Privileged helper for accepting a groomer offer; public API is the security-invoker wrapper.';

revoke all on function app_private.accept_groomer_offer(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.accept_groomer_offer(uuid) to authenticated;

create or replace function app_private.complete_booking(
  p_booking_id uuid
)
returns table (
  booking_id uuid,
  booking_status text,
  completed_timestamp timestamptz,
  completed_by uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_booking_id uuid;
  v_booking_status text;
  v_completed_at timestamptz;
  v_completed_by uuid;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_booking_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_booking';
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

  select
    booking.id,
    booking.status,
    booking.completed_at,
    booking.completed_by
  into
    v_booking_id,
    v_booking_status,
    v_completed_at,
    v_completed_by
  from public.bookings as booking
  where booking.id = p_booking_id
    and booking.groomer_id = v_user_id
  for update of booking;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_found';
  end if;

  if v_booking_status = 'completed' then
    return query
    select v_booking_id, v_booking_status, v_completed_at, v_completed_by;
    return;
  end if;

  if v_booking_status <> 'confirmed' then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_completable';
  end if;

  update public.bookings as booking
  set
    status = 'completed',
    completed_at = statement_timestamp(),
    completed_by = v_user_id
  where booking.id = v_booking_id
  returning
    booking.status,
    booking.completed_at,
    booking.completed_by
  into
    v_booking_status,
    v_completed_at,
    v_completed_by;

  return query
  select v_booking_id, v_booking_status, v_completed_at, v_completed_by;
end;
$$;

comment on function app_private.complete_booking(uuid) is
  'Privileged helper for groomer booking completion; public API is the security-invoker wrapper.';

revoke all on function app_private.complete_booking(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.complete_booking(uuid) to authenticated;
