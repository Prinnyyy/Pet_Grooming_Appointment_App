-- T-126 request-day capacity matching.
-- Local migration only until remote application is explicitly authorized.

create or replace function app_private.groomer_has_capacity_on_request_day(
  p_groomer_id uuid,
  p_requested_start timestamptz
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  with matching_window as (
    select
      availability_window.timezone,
      timezone(availability_window.timezone, p_requested_start)::date as local_request_date
    from public.groomer_availability_windows as availability_window
    join pg_catalog.pg_timezone_names as timezone_name
      on timezone_name.name = availability_window.timezone
    where p_groomer_id is not null
      and p_requested_start is not null
      and p_requested_start > statement_timestamp()
      and availability_window.groomer_id = p_groomer_id
      and availability_window.is_enabled
      and availability_window.weekday =
        extract(isodow from timezone(availability_window.timezone, p_requested_start))::smallint
  ),
  booking_preferences as (
    select
      coalesce(preferences.max_appointments_per_day, 4) as max_appointments_per_day,
      coalesce(preferences.minimum_advance_notice_days, 0) as minimum_advance_notice_days
    from public.groomer_profiles as groomer_profile
    left join public.groomer_booking_preferences as preferences
      on preferences.groomer_id = groomer_profile.user_id
    where groomer_profile.user_id = p_groomer_id
  )
  select coalesce(
    (
      select true
      from matching_window
      cross join booking_preferences
      where matching_window.local_request_date >=
        (
          timezone(matching_window.timezone, statement_timestamp())::date
          + booking_preferences.minimum_advance_notice_days
        )
        and not exists (
          select 1
          from public.groomer_time_off_windows as time_off
          where time_off.groomer_id = p_groomer_id
            and matching_window.local_request_date between time_off.start_date and time_off.end_date
        )
        and (
          select count(*)::integer
          from public.bookings as daily_booking
          where daily_booking.groomer_id = p_groomer_id
            and daily_booking.status in ('confirmed', 'completed')
            and timezone(matching_window.timezone, daily_booking.scheduled_start)::date =
              matching_window.local_request_date
        ) < booking_preferences.max_appointments_per_day
      limit 1
    ),
    false
  );
$$;

comment on function app_private.groomer_has_capacity_on_request_day(uuid, timestamptz) is
  'Checks whether a groomer has same-day request matching capacity for the customer preferred date. Offer and booking creation still use exact range availability checks.';

revoke all on function app_private.groomer_has_capacity_on_request_day(uuid, timestamptz)
from public, anon, authenticated;

grant execute on function app_private.groomer_has_capacity_on_request_day(uuid, timestamptz)
to service_role;

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
      end as location_reason,
      case
        when app_private.groomer_is_available_for_range(
          groomer_profile.user_id,
          p_preferred_start,
          p_preferred_end
        )
        then 'Preferred time fits'
        else 'Can suggest another time on your preferred day'
      end as availability_reason
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
      and app_private.groomer_has_capacity_on_request_day(
        groomer_profile.user_id,
        p_preferred_start
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
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '.'
        when pet_fit.reason_text is not null
          and claim_tag_fit.reason_text is not null
          and not coalesce(pet_fit.has_negative_evidence, false)
        then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
        when pet_fit.reason_text is not null then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '.'
        else
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
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
  'Creates a fixed-service customer grooming request and creates eligible same-day-capacity groomer matches with location, bounded evidence-backed pet-fit scoring, low-confidence groomer claim/portfolio signals, negative-evidence fairness calibration, and preferred-time context in match reasons.';

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
