-- T-294 private PostGIS address and radius-matching rollback validation.
-- Run only after the migration is applied. All fixtures roll back.

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
    '29400000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    't294-customer@example.invalid',
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
    '29400000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    't294-groomer@example.invalid',
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
  ('29400000-0000-4000-8000-000000000001', 'customer', 'T294 Customer'),
  ('29400000-0000-4000-8000-000000000002', 'groomer', 'T294 Groomer');

insert into public.customer_profiles (user_id)
values ('29400000-0000-4000-8000-000000000001')
on conflict (user_id) do nothing;

insert into public.groomer_profiles (user_id)
values ('29400000-0000-4000-8000-000000000002')
on conflict (user_id) do nothing;

set local role authenticated;

do $$
begin
  if has_table_privilege(
    'authenticated',
    'app_private.address_locations',
    'select'
  ) <> false then
    raise exception 'authenticated unexpectedly has address location SELECT';
  end if;

  if has_table_privilege(
    'authenticated',
    'app_private.address_locations',
    'insert'
  ) <> false then
    raise exception 'authenticated unexpectedly has address location INSERT';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  '{"sub":"29400000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select public.save_customer_profile_address_v2(
  '770 S Harbor Blvd',
  'Unit 2410',
  'Fullerton',
  'CA',
  '92832',
  'apple_maps',
  null,
  'US',
  33.8703,
  -117.9242,
  'autocomplete_selection',
  statement_timestamp()
);

do $$
begin
  if not exists (
    select 1
    from public.get_my_customer_profile_address_v2() as address
    where address.line_1 = '770 S Harbor Blvd'
      and address.line_2 = 'Unit 2410'
      and address.provider = 'apple_maps'
      and address.place_id is null
      and address.latitude = 33.8703
      and address.longitude = -117.9242
  ) then
    raise exception 'customer owner address round trip failed';
  end if;

  begin
    perform public.save_groomer_profile_address_v2(
      '1 Cross Role St',
      null,
      'Fullerton',
      'CA',
      '92832',
      'apple_maps',
      null,
      'US',
      33.87,
      -117.92,
      'manual_geocode',
      statement_timestamp()
    );
    raise exception 'customer unexpectedly saved Groomer address';
  exception
    when sqlstate 'P0001' then
      if sqlerrm <> 'groomer_profile_required' then
        raise;
      end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claims',
  '{"sub":"29400000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":false}',
  true
);

select public.save_groomer_profile_address_v2(
  '800 N Harbor Blvd',
  null,
  'La Habra',
  'CA',
  '90631',
  'apple_maps',
  't294-groomer-place',
  'US',
  33.9319,
  -117.9339,
  'manual_geocode',
  statement_timestamp()
);

reset role;

do $$
declare
  v_customer_location extensions.geography :=
    extensions.st_setsrid(extensions.st_makepoint(-118.0, 34.0), 4326)::extensions.geography;
  v_exact_ten_miles extensions.geography := extensions.st_project(
    v_customer_location,
    10 * 1609.344,
    pg_catalog.radians(90)
  );
  v_outside_ten_miles extensions.geography := extensions.st_project(
    v_customer_location,
    10.1 * 1609.344,
    pg_catalog.radians(90)
  );
  v_exact_five_miles extensions.geography := extensions.st_project(
    v_customer_location,
    5 * 1609.344,
    pg_catalog.radians(90)
  );
  v_fit record;
begin
  -- customer_comes_to_groomer: exact radius boundary is eligible.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    v_customer_location,
    v_exact_ten_miles,
    'customer_comes_to_groomer',
    10,
    5,
    'CA',
    '富勒顿',
    'NY',
    'Fullerton'
  );
  if not v_fit.is_eligible
    or v_fit.allowed_radius <> 10
    or v_fit.used_legacy_fallback
    or v_fit.location_reason not like '%customer''s 10-mile travel range%'
  then
    raise exception 'customer travel-radius exact boundary failed';
  end if;

  -- Coordinates are authoritative: multilingual city text does not alter fit.
  if v_fit.location_score not between 60 and 80 then
    raise exception 'multilingual city coordinate score failed';
  end if;

  -- customer_comes_to_groomer: outside radius is excluded.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    v_customer_location,
    v_outside_ten_miles,
    'customer_comes_to_groomer',
    10,
    50,
    'CA',
    'Fullerton',
    'CA',
    'Fullerton'
  );
  if v_fit.is_eligible then
    raise exception 'customer outside radius unexpectedly eligible';
  end if;

  -- groomer_comes_to_customer: Groomer service radius controls eligibility.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    v_customer_location,
    v_exact_five_miles,
    'groomer_comes_to_customer',
    100,
    5,
    'CA',
    'Fullerton',
    'CA',
    'Anaheim'
  );
  if not v_fit.is_eligible
    or v_fit.allowed_radius <> 5
    or v_fit.location_reason not like '%groomer''s 5-mile service range%'
  then
    raise exception 'Groomer service-radius exact boundary failed';
  end if;

  -- Missing coordinates retain the explicitly temporary Legacy location fallback.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    null,
    v_exact_five_miles,
    'groomer_comes_to_customer',
    100,
    5,
    'CA',
    '富勒顿',
    'CA',
    'Fullerton'
  );
  if not v_fit.is_eligible
    or not v_fit.used_legacy_fallback
    or v_fit.location_reason <> 'Legacy location fallback'
  then
    raise exception 'Legacy location fallback failed';
  end if;
end;
$$;

select
  count(*) as private_location_rows,
  count(*) filter (where location is not null) as generated_geography_rows
from app_private.address_locations
where owner_id in (
  '29400000-0000-4000-8000-000000000001',
  '29400000-0000-4000-8000-000000000002'
);

rollback;
