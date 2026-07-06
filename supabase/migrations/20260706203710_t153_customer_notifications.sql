-- T-153 reviewed SQL draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

create table public.customer_notifications (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  related_request_id uuid
    references public.grooming_requests (id) on delete set null,
  related_booking_id uuid
    references public.bookings (id) on delete set null,
  related_offer_id uuid
    references public.groomer_offers (id) on delete set null,
  constraint customer_notifications_kind_check check (
    kind in (
      'request_published',
      'request_cancelled',
      'booking_confirmed',
      'booking_cancelled'
    )
  ),
  constraint customer_notifications_title_check check (
    length(btrim(title)) between 1 and 120
  ),
  constraint customer_notifications_body_check check (
    length(btrim(body)) between 1 and 500
  ),
  constraint customer_notifications_read_state_check check (
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

comment on table public.customer_notifications is
  'Customer-owned in-app system notifications. APNs can reuse this durable model later.';
comment on column public.customer_notifications.kind is
  'System event kind for in-app customer notifications.';
comment on column public.customer_notifications.body is
  'Short system copy only; do not store chat bodies, full addresses, or sensitive free-form content.';

create index customer_notifications_customer_read_created_idx
on public.customer_notifications (customer_id, is_read, created_at desc);

create index customer_notifications_customer_created_idx
on public.customer_notifications (customer_id, created_at desc);

create index customer_notifications_related_request_idx
on public.customer_notifications (related_request_id)
where related_request_id is not null;

create index customer_notifications_related_booking_idx
on public.customer_notifications (related_booking_id)
where related_booking_id is not null;

create index customer_notifications_related_offer_idx
on public.customer_notifications (related_offer_id)
where related_offer_id is not null;

alter table public.customer_notifications enable row level security;

revoke all on table public.customer_notifications from public, anon, authenticated;

grant select on table public.customer_notifications to authenticated;
grant update (is_read, read_at) on table public.customer_notifications to authenticated;
grant select, insert, update, delete on table public.customer_notifications to service_role;

create policy customer_notifications_select_own
on public.customer_notifications
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
);

create policy customer_notifications_update_own_read_state
on public.customer_notifications
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.customer_profiles
    where user_id = (select auth.uid())
  )
)
with check (
  customer_id = (select auth.uid())
  and is_read = true
  and read_at is not null
);

create or replace function app_private.create_customer_notification(
  p_customer_id uuid,
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
  if p_customer_id is null then
    raise exception 'customer_profile_required'
      using errcode = 'P0001';
  end if;

  if p_kind not in (
    'request_published',
    'request_cancelled',
    'booking_confirmed',
    'booking_cancelled'
  ) then
    raise exception 'invalid_notification_kind'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.customer_profiles
    where user_id = p_customer_id
  ) then
    raise exception 'customer_profile_required'
      using errcode = 'P0001';
  end if;

  insert into public.customer_notifications (
    customer_id,
    kind,
    title,
    body,
    related_request_id,
    related_booking_id,
    related_offer_id
  )
  values (
    p_customer_id,
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

comment on function app_private.create_customer_notification(
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  uuid
) is
  'Private helper for creating customer-owned system notifications from trusted backend events.';

revoke all on function app_private.create_customer_notification(
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;

create or replace function public.mark_customer_notification_read(
  p_notification_id uuid
)
returns setof public.customer_notifications
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_customer_id uuid;
begin
  v_customer_id := (select auth.uid());

  if v_customer_id is null
     or coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
     or not exists (
       select 1
       from public.customer_profiles
       where user_id = v_customer_id
     ) then
    raise exception 'customer_profile_required'
      using errcode = 'P0001';
  end if;

  return query
  update public.customer_notifications as notification
  set
    is_read = true,
    read_at = coalesce(notification.read_at, statement_timestamp())
  where notification.id = p_notification_id
    and notification.customer_id = v_customer_id
  returning notification.*;

  if not found then
    raise exception 'notification_not_found'
      using errcode = 'P0001';
  end if;
end;
$$;

comment on function public.mark_customer_notification_read(uuid) is
  'Marks one current-customer notification as read.';

revoke all on function public.mark_customer_notification_read(uuid)
from public, anon, authenticated;

grant execute on function public.mark_customer_notification_read(uuid) to authenticated;

create or replace function public.mark_all_customer_notifications_read()
returns setof public.customer_notifications
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_customer_id uuid;
begin
  v_customer_id := (select auth.uid());

  if v_customer_id is null
     or coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
     or not exists (
       select 1
       from public.customer_profiles
       where user_id = v_customer_id
     ) then
    raise exception 'customer_profile_required'
      using errcode = 'P0001';
  end if;

  update public.customer_notifications as notification
  set
    is_read = true,
    read_at = coalesce(notification.read_at, statement_timestamp())
  where notification.customer_id = v_customer_id
    and notification.is_read = false;

  return query
  select notification.*
  from public.customer_notifications as notification
  where notification.customer_id = v_customer_id
  order by notification.created_at desc, notification.id;
end;
$$;

comment on function public.mark_all_customer_notifications_read() is
  'Marks all current-customer notifications as read and returns the refreshed list.';

revoke all on function public.mark_all_customer_notifications_read()
from public, anon, authenticated;

grant execute on function public.mark_all_customer_notifications_read() to authenticated;

create or replace function app_private.customer_notifications_after_request_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.create_customer_notification(
    new.customer_id,
    'request_published',
    'Request published',
    'Your grooming request was published successfully.',
    new.id,
    null,
    null
  );

  return new;
end;
$$;

create or replace function app_private.customer_notifications_after_request_cancelled()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'cancelled'
     and old.status is distinct from new.status then
    perform app_private.create_customer_notification(
      new.customer_id,
      'request_cancelled',
      'Request cancelled',
      'Your grooming request was cancelled successfully.',
      new.id,
      null,
      null
    );
  end if;

  return new;
end;
$$;

create or replace function app_private.customer_notifications_after_booking_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'confirmed' then
    perform app_private.create_customer_notification(
      new.customer_id,
      'booking_confirmed',
      'Booking confirmed',
      'Your appointment was booked successfully.',
      new.request_id,
      new.id,
      new.offer_id
    );
  end if;

  return new;
end;
$$;

create or replace function app_private.customer_notifications_after_booking_cancelled()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('cancelled_by_customer', 'cancelled_by_groomer')
     and old.status is distinct from new.status then
    perform app_private.create_customer_notification(
      new.customer_id,
      'booking_cancelled',
      'Booking cancelled',
      'Your appointment was cancelled successfully.',
      new.request_id,
      new.id,
      new.offer_id
    );
  end if;

  return new;
end;
$$;

revoke all on function app_private.customer_notifications_after_request_insert()
from public, anon, authenticated, service_role;
revoke all on function app_private.customer_notifications_after_request_cancelled()
from public, anon, authenticated, service_role;
revoke all on function app_private.customer_notifications_after_booking_insert()
from public, anon, authenticated, service_role;
revoke all on function app_private.customer_notifications_after_booking_cancelled()
from public, anon, authenticated, service_role;

create trigger customer_notifications_after_request_insert
after insert on public.grooming_requests
for each row execute function app_private.customer_notifications_after_request_insert();

create trigger customer_notifications_after_request_cancelled
after update of status on public.grooming_requests
for each row execute function app_private.customer_notifications_after_request_cancelled();

create trigger customer_notifications_after_booking_insert
after insert on public.bookings
for each row execute function app_private.customer_notifications_after_booking_insert();

create trigger customer_notifications_after_booking_cancelled
after update of status on public.bookings
for each row execute function app_private.customer_notifications_after_booking_cancelled();
