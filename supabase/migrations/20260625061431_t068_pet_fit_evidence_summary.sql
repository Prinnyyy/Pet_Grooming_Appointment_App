-- T-068 read-only pet-fit evidence summary.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create view public.groomer_pet_fit_evidence_summary
with (
  security_invoker = true,
  security_barrier = true
) as
with completed_booking_traits as (
  select
    booking.id as booking_id,
    booking.groomer_id,
    trait_rows.trait_type,
    trait_rows.trait_value,
    booking.completed_at
  from public.bookings as booking
  join public.grooming_requests as grooming_request
    on grooming_request.id = booking.request_id
   and grooming_request.customer_id = booking.customer_id
  cross join lateral (
    with input as (
      select
        nullif(
          lower(
            regexp_replace(
              btrim(coalesce(grooming_request.pet_snapshot ->> 'breed', '')),
              '[[:space:]]+',
              ' ',
              'g'
            )
          ),
          ''
        ) as breed,
        nullif(
          lower(
            regexp_replace(
              btrim(coalesce(grooming_request.pet_snapshot ->> 'temperament', '')),
              '[[:space:]]+',
              ' ',
              'g'
            )
          ),
          ''
        ) as temperament,
        case
          when (grooming_request.pet_snapshot ->> 'weight_lbs') ~
            '^-?[0-9]+(\.[0-9]+)?$'
          then (grooming_request.pet_snapshot ->> 'weight_lbs')::numeric
          else null::numeric
        end as weight_lbs,
        case
          when (grooming_request.pet_snapshot ->> 'birthday') ~
            '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          then (grooming_request.pet_snapshot ->> 'birthday')::date
          else null::date
        end as birthday,
        grooming_request.service_type,
        booking.completed_at::date as reference_date
    ),
    derived as (
      select
        case
          when input.breed like '%poodle%' then 'poodle'
          when input.breed like '%terrier%'
            or input.breed like '%westie%'
            or input.breed like '%west highland%'
          then 'terrier'
          else null::text
        end as breed_group,
        case
          when input.weight_lbs is null then null::text
          when input.weight_lbs < 10 then 'XS'
          when input.weight_lbs < 20 then 'S'
          when input.weight_lbs < 40 then 'M'
          when input.weight_lbs < 60 then 'L'
          when input.weight_lbs < 80 then 'XL'
          when input.weight_lbs <= 100 then 'XXL'
          else 'Giant'
        end as size_band,
        input.temperament in ('anxious', 'nervous', 'reactive') as is_anxious,
        input.birthday is not null
          and input.reference_date >=
            (input.birthday + interval '10 years')::date as is_senior,
        input.service_type
      from input
    )
    select trait_type, trait_value
    from (
      select
        10 as sort_order,
        'breed_group'::text as trait_type,
        derived.breed_group as trait_value
      from derived
      where derived.breed_group is not null

      union all

      select
        20,
        'size_band'::text,
        derived.size_band
      from derived
      where derived.size_band is not null

      union all

      select
        30,
        'care_flag'::text,
        'anxious'::text
      from derived
      where derived.is_anxious

      union all

      select
        31,
        'care_flag'::text,
        'senior'::text
      from derived
      where derived.is_senior

      union all

      select
        40,
        'service_fit'::text,
        'curly_coat'::text
      from derived
      where derived.breed_group = 'poodle'
        and derived.service_type in (
          'full_groom',
          'bath_and_brush',
          'haircut_only',
          'de_shedding',
          'custom_request'
        )

      union all

      select
        41,
        'service_fit'::text,
        'terrier_coat'::text
      from derived
      where derived.breed_group = 'terrier'
        and derived.service_type in (
          'full_groom',
          'bath_and_brush',
          'haircut_only',
          'de_shedding',
          'custom_request'
        )

      union all

      select
        42,
        'service_fit'::text,
        'gentle_handling'::text
      from derived
      where derived.is_anxious

      union all

      select
        43,
        'service_fit'::text,
        'senior_care'::text
      from derived
      where derived.is_senior
    ) as traits
    order by sort_order, trait_value
  ) as trait_rows
  where booking.status = 'completed'
),
booking_counts as (
  select
    completed_booking_traits.groomer_id,
    completed_booking_traits.trait_type,
    completed_booking_traits.trait_value,
    count(distinct completed_booking_traits.booking_id)::bigint
      as completed_booking_count,
    max(completed_booking_traits.completed_at) as last_completed_at
  from completed_booking_traits
  group by
    completed_booking_traits.groomer_id,
    completed_booking_traits.trait_type,
    completed_booking_traits.trait_value
),
review_counts as (
  select
    review_outcome.groomer_id,
    review_outcome.trait_type,
    review_outcome.trait_value,
    count(*) filter (
      where review_outcome.outcome = 'positive'
    )::bigint as positive_review_outcome_count,
    count(*) filter (
      where review_outcome.outcome = 'negative'
    )::bigint as negative_review_outcome_count,
    count(*)::bigint as structured_review_outcome_count,
    max(review_outcome.created_at) as last_review_outcome_at
  from public.review_pet_fit_outcomes as review_outcome
  join public.bookings as booking
    on booking.id = review_outcome.booking_id
   and booking.groomer_id = review_outcome.groomer_id
  where booking.status = 'completed'
  group by
    review_outcome.groomer_id,
    review_outcome.trait_type,
    review_outcome.trait_value
)
select
  coalesce(booking_counts.groomer_id, review_counts.groomer_id) as groomer_id,
  coalesce(booking_counts.trait_type, review_counts.trait_type) as trait_type,
  coalesce(booking_counts.trait_value, review_counts.trait_value) as trait_value,
  coalesce(booking_counts.completed_booking_count, 0::bigint)
    as completed_booking_count,
  coalesce(review_counts.positive_review_outcome_count, 0::bigint)
    as positive_review_outcome_count,
  coalesce(review_counts.negative_review_outcome_count, 0::bigint)
    as negative_review_outcome_count,
  coalesce(review_counts.structured_review_outcome_count, 0::bigint)
    as structured_review_outcome_count,
  booking_counts.last_completed_at,
  review_counts.last_review_outcome_at,
  case
    when booking_counts.last_completed_at is not null
      and review_counts.last_review_outcome_at is not null
    then greatest(
      booking_counts.last_completed_at,
      review_counts.last_review_outcome_at
    )
    else coalesce(
      booking_counts.last_completed_at,
      review_counts.last_review_outcome_at
    )
  end as evidence_updated_at,
  case
    when coalesce(booking_counts.completed_booking_count, 0) >= 5
      and coalesce(review_counts.positive_review_outcome_count, 0) >= 3
      and coalesce(review_counts.positive_review_outcome_count, 0) >
        coalesce(review_counts.negative_review_outcome_count, 0)
    then 'high'::text
    when coalesce(booking_counts.completed_booking_count, 0) >= 2
      and coalesce(review_counts.positive_review_outcome_count, 0) >= 1
      and coalesce(review_counts.positive_review_outcome_count, 0) >=
        coalesce(review_counts.negative_review_outcome_count, 0)
    then 'medium'::text
    else 'low'::text
  end as confidence_tier
from booking_counts
full join review_counts
  on review_counts.groomer_id = booking_counts.groomer_id
 and review_counts.trait_type = booking_counts.trait_type
 and review_counts.trait_value = booking_counts.trait_value;

comment on view public.groomer_pet_fit_evidence_summary is
  'Read-only pet-fit evidence summary grouped by groomer and canonical trait. It derives aggregate counts from completed bookings and structured review outcomes.';
comment on column public.groomer_pet_fit_evidence_summary.groomer_id is
  'Groomer whose completed bookings or structured review outcomes produced the evidence row.';
comment on column public.groomer_pet_fit_evidence_summary.trait_type is
  'Canonical T-065 trait type: breed_group, size_band, care_flag, or service_fit.';
comment on column public.groomer_pet_fit_evidence_summary.trait_value is
  'Canonical T-065 trait value for the selected trait_type.';
comment on column public.groomer_pet_fit_evidence_summary.completed_booking_count is
  'Count of completed bookings whose frozen request snapshot derives this trait.';
comment on column public.groomer_pet_fit_evidence_summary.positive_review_outcome_count is
  'Count of positive structured review outcomes recorded for this groomer and trait.';
comment on column public.groomer_pet_fit_evidence_summary.negative_review_outcome_count is
  'Count of negative structured review outcomes recorded for this groomer and trait.';
comment on column public.groomer_pet_fit_evidence_summary.structured_review_outcome_count is
  'Total structured review outcomes recorded for this groomer and trait.';
comment on column public.groomer_pet_fit_evidence_summary.last_completed_at is
  'Latest completed booking timestamp contributing snapshot-derived evidence for this trait.';
comment on column public.groomer_pet_fit_evidence_summary.last_review_outcome_at is
  'Latest structured review outcome timestamp contributing review-backed evidence for this trait.';
comment on column public.groomer_pet_fit_evidence_summary.evidence_updated_at is
  'Latest timestamp from either completed-booking or structured-review evidence.';
comment on column public.groomer_pet_fit_evidence_summary.confidence_tier is
  'Conservative derived tier: low, medium, or high based on completed-booking count and positive structured outcomes.';

revoke all on table public.groomer_pet_fit_evidence_summary
from public, anon, authenticated;

grant select on table public.groomer_pet_fit_evidence_summary
to authenticated, service_role;
