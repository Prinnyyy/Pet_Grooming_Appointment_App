-- T-082 matching fairness and calibration.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

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
            case summary.trait_type
              when 'service_fit' then 1
              when 'breed_group' then 2
              when 'care_flag' then 3
              when 'size_band' then 4
              else 99
            end as trait_sort,
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
              then 'mixed feedback for ' || evidence_label.trait_label
              when summary.positive_review_outcome_count > 0
              then evidence_label.trait_label || ' with positive reviews'
              when summary.completed_booking_count >= 2
              then evidence_label.trait_label || ' from completed bookings'
              else evidence_label.trait_label
            end as reason_label
          from request_traits as request_trait
          join public.groomer_pet_fit_evidence_summary as summary
            on summary.groomer_id = eligible_groomer.user_id
           and summary.trait_type = request_trait.trait_type
           and summary.trait_value = request_trait.trait_value
          cross join lateral (
            select case
              when summary.trait_type = 'breed_group'
                and summary.trait_value = 'poodle'
              then 'poodles'
              when summary.trait_type = 'breed_group'
                and summary.trait_value = 'terrier'
              then 'terriers'
              when summary.trait_type = 'size_band'
                and summary.trait_value = 'XS'
              then 'extra-small pets'
              when summary.trait_type = 'size_band'
                and summary.trait_value = 'S'
              then 'small pets'
              when summary.trait_type = 'size_band'
                and summary.trait_value = 'M'
              then 'medium pets'
              when summary.trait_type = 'size_band'
                and summary.trait_value = 'L'
              then 'large pets'
              when summary.trait_type = 'size_band'
                and summary.trait_value = 'XL'
              then 'extra-large pets'
              when summary.trait_type = 'size_band'
                and summary.trait_value = 'XXL'
              then 'very large pets'
              when summary.trait_type = 'size_band'
                and summary.trait_value = 'Giant'
              then 'giant pets'
              when summary.trait_type = 'care_flag'
                and summary.trait_value = 'anxious'
              then 'anxious pets'
              when summary.trait_type = 'care_flag'
                and summary.trait_value = 'senior'
              then 'senior pets'
              when summary.trait_type = 'service_fit'
                and summary.trait_value = 'curly_coat'
              then 'curly coats'
              when summary.trait_type = 'service_fit'
                and summary.trait_value = 'terrier_coat'
              then 'terrier coats'
              when summary.trait_type = 'service_fit'
                and summary.trait_value = 'gentle_handling'
              then 'gentle handling'
              when summary.trait_type = 'service_fit'
                and summary.trait_value = 'senior_care'
              then 'senior care'
              else replace(summary.trait_value, '_', ' ')
            end as trait_label
          ) as evidence_label
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
          case request_trait.trait_type
            when 'service_fit' then 1
            when 'breed_group' then 2
            when 'care_flag' then 3
            when 'size_band' then 4
            else 99
          end as trait_sort,
          2 as signal_points,
          'portfolio tag for ' || signal_label.trait_label as reason_label
        from request_traits as request_trait
        cross join lateral (
          select case
            when request_trait.trait_type = 'breed_group'
              and request_trait.trait_value = 'poodle'
            then 'poodles'
            when request_trait.trait_type = 'breed_group'
              and request_trait.trait_value = 'terrier'
            then 'terriers'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'XS'
            then 'extra-small pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'S'
            then 'small pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'M'
            then 'medium pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'L'
            then 'large pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'XL'
            then 'extra-large pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'XXL'
            then 'very large pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'Giant'
            then 'giant pets'
            when request_trait.trait_type = 'care_flag'
              and request_trait.trait_value = 'anxious'
            then 'anxious pets'
            when request_trait.trait_type = 'care_flag'
              and request_trait.trait_value = 'senior'
            then 'senior pets'
            when request_trait.trait_type = 'service_fit'
              and request_trait.trait_value = 'curly_coat'
            then 'curly coats'
            when request_trait.trait_type = 'service_fit'
              and request_trait.trait_value = 'terrier_coat'
            then 'terrier coats'
            when request_trait.trait_type = 'service_fit'
              and request_trait.trait_value = 'gentle_handling'
            then 'gentle handling'
            when request_trait.trait_type = 'service_fit'
              and request_trait.trait_value = 'senior_care'
            then 'senior care'
            else replace(request_trait.trait_value, '_', ' ')
          end as trait_label
        ) as signal_label
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
          case request_trait.trait_type
            when 'service_fit' then 1
            when 'breed_group' then 2
            when 'care_flag' then 3
            when 'size_band' then 4
            else 99
          end as trait_sort,
          1 as signal_points,
          'self-claimed fit for ' || signal_label.trait_label as reason_label
        from request_traits as request_trait
        cross join lateral (
          select case
            when request_trait.trait_type = 'breed_group'
              and request_trait.trait_value = 'poodle'
            then 'poodles'
            when request_trait.trait_type = 'breed_group'
              and request_trait.trait_value = 'terrier'
            then 'terriers'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'XS'
            then 'extra-small pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'S'
            then 'small pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'M'
            then 'medium pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'L'
            then 'large pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'XL'
            then 'extra-large pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'XXL'
            then 'very large pets'
            when request_trait.trait_type = 'size_band'
              and request_trait.trait_value = 'Giant'
            then 'giant pets'
            when request_trait.trait_type = 'care_flag'
              and request_trait.trait_value = 'anxious'
            then 'anxious pets'
            when request_trait.trait_type = 'care_flag'
              and request_trait.trait_value = 'senior'
            then 'senior pets'
            when request_trait.trait_type = 'service_fit'
              and request_trait.trait_value = 'curly_coat'
            then 'curly coats'
            when request_trait.trait_type = 'service_fit'
              and request_trait.trait_value = 'terrier_coat'
            then 'terrier coats'
            when request_trait.trait_type = 'service_fit'
              and request_trait.trait_value = 'gentle_handling'
            then 'gentle handling'
            when request_trait.trait_type = 'service_fit'
              and request_trait.trait_value = 'senior_care'
            then 'senior care'
            else replace(request_trait.trait_value, '_', ' ')
          end as trait_label
        ) as signal_label
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
  'Creates a fixed-service customer grooming request and creates eligible availability-aware groomer matches with location, bounded evidence-backed pet-fit scoring, low-confidence groomer claim/portfolio signals, and negative-evidence fairness calibration.';

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
