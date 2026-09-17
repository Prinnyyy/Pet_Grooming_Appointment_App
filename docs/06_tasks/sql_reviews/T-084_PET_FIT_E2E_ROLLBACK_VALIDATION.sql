-- T-084 pet-fit end-to-end rollback validation.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- This script must not be applied as a migration. It creates validation rows
-- in one transaction, asserts behavior, returns evidence, and rolls back.

begin;

insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  is_sso_user,
  is_anonymous
)
values
  (
    '84000000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    't084-e2e-customer@example.invalid',
    null,
    statement_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    statement_timestamp(),
    statement_timestamp(),
    false,
    false
  ),
  (
    '84000000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    't084-e2e-groomer@example.invalid',
    null,
    statement_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    statement_timestamp(),
    statement_timestamp(),
    false,
    false
  ),
  (
    '84000000-0000-4000-8000-000000000003',
    'authenticated',
    'authenticated',
    't084-e2e-unrelated@example.invalid',
    null,
    statement_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    statement_timestamp(),
    statement_timestamp(),
    false,
    false
  );

insert into public.profiles (id, role, display_name)
values
  (
    '84000000-0000-4000-8000-000000000001',
    'customer'::public.user_role,
    'T084 E2E Customer'
  ),
  (
    '84000000-0000-4000-8000-000000000002',
    'groomer'::public.user_role,
    'T084 E2E Groomer'
  ),
  (
    '84000000-0000-4000-8000-000000000003',
    'customer'::public.user_role,
    'T084 E2E Unrelated Customer'
  );

insert into public.customer_profiles (user_id)
values
  ('84000000-0000-4000-8000-000000000001'),
  ('84000000-0000-4000-8000-000000000003');

insert into public.groomer_profiles (
  user_id,
  business_name,
  bio,
  years_experience,
  base_city,
  base_state,
  service_radius_miles,
  rating_avg,
  rating_count,
  is_active,
  is_verified,
  service_location_mode,
  base_street_address,
  base_zip_code,
  service_location_modes
)
values (
  '84000000-0000-4000-8000-000000000002',
  'T084 E2E Groomer Studio',
  'Rollback-only validation groomer.',
  5,
  'San Francisco',
  'CA',
  25,
  0,
  0,
  true,
  false,
  'groomer_comes_to_customer',
  '1 Market St',
  '94105',
  array['groomer_comes_to_customer']::text[]
);

insert into public.groomer_services (
  groomer_id,
  title,
  description,
  base_price,
  duration_minutes,
  accepted_pet_sizes,
  is_active,
  service_type
)
values (
  '84000000-0000-4000-8000-000000000002',
  'T084 Full Groom',
  'Rollback-only validation full groom.',
  120.00,
  90,
  array['small', 'medium']::text[],
  true,
  'full_groom'
);

insert into public.groomer_availability_windows (
  groomer_id,
  weekday,
  start_time,
  end_time,
  is_enabled,
  timezone
)
select
  '84000000-0000-4000-8000-000000000002',
  weekday::smallint,
  time '00:00',
  time '23:59',
  true,
  'America/Los_Angeles'
from generate_series(1, 7) as weekday;

insert into public.groomer_booking_preferences (
  groomer_id,
  max_appointments_per_day,
  minimum_advance_notice_days,
  auto_accept_bookings
)
values (
  '84000000-0000-4000-8000-000000000002',
  4,
  0,
  false
);

insert into public.pets (
  id,
  customer_id,
  name,
  species,
  breed,
  size,
  weight_lbs,
  birthday,
  temperament,
  grooming_notes,
  is_active
)
values (
  '84000000-0000-4000-8000-000000000101',
  '84000000-0000-4000-8000-000000000001',
  'T084 Poodle',
  'Dog',
  'Poodle',
  'S',
  15.00,
  current_date - interval '3 years',
  'Gentle',
  'T084 rollback validation poodle coat.',
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

do $$
declare
  v_result record;
begin
  select *
  into v_result
  from public.create_grooming_request(
    '84000000-0000-4000-8000-000000000101',
    'full_groom',
    'T084 rollback validation first request',
    (
      date_trunc(
        'day',
        timezone('America/Los_Angeles', statement_timestamp())
      ) + interval '14 days' + interval '10 hours'
    ) at time zone 'America/Los_Angeles',
    (
      date_trunc(
        'day',
        timezone('America/Los_Angeles', statement_timestamp())
      ) + interval '14 days' + interval '11 hours 30 minutes'
    ) at time zone 'America/Los_Angeles',
    'groomer_comes_to_customer',
    '123 T084 Validation St',
    'San Francisco',
    'CA',
    '94105',
    null
  );

  if v_result.match_count < 1 then
    raise exception 'T084 expected first request to create at least one match';
  end if;
end $$;

reset role;

create temp table t084_first_match on commit drop as
select
  request_match.match_score,
  request_match.match_reason
from public.request_matches as request_match
join public.grooming_requests as grooming_request
  on grooming_request.id = request_match.request_id
where grooming_request.customer_id = '84000000-0000-4000-8000-000000000001'
  and grooming_request.service_notes = 'T084 rollback validation first request'
  and request_match.groomer_id = '84000000-0000-4000-8000-000000000002';

do $$
declare
  v_first_match record;
begin
  select *
  into v_first_match
  from t084_first_match;

  if not found then
    raise exception 'T084 expected first request match row';
  end if;

  if v_first_match.match_reason like '%Pet-fit evidence:%' then
    raise exception 'T084 first request unexpectedly had earned pet-fit evidence: %',
      v_first_match.match_reason;
  end if;
end $$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

do $$
declare
  v_offer record;
begin
  select *
  into v_offer
  from public.create_groomer_offer(
    (
      select grooming_request.id
      from public.grooming_requests as grooming_request
      where grooming_request.service_notes = 'T084 rollback validation first request'
      limit 1
    ),
    (
      date_trunc(
        'day',
        timezone('America/Los_Angeles', statement_timestamp())
      ) + interval '14 days' + interval '10 hours'
    ) at time zone 'America/Los_Angeles',
    (
      date_trunc(
        'day',
        timezone('America/Los_Angeles', statement_timestamp())
      ) + interval '14 days' + interval '11 hours 30 minutes'
    ) at time zone 'America/Los_Angeles',
    120.00,
    'T084 rollback validation offer'
  );

  if v_offer.offer_status <> 'pending' then
    raise exception 'T084 expected pending offer, got %', v_offer.offer_status;
  end if;
end $$;

reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

do $$
declare
  v_booking record;
begin
  select *
  into v_booking
  from public.accept_groomer_offer((
    select groomer_offer.id
    from public.groomer_offers as groomer_offer
    where groomer_offer.message = 'T084 rollback validation offer'
    limit 1
  ));

  if v_booking.booking_status <> 'confirmed'
    or v_booking.offer_status <> 'accepted_by_customer'
    or v_booking.request_status <> 'booked'
  then
    raise exception
      'T084 expected confirmed booking/accepted offer/booked request, got %, %, %',
      v_booking.booking_status,
      v_booking.offer_status,
      v_booking.request_status;
  end if;
end $$;

reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

do $$
declare
  v_completion record;
begin
  select *
  into v_completion
  from public.complete_booking((
    select booking.id
    from public.bookings as booking
    where booking.customer_id = '84000000-0000-4000-8000-000000000001'
      and booking.groomer_id = '84000000-0000-4000-8000-000000000002'
      and booking.status = 'confirmed'
    limit 1
  ));

  if v_completion.booking_status <> 'completed'
    or v_completion.completed_by <> '84000000-0000-4000-8000-000000000002'
  then
    raise exception 'T084 expected groomer-completed booking';
  end if;
end $$;

reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

do $$
declare
  v_review record;
begin
  select *
  into v_review
  from public.create_review(
    (
      select booking.id
      from public.bookings as booking
      where booking.customer_id = '84000000-0000-4000-8000-000000000001'
        and booking.groomer_id = '84000000-0000-4000-8000-000000000002'
        and booking.status = 'completed'
      limit 1
    ),
    5,
    'T084 rollback validation review',
    '[
      {
        "trait_type": "breed_group",
        "trait_value": "poodle",
        "outcome": "positive"
      },
      {
        "trait_type": "service_fit",
        "trait_value": "curly_coat",
        "outcome": "positive"
      }
    ]'::jsonb
  );

  if v_review.rating <> 5 then
    raise exception 'T084 expected five-star review';
  end if;
end $$;

do $$
begin
  if (
    select count(*)
    from public.review_pet_fit_outcomes as outcome
    where outcome.customer_id = '84000000-0000-4000-8000-000000000001'
      and outcome.groomer_id = '84000000-0000-4000-8000-000000000002'
      and outcome.outcome = 'positive'
  ) <> 2 then
    raise exception 'T084 expected two structured positive outcomes visible to customer';
  end if;

  if not exists (
    select 1
    from public.groomer_pet_fit_evidence_summary as summary
    where summary.groomer_id = '84000000-0000-4000-8000-000000000002'
      and summary.trait_type = 'breed_group'
      and summary.trait_value = 'poodle'
      and summary.completed_booking_count >= 1
      and summary.positive_review_outcome_count >= 1
  ) then
    raise exception 'T084 expected customer-visible poodle aggregate evidence';
  end if;
end $$;

reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

do $$
begin
  if not exists (
    select 1
    from public.get_my_groomer_pet_fit_evidence_summary() as summary
    where summary.trait_type = 'breed_group'
      and summary.trait_value = 'poodle'
      and summary.completed_booking_count >= 1
      and summary.positive_review_outcome_count >= 1
  ) then
    raise exception 'T084 expected owner aggregate RPC to return poodle evidence';
  end if;
end $$;

reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000003","role":"authenticated","is_anonymous":false}',
  true
);

do $$
begin
  if exists (
    select 1
    from public.grooming_requests
    where service_notes like 'T084 rollback validation%'
  ) then
    raise exception 'T084 unrelated customer unexpectedly read validation requests';
  end if;

  if exists (
    select 1
    from public.request_matches
    where customer_id = '84000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'T084 unrelated customer unexpectedly read request matches';
  end if;

  if exists (
    select 1
    from public.groomer_offers
    where customer_id = '84000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'T084 unrelated customer unexpectedly read offers';
  end if;

  if exists (
    select 1
    from public.bookings
    where customer_id = '84000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'T084 unrelated customer unexpectedly read bookings';
  end if;

  if exists (
    select 1
    from public.review_pet_fit_outcomes
    where customer_id = '84000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'T084 unrelated customer unexpectedly read review outcomes';
  end if;

  if exists (
    select 1
    from public.groomer_pet_fit_evidence_summary
    where groomer_id = '84000000-0000-4000-8000-000000000002'
  ) then
    raise exception 'T084 unrelated customer unexpectedly read aggregate evidence';
  end if;
end $$;

reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"84000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

do $$
declare
  v_result record;
begin
  select *
  into v_result
  from public.create_grooming_request(
    '84000000-0000-4000-8000-000000000101',
    'full_groom',
    'T084 rollback validation second request',
    (
      date_trunc(
        'day',
        timezone('America/Los_Angeles', statement_timestamp())
      ) + interval '15 days' + interval '10 hours'
    ) at time zone 'America/Los_Angeles',
    (
      date_trunc(
        'day',
        timezone('America/Los_Angeles', statement_timestamp())
      ) + interval '15 days' + interval '11 hours 30 minutes'
    ) at time zone 'America/Los_Angeles',
    'groomer_comes_to_customer',
    '123 T084 Validation St',
    'San Francisco',
    'CA',
    '94105',
    null
  );

  if v_result.match_count < 1 then
    raise exception 'T084 expected second request to create at least one match';
  end if;

  if exists (
    select 1
    from public.request_matches as request_match
    join public.grooming_requests as grooming_request
      on grooming_request.id = request_match.request_id
    where grooming_request.service_notes = 'T084 rollback validation second request'
  ) then
    raise exception 'T084 customer unexpectedly read unoffered second match';
  end if;
end $$;

reset role;

create temp table t084_second_match on commit drop as
select
  request_match.match_score,
  request_match.match_reason
from public.request_matches as request_match
join public.grooming_requests as grooming_request
  on grooming_request.id = request_match.request_id
where grooming_request.customer_id = '84000000-0000-4000-8000-000000000001'
  and grooming_request.service_notes = 'T084 rollback validation second request'
  and request_match.groomer_id = '84000000-0000-4000-8000-000000000002';

do $$
declare
  v_first_match record;
  v_second_match record;
begin
  select *
  into v_first_match
  from t084_first_match;

  select *
  into v_second_match
  from t084_second_match;

  if not found then
    raise exception 'T084 expected second request match row';
  end if;

  if v_second_match.match_reason not like '%Pet-fit evidence:%' then
    raise exception 'T084 expected second request reason to include earned evidence: %',
      v_second_match.match_reason;
  end if;

  if v_second_match.match_reason not like '%positive reviews%' then
    raise exception 'T084 expected second request reason to include positive review evidence: %',
      v_second_match.match_reason;
  end if;

  if v_second_match.match_score <= v_first_match.match_score then
    raise exception 'T084 expected second match score % to exceed first score %',
      v_second_match.match_score,
      v_first_match.match_score;
  end if;
end $$;

select
  't084_pet_fit_e2e_rollback_validation_passed' as status,
  (select match_score from t084_first_match) as first_match_score,
  (select match_reason from t084_first_match) as first_match_reason,
  (select match_score from t084_second_match) as second_match_score,
  (select match_reason from t084_second_match) as second_match_reason,
  (
    select count(*)
    from public.review_pet_fit_outcomes
    where customer_id = '84000000-0000-4000-8000-000000000001'
      and groomer_id = '84000000-0000-4000-8000-000000000002'
  ) as structured_outcome_count;

rollback;
