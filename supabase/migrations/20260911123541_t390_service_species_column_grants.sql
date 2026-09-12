-- The existing service writer uses column privileges plus owner/role RLS.
-- New columns do not inherit earlier explicit INSERT/UPDATE column grants.
grant insert (accepted_species), update (accepted_species)
  on public.groomer_services to authenticated;
