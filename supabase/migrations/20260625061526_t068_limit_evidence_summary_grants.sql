-- T-068 corrective grant tightening for the read-only evidence summary view.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

revoke all on table public.groomer_pet_fit_evidence_summary
from public, anon, authenticated, service_role;

grant select on table public.groomer_pet_fit_evidence_summary
to authenticated, service_role;
