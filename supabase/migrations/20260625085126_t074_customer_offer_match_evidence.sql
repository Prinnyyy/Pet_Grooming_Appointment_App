-- T-074 Customer offer match evidence RLS.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Purpose: allow customers to read backend-generated match evidence only for
-- request matches that already have an offer visible to that customer.

drop policy if exists request_matches_select_customer_offered
on public.request_matches;

create policy request_matches_select_customer_offered
on public.request_matches
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
  and exists (
    select 1
    from public.groomer_offers as offer
    where offer.match_id = request_matches.id
      and offer.request_id = request_matches.request_id
      and offer.customer_id = request_matches.customer_id
      and offer.groomer_id = request_matches.groomer_id
  )
);
