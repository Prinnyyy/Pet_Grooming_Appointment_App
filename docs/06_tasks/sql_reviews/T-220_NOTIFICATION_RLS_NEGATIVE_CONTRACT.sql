-- T-220 notification RLS and protected RPC rollback validation.
-- This script must not be applied as a migration. It creates validation rows
-- in one transaction, asserts negative authorization behavior, returns
-- evidence rows, and rolls back.

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
    '22000000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    't220-customer-a@example.invalid',
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
    '22000000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    't220-customer-b@example.invalid',
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
    '22000000-0000-4000-8000-000000000003',
    'authenticated',
    'authenticated',
    't220-groomer-a@example.invalid',
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
    '22000000-0000-4000-8000-000000000004',
    'authenticated',
    'authenticated',
    't220-groomer-b@example.invalid',
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
  ('22000000-0000-4000-8000-000000000001', 'customer', 'T220 Customer A'),
  ('22000000-0000-4000-8000-000000000002', 'customer', 'T220 Customer B'),
  ('22000000-0000-4000-8000-000000000003', 'groomer', 'T220 Groomer A'),
  ('22000000-0000-4000-8000-000000000004', 'groomer', 'T220 Groomer B');

insert into public.customer_profiles (user_id)
values
  ('22000000-0000-4000-8000-000000000001'),
  ('22000000-0000-4000-8000-000000000002');

insert into public.groomer_profiles (user_id)
values
  ('22000000-0000-4000-8000-000000000003'),
  ('22000000-0000-4000-8000-000000000004');

insert into public.customer_notifications (
  id,
  customer_id,
  kind,
  title,
  body
)
values
  (
    '22000000-0000-4000-8000-100000000001',
    '22000000-0000-4000-8000-000000000001',
    'request_published',
    'Own customer notification',
    'T-220 own customer notification.'
  ),
  (
    '22000000-0000-4000-8000-100000000002',
    '22000000-0000-4000-8000-000000000002',
    'request_published',
    'Other customer notification',
    'T-220 other customer notification.'
  );

insert into public.groomer_notifications (
  id,
  groomer_id,
  kind,
  title,
  body
)
values
  (
    '22000000-0000-4000-8000-200000000001',
    '22000000-0000-4000-8000-000000000003',
    'new_match',
    'Own groomer notification',
    'T-220 own groomer notification.'
  ),
  (
    '22000000-0000-4000-8000-200000000002',
    '22000000-0000-4000-8000-000000000004',
    'new_match',
    'Other groomer notification',
    'T-220 other groomer notification.'
  );

create temporary table t220_notification_contract_results (
  check_name text primary key,
  passed boolean not null,
  details text
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"22000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}';

insert into t220_notification_contract_results (check_name, passed, details)
select
  'customer_cross_read_count',
  count(*) = 0,
  count(*)::text
from public.customer_notifications
where customer_id = '22000000-0000-4000-8000-000000000002';

insert into t220_notification_contract_results (check_name, passed, details)
select
  'customer_cross_update_count',
  count(*) = 0,
  count(*)::text
from (
  update public.customer_notifications
  set is_read = true,
      read_at = statement_timestamp()
  where id = '22000000-0000-4000-8000-100000000002'
  returning id
) as updated_rows;

do $$
declare
  v_rejected boolean := false;
begin
  begin
    insert into public.customer_notifications (
      customer_id,
      kind,
      title,
      body
    )
    values (
      '22000000-0000-4000-8000-000000000001',
      'request_published',
      'Forbidden direct insert',
      'Authenticated customers must not insert notification rows.'
    );
  exception
    when insufficient_privilege then
      v_rejected := true;
  end;

  insert into t220_notification_contract_results (check_name, passed, details)
  values ('customer_insert_rejected', v_rejected = true, v_rejected::text);
end $$;

do $$
declare
  v_rejected boolean := false;
begin
  begin
    perform public.claim_customer_push_notifications(1);
  exception
    when insufficient_privilege then
      v_rejected := true;
  end;

  insert into t220_notification_contract_results (check_name, passed, details)
  values ('authenticated_claim_push_rpc_rejected', v_rejected = true, v_rejected::text);
end $$;

do $$
declare
  v_rejected boolean := false;
begin
  begin
    perform public.record_customer_push_delivery(
      '22000000-0000-4000-8000-100000000001',
      'sent',
      null
    );
  exception
    when insufficient_privilege then
      v_rejected := true;
  end;

  insert into t220_notification_contract_results (check_name, passed, details)
  values ('authenticated_record_push_rpc_rejected', v_rejected = true, v_rejected::text);
end $$;

set local request.jwt.claims = '{"sub":"22000000-0000-4000-8000-000000000003","role":"authenticated","is_anonymous":false}';

insert into t220_notification_contract_results (check_name, passed, details)
select
  'groomer_cross_read_count',
  count(*) = 0,
  count(*)::text
from public.groomer_notifications
where groomer_id = '22000000-0000-4000-8000-000000000004';

insert into t220_notification_contract_results (check_name, passed, details)
select
  'groomer_cross_update_count',
  count(*) = 0,
  count(*)::text
from (
  update public.groomer_notifications
  set is_read = true,
      read_at = statement_timestamp()
  where id = '22000000-0000-4000-8000-200000000002'
  returning id
) as updated_rows;

do $$
declare
  v_rejected boolean := false;
begin
  begin
    insert into public.groomer_notifications (
      groomer_id,
      kind,
      title,
      body
    )
    values (
      '22000000-0000-4000-8000-000000000003',
      'new_match',
      'Forbidden direct insert',
      'Authenticated groomers must not insert notification rows.'
    );
  exception
    when insufficient_privilege then
      v_rejected := true;
  end;

  insert into t220_notification_contract_results (check_name, passed, details)
  values ('groomer_insert_rejected', v_rejected = true, v_rejected::text);
end $$;

do $$
declare
  v_failure text;
begin
  select check_name || ':' || details
  into v_failure
  from t220_notification_contract_results
  where not passed
  order by check_name
  limit 1;

  if v_failure is not null then
    raise exception 'T-220 notification negative contract failed: %', v_failure
      using errcode = 'P0001';
  end if;
end $$;

select *
from t220_notification_contract_results
order by check_name;

rollback;
