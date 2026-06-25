-- T-071 groomer availability enforcement.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create or replace function app_private.groomer_is_available_for_range(
  p_groomer_id uuid,
  p_scheduled_start timestamptz,
  p_scheduled_end timestamptz
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  with matching_window as (
    select
      availability_window.timezone,
      timezone(availability_window.timezone, p_scheduled_start) as local_start,
      timezone(availability_window.timezone, p_scheduled_end) as local_end,
      availability_window.start_time,
      availability_window.end_time
    from public.groomer_availability_windows as availability_window
    join pg_catalog.pg_timezone_names as timezone_name
      on timezone_name.name = availability_window.timezone
    where p_groomer_id is not null
      and p_scheduled_start is not null
      and p_scheduled_end is not null
      and p_scheduled_start > statement_timestamp()
      and p_scheduled_end > p_scheduled_start
      and availability_window.groomer_id = p_groomer_id
      and availability_window.is_enabled
      and availability_window.weekday =
        extract(isodow from timezone(availability_window.timezone, p_scheduled_start))::smallint
  ),
  feasible_window as (
    select
      matching_window.timezone,
      matching_window.local_start::date as local_date
    from matching_window
    where matching_window.local_start::date = matching_window.local_end::date
      and matching_window.local_start::time >= matching_window.start_time
      and matching_window.local_end::time <= matching_window.end_time
  ),
  booking_preferences as (
    select
      coalesce(preferences.max_appointments_per_day, 4) as max_appointments_per_day,
      coalesce(preferences.minimum_advance_notice_days, 0) as minimum_advance_notice_days
    from public.groomer_profiles as groomer_profile
    left join public.groomer_booking_preferences as preferences
      on preferences.groomer_id = groomer_profile.user_id
    where groomer_profile.user_id = p_groomer_id
  )
  select coalesce(
    (
      select true
      from feasible_window
      cross join booking_preferences
      where feasible_window.local_date >=
        (
          timezone(feasible_window.timezone, statement_timestamp())::date
          + booking_preferences.minimum_advance_notice_days
        )
        and not exists (
          select 1
          from public.groomer_time_off_windows as time_off
          where time_off.groomer_id = p_groomer_id
            and feasible_window.local_date between time_off.start_date and time_off.end_date
        )
        and not exists (
          select 1
          from public.bookings as existing_booking
          where existing_booking.groomer_id = p_groomer_id
            and existing_booking.status in ('confirmed', 'completed')
            and existing_booking.scheduled_start < p_scheduled_end
            and p_scheduled_start < existing_booking.scheduled_end
        )
        and (
          select count(*)::integer
          from public.bookings as daily_booking
          where daily_booking.groomer_id = p_groomer_id
            and daily_booking.status in ('confirmed', 'completed')
            and timezone(feasible_window.timezone, daily_booking.scheduled_start)::date =
              feasible_window.local_date
        ) < booking_preferences.max_appointments_per_day
      limit 1
    ),
    false
  );
$$;

comment on function app_private.groomer_is_available_for_range(uuid, timestamptz, timestamptz) is
  'Checks whether a proposed booking range fits enabled weekly availability, time off, booking preferences, and existing bookings for one groomer.';

revoke all on function app_private.groomer_is_available_for_range(uuid, timestamptz, timestamptz)
from public, anon, authenticated;

grant execute on function app_private.groomer_is_available_for_range(uuid, timestamptz, timestamptz)
to service_role;

create or replace function public.create_groomer_offer(
  p_request_id uuid,
  p_proposed_start timestamptz,
  p_proposed_end timestamptz,
  p_price_estimate numeric,
  p_message text default null
)
returns table (
  offer_id uuid,
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
$$;

comment on function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text) is
  'Creates one pending offer for the calling groomer on an eligible matched request when the proposed range fits groomer availability.';

revoke all on function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text)
from public, anon, authenticated;

grant execute on function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text)
to authenticated, service_role;

create or replace function public.accept_groomer_offer(
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
  v_match_id uuid;
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
    groomer_offer.match_id,
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
    v_match_id,
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

comment on function public.accept_groomer_offer(uuid) is
  'Accepts one pending groomer offer for the calling customer and atomically creates a booking and conversation after rechecking groomer availability.';

revoke all on function public.accept_groomer_offer(uuid)
from public, anon, authenticated;

grant execute on function public.accept_groomer_offer(uuid)
to authenticated, service_role;
