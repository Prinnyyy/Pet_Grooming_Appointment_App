-- T-066 corrective migration for advisor findings.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

drop policy groomer_fit_claims_select_own
on public.groomer_fit_claims;

drop policy groomer_fit_claims_select_active_groomer
on public.groomer_fit_claims;

create policy groomer_fit_claims_select_authenticated
on public.groomer_fit_claims
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    groomer_id = (select auth.uid())
    or (
      is_active
      and exists (
        select 1
        from public.groomer_profiles
        where user_id = groomer_fit_claims.groomer_id
          and is_active
      )
    )
  )
);

drop policy groomer_portfolio_fit_tags_select_own
on public.groomer_portfolio_fit_tags;

drop policy groomer_portfolio_fit_tags_select_active_groomer
on public.groomer_portfolio_fit_tags;

create policy groomer_portfolio_fit_tags_select_authenticated
on public.groomer_portfolio_fit_tags
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    groomer_id = (select auth.uid())
    or exists (
      select 1
      from public.groomer_profiles
      where user_id = groomer_portfolio_fit_tags.groomer_id
        and is_active
    )
  )
);

create index groomer_portfolio_fit_tags_photo_groomer_idx
on public.groomer_portfolio_fit_tags (portfolio_photo_id, groomer_id);
