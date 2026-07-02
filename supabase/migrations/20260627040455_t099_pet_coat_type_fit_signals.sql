-- T-099 pet coat type and professional fit-signal taxonomy.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

alter table public.pets
  add column if not exists coat_type text;

alter table public.pets
  drop constraint if exists pets_coat_type_check,
  add constraint pets_coat_type_check check (
    coat_type is null
    or coat_type in (
      'not_sure',
      'curly_wavy',
      'wire',
      'double_coat',
      'drop_coat',
      'long_silky',
      'short_smooth',
      'hairless_low_coat'
    )
  );

comment on column public.pets.coat_type is
  'Optional customer-selected coat structure used when breed is unknown or breed-derived coat inference needs confirmation.';

create or replace function app_private.pet_fit_coat_type(
  p_breed text,
  p_coat_type text default null
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  with input as (
    select
      app_private.pet_fit_normalized_text(p_breed) as breed,
      app_private.pet_fit_normalized_text(p_coat_type) as coat_type
  )
  select case
    when coat_type in (
      'curly_wavy',
      'wire',
      'double_coat',
      'drop_coat',
      'long_silky',
      'short_smooth',
      'hairless_low_coat'
    )
    then coat_type
    when breed like '%poodle%'
      or breed like '%doodle%'
      or breed like '%bichon%'
    then 'curly_wavy'
    when breed like '%schnauzer%'
      or breed like '%wire%'
      or breed like '%westie%'
      or breed like '%west highland%'
    then 'wire'
    when breed like '%husky%'
      or breed like '%shepherd%'
      or breed like '%retriever%'
      or breed like '%corgi%'
      or breed like '%shiba%'
      or breed like '%spitz%'
      or breed like '%pomeranian%'
      or breed like '%collie%'
    then 'double_coat'
    when breed like '%shih%'
      or breed like '%maltese%'
      or breed like '%york%'
    then 'drop_coat'
    when breed like '%spaniel%'
      or breed like '%cavalier%'
      or breed like '%setter%'
      or breed like '%domestic longhair%'
      or breed like '%domestic long hair%'
      or breed like '%persian%'
      or breed like '%maine coon%'
      or breed like '%ragdoll%'
    then 'long_silky'
    when breed like '%bulldog%'
      or breed like '%beagle%'
      or breed like '%boxer%'
      or breed like '%dachshund%'
      or breed like '%doberman%'
      or breed like '%great dane%'
      or breed like '%boston%'
      or breed like '%pit bull%'
      or breed like '%domestic shorthair%'
      or breed like '%domestic short hair%'
      or breed like '%siamese%'
      or breed like '%british shorthair%'
      or breed like '%bengal%'
      or breed like '%scottish fold%'
      or breed like '%russian blue%'
    then 'short_smooth'
    when breed like '%sphynx%'
      or breed like '%hairless%'
    then 'hairless_low_coat'
    else null::text
  end
  from input
$$;

create or replace function app_private.pet_fit_care_flags(
  p_temperament text,
  p_birthday date,
  p_reference_date date default current_date
)
returns text[]
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(array_agg(flag order by sort_order), array[]::text[])
  from (
    values
      (
        case
          when app_private.pet_fit_normalized_text(p_temperament) in (
            'reactive',
            'protective'
          )
          then 'reactive'::text
          else null::text
        end,
        10
      ),
      (
        case
          when app_private.pet_fit_normalized_text(p_temperament) in (
            'anxious',
            'nervous',
            'shy'
          )
          then 'anxious'::text
          else null::text
        end,
        20
      ),
      (
        case
          when p_birthday is not null
            and coalesce(p_reference_date, current_date) <
              (p_birthday + interval '18 months')::date
          then 'puppy'::text
          else null::text
        end,
        30
      ),
      (
        case
          when p_birthday is not null
            and coalesce(p_reference_date, current_date) >=
              (p_birthday + interval '10 years')::date
          then 'senior'::text
          else null::text
        end,
        40
      )
  ) as derived(flag, sort_order)
  where flag is not null
$$;

create or replace function app_private.pet_fit_service_traits(
  p_breed text,
  p_coat_type text,
  p_temperament text,
  p_birthday date,
  p_grooming_notes text,
  p_service_type text,
  p_reference_date date
)
returns text[]
language sql
stable
security invoker
set search_path = ''
as $$
  with input as (
    select
      app_private.pet_fit_breed_group(p_breed) as breed_group,
      app_private.pet_fit_coat_type(p_breed, p_coat_type) as coat_type,
      app_private.pet_fit_normalized_text(p_service_type) as service_type,
      app_private.pet_fit_normalized_text(p_grooming_notes) as grooming_notes,
      app_private.pet_fit_care_flags(
        p_temperament,
        p_birthday,
        p_reference_date
      ) as care_flags
  )
  select coalesce(array_agg(trait order by sort_order), array[]::text[])
  from (
    select
      case
        when input.service_type in ('full_groom', 'haircut_only')
        then 'full_haircut_styling'::text
        else null::text
      end as trait,
      10 as sort_order
    from input

    union all

    select
      case
        when input.service_type = 'de_shedding'
        then 'de_shedding_treatment'::text
        else null::text
      end as trait,
      20 as sort_order
    from input

    union all

    select
      case
        when input.service_type = 'nail_trim'
        then 'nail_paw_care'::text
        else null::text
      end as trait,
      30 as sort_order
    from input

    union all

    select
      case
        when input.coat_type = 'wire'
          and input.service_type in (
            'full_groom',
            'bath_and_brush',
            'haircut_only',
            'de_shedding',
            'custom_request'
          )
        then 'hand_stripping_carding'::text
        else null::text
      end as trait,
      40 as sort_order
    from input

    union all

    select
      case
        when input.breed_group = 'poodle'
          and input.service_type in (
            'full_groom',
            'bath_and_brush',
            'haircut_only',
            'de_shedding',
            'custom_request'
          )
        then 'curly_coat'::text
        else null::text
      end as trait,
      50 as sort_order
    from input

    union all

    select
      case
        when input.breed_group = 'terrier'
          and input.service_type in (
            'full_groom',
            'bath_and_brush',
            'haircut_only',
            'de_shedding',
            'custom_request'
          )
        then 'terrier_coat'::text
        else null::text
      end as trait,
      60 as sort_order
    from input

    union all

    select 'gentle_handling'::text, 70
    from input
    where 'anxious' = any(input.care_flags)

    union all

    select 'reactive_low_tolerance'::text, 80
    from input
    where 'reactive' = any(input.care_flags)

    union all

    select 'puppy_first_groom'::text, 90
    from input
    where 'puppy' = any(input.care_flags)

    union all

    select 'senior_care'::text, 100
    from input
    where 'senior' = any(input.care_flags)

    union all

    select 'matted_coat_handling'::text, 110
    from input
    where input.grooming_notes like '%mat%'
      or input.grooming_notes like '%tangle%'
      or input.grooming_notes like '%knot%'
  ) as derived
  where trait is not null
$$;

create or replace function app_private.pet_fit_service_traits(
  p_breed text,
  p_temperament text,
  p_birthday date,
  p_service_type text,
  p_reference_date date default current_date
)
returns text[]
language sql
stable
security invoker
set search_path = ''
as $$
  select app_private.pet_fit_service_traits(
    p_breed,
    null::text,
    p_temperament,
    p_birthday,
    null::text,
    p_service_type,
    p_reference_date
  )
$$;

create or replace function app_private.pet_fit_valid_trait_pair(
  p_trait_type text,
  p_trait_value text
)
returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  with normalized as (
    select
      app_private.pet_fit_normalized_text(p_trait_type) as trait_type,
      app_private.pet_fit_normalized_text(p_trait_value) as trait_value
  )
  select case
    when trait_type = 'coat_type' then trait_value in (
      'curly_wavy',
      'wire',
      'double_coat',
      'drop_coat',
      'long_silky',
      'short_smooth',
      'hairless_low_coat'
    )
    when trait_type = 'breed_group' then trait_value in ('poodle', 'terrier')
    when trait_type = 'size_band' then trait_value in (
      'xs',
      's',
      'm',
      'l',
      'xl',
      'xxl',
      'giant'
    )
    when trait_type = 'care_flag' then trait_value in (
      'anxious',
      'reactive',
      'puppy',
      'senior'
    )
    when trait_type = 'service_fit' then trait_value in (
      'curly_coat',
      'de_shedding_treatment',
      'full_haircut_styling',
      'gentle_handling',
      'hand_stripping_carding',
      'matted_coat_handling',
      'nail_paw_care',
      'puppy_first_groom',
      'reactive_low_tolerance',
      'senior_care',
      'terrier_coat'
    )
    else false
  end
  from normalized
$$;

create or replace function app_private.pet_fit_request_traits(
  p_breed text,
  p_coat_type text,
  p_weight_lbs numeric,
  p_temperament text,
  p_birthday date,
  p_grooming_notes text,
  p_service_type text,
  p_reference_date date default current_date
)
returns table (
  trait_type text,
  trait_value text
)
language sql
stable
security invoker
set search_path = ''
as $$
  with derived as (
    select
      app_private.pet_fit_coat_type(p_breed, p_coat_type) as coat_type,
      app_private.pet_fit_breed_group(p_breed) as breed_group,
      app_private.pet_fit_size_band(p_weight_lbs) as size_band,
      app_private.pet_fit_care_flags(
        p_temperament,
        p_birthday,
        p_reference_date
      ) as care_flags,
      app_private.pet_fit_service_traits(
        p_breed,
        p_coat_type,
        p_temperament,
        p_birthday,
        p_grooming_notes,
        p_service_type,
        p_reference_date
      ) as service_traits
  )
  select trait_type, trait_value
  from (
    select 10 as sort_order, 'coat_type'::text as trait_type, coat_type as trait_value
    from derived
    where coat_type is not null

    union all

    select 20, 'breed_group'::text, breed_group
    from derived
    where breed_group is not null

    union all

    select 30, 'size_band'::text, size_band
    from derived
    where size_band is not null

    union all

    select 40, 'care_flag'::text, care_flag
    from derived, unnest(care_flags) as care_flag

    union all

    select 50, 'service_fit'::text, service_trait
    from derived, unnest(service_traits) as service_trait
  ) as traits
  order by sort_order, trait_value
$$;

create or replace function app_private.pet_fit_request_traits(
  p_breed text,
  p_weight_lbs numeric,
  p_temperament text,
  p_birthday date,
  p_service_type text,
  p_reference_date date default current_date
)
returns table (
  trait_type text,
  trait_value text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select trait_type, trait_value
  from app_private.pet_fit_request_traits(
    p_breed,
    null::text,
    p_weight_lbs,
    p_temperament,
    p_birthday,
    null::text,
    p_service_type,
    p_reference_date
  )
$$;

create or replace function app_private.pet_fit_traits_from_snapshot(
  p_pet_snapshot jsonb,
  p_service_type text,
  p_reference_date date default current_date
)
returns table (
  trait_type text,
  trait_value text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select trait_type, trait_value
  from app_private.pet_fit_request_traits(
    p_pet_snapshot ->> 'breed',
    p_pet_snapshot ->> 'coat_type',
    case
      when (p_pet_snapshot ->> 'weight_lbs') ~ '^-?[0-9]+(\.[0-9]+)?$'
      then (p_pet_snapshot ->> 'weight_lbs')::numeric
      else null::numeric
    end,
    p_pet_snapshot ->> 'temperament',
    case
      when (p_pet_snapshot ->> 'birthday') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      then (p_pet_snapshot ->> 'birthday')::date
      else null::date
    end,
    p_pet_snapshot ->> 'grooming_notes',
    p_service_type,
    p_reference_date
  )
$$;

create or replace function app_private.pet_fit_trait_sort(
  p_trait_type text
)
returns integer
language sql
immutable
security invoker
set search_path = ''
as $$
  select case app_private.pet_fit_normalized_text(p_trait_type)
    when 'coat_type' then 1
    when 'service_fit' then 2
    when 'breed_group' then 3
    when 'care_flag' then 4
    when 'size_band' then 5
    else 99
  end
$$;

create or replace function app_private.pet_fit_trait_label(
  p_trait_type text,
  p_trait_value text
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  with normalized as (
    select
      app_private.pet_fit_normalized_text(p_trait_type) as trait_type,
      app_private.pet_fit_normalized_text(p_trait_value) as trait_value
  )
  select case
    when trait_type = 'coat_type' and trait_value = 'curly_wavy'
    then 'curly/wavy coats'
    when trait_type = 'coat_type' and trait_value = 'wire'
    then 'wire coats'
    when trait_type = 'coat_type' and trait_value = 'double_coat'
    then 'double coats'
    when trait_type = 'coat_type' and trait_value = 'drop_coat'
    then 'drop coats'
    when trait_type = 'coat_type' and trait_value = 'long_silky'
    then 'long silky coats'
    when trait_type = 'coat_type' and trait_value = 'short_smooth'
    then 'short smooth coats'
    when trait_type = 'coat_type' and trait_value = 'hairless_low_coat'
    then 'hairless or low-coat pets'
    when trait_type = 'breed_group' and trait_value = 'poodle'
    then 'poodles'
    when trait_type = 'breed_group' and trait_value = 'terrier'
    then 'terriers'
    when trait_type = 'size_band' and trait_value = 'xs'
    then 'extra-small pets'
    when trait_type = 'size_band' and trait_value = 's'
    then 'small pets'
    when trait_type = 'size_band' and trait_value = 'm'
    then 'medium pets'
    when trait_type = 'size_band' and trait_value = 'l'
    then 'large pets'
    when trait_type = 'size_band' and trait_value = 'xl'
    then 'extra-large pets'
    when trait_type = 'size_band' and trait_value = 'xxl'
    then 'very large pets'
    when trait_type = 'size_band' and trait_value = 'giant'
    then 'giant pets'
    when trait_type = 'care_flag' and trait_value = 'anxious'
    then 'anxious pets'
    when trait_type = 'care_flag' and trait_value = 'reactive'
    then 'reactive pets'
    when trait_type = 'care_flag' and trait_value = 'puppy'
    then 'puppies or first grooms'
    when trait_type = 'care_flag' and trait_value = 'senior'
    then 'senior pets'
    when trait_type = 'service_fit' and trait_value = 'curly_coat'
    then 'curly coats'
    when trait_type = 'service_fit' and trait_value = 'de_shedding_treatment'
    then 'de-shedding treatments'
    when trait_type = 'service_fit' and trait_value = 'full_haircut_styling'
    then 'full haircut and styling'
    when trait_type = 'service_fit' and trait_value = 'gentle_handling'
    then 'gentle handling'
    when trait_type = 'service_fit' and trait_value = 'hand_stripping_carding'
    then 'hand stripping or carding'
    when trait_type = 'service_fit' and trait_value = 'matted_coat_handling'
    then 'matted coat handling'
    when trait_type = 'service_fit' and trait_value = 'nail_paw_care'
    then 'nail and paw care'
    when trait_type = 'service_fit' and trait_value = 'puppy_first_groom'
    then 'puppy or first-groom handling'
    when trait_type = 'service_fit' and trait_value = 'reactive_low_tolerance'
    then 'reactive or low-tolerance handling'
    when trait_type = 'service_fit' and trait_value = 'senior_care'
    then 'senior care'
    when trait_type = 'service_fit' and trait_value = 'terrier_coat'
    then 'terrier coats'
    else replace(coalesce(trait_value, ''), '_', ' ')
  end
  from normalized
$$;

comment on function app_private.pet_fit_coat_type(text, text) is
  'Maps an explicit customer coat type or breed text to the T-099 coat_type vocabulary.';
comment on function app_private.pet_fit_care_flags(text, date, date) is
  'Derives care flags such as anxious, reactive, puppy, and senior from request pet snapshot fields.';
comment on function app_private.pet_fit_service_traits(text, text, date, text, date) is
  'Compatibility overload for legacy T-065 service-fit derivation without explicit coat type or grooming notes.';
comment on function app_private.pet_fit_service_traits(text, text, text, date, text, text, date) is
  'Derives service-fit traits from breed, coat type, care flags, notes, and requested service.';
comment on function app_private.pet_fit_valid_trait_pair(text, text) is
  'Validates T-099 pet-fit trait type/value pairs for claim, tag, review, evidence, and scoring tables.';
comment on function app_private.pet_fit_request_traits(text, numeric, text, date, text, date) is
  'Compatibility overload returning normalized pet-fit trait rows from legacy request pet fields.';
comment on function app_private.pet_fit_request_traits(text, text, numeric, text, date, text, text, date) is
  'Returns normalized pet-fit trait rows from request pet fields, including explicit coat type and grooming notes.';
comment on function app_private.pet_fit_traits_from_snapshot(jsonb, text, date) is
  'Returns normalized pet-fit trait rows from grooming_requests.pet_snapshot JSON for matching evidence and scoring.';
comment on function app_private.pet_fit_trait_sort(text) is
  'Returns stable pet-fit trait ordering used by matching reason text.';
comment on function app_private.pet_fit_trait_label(text, text) is
  'Returns customer-safe pet-fit trait labels used by matching reason text.';

revoke all on function app_private.pet_fit_coat_type(text, text)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_care_flags(text, date, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_service_traits(text, text, date, text, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_service_traits(text, text, text, date, text, text, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_valid_trait_pair(text, text)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_request_traits(text, numeric, text, date, text, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_request_traits(text, text, numeric, text, date, text, text, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_traits_from_snapshot(jsonb, text, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_trait_sort(text)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_trait_label(text, text)
from public, anon, authenticated;

grant execute on function app_private.pet_fit_coat_type(text, text)
to service_role;
grant execute on function app_private.pet_fit_care_flags(text, date, date)
to service_role;
grant execute on function app_private.pet_fit_service_traits(text, text, date, text, date)
to service_role;
grant execute on function app_private.pet_fit_service_traits(text, text, text, date, text, text, date)
to service_role;
grant execute on function app_private.pet_fit_valid_trait_pair(text, text)
to service_role;
grant execute on function app_private.pet_fit_request_traits(text, numeric, text, date, text, date)
to service_role;
grant execute on function app_private.pet_fit_request_traits(text, text, numeric, text, date, text, text, date)
to service_role;
grant execute on function app_private.pet_fit_traits_from_snapshot(jsonb, text, date)
to service_role;
grant execute on function app_private.pet_fit_trait_sort(text)
to service_role;
grant execute on function app_private.pet_fit_trait_label(text, text)
to service_role;

alter table public.groomer_fit_claims
  drop constraint groomer_fit_claims_trait_check,
  add constraint groomer_fit_claims_trait_check check (
    (
      trait_type = 'coat_type'
      and trait_value in (
        'curly_wavy',
        'wire',
        'double_coat',
        'drop_coat',
        'long_silky',
        'short_smooth',
        'hairless_low_coat'
      )
    )
    or (
      trait_type = 'breed_group'
      and trait_value in ('poodle', 'terrier')
    )
    or (
      trait_type = 'size_band'
      and trait_value in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
    )
    or (
      trait_type = 'care_flag'
      and trait_value in ('anxious', 'reactive', 'puppy', 'senior')
    )
    or (
      trait_type = 'service_fit'
      and trait_value in (
        'curly_coat',
        'de_shedding_treatment',
        'full_haircut_styling',
        'gentle_handling',
        'hand_stripping_carding',
        'matted_coat_handling',
        'nail_paw_care',
        'puppy_first_groom',
        'reactive_low_tolerance',
        'senior_care',
        'terrier_coat'
      )
    )
  );

alter table public.groomer_portfolio_fit_tags
  drop constraint groomer_portfolio_fit_tags_trait_check,
  add constraint groomer_portfolio_fit_tags_trait_check check (
    (
      trait_type = 'coat_type'
      and trait_value in (
        'curly_wavy',
        'wire',
        'double_coat',
        'drop_coat',
        'long_silky',
        'short_smooth',
        'hairless_low_coat'
      )
    )
    or (
      trait_type = 'breed_group'
      and trait_value in ('poodle', 'terrier')
    )
    or (
      trait_type = 'size_band'
      and trait_value in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
    )
    or (
      trait_type = 'care_flag'
      and trait_value in ('anxious', 'reactive', 'puppy', 'senior')
    )
    or (
      trait_type = 'service_fit'
      and trait_value in (
        'curly_coat',
        'de_shedding_treatment',
        'full_haircut_styling',
        'gentle_handling',
        'hand_stripping_carding',
        'matted_coat_handling',
        'nail_paw_care',
        'puppy_first_groom',
        'reactive_low_tolerance',
        'senior_care',
        'terrier_coat'
      )
    )
  );

alter table public.review_pet_fit_outcomes
  drop constraint review_pet_fit_outcomes_trait_check,
  add constraint review_pet_fit_outcomes_trait_check check (
    (
      trait_type = 'coat_type'
      and trait_value in (
        'curly_wavy',
        'wire',
        'double_coat',
        'drop_coat',
        'long_silky',
        'short_smooth',
        'hairless_low_coat'
      )
    )
    or (
      trait_type = 'breed_group'
      and trait_value in ('poodle', 'terrier')
    )
    or (
      trait_type = 'size_band'
      and trait_value in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
    )
    or (
      trait_type = 'care_flag'
      and trait_value in ('anxious', 'reactive', 'puppy', 'senior')
    )
    or (
      trait_type = 'service_fit'
      and trait_value in (
        'curly_coat',
        'de_shedding_treatment',
        'full_haircut_styling',
        'gentle_handling',
        'hand_stripping_carding',
        'matted_coat_handling',
        'nail_paw_care',
        'puppy_first_groom',
        'reactive_low_tolerance',
        'senior_care',
        'terrier_coat'
      )
    )
  );

create or replace view public.groomer_pet_fit_evidence_summary
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
              btrim(coalesce(grooming_request.pet_snapshot ->> 'coat_type', '')),
              '[[:space:]]+',
              ' ',
              'g'
            )
          ),
          ''
        ) as coat_type,
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
        nullif(
          lower(
            regexp_replace(
              btrim(coalesce(grooming_request.pet_snapshot ->> 'grooming_notes', '')),
              '[[:space:]]+',
              ' ',
              'g'
            )
          ),
          ''
        ) as grooming_notes,
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
          when input.coat_type in (
            'curly_wavy',
            'wire',
            'double_coat',
            'drop_coat',
            'long_silky',
            'short_smooth',
            'hairless_low_coat'
          )
          then input.coat_type
          when input.breed like '%poodle%'
            or input.breed like '%doodle%'
            or input.breed like '%bichon%'
          then 'curly_wavy'
          when input.breed like '%schnauzer%'
            or input.breed like '%wire%'
            or input.breed like '%westie%'
            or input.breed like '%west highland%'
          then 'wire'
          when input.breed like '%husky%'
            or input.breed like '%shepherd%'
            or input.breed like '%retriever%'
            or input.breed like '%corgi%'
            or input.breed like '%shiba%'
            or input.breed like '%spitz%'
            or input.breed like '%pomeranian%'
            or input.breed like '%collie%'
          then 'double_coat'
          when input.breed like '%shih%'
            or input.breed like '%maltese%'
            or input.breed like '%york%'
          then 'drop_coat'
          when input.breed like '%spaniel%'
            or input.breed like '%cavalier%'
            or input.breed like '%setter%'
            or input.breed like '%domestic longhair%'
            or input.breed like '%domestic long hair%'
            or input.breed like '%persian%'
            or input.breed like '%maine coon%'
            or input.breed like '%ragdoll%'
          then 'long_silky'
          when input.breed like '%bulldog%'
            or input.breed like '%beagle%'
            or input.breed like '%boxer%'
            or input.breed like '%dachshund%'
            or input.breed like '%doberman%'
            or input.breed like '%great dane%'
            or input.breed like '%boston%'
            or input.breed like '%pit bull%'
            or input.breed like '%domestic shorthair%'
            or input.breed like '%domestic short hair%'
            or input.breed like '%siamese%'
            or input.breed like '%british shorthair%'
            or input.breed like '%bengal%'
            or input.breed like '%scottish fold%'
            or input.breed like '%russian blue%'
          then 'short_smooth'
          when input.breed like '%sphynx%'
            or input.breed like '%hairless%'
          then 'hairless_low_coat'
          else null::text
        end as coat_type,
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
        input.temperament in ('anxious', 'nervous', 'shy') as is_anxious,
        input.temperament in ('reactive', 'protective') as is_reactive,
        input.birthday is not null
          and input.reference_date <
            (input.birthday + interval '18 months')::date as is_puppy,
        input.birthday is not null
          and input.reference_date >=
            (input.birthday + interval '10 years')::date as is_senior,
        input.grooming_notes like '%mat%'
          or input.grooming_notes like '%tangle%'
          or input.grooming_notes like '%knot%' as has_matted_notes,
        input.service_type
      from input
    )
    select trait_type, trait_value
    from (
      select
        10 as sort_order,
        'coat_type'::text as trait_type,
        derived.coat_type as trait_value
      from derived
      where derived.coat_type is not null

      union all

      select
        20,
        'breed_group'::text,
        derived.breed_group
      from derived
      where derived.breed_group is not null

      union all

      select
        30,
        'size_band'::text,
        derived.size_band
      from derived
      where derived.size_band is not null

      union all

      select 40, 'care_flag'::text, 'anxious'::text
      from derived
      where derived.is_anxious

      union all

      select 41, 'care_flag'::text, 'reactive'::text
      from derived
      where derived.is_reactive

      union all

      select 42, 'care_flag'::text, 'puppy'::text
      from derived
      where derived.is_puppy

      union all

      select 43, 'care_flag'::text, 'senior'::text
      from derived
      where derived.is_senior

      union all

      select 50, 'service_fit'::text, 'full_haircut_styling'::text
      from derived
      where derived.service_type in ('full_groom', 'haircut_only')

      union all

      select 51, 'service_fit'::text, 'de_shedding_treatment'::text
      from derived
      where derived.service_type = 'de_shedding'

      union all

      select 52, 'service_fit'::text, 'nail_paw_care'::text
      from derived
      where derived.service_type = 'nail_trim'

      union all

      select 53, 'service_fit'::text, 'hand_stripping_carding'::text
      from derived
      where derived.coat_type = 'wire'
        and derived.service_type in (
          'full_groom',
          'bath_and_brush',
          'haircut_only',
          'de_shedding',
          'custom_request'
        )

      union all

      select 54, 'service_fit'::text, 'curly_coat'::text
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

      select 55, 'service_fit'::text, 'terrier_coat'::text
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

      select 56, 'service_fit'::text, 'gentle_handling'::text
      from derived
      where derived.is_anxious

      union all

      select 57, 'service_fit'::text, 'reactive_low_tolerance'::text
      from derived
      where derived.is_reactive

      union all

      select 58, 'service_fit'::text, 'puppy_first_groom'::text
      from derived
      where derived.is_puppy

      union all

      select 59, 'service_fit'::text, 'senior_care'::text
      from derived
      where derived.is_senior

      union all

      select 60, 'service_fit'::text, 'matted_coat_handling'::text
      from derived
      where derived.has_matted_notes
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
comment on column public.groomer_pet_fit_evidence_summary.trait_type is
  'Canonical T-099 trait type: coat_type, breed_group, size_band, care_flag, or service_fit.';
comment on column public.groomer_pet_fit_evidence_summary.trait_value is
  'Canonical T-099 trait value for the selected trait_type.';

revoke all on table public.groomer_pet_fit_evidence_summary
from public, anon, authenticated;

grant select on table public.groomer_pet_fit_evidence_summary
to authenticated, service_role;

create or replace function public.create_review(
  p_booking_id uuid,
  p_rating integer,
  p_content text default null,
  p_pet_fit_outcomes jsonb default '[]'::jsonb
)
returns table (
  review_id uuid,
  booking_id uuid,
  customer_id uuid,
  groomer_id uuid,
  rating integer,
  content text,
  created_at timestamptz,
  groomer_rating_avg numeric,
  groomer_rating_count integer
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
  v_booking_id uuid;
  v_customer_id uuid;
  v_groomer_id uuid;
  v_booking_status text;
  v_content text := nullif(
    regexp_replace(
      coalesce(p_content, ''),
      '^[[:space:]]+|[[:space:]]+$',
      '',
      'g'
    ),
    ''
  );
  v_review_id uuid;
  v_created_at timestamptz;
  v_old_rating_avg numeric(3, 2);
  v_old_rating_count integer;
  v_new_rating_avg numeric(3, 2);
  v_new_rating_count integer;
  v_pet_fit_outcomes jsonb := coalesce(p_pet_fit_outcomes, '[]'::jsonb);
  v_outcome_item jsonb;
  v_trait_type text;
  v_trait_value text;
  v_outcome text;
  v_seen_outcome_keys text[] := array[]::text[];
  v_seen_outcome_key text;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_booking_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_booking';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception using
      errcode = '22023',
      message = 'invalid_rating';
  end if;

  if v_content is not null and char_length(v_content) > 2000 then
    raise exception using
      errcode = '22023',
      message = 'invalid_review_content';
  end if;

  if jsonb_typeof(v_pet_fit_outcomes) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'invalid_review_outcomes';
  end if;

  if jsonb_array_length(v_pet_fit_outcomes) > 20 then
    raise exception using
      errcode = '22023',
      message = 'too_many_review_outcomes';
  end if;

  perform 1
  from public.customer_profiles as customer_profile
  join public.profiles as profile
    on profile.id = customer_profile.user_id
  where customer_profile.user_id = v_user_id
    and profile.role = 'customer'::public.user_role;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'customer_profile_required';
  end if;

  select
    booking.id,
    booking.customer_id,
    booking.groomer_id,
    booking.status
  into
    v_booking_id,
    v_customer_id,
    v_groomer_id,
    v_booking_status
  from public.bookings as booking
  where booking.id = p_booking_id
    and booking.customer_id = v_user_id
  for update of booking;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_found';
  end if;

  if v_booking_status <> 'completed' then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_completed';
  end if;

  select
    groomer_profile.rating_avg,
    groomer_profile.rating_count
  into
    v_old_rating_avg,
    v_old_rating_count
  from public.groomer_profiles as groomer_profile
  where groomer_profile.user_id = v_groomer_id
  for update of groomer_profile;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_profile_required';
  end if;

  begin
    insert into public.reviews as review (
      booking_id,
      customer_id,
      groomer_id,
      rating,
      content
    )
    values (
      v_booking_id,
      v_customer_id,
      v_groomer_id,
      p_rating,
      v_content
    )
    returning
      review.id,
      review.created_at
    into
      v_review_id,
      v_created_at;
  exception
    when unique_violation then
      raise exception using
        errcode = 'P0001',
        message = 'review_already_exists';
  end;

  for v_outcome_item in
    select value
    from jsonb_array_elements(v_pet_fit_outcomes)
  loop
    if jsonb_typeof(v_outcome_item) <> 'object' then
      raise exception using
        errcode = '22023',
        message = 'invalid_review_outcomes';
    end if;

    v_trait_type := v_outcome_item ->> 'trait_type';
    v_trait_value := v_outcome_item ->> 'trait_value';
    v_outcome := v_outcome_item ->> 'outcome';

    if not app_private.pet_fit_valid_trait_pair(v_trait_type, v_trait_value) then
      raise exception using
        errcode = '22023',
        message = 'invalid_review_outcome_trait';
    end if;

    if v_outcome is null or v_outcome not in ('positive', 'negative') then
      raise exception using
        errcode = '22023',
        message = 'invalid_review_outcome_value';
    end if;

    v_seen_outcome_key := v_trait_type || ':' || v_trait_value;

    if v_seen_outcome_key = any(v_seen_outcome_keys) then
      raise exception using
        errcode = '22023',
        message = 'duplicate_review_outcome';
    end if;

    v_seen_outcome_keys := array_append(
      v_seen_outcome_keys,
      v_seen_outcome_key
    );

    insert into public.review_pet_fit_outcomes (
      review_id,
      booking_id,
      customer_id,
      groomer_id,
      trait_type,
      trait_value,
      outcome
    )
    values (
      v_review_id,
      v_booking_id,
      v_customer_id,
      v_groomer_id,
      v_trait_type,
      v_trait_value,
      v_outcome
    );
  end loop;

  v_new_rating_count := v_old_rating_count + 1;
  v_new_rating_avg := round(
    ((v_old_rating_avg * v_old_rating_count) + p_rating)::numeric
    / v_new_rating_count,
    2
  );

  update public.groomer_profiles as groomer_profile
  set
    rating_avg = v_new_rating_avg,
    rating_count = v_new_rating_count
  where groomer_profile.user_id = v_groomer_id
  returning
    groomer_profile.rating_avg,
    groomer_profile.rating_count
  into
    v_new_rating_avg,
    v_new_rating_count;

  return query
  select
    v_review_id,
    v_booking_id,
    v_customer_id,
    v_groomer_id,
    p_rating,
    v_content,
    v_created_at,
    v_new_rating_avg,
    v_new_rating_count;
end;
$$;

comment on function public.create_review(uuid, integer, text, jsonb) is
  'Creates the single customer review for a completed booking, optionally records structured T-099 pet-fit outcomes, and updates the groomer rating summary.';

revoke all on function public.create_review(uuid, integer, text, jsonb)
from public, anon, authenticated;

grant execute on function public.create_review(uuid, integer, text, jsonb)
to authenticated, service_role;

create or replace function public.create_grooming_request(
  p_pet_id uuid,
  p_service_type text,
  p_service_notes text,
  p_preferred_start timestamptz,
  p_preferred_end timestamptz,
  p_location_mode text,
  p_street_address text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_travel_radius_miles integer default null
)
returns table (
  request_id uuid,
  match_count integer
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
  v_service_type text := lower(btrim(p_service_type));
  v_service_notes text := nullif(btrim(p_service_notes), '');
  v_location_mode text := lower(btrim(p_location_mode));
  v_street_address text := btrim(p_street_address);
  v_city text := btrim(p_city);
  v_state text := upper(btrim(p_state));
  v_zip_code text := btrim(p_zip_code);
  v_travel_radius_miles integer := p_travel_radius_miles;
  v_open_request_count integer;
  v_request_id uuid;
  v_match_count integer := 0;
  v_pet public.pets%rowtype;
  v_pet_snapshot jsonb;
  v_photo_snapshot jsonb;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  perform 1
  from public.customer_profiles as customer_profile
  join public.profiles as profile
    on profile.id = customer_profile.user_id
  where customer_profile.user_id = v_user_id
    and profile.role = 'customer'::public.user_role
  for update of customer_profile;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'customer_profile_required';
  end if;

  if p_pet_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_pet';
  end if;

  if v_service_type not in (
    'full_groom',
    'bath_and_brush',
    'haircut_only',
    'nail_trim',
    'de_shedding',
    'custom_request'
  ) then
    raise exception using
      errcode = '22023',
      message = 'invalid_service_type';
  end if;

  if v_service_notes is not null
    and char_length(v_service_notes) > 2000
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_service_notes';
  end if;

  if p_preferred_start is null
    or p_preferred_end is null
    or p_preferred_start <= statement_timestamp()
    or p_preferred_end <= p_preferred_start
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_preferred_range';
  end if;

  if v_location_mode not in (
    'groomer_comes_to_customer',
    'customer_comes_to_groomer'
  ) then
    raise exception using
      errcode = '22023',
      message = 'invalid_location_mode';
  end if;

  if v_street_address is null
    or char_length(v_street_address) not between 1 and 160
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_street_address';
  end if;

  if v_city is null
    or char_length(v_city) not between 1 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_city';
  end if;

  if v_state is null
    or v_state !~ '^[A-Z]{2}$'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_state';
  end if;

  if v_zip_code is null
    or v_zip_code !~ '^[0-9]{5}(-[0-9]{4})?$'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_zip_code';
  end if;

  if v_location_mode = 'groomer_comes_to_customer' then
    v_travel_radius_miles := null;
  elsif v_travel_radius_miles is null
    or v_travel_radius_miles not between 5 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_travel_radius';
  end if;

  select count(*)::integer
  into v_open_request_count
  from public.grooming_requests as request
  where request.customer_id = v_user_id
    and request.status in ('open', 'has_offers')
    and request.expires_at > statement_timestamp();

  if v_open_request_count >= 3 then
    raise exception using
      errcode = 'P0001',
      message = 'open_request_limit_exceeded';
  end if;

  select pet.*
  into v_pet
  from public.pets as pet
  where pet.id = p_pet_id
    and pet.customer_id = v_user_id
    and pet.is_active
    and pet.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'pet_not_found';
  end if;

  v_pet_snapshot := jsonb_build_object(
    'id', v_pet.id,
    'name', v_pet.name,
    'species', v_pet.species,
    'breed', v_pet.breed,
    'coat_type', v_pet.coat_type,
    'size', v_pet.size,
    'weight_lbs', v_pet.weight_lbs,
    'birthday', v_pet.birthday,
    'temperament', v_pet.temperament,
    'medical_notes', v_pet.medical_notes,
    'grooming_notes', v_pet.grooming_notes,
    'snapshot_at', statement_timestamp()
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', photo.id,
        'storage_bucket', photo.storage_bucket,
        'storage_path', photo.storage_path,
        'caption', photo.caption,
        'sort_order', photo.sort_order,
        'is_primary', photo.is_primary,
        'created_at', photo.created_at
      )
      order by photo.is_primary desc, photo.sort_order, photo.created_at
    ),
    '[]'::jsonb
  )
  into v_photo_snapshot
  from (
    select photo.*
    from public.pet_photos as photo
    where photo.customer_id = v_user_id
      and photo.pet_id = p_pet_id
    order by photo.is_primary desc, photo.sort_order, photo.created_at
    limit 20
  ) as photo;

  insert into public.grooming_requests (
    customer_id,
    pet_id,
    pet_snapshot,
    photo_snapshot,
    service_type,
    service_notes,
    preferred_start,
    preferred_end,
    location_mode,
    street_address,
    city,
    state,
    zip_code,
    travel_radius_miles,
    status,
    expires_at
  )
  values (
    v_user_id,
    p_pet_id,
    v_pet_snapshot,
    v_photo_snapshot,
    v_service_type,
    v_service_notes,
    p_preferred_start,
    p_preferred_end,
    v_location_mode,
    v_street_address,
    v_city,
    v_state,
    v_zip_code,
    v_travel_radius_miles,
    'open',
    statement_timestamp() + interval '48 hours'
  )
  returning id into v_request_id;

  with request_traits as materialized (
    select trait_type, trait_value
    from app_private.pet_fit_traits_from_snapshot(
      v_pet_snapshot,
      v_service_type,
      p_preferred_start::date
    )
  ),
  eligible_groomers as (
    select
      groomer_profile.user_id,
      case
        when groomer_profile.base_state = v_state
          and lower(groomer_profile.base_city) = lower(v_city)
        then 80
        when groomer_profile.base_state = v_state
        then 60
        else 50
      end as location_score,
      case
        when groomer_profile.base_state = v_state
          and lower(groomer_profile.base_city) = lower(v_city)
        then 'Same city and service location'
        when groomer_profile.base_state = v_state
        then 'Same state and service location'
        else 'Same city name and service location'
      end as location_reason
    from public.groomer_profiles as groomer_profile
    join public.profiles as profile
      on profile.id = groomer_profile.user_id
    where profile.role = 'groomer'::public.user_role
      and groomer_profile.is_active
      and (
        groomer_profile.service_location_modes @> array[v_location_mode]::text[]
        or (
          groomer_profile.service_location_modes is null
          and groomer_profile.service_location_mode = v_location_mode
        )
      )
      and (
        groomer_profile.base_state = v_state
        or lower(groomer_profile.base_city) = lower(v_city)
      )
      and exists (
        select 1
        from public.groomer_services as groomer_service
        where groomer_service.groomer_id = groomer_profile.user_id
          and groomer_service.is_active
          and groomer_service.service_type = v_service_type
      )
      and app_private.groomer_is_available_for_range(
        groomer_profile.user_id,
        p_preferred_start,
        p_preferred_end
      )
  )
  insert into public.request_matches (
    request_id,
    groomer_id,
    customer_id,
    match_score,
    match_reason,
    status
  )
  select
    v_request_id,
    eligible_groomer.user_id,
    v_user_id,
    greatest(
      0,
      least(
        100,
        eligible_groomer.location_score +
          coalesce(pet_fit.adjustment, 0) +
          case
            when coalesce(pet_fit.has_negative_evidence, false) then 0
            else coalesce(claim_tag_fit.adjustment, 0)
          end
      )
    )::numeric(5, 2),
    left(
      case
        when pet_fit.reason_text is null
          and (
            claim_tag_fit.reason_text is null
            or coalesce(pet_fit.has_negative_evidence, false)
          )
        then
          eligible_groomer.location_reason || '.'
        when pet_fit.reason_text is not null
          and claim_tag_fit.reason_text is not null
          and not coalesce(pet_fit.has_negative_evidence, false)
        then
          eligible_groomer.location_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
        when pet_fit.reason_text is not null then
          eligible_groomer.location_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '.'
        else
          eligible_groomer.location_reason ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
      end,
      500
    ),
    'visible'
  from eligible_groomers as eligible_groomer
  left join lateral (
    select
      greatest(
        -10,
        least(20, coalesce(sum(ranked_evidence.evidence_points), 0))
      )::integer as adjustment,
      coalesce(
        bool_or(ranked_evidence.evidence_points < 0),
        false
      ) as has_negative_evidence,
      string_agg(
        ranked_evidence.reason_label,
        ', '
        order by
          case
            when ranked_evidence.evidence_points < 0 then 0
            else 1
          end,
          case
            when ranked_evidence.evidence_points < 0
            then ranked_evidence.evidence_points
            else -ranked_evidence.evidence_points
          end,
          ranked_evidence.trait_sort,
          ranked_evidence.trait_value
      ) as reason_text
    from (
      select prioritized_evidence.*
      from (
        select
          evidence.*,
          row_number() over (
            order by
              case
                when evidence.evidence_points < 0 then 0
                else 1
              end,
              case
                when evidence.evidence_points < 0 then evidence.evidence_points
                else -evidence.evidence_points
              end,
              evidence.trait_sort,
              evidence.trait_value
          ) as fairness_rank
        from (
          select
            summary.trait_type,
            summary.trait_value,
            app_private.pet_fit_trait_sort(summary.trait_type) as trait_sort,
            case
              when summary.negative_review_outcome_count >
                summary.positive_review_outcome_count
              then -4
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
                and summary.confidence_tier = 'high'
              then 8
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
                and summary.confidence_tier = 'medium'
              then 6
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
              then 4
              when summary.positive_review_outcome_count =
                summary.negative_review_outcome_count
                and summary.positive_review_outcome_count > 0
              then 2
              when summary.completed_booking_count >= 2
              then 3
              when summary.completed_booking_count >= 1
              then 1
              else 0
            end as evidence_points,
            case
              when summary.negative_review_outcome_count >
                summary.positive_review_outcome_count
              then 'mixed feedback for ' ||
                app_private.pet_fit_trait_label(summary.trait_type, summary.trait_value)
              when summary.positive_review_outcome_count > 0
              then app_private.pet_fit_trait_label(summary.trait_type, summary.trait_value) ||
                ' with positive reviews'
              when summary.completed_booking_count >= 2
              then app_private.pet_fit_trait_label(summary.trait_type, summary.trait_value) ||
                ' from completed bookings'
              else app_private.pet_fit_trait_label(summary.trait_type, summary.trait_value)
            end as reason_label
          from request_traits as request_trait
          join public.groomer_pet_fit_evidence_summary as summary
            on summary.groomer_id = eligible_groomer.user_id
           and summary.trait_type = request_trait.trait_type
           and summary.trait_value = request_trait.trait_value
          where summary.completed_booking_count > 0
            or summary.structured_review_outcome_count > 0
        ) as evidence
        where evidence.evidence_points <> 0
      ) as prioritized_evidence
      where prioritized_evidence.fairness_rank <= 3
      order by
        prioritized_evidence.fairness_rank
    ) as ranked_evidence
  ) as pet_fit
    on true
  left join lateral (
    select
      least(
        6,
        coalesce(sum(ranked_signal.signal_points), 0)
      )::integer as adjustment,
      string_agg(
        ranked_signal.reason_label,
        ', '
        order by
          ranked_signal.signal_points desc,
          ranked_signal.signal_sort,
          ranked_signal.trait_sort,
          ranked_signal.trait_value
      ) as reason_text
    from (
      select signal.*
      from (
        select
          request_trait.trait_type,
          request_trait.trait_value,
          1 as signal_sort,
          app_private.pet_fit_trait_sort(request_trait.trait_type) as trait_sort,
          2 as signal_points,
          'portfolio tag for ' ||
            app_private.pet_fit_trait_label(
              request_trait.trait_type,
              request_trait.trait_value
            ) as reason_label
        from request_traits as request_trait
        where exists (
          select 1
          from public.groomer_portfolio_fit_tags as portfolio_tag
          where portfolio_tag.groomer_id = eligible_groomer.user_id
            and portfolio_tag.trait_type = request_trait.trait_type
            and portfolio_tag.trait_value = request_trait.trait_value
        )

        union all

        select
          request_trait.trait_type,
          request_trait.trait_value,
          2 as signal_sort,
          app_private.pet_fit_trait_sort(request_trait.trait_type) as trait_sort,
          1 as signal_points,
          'self-claimed fit for ' ||
            app_private.pet_fit_trait_label(
              request_trait.trait_type,
              request_trait.trait_value
            ) as reason_label
        from request_traits as request_trait
        where exists (
          select 1
          from public.groomer_fit_claims as claim
          where claim.groomer_id = eligible_groomer.user_id
            and claim.trait_type = request_trait.trait_type
            and claim.trait_value = request_trait.trait_value
            and claim.is_active
        )
      ) as signal
      order by
        signal.signal_points desc,
        signal.signal_sort,
        signal.trait_sort,
        signal.trait_value
      limit 3
    ) as ranked_signal
  ) as claim_tag_fit
    on true
  on conflict on constraint request_matches_request_groomer_key do nothing;

  get diagnostics v_match_count = row_count;

  return query
  select v_request_id, v_match_count;
end;
$$;

comment on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text,
  text,
  integer
) is
  'Creates a fixed-service customer grooming request and creates eligible availability-aware groomer matches with location, bounded evidence-backed T-099 pet-fit scoring, low-confidence groomer claim/portfolio signals, and negative-evidence fairness calibration.';

revoke all on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text,
  text,
  integer
) from public, anon, authenticated;

grant execute on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text,
  text,
  text,
  integer
) to authenticated, service_role;
