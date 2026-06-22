-- T-044 reviewed SQL draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- User authorized this request-cancellation backend feature on 2026-06-22
-- after local and remote inspection confirmed no existing request cancel RPC.

create or replace function public.cancel_grooming_request(
  p_request_id uuid
)
returns table (
  request_id uuid,
  request_status text,
  cancelled_timestamp timestamptz
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
  v_request_id uuid;
  v_request_status text;
  v_cancelled_at timestamptz;
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

  if p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_request';
  end if;

  select
    grooming_request.id,
    grooming_request.status
  into
    v_request_id,
    v_request_status
  from public.grooming_requests as grooming_request
  where grooming_request.id = p_request_id
    and grooming_request.customer_id = v_user_id
  for update of grooming_request;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_found';
  end if;

  if v_request_status = 'cancelled' then
    select grooming_request.updated_at
    into v_cancelled_at
    from public.grooming_requests as grooming_request
    where grooming_request.id = v_request_id;

    return query
    select v_request_id, v_request_status, v_cancelled_at;
    return;
  end if;

  if v_request_status not in ('open', 'has_offers') then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_cancellable';
  end if;

  update public.groomer_offers as groomer_offer
  set status = 'declined_by_customer'
  where groomer_offer.request_id = v_request_id
    and groomer_offer.customer_id = v_user_id
    and groomer_offer.status = 'pending';

  update public.request_matches as request_match
  set status = 'hidden'
  where request_match.request_id = v_request_id
    and request_match.customer_id = v_user_id
    and request_match.status in ('visible', 'viewed', 'offered');

  update public.grooming_requests as grooming_request
  set status = 'cancelled'
  where grooming_request.id = v_request_id
    and grooming_request.customer_id = v_user_id
  returning grooming_request.status, grooming_request.updated_at
  into v_request_status, v_cancelled_at;

  return query
  select v_request_id, v_request_status, v_cancelled_at;
end;
$$;

comment on function public.cancel_grooming_request(uuid) is
  'Cancels an open customer-owned grooming request and closes pending offers/matches. Booked requests remain final and are not cancelled by this RPC.';

revoke all on function public.cancel_grooming_request(uuid)
from public, anon, authenticated;

grant execute on function public.cancel_grooming_request(uuid)
to authenticated, service_role;
