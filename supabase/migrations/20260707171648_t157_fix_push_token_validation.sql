set check_function_bodies = on;

create or replace function app_private.register_customer_push_token(
  p_token text,
  p_installation_id uuid,
  p_environment text default 'sandbox'
)
returns table (
  token_id uuid,
  customer_id uuid,
  environment text,
  is_active boolean,
  registered_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_environment text := lower(btrim(coalesce(p_environment, 'sandbox')));
  v_token text := lower(regexp_replace(coalesce(p_token, ''), '[^0-9a-fA-F]', '', 'g'));
begin
  if v_customer_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if v_environment not in ('sandbox', 'production') then
    raise exception using
      errcode = '22023',
      message = 'invalid_push_environment';
  end if;

  if length(v_token) not between 32 and 256 or v_token !~ '^[0-9a-f]+$' then
    raise exception using
      errcode = '22023',
      message = 'invalid_device_token';
  end if;

  if p_installation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_installation';
  end if;

  update public.customer_push_tokens as push_token
  set disabled_at = statement_timestamp()
  where push_token.customer_id = v_customer_id
    and push_token.installation_id = p_installation_id
    and push_token.environment = v_environment
    and push_token.token <> v_token
    and push_token.disabled_at is null;

  return query
  insert into public.customer_push_tokens (
    customer_id,
    token,
    installation_id,
    environment
  )
  values (
    v_customer_id,
    v_token,
    p_installation_id,
    v_environment
  )
  on conflict (customer_id, installation_id, environment)
  where disabled_at is null
  do update set
    token = excluded.token,
    updated_at = statement_timestamp()
  returning
    customer_push_tokens.id,
    customer_push_tokens.customer_id,
    customer_push_tokens.environment,
    customer_push_tokens.disabled_at is null,
    customer_push_tokens.created_at;
end;
$$;

comment on function app_private.register_customer_push_token(text, uuid, text) is
  'Private helper for registering the current customer APNs token. Token length is checked separately from hex format to avoid Postgres regex repetition limits.';

revoke all on function app_private.register_customer_push_token(text, uuid, text)
from public, anon, authenticated, service_role;

grant execute on function app_private.register_customer_push_token(text, uuid, text)
to authenticated;

create or replace function app_private.unregister_customer_push_token(
  p_token text,
  p_installation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_token text := lower(regexp_replace(coalesce(p_token, ''), '[^0-9a-fA-F]', '', 'g'));
begin
  if v_customer_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_installation_id is null or length(v_token) not between 32 and 256 or v_token !~ '^[0-9a-f]+$' then
    raise exception using
      errcode = '22023',
      message = 'invalid_device_token';
  end if;

  update public.customer_push_tokens as push_token
  set disabled_at = coalesce(push_token.disabled_at, statement_timestamp())
  where push_token.customer_id = v_customer_id
    and push_token.installation_id = p_installation_id
    and push_token.token = v_token
    and push_token.disabled_at is null;

  return found;
end;
$$;

comment on function app_private.unregister_customer_push_token(text, uuid) is
  'Private helper for disabling the current customer APNs token. Token length is checked separately from hex format to avoid Postgres regex repetition limits.';

revoke all on function app_private.unregister_customer_push_token(text, uuid)
from public, anon, authenticated, service_role;

grant execute on function app_private.unregister_customer_push_token(text, uuid)
to authenticated;
