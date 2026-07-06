-- T-154: controlled expiry conversion for stale open request flows.

create extension if not exists pg_cron;

create or replace function app_private.expire_grooming_requests(
  p_batch_size integer default 250
)
returns table (
  expired_request_count integer,
  expired_offer_count integer,
  expired_match_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_batch_size integer;
  v_request_ids uuid[];
begin
  v_batch_size := greatest(1, least(coalesce(p_batch_size, 250), 1000));

  select coalesce(array_agg(candidate.id), '{}'::uuid[])
  into v_request_ids
  from (
    select grooming_request.id
    from public.grooming_requests as grooming_request
    where grooming_request.status in ('open', 'has_offers')
      and grooming_request.expires_at <= statement_timestamp()
    order by expires_at, created_at
    limit v_batch_size
    for update skip locked
  ) as candidate;

  expired_request_count := coalesce(array_length(v_request_ids, 1), 0);
  expired_offer_count := 0;
  expired_match_count := 0;

  if expired_request_count = 0 then
    return next;
    return;
  end if;

  update public.groomer_offers as groomer_offer
  set status = 'expired'
  where groomer_offer.request_id = any(v_request_ids)
    and groomer_offer.status = 'pending';

  get diagnostics expired_offer_count = row_count;

  update public.request_matches as request_match
  set status = 'expired'
  where request_match.request_id = any(v_request_ids)
    and request_match.status in ('visible', 'viewed', 'offered');

  get diagnostics expired_match_count = row_count;

  update public.grooming_requests as grooming_request
  set status = 'expired'
  where grooming_request.id = any(v_request_ids)
    and grooming_request.status in ('open', 'has_offers');

  get diagnostics expired_request_count = row_count;

  return next;
end;
$$;

comment on function app_private.expire_grooming_requests(integer) is
  'Expires stale open/has-offers grooming requests and their pending offers/active matches in bounded batches.';

revoke all on function app_private.expire_grooming_requests(integer)
from public, anon, authenticated, service_role;

grant execute on function app_private.expire_grooming_requests(integer) to service_role;

select cron.schedule(
  'groomly_expire_grooming_requests',
  '*/5 * * * *',
  $$ select app_private.expire_grooming_requests(250); $$
);
