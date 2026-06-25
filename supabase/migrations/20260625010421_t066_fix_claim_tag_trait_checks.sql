-- T-066 corrective migration for groomer fit claims and portfolio tags.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

alter table public.groomer_fit_claims
  drop constraint groomer_fit_claims_trait_check,
  add constraint groomer_fit_claims_trait_check check (
    (
      trait_type = 'breed_group'
      and trait_value in ('poodle', 'terrier')
    )
    or (
      trait_type = 'size_band'
      and trait_value in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
    )
    or (
      trait_type = 'care_flag'
      and trait_value in ('anxious', 'senior')
    )
    or (
      trait_type = 'service_fit'
      and trait_value in (
        'curly_coat',
        'terrier_coat',
        'gentle_handling',
        'senior_care'
      )
    )
  );

alter table public.groomer_portfolio_fit_tags
  drop constraint groomer_portfolio_fit_tags_trait_check,
  add constraint groomer_portfolio_fit_tags_trait_check check (
    (
      trait_type = 'breed_group'
      and trait_value in ('poodle', 'terrier')
    )
    or (
      trait_type = 'size_band'
      and trait_value in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
    )
    or (
      trait_type = 'care_flag'
      and trait_value in ('anxious', 'senior')
    )
    or (
      trait_type = 'service_fit'
      and trait_value in (
        'curly_coat',
        'terrier_coat',
        'gentle_handling',
        'senior_care'
      )
    )
  );

revoke execute on function app_private.pet_fit_normalized_text(text)
from authenticated;
revoke execute on function app_private.pet_fit_valid_trait_pair(text, text)
from authenticated;
