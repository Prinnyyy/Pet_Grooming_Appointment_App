-- T-074 corrective migration for request_matches SELECT advisor finding.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Purpose: keep one authenticated SELECT policy while preserving groomer
-- own-match visibility and customer offered-match evidence visibility.

drop policy if exists request_matches_select_customer_offered
on public.request_matches;

drop policy if exists request_matches_select_groomer_own
on public.request_matches;

create policy request_matches_select_groomer_or_customer_offered
on public.request_matches
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    (
      groomer_id = (select auth.uid())
      and exists (
        select 1
        from public.groomer_profiles
        where user_id = (select auth.uid())
      )
    )
    or (
      customer_id = (select auth.uid())
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
    )
  )
);
