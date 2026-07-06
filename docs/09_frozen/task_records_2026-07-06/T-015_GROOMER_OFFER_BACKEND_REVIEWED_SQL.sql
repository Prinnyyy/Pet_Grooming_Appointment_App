-- T-015 reviewed SQL draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

alter table public.request_matches
add constraint request_matches_identity_key
unique (id, request_id, groomer_id, customer_id);

create table public.groomer_offers (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  match_id uuid not null,
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  proposed_start timestamptz not null,
  proposed_end timestamptz not null,
  price_estimate numeric(10, 2) not null,
  message text,
  status text not null default 'pending',
  expires_at timestamptz not null,
  withdrawn_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groomer_offers_request_customer_fkey
    foreign key (request_id, customer_id)
    references public.grooming_requests (id, customer_id)
    on delete cascade,
  constraint groomer_offers_match_identity_fkey
    foreign key (match_id, request_id, groomer_id, customer_id)
    references public.request_matches (id, request_id, groomer_id, customer_id)
    on delete cascade,
  constraint groomer_offers_proposed_range_check check (
    proposed_end > proposed_start
  ),
  constraint groomer_offers_price_estimate_check check (
    price_estimate >= 0
    and price_estimate <= 100000
    and price_estimate = round(price_estimate, 2)
  ),
  constraint groomer_offers_message_check check (
    message is null
    or (
      message = regexp_replace(message, '^[[:space:]]+|[[:space:]]+$', '', 'g')
      and char_length(message) between 1 and 2000
    )
  ),
  constraint groomer_offers_status_check check (
    status in (
      'pending',
      'accepted_by_customer',
      'declined_by_customer',
      'withdrawn_by_groomer',
      'expired'
    )
  ),
  constraint groomer_offers_withdrawn_at_check check (
    (status = 'withdrawn_by_groomer' and withdrawn_at is not null)
    or (status <> 'withdrawn_by_groomer' and withdrawn_at is null)
  ),
  constraint groomer_offers_expires_at_check check (
    expires_at > created_at
  )
);

comment on table public.groomer_offers is
  'Groomer-created offer for a matched grooming request with backend-controlled status transitions.';
comment on column public.groomer_offers.price_estimate is
  'Estimated offer price supplied by the groomer. Final booking price remains a later booking concern.';
comment on column public.groomer_offers.message is
  'Optional groomer message shown to the customer before offer acceptance.';

create unique index groomer_offers_one_pending_per_request_groomer_idx
on public.groomer_offers (request_id, groomer_id)
where status = 'pending';

create index groomer_offers_customer_request_status_created_idx
on public.groomer_offers (customer_id, request_id, status, created_at desc);

create index groomer_offers_groomer_status_created_idx
on public.groomer_offers (groomer_id, status, created_at desc);

create index groomer_offers_request_status_created_idx
on public.groomer_offers (request_id, status, created_at desc);

create index groomer_offers_match_idx
on public.groomer_offers (match_id);

create trigger groomer_offers_set_updated_at
before update on public.groomer_offers
for each row execute function app_private.set_updated_at();

alter table public.groomer_offers enable row level security;

revoke all on table public.groomer_offers from public, anon, authenticated;

grant select on table public.groomer_offers to authenticated;

grant select, insert, update, delete
on table public.groomer_offers
to service_role;

create policy groomer_offers_select_participants
on public.groomer_offers
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

create function public.create_groomer_offer(
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
  'Creates one pending offer for the calling groomer on an eligible matched request.';

revoke all on function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text)
from public, anon, authenticated;

grant execute on function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text)
to authenticated, service_role;

create function public.withdraw_groomer_offer(
  p_offer_id uuid
)
returns table (
  offer_id uuid,
  offer_status text,
  withdrawn_timestamp timestamptz,
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
$$;

comment on function public.withdraw_groomer_offer(uuid) is
  'Withdraws the calling groomer''s pending offer and makes the matched request offerable again for that groomer.';

revoke all on function public.withdraw_groomer_offer(uuid)
from public, anon, authenticated;

grant execute on function public.withdraw_groomer_offer(uuid)
to authenticated, service_role;
