-- T-018 reviewed SQL draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

create extension if not exists btree_gist with schema extensions;

alter table public.groomer_offers
add constraint groomer_offers_identity_key
unique (id, request_id, customer_id, groomer_id);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  offer_id uuid not null,
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  scheduled_start timestamptz not null,
  scheduled_end timestamptz not null,
  price_estimate numeric(10, 2) not null,
  status text not null default 'confirmed',
  cancelled_by uuid,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_request_key unique (request_id),
  constraint bookings_offer_key unique (offer_id),
  constraint bookings_identity_key
    unique (id, request_id, customer_id, groomer_id),
  constraint bookings_request_customer_fkey
    foreign key (request_id, customer_id)
    references public.grooming_requests (id, customer_id)
    on delete cascade,
  constraint bookings_offer_identity_fkey
    foreign key (offer_id, request_id, customer_id, groomer_id)
    references public.groomer_offers (id, request_id, customer_id, groomer_id)
    on delete cascade,
  constraint bookings_scheduled_range_check check (
    scheduled_end > scheduled_start
  ),
  constraint bookings_price_estimate_check check (
    price_estimate >= 0
    and price_estimate <= 100000
    and price_estimate = round(price_estimate, 2)
  ),
  constraint bookings_status_check check (
    status in (
      'confirmed',
      'completed',
      'cancelled_by_customer',
      'cancelled_by_groomer'
    )
  ),
  constraint bookings_cancellation_check check (
    (
      status = 'cancelled_by_customer'
      and cancelled_at is not null
      and cancelled_by = customer_id
    )
    or (
      status = 'cancelled_by_groomer'
      and cancelled_at is not null
      and cancelled_by = groomer_id
    )
    or (
      status in ('confirmed', 'completed')
      and cancelled_at is null
      and cancelled_by is null
    )
  )
);

comment on table public.bookings is
  'Durable booking created by accepting one groomer offer for one customer request.';
comment on column public.bookings.price_estimate is
  'Accepted offer price estimate copied from groomer_offers at booking creation.';
comment on column public.bookings.status is
  'Backend-controlled booking status. MVP cancellation preserves request and offer closure.';

alter table public.bookings
add constraint bookings_no_groomer_time_overlap
exclude using gist (
  groomer_id with =,
  tstzrange(scheduled_start, scheduled_end, '[)') with &&
)
where (status = 'confirmed');

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique,
  request_id uuid not null,
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conversations_booking_identity_fkey
    foreign key (booking_id, request_id, customer_id, groomer_id)
    references public.bookings (id, request_id, customer_id, groomer_id)
    on delete cascade
);

comment on table public.conversations is
  'Participant boundary created atomically with an accepted booking. Message rows are deferred to T-020.';

create index bookings_customer_status_start_idx
on public.bookings (customer_id, status, scheduled_start desc);

create index bookings_groomer_status_start_idx
on public.bookings (groomer_id, status, scheduled_start desc);

create index bookings_groomer_confirmed_range_idx
on public.bookings (groomer_id, scheduled_start, scheduled_end)
where status = 'confirmed';

create index conversations_customer_created_idx
on public.conversations (customer_id, created_at desc);

create index conversations_groomer_created_idx
on public.conversations (groomer_id, created_at desc);

create trigger bookings_set_updated_at
before update on public.bookings
for each row execute function app_private.set_updated_at();

create trigger conversations_set_updated_at
before update on public.conversations
for each row execute function app_private.set_updated_at();

alter table public.bookings enable row level security;
alter table public.conversations enable row level security;

revoke all on table public.bookings from public, anon, authenticated;
revoke all on table public.conversations from public, anon, authenticated;

grant select on table public.bookings to authenticated;
grant select on table public.conversations to authenticated;

grant select, insert, update, delete
on table public.bookings, public.conversations
to service_role;

create policy bookings_select_participants
on public.bookings
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    (
      customer_id = (select auth.uid())
      and exists (
        select 1
        from public.customer_profiles
        where user_id = (select auth.uid())
      )
    )
    or (
      groomer_id = (select auth.uid())
      and exists (
        select 1
        from public.groomer_profiles
        where user_id = (select auth.uid())
      )
    )
  )
);

create policy conversations_select_participants
on public.conversations
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    (
      customer_id = (select auth.uid())
      and exists (
        select 1
        from public.customer_profiles
        where user_id = (select auth.uid())
      )
    )
    or (
      groomer_id = (select auth.uid())
      and exists (
        select 1
        from public.groomer_profiles
        where user_id = (select auth.uid())
      )
    )
  )
);

create function public.accept_groomer_offer(
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
  'Accepts one pending groomer offer for the calling customer and atomically creates a booking and conversation.';

revoke all on function public.accept_groomer_offer(uuid)
from public, anon, authenticated;

grant execute on function public.accept_groomer_offer(uuid)
to authenticated, service_role;

create function public.cancel_booking(
  p_booking_id uuid
)
returns table (
  booking_id uuid,
  booking_status text,
  cancelled_timestamp timestamptz,
  cancelled_by uuid
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
  v_customer_id uuid;
  v_groomer_id uuid;
  v_booking_status text;
  v_cancelled_at timestamptz;
  v_cancelled_by uuid;
  v_new_status text;
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

  select
    booking.id,
    booking.customer_id,
    booking.groomer_id,
    booking.status,
    booking.cancelled_at,
    booking.cancelled_by
  into
    v_booking_id,
    v_customer_id,
    v_groomer_id,
    v_booking_status,
    v_cancelled_at,
    v_cancelled_by
  from public.bookings as booking
  where booking.id = p_booking_id
    and (
      booking.customer_id = v_user_id
      or booking.groomer_id = v_user_id
    )
  for update of booking;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_found';
  end if;

  if v_user_id = v_customer_id then
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

    v_new_status := 'cancelled_by_customer';
  elsif v_user_id = v_groomer_id then
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

    v_new_status := 'cancelled_by_groomer';
  end if;

  if v_booking_status in ('cancelled_by_customer', 'cancelled_by_groomer') then
    return query
    select v_booking_id, v_booking_status, v_cancelled_at, v_cancelled_by;
    return;
  end if;

  if v_booking_status <> 'confirmed' then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_cancellable';
  end if;

  update public.bookings as booking
  set
    status = v_new_status,
    cancelled_by = v_user_id,
    cancelled_at = statement_timestamp()
  where booking.id = v_booking_id
  returning booking.status, booking.cancelled_at, booking.cancelled_by
  into v_booking_status, v_cancelled_at, v_cancelled_by;

  return query
  select v_booking_id, v_booking_status, v_cancelled_at, v_cancelled_by;
end;
$$;

comment on function public.cancel_booking(uuid) is
  'Cancels a confirmed booking as the calling customer or groomer participant. It does not reopen requests or offers.';

revoke all on function public.cancel_booking(uuid)
from public, anon, authenticated;

grant execute on function public.cancel_booking(uuid)
to authenticated, service_role;
