create temporary table t351_conversation_merge_map
on commit drop
as
with ranked as (
  select
    conversation.id as conversation_id,
    first_value(conversation.id) over (
      partition by conversation.customer_id, conversation.groomer_id
      order by conversation.created_at asc, conversation.id asc
    ) as canonical_conversation_id,
    row_number() over (
      partition by conversation.customer_id, conversation.groomer_id
      order by conversation.created_at asc, conversation.id asc
    ) as pair_ordinal,
    max(conversation.updated_at) over (
      partition by conversation.customer_id, conversation.groomer_id
    ) as pair_updated_at
  from public.conversations as conversation
)
select * from ranked;

update public.messages as message
set conversation_id = merge_map.canonical_conversation_id
from t351_conversation_merge_map as merge_map
where message.conversation_id = merge_map.conversation_id
  and merge_map.conversation_id <> merge_map.canonical_conversation_id;

update public.conversations as conversation
set updated_at = greatest(
  conversation.updated_at,
  latest_message.created_at
)
from (
  select
    message.conversation_id,
    max(message.created_at) as created_at
  from public.messages as message
  group by message.conversation_id
) as latest_message
where conversation.id = latest_message.conversation_id;

update public.conversations as conversation
set updated_at = greatest(
  conversation.updated_at,
  merge_map.pair_updated_at
)
from t351_conversation_merge_map as merge_map
where conversation.id = merge_map.canonical_conversation_id
  and merge_map.pair_ordinal = 1;

delete from public.conversations as conversation
using t351_conversation_merge_map as merge_map
where conversation.id = merge_map.conversation_id
  and merge_map.conversation_id <> merge_map.canonical_conversation_id;

alter table public.conversations
drop constraint conversations_booking_identity_fkey,
drop constraint conversations_booking_id_key,
drop column booking_id,
drop column request_id,
add constraint conversations_customer_groomer_key
  unique (customer_id, groomer_id);

comment on table public.conversations is
  'One durable participant conversation for each Customer and Groomer pair.';

alter table public.messages
drop constraint messages_body_check,
add column kind text not null default 'text',
add column booking_id uuid
  references public.bookings (id) on delete cascade,
alter column body drop not null,
add constraint messages_kind_check check (
  kind in ('text', 'booking_card')
),
add constraint messages_content_check check (
  (
    kind = 'text'
    and booking_id is null
    and body = regexp_replace(body, '^[[:space:]]+|[[:space:]]+$', '', 'g')
    and char_length(body) >= 1
    and char_length(body) <= 4000
  )
  or (
    kind = 'booking_card'
    and booking_id is not null
    and body is null
  )
);

comment on table public.messages is
  'Participant text and server-created live booking-card messages.';
comment on column public.messages.kind is
  'Message presentation kind: text or booking_card.';
comment on column public.messages.booking_id is
  'Live booking reference for a server-created booking card.';

create index messages_booking_created_idx
on public.messages (booking_id, created_at asc, id asc)
where booking_id is not null;

drop index public.messages_conversation_created_idx;
create index messages_conversation_created_idx
on public.messages (conversation_id, created_at asc, id asc);

revoke insert on table public.messages from authenticated;
grant insert (conversation_id, sender_id, body)
on table public.messages
to authenticated;

drop policy messages_insert_conversation_participants
on public.messages;

create policy messages_insert_conversation_participants
on public.messages
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and sender_id = (select auth.uid())
  and kind = 'text'
  and booking_id is null
  and exists (
    select 1
    from public.conversations as conversation
    where conversation.id = messages.conversation_id
      and (
        (
          conversation.customer_id = (select auth.uid())
          and exists (
            select 1
            from public.customer_profiles
            where user_id = (select auth.uid())
          )
        )
        or (
          conversation.groomer_id = (select auth.uid())
          and exists (
            select 1
            from public.groomer_profiles
            where user_id = (select auth.uid())
          )
        )
      )
  )
);

create or replace function app_private.t351_touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations as conversation
  set updated_at = greatest(conversation.updated_at, new.created_at)
  where conversation.id = new.conversation_id;

  return new;
end;
$$;

revoke all on function app_private.t351_touch_conversation()
from public, anon, authenticated, service_role;

create trigger t351_touch_conversation
after insert on public.messages
for each row execute function app_private.t351_touch_conversation();

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
  v_event_created_at timestamptz;
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
    raise exception using errcode = 'P0001', message = 'offer_not_found';
  end if;
  if v_offer_status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'offer_not_pending';
  end if;
  if v_offer_expires_at <= statement_timestamp() then
    raise exception using errcode = 'P0001', message = 'offer_expired';
  end if;
  if v_match_status <> 'offered' then
    raise exception using errcode = 'P0001', message = 'match_not_offerable';
  end if;
  if v_request_status not in ('open', 'has_offers')
    or v_request_expires_at <= statement_timestamp()
  then
    raise exception using errcode = 'P0001', message = 'request_not_open';
  end if;
  if exists (
    select 1
    from public.bookings as existing_booking
    where existing_booking.request_id = v_request_id
       or existing_booking.offer_id = v_offer_id
  ) then
    raise exception using errcode = 'P0001', message = 'booking_already_exists';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_groomer_id::text, 71071)
  );

  if not app_private.groomer_is_available_for_range(
    v_groomer_id,
    v_scheduled_start,
    v_scheduled_end
  ) then
    raise exception using errcode = 'P0001', message = 'booking_conflict';
  end if;

  perform 1
  from public.bookings as existing_booking
  where existing_booking.groomer_id = v_groomer_id
    and existing_booking.status = 'confirmed'
    and existing_booking.scheduled_start < v_scheduled_end
    and v_scheduled_start < existing_booking.scheduled_end
  for update;

  if found then
    raise exception using errcode = 'P0001', message = 'booking_conflict';
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
      raise exception using errcode = 'P0001', message = 'booking_already_exists';
    when exclusion_violation then
      raise exception using errcode = 'P0001', message = 'booking_conflict';
  end;

  insert into public.conversations (
    customer_id,
    groomer_id
  )
  values (
    v_customer_id,
    v_groomer_id
  )
  on conflict (customer_id, groomer_id)
  do update set updated_at = greatest(
    public.conversations.updated_at,
    excluded.updated_at
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

  v_event_created_at := clock_timestamp();

  insert into public.messages (
    conversation_id,
    sender_id,
    body,
    kind,
    booking_id,
    created_at
  )
  values (
    v_conversation_id,
    v_user_id,
    null,
    'booking_card',
    v_booking_id,
    v_event_created_at
  );

  insert into public.messages (
    conversation_id,
    sender_id,
    body,
    kind,
    booking_id,
    created_at
  )
  values (
    v_conversation_id,
    v_user_id,
    'Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!',
    'text',
    null,
    v_event_created_at + interval '1 microsecond'
  );

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
  'Accepts an offer, reuses the participant conversation, and appends an ordered booking card plus Customer text.';

revoke all on function app_private.accept_groomer_offer(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.accept_groomer_offer(uuid)
to authenticated;

create or replace function app_private.cancel_booking(
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
  v_conversation_id uuid;
  v_event_created_at timestamptz;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using errcode = '28000', message = 'authenticated_user_required';
  end if;
  if p_booking_id is null then
    raise exception using errcode = '22023', message = 'invalid_booking';
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
    raise exception using errcode = 'P0001', message = 'booking_not_found';
  end if;

  if v_user_id = v_customer_id then
    perform 1
    from public.customer_profiles as customer_profile
    join public.profiles as profile
      on profile.id = customer_profile.user_id
    where customer_profile.user_id = v_user_id
      and profile.role = 'customer'::public.user_role;
    if not found then
      raise exception using errcode = 'P0001', message = 'customer_profile_required';
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
      raise exception using errcode = 'P0001', message = 'groomer_profile_required';
    end if;
    v_new_status := 'cancelled_by_groomer';
  end if;

  if v_booking_status in ('cancelled_by_customer', 'cancelled_by_groomer') then
    return query
    select v_booking_id, v_booking_status, v_cancelled_at, v_cancelled_by;
    return;
  end if;
  if v_booking_status <> 'confirmed' then
    raise exception using errcode = 'P0001', message = 'booking_not_cancellable';
  end if;

  update public.bookings as booking
  set
    status = v_new_status,
    cancelled_by = v_user_id,
    cancelled_at = statement_timestamp()
  where booking.id = v_booking_id
  returning booking.status, booking.cancelled_at, booking.cancelled_by
  into v_booking_status, v_cancelled_at, v_cancelled_by;

  select conversation.id
  into v_conversation_id
  from public.conversations as conversation
  where conversation.customer_id = v_customer_id
    and conversation.groomer_id = v_groomer_id;

  if v_conversation_id is null then
    raise exception using errcode = 'P0001', message = 'conversation_not_found';
  end if;

  v_event_created_at := clock_timestamp();

  insert into public.messages (
    conversation_id,
    sender_id,
    body,
    kind,
    booking_id,
    created_at
  )
  values (
    v_conversation_id,
    v_user_id,
    null,
    'booking_card',
    v_booking_id,
    v_event_created_at
  );

  insert into public.messages (
    conversation_id,
    sender_id,
    body,
    kind,
    booking_id,
    created_at
  )
  values (
    v_conversation_id,
    v_user_id,
    'Hi, I''m sorry, but I''ve had to cancel this booking. Thank you for understanding.',
    'text',
    null,
    v_event_created_at + interval '1 microsecond'
  );

  return query
  select v_booking_id, v_booking_status, v_cancelled_at, v_cancelled_by;
end;
$$;

comment on function app_private.cancel_booking(uuid) is
  'Cancels a confirmed booking and appends an ordered live booking card plus actor-authored text.';

revoke all on function app_private.cancel_booking(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.cancel_booking(uuid)
to authenticated;

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
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.accept_groomer_offer(p_offer_id);
$$;

revoke all on function public.accept_groomer_offer(uuid)
from public, anon, authenticated;
grant execute on function public.accept_groomer_offer(uuid)
to authenticated;

create or replace function public.cancel_booking(
  p_booking_id uuid
)
returns table (
  booking_id uuid,
  booking_status text,
  cancelled_timestamp timestamptz,
  cancelled_by uuid
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.cancel_booking(p_booking_id);
$$;

revoke all on function public.cancel_booking(uuid)
from public, anon, authenticated;
grant execute on function public.cancel_booking(uuid)
to authenticated;

create or replace function app_private.customer_notifications_after_groomer_message_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid;
  v_groomer_id uuid;
begin
  if new.kind <> 'text' then
    return new;
  end if;

  select
    conversation.customer_id,
    conversation.groomer_id
  into
    v_customer_id,
    v_groomer_id
  from public.conversations as conversation
  where conversation.id = new.conversation_id;

  if found and new.sender_id = v_groomer_id then
    perform app_private.create_customer_notification(
      v_customer_id,
      'new_message',
      'New message',
      'Your groomer sent you a message.',
      null,
      null,
      null
    );
  end if;

  return new;
end;
$$;

create or replace function app_private.groomer_notifications_after_customer_message_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid;
  v_groomer_id uuid;
begin
  if new.kind <> 'text' then
    return new;
  end if;

  select
    conversation.customer_id,
    conversation.groomer_id
  into
    v_customer_id,
    v_groomer_id
  from public.conversations as conversation
  where conversation.id = new.conversation_id;

  if found and new.sender_id = v_customer_id then
    perform app_private.create_groomer_notification(
      v_groomer_id,
      'new_message',
      'New message',
      'Your customer sent you a message.',
      null,
      null,
      null
    );
  end if;

  return new;
end;
$$;

revoke all on function app_private.customer_notifications_after_groomer_message_insert()
from public, anon, authenticated, service_role;
revoke all on function app_private.groomer_notifications_after_customer_message_insert()
from public, anon, authenticated, service_role;
