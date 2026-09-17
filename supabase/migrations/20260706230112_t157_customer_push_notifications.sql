-- T-157 reviewed SQL draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

alter table public.customer_notifications
drop constraint customer_notifications_kind_check;

alter table public.customer_notifications
add constraint customer_notifications_kind_check check (
  kind in (
    'request_published',
    'request_cancelled',
    'booking_confirmed',
    'booking_cancelled',
    'new_offer',
    'new_message'
  )
);

alter table public.customer_notifications
add column push_delivery_status text not null default 'pending';

alter table public.customer_notifications
add column push_attempt_count integer not null default 0;

alter table public.customer_notifications
add column push_attempted_at timestamptz;

alter table public.customer_notifications
add column push_delivered_at timestamptz;

alter table public.customer_notifications
add column push_last_error text;

alter table public.customer_notifications
add constraint customer_notifications_push_delivery_status_check check (
  push_delivery_status in (
    'pending',
    'processing',
    'sent',
    'failed',
    'no_active_tokens'
  )
);

alter table public.customer_notifications
add constraint customer_notifications_push_attempt_count_check check (
  push_attempt_count >= 0
  and push_attempt_count <= 20
);

alter table public.customer_notifications
add constraint customer_notifications_push_delivery_state_check check (
  (
    push_delivery_status = 'sent'
    and push_delivered_at is not null
  )
  or (
    push_delivery_status <> 'sent'
    and push_delivered_at is null
  )
);

create index customer_notifications_push_pending_idx
on public.customer_notifications (push_delivery_status, created_at asc, id asc)
where push_delivery_status in ('pending', 'failed');

comment on column public.customer_notifications.push_delivery_status is
  'APNs delivery queue status for the durable in-app notification.';
comment on column public.customer_notifications.push_last_error is
  'Short APNs dispatch error summary only; never store notification payloads, secrets, or user message bodies.';

create table public.customer_push_tokens (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  token text not null,
  installation_id uuid not null,
  environment text not null,
  disabled_at timestamptz,
  last_registered_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint customer_push_tokens_token_check check (
    token = lower(token)
    and token ~ '^[0-9a-f]{32,256}$'
  ),
  constraint customer_push_tokens_environment_check check (
    environment in ('sandbox', 'production')
  )
);

comment on table public.customer_push_tokens is
  'Customer-owned APNs device tokens for server-side push notification delivery.';
comment on column public.customer_push_tokens.token is
  'Raw APNs device token. Never expose through client-readable table grants.';
comment on column public.customer_push_tokens.installation_id is
  'Stable app-installation UUID generated locally so token rotation disables older tokens for that installation.';

create unique index customer_push_tokens_token_environment_key
on public.customer_push_tokens (token, environment);

create unique index customer_push_tokens_customer_installation_environment_active_key
on public.customer_push_tokens (customer_id, installation_id, environment)
where disabled_at is null;

create index customer_push_tokens_customer_active_idx
on public.customer_push_tokens (customer_id, environment, updated_at desc)
where disabled_at is null;

create trigger customer_push_tokens_set_updated_at
before update on public.customer_push_tokens
for each row execute function app_private.set_updated_at();

alter table public.customer_push_tokens enable row level security;

revoke all on table public.customer_push_tokens from public, anon, authenticated;

grant select, insert, update, delete
on table public.customer_push_tokens
to service_role;

create or replace function app_private.register_customer_push_token(
  p_token text,
  p_installation_id uuid,
  p_environment text default 'sandbox'
)
returns table (
  token_id uuid,
  customer_id uuid,
  environment text,
  is_active boolean,
  registered_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_token text := lower(regexp_replace(coalesce(p_token, ''), '[^0-9a-fA-F]', '', 'g'));
  v_environment text := lower(btrim(coalesce(p_environment, '')));
begin
  if v_customer_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if not exists (
    select 1
    from public.customer_profiles
    where user_id = v_customer_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'customer_profile_required';
  end if;

  if p_installation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_installation';
  end if;

  if v_environment not in ('sandbox', 'production') then
    raise exception using
      errcode = '22023',
      message = 'invalid_push_environment';
  end if;

  if v_token !~ '^[0-9a-f]{32,256}$' then
    raise exception using
      errcode = '22023',
      message = 'invalid_device_token';
  end if;

  update public.customer_push_tokens as push_token
  set disabled_at = coalesce(push_token.disabled_at, statement_timestamp())
  where push_token.customer_id = v_customer_id
    and push_token.installation_id = p_installation_id
    and push_token.environment = v_environment
    and push_token.token <> v_token
    and push_token.disabled_at is null;

  return query
  insert into public.customer_push_tokens as push_token (
    customer_id,
    token,
    installation_id,
    environment,
    disabled_at,
    last_registered_at
  )
  values (
    v_customer_id,
    v_token,
    p_installation_id,
    v_environment,
    null,
    statement_timestamp()
  )
  on conflict (token, environment) do update
  set
    customer_id = excluded.customer_id,
    installation_id = excluded.installation_id,
    disabled_at = null,
    last_registered_at = statement_timestamp(),
    updated_at = statement_timestamp()
  returning
    push_token.id,
    push_token.customer_id,
    push_token.environment,
    push_token.disabled_at is null,
    push_token.last_registered_at;
end;
$$;

comment on function app_private.register_customer_push_token(text, uuid, text) is
  'Private helper for current-customer APNs token registration.';

revoke all on function app_private.register_customer_push_token(text, uuid, text)
from public, anon, authenticated, service_role;

grant execute on function app_private.register_customer_push_token(text, uuid, text)
to authenticated;

create or replace function public.register_customer_push_token(
  p_token text,
  p_installation_id uuid,
  p_environment text default 'sandbox'
)
returns table (
  token_id uuid,
  customer_id uuid,
  environment text,
  is_active boolean,
  registered_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.register_customer_push_token(
    p_token,
    p_installation_id,
    p_environment
  );
$$;

comment on function public.register_customer_push_token(text, uuid, text) is
  'Registers or refreshes the current customer APNs token without exposing the token table to clients.';

revoke all on function public.register_customer_push_token(text, uuid, text)
from public, anon, authenticated;

grant execute on function public.register_customer_push_token(text, uuid, text) to authenticated;

create or replace function app_private.unregister_customer_push_token(
  p_token text,
  p_installation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_token text := lower(regexp_replace(coalesce(p_token, ''), '[^0-9a-fA-F]', '', 'g'));
begin
  if v_customer_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_installation_id is null or v_token !~ '^[0-9a-f]{32,256}$' then
    raise exception using
      errcode = '22023',
      message = 'invalid_device_token';
  end if;

  update public.customer_push_tokens as push_token
  set disabled_at = coalesce(push_token.disabled_at, statement_timestamp())
  where push_token.customer_id = v_customer_id
    and push_token.installation_id = p_installation_id
    and push_token.token = v_token
    and push_token.disabled_at is null;

  return found;
end;
$$;

comment on function app_private.unregister_customer_push_token(text, uuid) is
  'Private helper for disabling the current customer APNs token.';

revoke all on function app_private.unregister_customer_push_token(text, uuid)
from public, anon, authenticated, service_role;

grant execute on function app_private.unregister_customer_push_token(text, uuid)
to authenticated;

create or replace function public.unregister_customer_push_token(
  p_token text,
  p_installation_id uuid
)
returns boolean
language sql
security invoker
set search_path = ''
as $$
  select app_private.unregister_customer_push_token(
    p_token,
    p_installation_id
  );
$$;

comment on function public.unregister_customer_push_token(text, uuid) is
  'Disables the current customer APNs token.';

revoke all on function public.unregister_customer_push_token(text, uuid)
from public, anon, authenticated;

grant execute on function public.unregister_customer_push_token(text, uuid) to authenticated;

create or replace function public.claim_customer_push_notifications(
  p_limit integer default 50
)
returns table (
  notification_id uuid,
  customer_id uuid,
  kind text,
  title text,
  body text,
  related_request_id uuid,
  related_booking_id uuid,
  related_offer_id uuid
)
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if p_limit is null or p_limit < 1 or p_limit > 250 then
    raise exception using
      errcode = '22023',
      message = 'invalid_push_claim_limit';
  end if;

  return query
  with candidate as (
    select notification.id
    from public.customer_notifications as notification
    where notification.push_delivery_status = 'pending'
    order by notification.created_at asc, notification.id asc
    limit p_limit
    for update skip locked
  )
  update public.customer_notifications as notification
  set
    push_delivery_status = 'processing',
    push_attempted_at = statement_timestamp(),
    push_attempt_count = notification.push_attempt_count + 1,
    push_last_error = null
  from candidate
  where notification.id = candidate.id
  returning
    notification.id,
    notification.customer_id,
    notification.kind,
    notification.title,
    notification.body,
    notification.related_request_id,
    notification.related_booking_id,
    notification.related_offer_id;
end;
$$;

comment on function public.claim_customer_push_notifications(integer) is
  'Service-role RPC that atomically claims pending customer notifications for APNs dispatch.';

revoke all on function public.claim_customer_push_notifications(integer)
from public, anon, authenticated, service_role;

grant execute on function public.claim_customer_push_notifications(integer) to service_role;

create or replace function public.record_customer_push_delivery(
  p_notification_id uuid,
  p_status text,
  p_error text default null
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text := lower(btrim(coalesce(p_status, '')));
  v_error text := nullif(left(btrim(coalesce(p_error, '')), 240), '');
begin
  if p_notification_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_notification';
  end if;

  if v_status not in ('sent', 'failed', 'no_active_tokens') then
    raise exception using
      errcode = '22023',
      message = 'invalid_push_delivery_status';
  end if;

  update public.customer_notifications as notification
  set
    push_delivery_status = v_status,
    push_delivered_at = case
      when v_status = 'sent' then statement_timestamp()
      else null
    end,
    push_last_error = case
      when v_status = 'sent' then null
      else v_error
    end
  where notification.id = p_notification_id
    and notification.push_delivery_status = 'processing';

  return found;
end;
$$;

comment on function public.record_customer_push_delivery(uuid, text, text) is
  'Service-role RPC that records the APNs dispatch result for one claimed customer notification.';

revoke all on function public.record_customer_push_delivery(uuid, text, text)
from public, anon, authenticated, service_role;

grant execute on function public.record_customer_push_delivery(uuid, text, text) to service_role;

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
    'booking_cancelled',
    'new_offer',
    'new_message'
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

create or replace function app_private.customer_notifications_after_offer_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'pending' then
    perform app_private.create_customer_notification(
      new.customer_id,
      'new_offer',
      'New offer received',
      'A groomer sent a new offer for your request.',
      new.request_id,
      null,
      new.id
    );
  end if;

  return new;
end;
$$;

create or replace function app_private.customer_notifications_after_groomer_message_insert()
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

  if found and new.sender_id = v_groomer_id then
    perform app_private.create_customer_notification(
      v_customer_id,
      'new_message',
      'New message',
      'Your groomer sent you a message.',
      v_request_id,
      v_booking_id,
      null
    );
  end if;

  return new;
end;
$$;

revoke all on function app_private.customer_notifications_after_offer_insert()
from public, anon, authenticated, service_role;

revoke all on function app_private.customer_notifications_after_groomer_message_insert()
from public, anon, authenticated, service_role;

create trigger customer_notifications_after_offer_insert
after insert on public.groomer_offers
for each row execute function app_private.customer_notifications_after_offer_insert();

create trigger customer_notifications_after_groomer_message_insert
after insert on public.messages
for each row execute function app_private.customer_notifications_after_groomer_message_insert();
