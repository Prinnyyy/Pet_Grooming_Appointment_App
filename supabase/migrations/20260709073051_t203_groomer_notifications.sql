-- T-203 reviewed SQL draft.
-- Local migration only until remote application is explicitly authorized.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

create table public.groomer_notifications (
  id uuid primary key default gen_random_uuid(),
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  read_at timestamptz,
  related_request_id uuid
    references public.grooming_requests (id) on delete set null,
  related_booking_id uuid
    references public.bookings (id) on delete set null,
  related_offer_id uuid
    references public.groomer_offers (id) on delete set null,
  constraint groomer_notifications_kind_check check (
    kind in (
      'new_match',
      'offer_accepted',
      'booking_cancelled_by_customer',
      'new_message'
    )
  ),
  constraint groomer_notifications_title_check check (
    length(btrim(title)) between 1 and 120
  ),
  constraint groomer_notifications_body_check check (
    length(btrim(body)) between 1 and 500
  ),
  constraint groomer_notifications_read_state_check check (
    (
      is_read = false
      and read_at is null
    )
    or (
      is_read = true
      and read_at is not null
      and read_at >= created_at
    )
  )
);

comment on table public.groomer_notifications is
  'Groomer-owned in-app system notifications for request, booking, and message events.';
comment on column public.groomer_notifications.kind is
  'System event kind for in-app groomer notifications.';
comment on column public.groomer_notifications.body is
  'Short system copy only; do not store chat bodies, full addresses, or sensitive free-form content.';

create index groomer_notifications_groomer_read_created_idx
on public.groomer_notifications (groomer_id, is_read, created_at desc);

create index groomer_notifications_groomer_created_idx
on public.groomer_notifications (groomer_id, created_at desc);

create index groomer_notifications_related_request_idx
on public.groomer_notifications (related_request_id)
where related_request_id is not null;

create index groomer_notifications_related_booking_idx
on public.groomer_notifications (related_booking_id)
where related_booking_id is not null;

create index groomer_notifications_related_offer_idx
on public.groomer_notifications (related_offer_id)
where related_offer_id is not null;

alter table public.groomer_notifications enable row level security;

revoke all on table public.groomer_notifications from public, anon, authenticated;

grant select on table public.groomer_notifications to authenticated;
grant update (is_read, read_at) on table public.groomer_notifications to authenticated;
grant select, insert, update, delete on table public.groomer_notifications to service_role;

create policy groomer_notifications_select_own
on public.groomer_notifications
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create policy groomer_notifications_update_own_read_state
on public.groomer_notifications
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
)
with check (
  groomer_id = (select auth.uid())
  and is_read = true
  and read_at is not null
);

create or replace function app_private.create_groomer_notification(
  p_groomer_id uuid,
  p_kind text,
  p_title text,
  p_body text,
  p_related_request_id uuid default null,
  p_related_booking_id uuid default null,
  p_related_offer_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notification_id uuid;
begin
  if p_groomer_id is null then
    raise exception 'groomer_profile_required'
      using errcode = 'P0001';
  end if;

  if p_kind not in (
    'new_match',
    'offer_accepted',
    'booking_cancelled_by_customer',
    'new_message'
  ) then
    raise exception 'invalid_notification_kind'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.groomer_profiles
    where user_id = p_groomer_id
  ) then
    raise exception 'groomer_profile_required'
      using errcode = 'P0001';
  end if;

  insert into public.groomer_notifications (
    groomer_id,
    kind,
    title,
    body,
    related_request_id,
    related_booking_id,
    related_offer_id
  )
  values (
    p_groomer_id,
    p_kind,
    btrim(p_title),
    btrim(p_body),
    p_related_request_id,
    p_related_booking_id,
    p_related_offer_id
  )
  returning id into v_notification_id;

  return v_notification_id;
end;
$$;

comment on function app_private.create_groomer_notification(
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  uuid
) is
  'Private helper for creating groomer-owned system notifications from trusted backend events.';

revoke all on function app_private.create_groomer_notification(
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;

create or replace function public.mark_groomer_notification_read(
  p_notification_id uuid
)
returns setof public.groomer_notifications
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_groomer_id uuid;
begin
  v_groomer_id := (select auth.uid());

  if v_groomer_id is null
     or coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
     or not exists (
       select 1
       from public.groomer_profiles
       where user_id = v_groomer_id
     ) then
    raise exception 'groomer_profile_required'
      using errcode = 'P0001';
  end if;

  return query
  update public.groomer_notifications as notification
  set
    is_read = true,
    read_at = coalesce(notification.read_at, statement_timestamp())
  where notification.id = p_notification_id
    and notification.groomer_id = v_groomer_id
  returning notification.*;

  if not found then
    raise exception 'notification_not_found'
      using errcode = 'P0001';
  end if;
end;
$$;

comment on function public.mark_groomer_notification_read(uuid) is
  'Marks one current-groomer notification as read.';

revoke all on function public.mark_groomer_notification_read(uuid)
from public, anon, authenticated;

grant execute on function public.mark_groomer_notification_read(uuid) to authenticated;

create or replace function public.mark_all_groomer_notifications_read()
returns setof public.groomer_notifications
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_groomer_id uuid;
begin
  v_groomer_id := (select auth.uid());

  if v_groomer_id is null
     or coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
     or not exists (
       select 1
       from public.groomer_profiles
       where user_id = v_groomer_id
     ) then
    raise exception 'groomer_profile_required'
      using errcode = 'P0001';
  end if;

  update public.groomer_notifications as notification
  set
    is_read = true,
    read_at = coalesce(notification.read_at, statement_timestamp())
  where notification.groomer_id = v_groomer_id
    and notification.is_read = false;

  return query
  select notification.*
  from public.groomer_notifications as notification
  where notification.groomer_id = v_groomer_id
  order by notification.created_at desc, notification.id;
end;
$$;

comment on function public.mark_all_groomer_notifications_read() is
  'Marks all current-groomer notifications as read and returns the refreshed list.';

revoke all on function public.mark_all_groomer_notifications_read()
from public, anon, authenticated;

grant execute on function public.mark_all_groomer_notifications_read() to authenticated;

create or replace function app_private.groomer_notifications_after_match_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('visible', 'viewed') then
    perform app_private.create_groomer_notification(
      new.groomer_id,
      'new_match',
      'New request match',
      'A customer request matches your services.',
      new.request_id,
      null,
      null
    );
  end if;

  return new;
end;
$$;

create or replace function app_private.groomer_notifications_after_booking_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'confirmed' then
    perform app_private.create_groomer_notification(
      new.groomer_id,
      'offer_accepted',
      'Offer accepted',
      'Your offer was accepted and the booking is confirmed.',
      new.request_id,
      new.id,
      new.offer_id
    );
  end if;

  return new;
end;
$$;

create or replace function app_private.groomer_notifications_after_customer_booking_cancelled()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'cancelled_by_customer'
     and old.status is distinct from new.status then
    perform app_private.create_groomer_notification(
      new.groomer_id,
      'booking_cancelled_by_customer',
      'Booking cancelled',
      'The customer cancelled this booking.',
      new.request_id,
      new.id,
      new.offer_id
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
  v_request_id uuid;
  v_booking_id uuid;
begin
  select
    conversation.customer_id,
    conversation.groomer_id,
    conversation.request_id,
    conversation.booking_id
  into
    v_customer_id,
    v_groomer_id,
    v_request_id,
    v_booking_id
  from public.conversations as conversation
  where conversation.id = new.conversation_id;

  if found and new.sender_id = v_customer_id then
    perform app_private.create_groomer_notification(
      v_groomer_id,
      'new_message',
      'New message',
      'Your customer sent you a message.',
      v_request_id,
      v_booking_id,
      null
    );
  end if;

  return new;
end;
$$;

revoke all on function app_private.groomer_notifications_after_match_insert()
from public, anon, authenticated, service_role;

revoke all on function app_private.groomer_notifications_after_booking_insert()
from public, anon, authenticated, service_role;

revoke all on function app_private.groomer_notifications_after_customer_booking_cancelled()
from public, anon, authenticated, service_role;

revoke all on function app_private.groomer_notifications_after_customer_message_insert()
from public, anon, authenticated, service_role;

create trigger groomer_notifications_after_match_insert
after insert on public.request_matches
for each row execute function app_private.groomer_notifications_after_match_insert();

create trigger groomer_notifications_after_booking_insert
after insert on public.bookings
for each row execute function app_private.groomer_notifications_after_booking_insert();

create trigger groomer_notifications_after_customer_booking_cancelled
after update of status on public.bookings
for each row execute function app_private.groomer_notifications_after_customer_booking_cancelled();

create trigger groomer_notifications_after_customer_message_insert
after insert on public.messages
for each row execute function app_private.groomer_notifications_after_customer_message_insert();
