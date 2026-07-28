begin;

create temporary table t358_context (
  customer_id uuid not null,
  pet_id uuid not null,
  operation_id uuid not null
) on commit drop;

create temporary table t358_results (
  first_request_id uuid not null,
  first_match_count integer not null,
  second_request_id uuid not null,
  second_match_count integer not null
) on commit drop;

grant select on t358_context to authenticated, anon;
grant select, insert on t358_results to authenticated;

insert into t358_context (customer_id, pet_id, operation_id)
select
  customer_profile.user_id,
  pet.id,
  gen_random_uuid()
from public.customer_profiles as customer_profile
join public.profiles as profile
  on profile.id = customer_profile.user_id
join public.pets as pet
  on pet.customer_id = customer_profile.user_id
where profile.role = 'customer'::public.user_role
  and pet.is_active
  and pet.deleted_at is null
  and (
    select count(*)
    from public.grooming_requests as open_request
    where open_request.customer_id = customer_profile.user_id
      and open_request.status in ('open', 'has_offers')
      and open_request.expires_at > statement_timestamp()
  ) < 3
order by customer_profile.user_id, pet.created_at, pet.id
limit 1;

do $$
begin
  if not exists (select 1 from t358_context) then
    raise exception 'T-358 requires one active Customer pet below the open Request limit';
  end if;
end;
$$;

set local role authenticated;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', context.customer_id,
    'role', 'authenticated',
    'is_anonymous', false
  )::text,
  true
)
from t358_context as context;

do $$
declare
  v_context t358_context%rowtype;
  v_first_request_id uuid;
  v_first_match_count integer;
  v_second_request_id uuid;
  v_second_match_count integer;
begin
  select * into strict v_context from t358_context;

  select result.request_id, result.match_count
  into v_first_request_id, v_first_match_count
  from public.create_grooming_request_v3(
    v_context.operation_id,
    v_context.pet_id,
    'full_groom',
    'TESTOPS:T358 request publish idempotency validation',
    statement_timestamp() + interval '3 days',
    statement_timestamp() + interval '3 days 2 hours',
    'groomer_comes_to_customer',
    '770 S Harbor Blvd',
    'Fullerton',
    'CA',
    '92832',
    'Unit 2410',
    'apple_maps',
    'T358-ROLLBACK-VALIDATION',
    'US',
    33.8703,
    -117.9242,
    'autocomplete_selection',
    statement_timestamp(),
    null
  ) as result;

  select result.request_id, result.match_count
  into v_second_request_id, v_second_match_count
  from public.create_grooming_request_v3(
    v_context.operation_id,
    v_context.pet_id,
    'bath_and_brush',
    'TESTOPS:T358 replay must ignore changed retry payload',
    statement_timestamp() + interval '4 days',
    statement_timestamp() + interval '4 days 2 hours',
    'groomer_comes_to_customer',
    '800 N State College Blvd',
    'Fullerton',
    'CA',
    '92831',
    null,
    'apple_maps',
    'T358-REPLAY-PAYLOAD',
    'US',
    33.8802,
    -117.8889,
    'autocomplete_selection',
    statement_timestamp(),
    null
  ) as result;

  if not (
    v_first_request_id is not null
    and v_first_request_id = v_second_request_id
    and v_first_match_count = v_second_match_count
  ) then
    raise exception 'same_request_replayed failed';
  end if;

  insert into t358_results (
    first_request_id,
    first_match_count,
    second_request_id,
    second_match_count
  )
  values (
    v_first_request_id,
    v_first_match_count,
    v_second_request_id,
    v_second_match_count
  );
end;
$$;

reset role;

do $$
declare
  v_context t358_context%rowtype;
  v_results t358_results%rowtype;
  v_single_request_created boolean;
  v_single_operation_recorded boolean;
begin
  select * into strict v_context from t358_context;
  select * into strict v_results from t358_results;

  select count(*) = 1
  into v_single_request_created
  from public.grooming_requests as request
  where request.customer_id = v_context.customer_id
    and request.id = v_results.first_request_id;

  if not v_single_request_created then
    raise exception 'single_request_created failed';
  end if;

  select count(*) = 1
  into v_single_operation_recorded
  from app_private.request_publish_operations as operation
  where operation.customer_id = v_context.customer_id
    and operation.operation_id = v_context.operation_id
    and operation.request_id = v_results.first_request_id
    and operation.match_count = v_results.first_match_count;

  if not v_single_operation_recorded then
    raise exception 'single_operation_recorded failed';
  end if;
end;
$$;

set local role anon;
select set_config('request.jwt.claims', '{}'::text, true);

do $$
declare
  v_context t358_context%rowtype;
  v_rejected boolean := false;
begin
  select * into strict v_context from t358_context;

  begin
    perform public.create_grooming_request_v3(
      gen_random_uuid(),
      v_context.pet_id,
      'full_groom',
      null,
      statement_timestamp() + interval '3 days',
      statement_timestamp() + interval '3 days 2 hours',
      'groomer_comes_to_customer',
      '770 S Harbor Blvd',
      'Fullerton',
      'CA',
      '92832',
      null,
      'apple_maps',
      null,
      'US',
      33.8703,
      -117.9242,
      'manual_geocode',
      statement_timestamp(),
      null
    );
  exception
    when insufficient_privilege then
      v_rejected := true;
  end;

  if not ('anonymous_execute_rejected' is not null and v_rejected = true) then
    raise exception 'anonymous_execute_rejected failed';
  end if;
end;
$$;

reset role;

select
  't358_request_publish_idempotency_rollback_validation_passed' as status,
  results.first_request_id,
  results.first_match_count
from t358_results as results;

rollback;
