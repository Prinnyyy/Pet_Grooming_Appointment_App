-- T-156 booking handoff read-state persistence.
-- Local migration only until remote application is explicitly authorized.

create table public.customer_booking_handoff_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  request_id uuid not null,
  booking_id uuid not null
    references public.bookings (id) on delete cascade,
  acknowledged_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_booking_handoff_acknowledgements_request_key
    unique (customer_id, request_id),
  constraint customer_booking_handoff_acknowledgements_request_fkey
    foreign key (request_id, customer_id)
    references public.grooming_requests (id, customer_id)
    on delete cascade,
  constraint customer_booking_handoff_acknowledgements_ack_time_check check (
    acknowledged_at >= created_at
  )
);

comment on table public.customer_booking_handoff_acknowledgements is
  'Customer-owned durable read state for confirmed booking handoff cards shown after a request becomes booked.';
comment on column public.customer_booking_handoff_acknowledgements.acknowledged_at is
  'Server timestamp when the customer first dismissed the booking handoff card.';

create index customer_booking_handoff_ack_customer_ack_idx
on public.customer_booking_handoff_acknowledgements (
  customer_id,
  acknowledged_at desc
);

create trigger customer_booking_handoff_acknowledgements_set_updated_at
before update on public.customer_booking_handoff_acknowledgements
for each row execute function app_private.set_updated_at();

alter table public.customer_booking_handoff_acknowledgements
enable row level security;

revoke all on table public.customer_booking_handoff_acknowledgements
from public, anon, authenticated;

grant select on table public.customer_booking_handoff_acknowledgements
to authenticated;

grant insert (customer_id, request_id, booking_id)
on table public.customer_booking_handoff_acknowledgements
to authenticated;

grant select, insert, update, delete
on table public.customer_booking_handoff_acknowledgements
to service_role;

create policy customer_booking_handoff_acknowledgements_select_own
on public.customer_booking_handoff_acknowledgements
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
);

create policy customer_booking_handoff_acknowledgements_insert_own_confirmed
on public.customer_booking_handoff_acknowledgements
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and customer_id = (select auth.uid())
  and exists (
    select 1
    from public.bookings as booking
    where booking.id =
      customer_booking_handoff_acknowledgements.booking_id
      and booking.customer_id =
        customer_booking_handoff_acknowledgements.customer_id
      and booking.request_id =
        customer_booking_handoff_acknowledgements.request_id
      and booking.status = 'confirmed'
  )
);

create or replace function public.get_acknowledged_booking_handoff_request_ids()
returns table (
  request_id uuid
)
language sql
security invoker
set search_path = ''
as $$
  select acknowledgement.request_id
  from public.customer_booking_handoff_acknowledgements as acknowledgement
  where acknowledgement.customer_id = (select auth.uid())
  order by acknowledgement.acknowledged_at desc, acknowledgement.request_id;
$$;

comment on function public.get_acknowledged_booking_handoff_request_ids() is
  'Returns request IDs whose customer booking handoff card has already been acknowledged by the current customer.';

revoke all on function public.get_acknowledged_booking_handoff_request_ids()
from public, anon, authenticated;

grant execute on function public.get_acknowledged_booking_handoff_request_ids()
to authenticated;

create or replace function public.acknowledge_booking_handoff(
  p_request_id uuid,
  p_booking_id uuid
)
returns table (
  request_id uuid,
  booking_id uuid,
  acknowledged_at timestamptz
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '42501',
      message = 'customer_profile_required';
  end if;

  if p_request_id is null or p_booking_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_booking_handoff';
  end if;

  return query
  with inserted as (
    insert into public.customer_booking_handoff_acknowledgements (
      customer_id,
      request_id,
      booking_id
    )
    select
      v_user_id,
      p_request_id,
      p_booking_id
    from public.bookings as booking
    where booking.id = p_booking_id
      and booking.request_id = p_request_id
      and booking.customer_id = v_user_id
      and booking.status = 'confirmed'
    on conflict on constraint
      customer_booking_handoff_acknowledgements_request_key
    do nothing
    returning
      customer_booking_handoff_acknowledgements.request_id,
      customer_booking_handoff_acknowledgements.booking_id,
      customer_booking_handoff_acknowledgements.acknowledged_at
  )
  select
    inserted.request_id,
    inserted.booking_id,
    inserted.acknowledged_at
  from inserted
  union all
  select
    acknowledgement.request_id,
    acknowledgement.booking_id,
    acknowledgement.acknowledged_at
  from public.customer_booking_handoff_acknowledgements as acknowledgement
  where acknowledgement.customer_id = v_user_id
    and acknowledgement.request_id = p_request_id
    and acknowledgement.booking_id = p_booking_id
    and not exists (select 1 from inserted)
  limit 1;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'booking_handoff_not_found';
  end if;
end;
$$;

comment on function public.acknowledge_booking_handoff(uuid, uuid) is
  'Acknowledges a confirmed current-customer booking handoff card using durable backend state.';

revoke all on function public.acknowledge_booking_handoff(uuid, uuid)
from public, anon, authenticated;

grant execute on function public.acknowledge_booking_handoff(uuid, uuid)
to authenticated;
