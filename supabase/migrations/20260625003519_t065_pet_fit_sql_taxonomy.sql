-- T-065 pet-fit SQL taxonomy foundation.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create or replace function app_private.pet_fit_normalized_text(
  p_value text
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select nullif(
    lower(regexp_replace(btrim(coalesce(p_value, '')), '\s+', ' ', 'g')),
    ''
  )
$$;

create or replace function app_private.pet_fit_breed_group(
  p_breed text
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  with normalized as (
    select app_private.pet_fit_normalized_text(p_breed) as breed
  )
  select case
    when breed like '%poodle%' then 'poodle'
    when breed like '%terrier%'
      or breed like '%westie%'
      or breed like '%west highland%'
    then 'terrier'
    else null
  end
  from normalized
$$;

create or replace function app_private.pet_fit_size_band(
  p_weight_lbs numeric
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_weight_lbs is null then null
    when p_weight_lbs < 10 then 'XS'
    when p_weight_lbs < 20 then 'S'
    when p_weight_lbs < 40 then 'M'
    when p_weight_lbs < 60 then 'L'
    when p_weight_lbs < 80 then 'XL'
    when p_weight_lbs <= 100 then 'XXL'
    else 'Giant'
  end
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
            'anxious',
            'nervous',
            'reactive'
          )
          then 'anxious'::text
          else null::text
        end,
        10
      ),
      (
        case
          when p_birthday is not null
            and coalesce(p_reference_date, current_date) >=
              (p_birthday + interval '10 years')::date
          then 'senior'::text
          else null::text
        end,
        20
      )
  ) as derived(flag, sort_order)
  where flag is not null
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
  with input as (
    select
      app_private.pet_fit_breed_group(p_breed) as breed_group,
      app_private.pet_fit_normalized_text(p_service_type) as service_type,
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
      10 as sort_order
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
      20 as sort_order
    from input

    union all

    select 'gentle_handling'::text, 30
    from input
    where 'anxious' = any(input.care_flags)

    union all

    select 'senior_care'::text, 40
    from input
    where 'senior' = any(input.care_flags)
  ) as derived
  where trait is not null
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
    when trait_type = 'care_flag' then trait_value in ('anxious', 'senior')
    when trait_type = 'service_fit' then trait_value in (
      'curly_coat',
      'terrier_coat',
      'gentle_handling',
      'senior_care'
    )
    else false
  end
  from normalized
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
  with derived as (
    select
      app_private.pet_fit_breed_group(p_breed) as breed_group,
      app_private.pet_fit_size_band(p_weight_lbs) as size_band,
      app_private.pet_fit_care_flags(
        p_temperament,
        p_birthday,
        p_reference_date
      ) as care_flags,
      app_private.pet_fit_service_traits(
        p_breed,
        p_temperament,
        p_birthday,
        p_service_type,
        p_reference_date
      ) as service_traits
  )
  select trait_type, trait_value
  from (
    select 10 as sort_order, 'breed_group'::text as trait_type, breed_group as trait_value
    from derived
    where breed_group is not null

    union all

    select 20, 'size_band'::text, size_band
    from derived
    where size_band is not null

    union all

    select 30, 'care_flag'::text, care_flag
    from derived, unnest(care_flags) as care_flag

    union all

    select 40, 'service_fit'::text, service_trait
    from derived, unnest(service_traits) as service_trait
  ) as traits
  order by sort_order, trait_value
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
    p_service_type,
    p_reference_date
  )
$$;

comment on function app_private.pet_fit_breed_group(text) is
  'Maps customer pet breed text to the T-065 pet-fit breed group vocabulary.';
comment on function app_private.pet_fit_size_band(numeric) is
  'Maps customer pet weight in pounds to the pet-fit size band vocabulary without depending on the undeployed T-050 draft.';
comment on function app_private.pet_fit_care_flags(text, date, date) is
  'Derives care flags such as anxious and senior from request pet snapshot fields.';
comment on function app_private.pet_fit_service_traits(text, text, date, text, date) is
  'Derives service-fit traits such as curly coat, terrier coat, gentle handling, and senior care.';
comment on function app_private.pet_fit_valid_trait_pair(text, text) is
  'Validates T-065 pet-fit trait type/value pairs for later claim, tag, and evidence tables.';
comment on function app_private.pet_fit_request_traits(text, numeric, text, date, text, date) is
  'Returns normalized pet-fit trait rows from request pet fields for later matching evidence and scoring.';
comment on function app_private.pet_fit_traits_from_snapshot(jsonb, text, date) is
  'Returns normalized pet-fit trait rows from grooming_requests.pet_snapshot JSON for later matching evidence and scoring.';

revoke all on function app_private.pet_fit_normalized_text(text)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_breed_group(text)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_size_band(numeric)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_care_flags(text, date, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_service_traits(text, text, date, text, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_valid_trait_pair(text, text)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_request_traits(text, numeric, text, date, text, date)
from public, anon, authenticated;
revoke all on function app_private.pet_fit_traits_from_snapshot(jsonb, text, date)
from public, anon, authenticated;

grant execute on function app_private.pet_fit_normalized_text(text)
to service_role;
grant execute on function app_private.pet_fit_breed_group(text)
to service_role;
grant execute on function app_private.pet_fit_size_band(numeric)
to service_role;
grant execute on function app_private.pet_fit_care_flags(text, date, date)
to service_role;
grant execute on function app_private.pet_fit_service_traits(text, text, date, text, date)
to service_role;
grant execute on function app_private.pet_fit_valid_trait_pair(text, text)
to service_role;
grant execute on function app_private.pet_fit_request_traits(text, numeric, text, date, text, date)
to service_role;
grant execute on function app_private.pet_fit_traits_from_snapshot(jsonb, text, date)
to service_role;
