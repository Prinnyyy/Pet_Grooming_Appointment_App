-- T-300 strict coordinate matching rollback-only validation.

begin;

do $$
begin
  if has_table_privilege(
    'authenticated',
    'app_private.address_locations',
    'select'
  ) <> false then
    raise exception 'authenticated unexpectedly has address location SELECT';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.create_grooming_request(uuid,text,text,timestamptz,timestamptz,text,text,text,text,text,integer)',
    'execute'
  ) <> false then
    raise exception 'authenticated unexpectedly retains legacy request RPC EXECUTE';
  end if;
end;
$$;

set local role service_role;

do $$
declare
  v_origin extensions.geography :=
    extensions.st_setsrid(extensions.st_makepoint(-117.9242, 33.8703), 4326)::extensions.geography;
  v_exact_ten_miles extensions.geography := extensions.st_project(
    v_origin,
    10 * 1609.344,
    pg_catalog.radians(90)
  );
  v_outside_ten_miles extensions.geography := extensions.st_project(
    v_origin,
    10.1 * 1609.344,
    pg_catalog.radians(90)
  );
  v_fit record;
begin
  -- Exact radius boundary remains eligible.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    v_origin, v_exact_ten_miles, 'customer_comes_to_groomer', 10, 50,
    'CA', '富勒顿', 'NY', 'Fullerton'
  );
  if not v_fit.is_eligible
    or v_fit.allowed_radius <> 10
    or v_fit.used_legacy_fallback
    or v_fit.location_reason not like '%customer''s 10-mile travel range%'
  then
    raise exception 'exact radius boundary failed';
  end if;

  -- Outside radius remains excluded.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    v_origin, v_outside_ten_miles, 'customer_comes_to_groomer', 10, 50,
    'CA', 'Fullerton', 'CA', 'Fullerton'
  );
  if v_fit.is_eligible then
    raise exception 'outside radius unexpectedly eligible';
  end if;

  -- A missing request coordinate is ineligible even when text is identical.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    null, v_origin, 'customer_comes_to_groomer', 10, 50,
    'CA', 'Fullerton', 'CA', 'Fullerton'
  );
  if v_fit.is_eligible or v_fit.used_legacy_fallback then
    raise exception 'missing request coordinate entered matching';
  end if;

  -- A missing Groomer coordinate is ineligible even when text is identical.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    v_origin, null, 'groomer_comes_to_customer', 10, 50,
    'CA', 'Fullerton', 'CA', 'Fullerton'
  );
  if v_fit.is_eligible or v_fit.used_legacy_fallback then
    raise exception 'missing groomer coordinate entered matching';
  end if;

  -- Same text address cannot bypass missing coordinates.
  select * into v_fit
  from app_private.evaluate_request_location_fit(
    null, null, 'customer_comes_to_groomer', 10, 50,
    'CA', 'Fullerton', 'CA', 'Fullerton'
  );
  if v_fit.is_eligible
    or v_fit.location_score <> 0
    or v_fit.location_reason is not null
  then
    raise exception 'same text address bypassed strict coordinates';
  end if;
end;
$$;

reset role;

rollback;
