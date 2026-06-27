-- T-100 pet coat and fit-claim save permission fix.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

grant insert (coat_type)
on table public.pets
to authenticated;

grant update (coat_type)
on table public.pets
to authenticated;

grant update (groomer_id)
on table public.groomer_fit_claims
to authenticated;
