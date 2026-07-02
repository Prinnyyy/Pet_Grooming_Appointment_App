-- T-081A owner-readable groomer evidence dashboard RPC.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create function public.get_my_groomer_pet_fit_evidence_summary()
returns table (
  groomer_id uuid,
  trait_type text,
  trait_value text,
  completed_booking_count bigint,
  positive_review_outcome_count bigint,
  negative_review_outcome_count bigint,
  structured_review_outcome_count bigint,
  last_completed_at timestamptz,
  last_review_outcome_at timestamptz,
  evidence_updated_at timestamptz,
  confidence_tier text
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

  return query
  select
    summary.groomer_id,
    summary.trait_type,
    summary.trait_value,
    summary.completed_booking_count,
    summary.positive_review_outcome_count,
    summary.negative_review_outcome_count,
    summary.structured_review_outcome_count,
    summary.last_completed_at,
    summary.last_review_outcome_at,
    summary.evidence_updated_at,
    summary.confidence_tier
  from public.groomer_pet_fit_evidence_summary as summary
  where summary.groomer_id = v_user_id
  order by
    case summary.confidence_tier
      when 'high' then 1
      when 'medium' then 2
      else 3
    end,
    summary.completed_booking_count desc,
    summary.positive_review_outcome_count desc,
    summary.structured_review_outcome_count desc,
    summary.trait_type,
    summary.trait_value;
end;
$$;

comment on function public.get_my_groomer_pet_fit_evidence_summary() is
  'Owner-readable aggregate pet-fit evidence dashboard contract for the authenticated groomer. Returns only canonical trait aggregates from groomer_pet_fit_evidence_summary and never raw customer, pet, request, booking, review, or pet_snapshot details.';

revoke all on function public.get_my_groomer_pet_fit_evidence_summary()
from public, anon, authenticated, service_role;

grant execute on function public.get_my_groomer_pet_fit_evidence_summary()
to authenticated, service_role;
