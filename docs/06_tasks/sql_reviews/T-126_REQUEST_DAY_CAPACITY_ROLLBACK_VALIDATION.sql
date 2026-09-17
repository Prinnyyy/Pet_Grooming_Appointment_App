-- T-126 request-day capacity matching rollback validation.
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
    '12600000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    't126-customer@example.invalid',
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
    '12600000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    't126-day-capacity@example.invalid',
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
    '12600000-0000-4000-8000-000000000003',
    'authenticated',
    'authenticated',
    't126-exact-window@example.invalid',
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
    '12600000-0000-4000-8000-000000000004',
    'authenticated',
    'authenticated',
    't126-time-off@example.invalid',
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
    '12600000-0000-4000-8000-000000000005',
    'authenticated',
    'authenticated',
    't126-advance@example.invalid',
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
    '12600000-0000-4000-8000-000000000006',
    'authenticated',
    'authenticated',
    't126-full-day@example.invalid',
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
    '12600000-0000-4000-8000-000000000001',
    'customer'::public.user_role,
    'T126 Customer'
  ),
  (
    '12600000-0000-4000-8000-000000000002',
    'groomer'::public.user_role,
    'T126 Day Capacity Groomer'
  ),
  (
    '12600000-0000-4000-8000-000000000003',
    'groomer'::public.user_role,
    'T126 Exact Groomer'
  ),
  (
    '12600000-0000-4000-8000-000000000004',
    'groomer'::public.user_role,
    'T126 Time Off Groomer'
  ),
  (
    '12600000-0000-4000-8000-000000000005',
    'groomer'::public.user_role,
    'T126 Advance Groomer'
  ),
  (
    '12600000-0000-4000-8000-000000000006',
    'groomer'::public.user_role,
    'T126 Full Day Groomer'
  );

insert into public.customer_profiles (user_id)
values ('12600000-0000-4000-8000-000000000001');

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
select
  groomer_id,
  business_name,
  'T126 rollback validation groomer.',
  5,
  'T126 City',
  'VT',
  25,
  0,
  0,
  true,
  false,
  'groomer_comes_to_customer',
  '1 T126 Market St',
  '05001',
  array['groomer_comes_to_customer']::text[]
from (
  values
    (
      '12600000-0000-4000-8000-000000000002'::uuid,
      'T126 Day Capacity Groomer'
    ),
    (
      '12600000-0000-4000-8000-000000000003'::uuid,
      'T126 Exact Groomer'
    ),
    (
      '12600000-0000-4000-8000-000000000004'::uuid,
      'T126 Time Off Groomer'
    ),
    (
      '12600000-0000-4000-8000-000000000005'::uuid,
      'T126 Advance Groomer'
    ),
    (
      '12600000-0000-4000-8000-000000000006'::uuid,
      'T126 Full Day Groomer'
    )
) as groomer_seed(groomer_id, business_name);

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
select
  groomer_profile.user_id,
  'T126 Full Groom',
  'Rollback-only validation full groom.',
  120.00,
  90,
  array['XS', 'S', 'M']::text[],
  true,
  'full_groom'
from public.groomer_profiles as groomer_profile
where groomer_profile.user_id in (
  '12600000-0000-4000-8000-000000000002',
  '12600000-0000-4000-8000-000000000003',
  '12600000-0000-4000-8000-000000000004',
  '12600000-0000-4000-8000-000000000005',
  '12600000-0000-4000-8000-000000000006'
);

create temp table t126_request_window on commit drop as
select
  (
    date_trunc(
      'day',
      timezone('America/Los_Angeles', statement_timestamp())
    ) + interval '1 day' + interval '17 hours'
  ) at time zone 'America/Los_Angeles' as preferred_start,
  (
    date_trunc(
      'day',
      timezone('America/Los_Angeles', statement_timestamp())
    ) + interval '1 day' + interval '18 hours 30 minutes'
  ) at time zone 'America/Los_Angeles' as preferred_end,
  (
    date_trunc(
      'day',
      timezone('America/Los_Angeles', statement_timestamp())
    ) + interval '1 day'
  )::date as local_request_date,
  extract(
    isodow from
    (
      date_trunc(
        'day',
        timezone('America/Los_Angeles', statement_timestamp())
        ) + interval '1 day'
    )
  )::smallint as weekday;

grant select on table t126_request_window to authenticated;

insert into public.groomer_availability_windows (
  groomer_id,
  weekday,
  start_time,
  end_time,
  is_enabled,
  timezone
)
select
  availability.groomer_id,
  t126_request_window.weekday,
  availability.start_time,
  availability.end_time,
  true,
  'America/Los_Angeles'
from t126_request_window
cross join (
  values
    ('12600000-0000-4000-8000-000000000002'::uuid, time '09:00', time '12:00'),
    ('12600000-0000-4000-8000-000000000003'::uuid, time '17:00', time '19:00'),
    ('12600000-0000-4000-8000-000000000004'::uuid, time '09:00', time '12:00'),
    ('12600000-0000-4000-8000-000000000005'::uuid, time '09:00', time '12:00'),
    ('12600000-0000-4000-8000-000000000006'::uuid, time '09:00', time '12:00')
) as availability(groomer_id, start_time, end_time);

insert into public.groomer_booking_preferences (
  groomer_id,
  max_appointments_per_day,
  minimum_advance_notice_days,
  auto_accept_bookings
)
values
  ('12600000-0000-4000-8000-000000000002', 4, 0, false),
  ('12600000-0000-4000-8000-000000000003', 4, 0, false),
  ('12600000-0000-4000-8000-000000000004', 4, 0, false),
  ('12600000-0000-4000-8000-000000000005', 4, 2, false),
  ('12600000-0000-4000-8000-000000000006', 1, 0, false);

insert into public.groomer_time_off_windows (
  groomer_id,
  title,
  start_date,
  end_date
)
select
  '12600000-0000-4000-8000-000000000004',
  'T126 Time Off',
  local_request_date,
  local_request_date
from t126_request_window;

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
  '12600000-0000-4000-8000-000000000101',
  '12600000-0000-4000-8000-000000000001',
  'T126 Poodle',
  'Dog',
  'Poodle',
  'S',
  15.00,
  current_date - interval '3 years',
  'Gentle',
  'T126 rollback validation poodle coat.',
  true
);

insert into public.grooming_requests (
  id,
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
select
  '12600000-0000-4000-8000-000000000201',
  '12600000-0000-4000-8000-000000000001',
  '12600000-0000-4000-8000-000000000101',
  jsonb_build_object('id', '12600000-0000-4000-8000-000000000101', 'name', 'T126 Poodle'),
  '[]'::jsonb,
  'full_groom',
  'T126 capacity seed request',
  preferred_start,
  preferred_end,
  'groomer_comes_to_customer',
  '123 T126 Validation St',
  'T126 City',
  'VT',
  '05001',
  null,
  'booked',
  statement_timestamp() + interval '48 hours'
from t126_request_window;

insert into public.request_matches (
  id,
  request_id,
  groomer_id,
  customer_id,
  match_score,
  match_reason,
  status
)
values (
  '12600000-0000-4000-8000-000000000301',
  '12600000-0000-4000-8000-000000000201',
  '12600000-0000-4000-8000-000000000006',
  '12600000-0000-4000-8000-000000000001',
  80.00,
  'T126 capacity seed match.',
  'offered'
);

insert into public.groomer_offers (
  id,
  request_id,
  match_id,
  customer_id,
  groomer_id,
  proposed_start,
  proposed_end,
  price_estimate,
  message,
  status,
  expires_at
)
select
  '12600000-0000-4000-8000-000000000401',
  '12600000-0000-4000-8000-000000000201',
  '12600000-0000-4000-8000-000000000301',
  '12600000-0000-4000-8000-000000000001',
  '12600000-0000-4000-8000-000000000006',
  preferred_start - interval '7 hours',
  preferred_start - interval '6 hours',
  100.00,
  'T126 capacity seed offer',
  'accepted_by_customer',
  statement_timestamp() + interval '48 hours'
from t126_request_window;

insert into public.bookings (
  id,
  request_id,
  offer_id,
  customer_id,
  groomer_id,
  scheduled_start,
  scheduled_end,
  price_estimate,
  status
)
select
  '12600000-0000-4000-8000-000000000501',
  '12600000-0000-4000-8000-000000000201',
  '12600000-0000-4000-8000-000000000401',
  '12600000-0000-4000-8000-000000000001',
  '12600000-0000-4000-8000-000000000006',
  preferred_start - interval '7 hours',
  preferred_start - interval '6 hours',
  100.00,
  'confirmed'
from t126_request_window;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"12600000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

do $$
declare
  v_result record;
begin
  select *
  into v_result
  from public.create_grooming_request(
    '12600000-0000-4000-8000-000000000101',
    'full_groom',
    'T126 request day capacity validation',
    (select preferred_start from t126_request_window),
    (select preferred_end from t126_request_window),
    'groomer_comes_to_customer',
    '123 T126 Validation St',
    'T126 City',
    'VT',
    '05001',
    null
  );

  if v_result.match_count <> 2 then
    raise exception 'T126 expected exactly 2 matches, got %',
      v_result.match_count;
  end if;
end $$;

reset role;

do $$
declare
  v_day_capacity_reason text;
  v_exact_reason text;
  v_blocked_count integer;
begin
  select request_match.match_reason
  into v_day_capacity_reason
  from public.request_matches as request_match
  join public.grooming_requests as grooming_request
    on grooming_request.id = request_match.request_id
  where grooming_request.service_notes = 'T126 request day capacity validation'
    and request_match.groomer_id = '12600000-0000-4000-8000-000000000002';

  if not found then
    raise exception 'T126 expected day-capacity groomer to receive match';
  end if;

  if v_day_capacity_reason not like '%Can suggest another time on your preferred day%' then
    raise exception 'T126 expected same-day reason, got %',
      v_day_capacity_reason;
  end if;

  select request_match.match_reason
  into v_exact_reason
  from public.request_matches as request_match
  join public.grooming_requests as grooming_request
    on grooming_request.id = request_match.request_id
  where grooming_request.service_notes = 'T126 request day capacity validation'
    and request_match.groomer_id = '12600000-0000-4000-8000-000000000003';

  if not found then
    raise exception 'T126 expected exact-window groomer to receive match';
  end if;

  if v_exact_reason not like '%Preferred time fits%' then
    raise exception 'T126 expected exact preferred-time reason, got %',
      v_exact_reason;
  end if;

  select count(*)::integer
  into v_blocked_count
  from public.request_matches as request_match
  join public.grooming_requests as grooming_request
    on grooming_request.id = request_match.request_id
  where grooming_request.service_notes = 'T126 request day capacity validation'
    and request_match.groomer_id in (
      '12600000-0000-4000-8000-000000000004',
      '12600000-0000-4000-8000-000000000005',
      '12600000-0000-4000-8000-000000000006'
    );

  if v_blocked_count <> 0 then
    raise exception 'T126 expected time-off/advance/full-day groomers blocked, got %',
      v_blocked_count;
  end if;
end $$;

select
  't126_request_day_capacity_rollback_validation_passed' as status,
  count(*)::integer as matched_groomers
from public.request_matches as request_match
join public.grooming_requests as grooming_request
  on grooming_request.id = request_match.request_id
where grooming_request.service_notes = 'T126 request day capacity validation';

rollback;
