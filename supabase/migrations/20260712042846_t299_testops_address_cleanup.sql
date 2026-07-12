-- T-299 service-role-only cleanup for tagged TestOps request locations.

create function app_private.cleanup_testops_request_address_location(
  p_request_id uuid,
  p_run_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run_id text := btrim(p_run_id);
  v_owner_id uuid;
  v_location_id uuid;
begin
  if v_run_id is null
    or v_run_id !~ '^[A-Za-z0-9._-]{1,100}$'
  then
    raise exception using errcode = '22023', message = 'invalid_testops_run_id';
  end if;

  select grooming_request.customer_id, grooming_request.address_location_id
  into v_owner_id, v_location_id
  from public.grooming_requests as grooming_request
  where grooming_request.id = p_request_id
    and (
      grooming_request.service_notes = 'TESTOPS:' || v_run_id
      or grooming_request.service_notes like 'TESTOPS:' || v_run_id || ' %'
    )
  for update of grooming_request;

  if not found then
    raise exception using errcode = '42501', message = 'testops_tagged_request_required';
  end if;
  if v_location_id is null then
    return false;
  end if;

  delete from app_private.address_locations as address_location
  where address_location.id = v_location_id
    and address_location.owner_id = v_owner_id
    and address_location.resolution_source = 'manual_geocode';
  return found;
end;
$$;

create function public.cleanup_testops_request_address_location(
  p_request_id uuid,
  p_run_id text
)
returns boolean
language sql
security invoker
set search_path = ''
as $$
  select app_private.cleanup_testops_request_address_location(p_request_id, p_run_id);
$$;

revoke all on function app_private.cleanup_testops_request_address_location(uuid, text)
from public, anon, authenticated, service_role;
grant execute on function app_private.cleanup_testops_request_address_location(uuid, text)
to service_role;

revoke all on function public.cleanup_testops_request_address_location(uuid, text)
from public, anon, authenticated, service_role;
grant execute on function public.cleanup_testops_request_address_location(uuid, text)
to service_role;

comment on function public.cleanup_testops_request_address_location(uuid, text) is
  'Service-role-only cleanup of a private manual-geocode location owned by an exactly tagged TestOps request.';
