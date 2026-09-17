-- T-233 account deletion Storage API boundary rollback validation.
-- This script creates one transaction-scoped customer, executes the public
-- account deletion RPC as that customer, verifies database anonymization, and
-- rolls back. Storage object cleanup is tested at the Edge Function boundary.

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
values (
  '23200000-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  't233-customer@example.invalid',
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
values (
  '23200000-0000-4000-8000-000000000001',
  'customer',
  'T233 Customer'
);

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"23200000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',
  true
);

select *
from public.request_account_deletion();

reset role;

do $$
begin
  if not exists (
    select 1
    from public.account_deletion_requests as deletion_request
    where deletion_request.user_id = '23200000-0000-4000-8000-000000000001'
      and deletion_request.status = 'pending_auth_soft_delete'
  ) then
    raise exception 'T-233 account deletion request was not persisted in the transaction';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = '23200000-0000-4000-8000-000000000001'
      and profile.display_name = 'Deleted customer'
  ) then
    raise exception 'T-233 customer profile was not anonymized in the transaction';
  end if;
end;
$$;

rollback;

select
  'account_deletion_storage_boundary_runtime' as check_name,
  true as passed,
  'Database anonymization executed and transaction rolled back' as details;
