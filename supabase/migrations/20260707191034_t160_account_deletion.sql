-- T-160 account deletion request, anonymization, and Auth soft-delete tracking.
-- Remote apply/deploy requires explicit user authorization.

create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null
    references public.profiles (id) on delete cascade,
  role public.user_role not null,
  status text not null default 'pending_auth_soft_delete',
  requested_at timestamptz not null default now(),
  anonymized_at timestamptz,
  auth_deleted_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_deletion_requests_user_key unique (user_id),
  constraint account_deletion_requests_status_check check (
    status in (
      'pending_auth_soft_delete',
      'completed',
      'failed'
    )
  ),
  constraint account_deletion_requests_error_check check (
    last_error is null
    or (
      last_error = btrim(last_error)
      and char_length(last_error) between 1 and 500
    )
  )
);

comment on table public.account_deletion_requests is
  'Account deletion audit row created by a signed-in user before the Edge Function soft-deletes the Auth user.';
comment on column public.account_deletion_requests.status is
  'pending_auth_soft_delete after database anonymization, completed after Auth soft delete, failed when Auth deletion must be retried.';

create index account_deletion_requests_user_status_idx
on public.account_deletion_requests (user_id, status, requested_at desc);

create trigger account_deletion_requests_set_updated_at
before update on public.account_deletion_requests
for each row execute function app_private.set_updated_at();

alter table public.account_deletion_requests enable row level security;

revoke all on table public.account_deletion_requests
from public, anon, authenticated;

grant select on table public.account_deletion_requests to authenticated;
grant select, insert, update, delete
on table public.account_deletion_requests
to service_role;

create policy account_deletion_requests_select_own
on public.account_deletion_requests
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and user_id = (select auth.uid())
);

create or replace function app_private.request_account_deletion()
returns table (
  deletion_request_id uuid,
  user_id uuid,
  role public.user_role,
  status text,
  requested_at timestamptz
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
  v_role public.user_role;
  v_deletion_request_id uuid;
  v_requested_at timestamptz := statement_timestamp();
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  select profile.role
  into v_role
  from public.profiles as profile
  where profile.id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'profile_required';
  end if;

  insert into public.account_deletion_requests (
    user_id,
    role,
    status,
    requested_at,
    last_error
  )
  values (
    v_user_id,
    v_role,
    'pending_auth_soft_delete',
    v_requested_at,
    null
  )
  on conflict (user_id) do update
  set
    role = excluded.role,
    status = 'pending_auth_soft_delete',
    requested_at = excluded.requested_at,
    auth_deleted_at = null,
    last_error = null
  returning id
  into v_deletion_request_id;

  update public.profiles as profile
  set
    display_name = case v_role
      when 'customer'::public.user_role then 'Deleted customer'
      when 'groomer'::public.user_role then 'Deleted groomer'
    end,
    avatar_path = null
  where profile.id = v_user_id;

  delete from storage.objects as object
  where object.bucket_id in (
      'avatars',
      'customer-avatars',
      'pet-photos',
      'request-photos',
      'groomer-portfolio'
    )
    and split_part(object.name, '/', 1) = v_user_id::text;

  if v_role = 'customer'::public.user_role then
    update public.bookings as booking
    set
      status = 'cancelled_by_customer',
      cancelled_by = v_user_id,
      cancelled_at = statement_timestamp()
    where booking.customer_id = v_user_id
      and booking.status = 'confirmed';

    update public.groomer_offers as offer
    set
      status = 'declined_by_customer',
      message = null
    where offer.customer_id = v_user_id
      and offer.status = 'pending';

    update public.request_matches as request_match
    set
      status = 'hidden',
      match_reason = null,
      dismiss_reason = 'account_deleted',
      dismissed_at = null
    where request_match.customer_id = v_user_id
      and request_match.status <> 'hidden';

    update public.grooming_requests as grooming_request
    set
      pet_snapshot = jsonb_build_object(
        'id',
        grooming_request.pet_id,
        'name',
        'Deleted pet',
        'species',
        'pet',
        'snapshot_at',
        statement_timestamp()
      ),
      photo_snapshot = '[]'::jsonb,
      service_notes = null,
      street_address = 'Address removed',
      city = 'Deleted',
      state = 'NA',
      zip_code = '00000',
      travel_radius_miles = case
        when grooming_request.location_mode = 'customer_comes_to_groomer'
        then coalesce(grooming_request.travel_radius_miles, 5)
        else null
      end,
      status = case
        when grooming_request.status in ('open', 'has_offers') then 'cancelled'
        else grooming_request.status
      end
    where grooming_request.customer_id = v_user_id;

    update public.pets as pet
    set
      name = 'Deleted pet',
      species = 'pet',
      breed = null,
      size = null,
      weight_lbs = null,
      birthday = null,
      temperament = null,
      medical_notes = null,
      grooming_notes = null,
      is_active = false,
      deleted_at = coalesce(pet.deleted_at, statement_timestamp())
    where pet.customer_id = v_user_id;

    update public.customer_profiles as customer_profile
    set
      street_address = null,
      city = null,
      state = null,
      zip_code = null,
      contact_email = null,
      phone_number = null
    where customer_profile.user_id = v_user_id;

    update public.messages as message
    set body = 'Message removed because this account was deleted.'
    where message.sender_id = v_user_id;

    update public.reviews as review
    set content = null
    where review.customer_id = v_user_id;

    delete from public.customer_notifications as notification
    where notification.customer_id = v_user_id;

    delete from public.customer_push_tokens as push_token
    where push_token.customer_id = v_user_id;

    delete from public.customer_booking_handoff_acknowledgements as acknowledgement
    where acknowledgement.customer_id = v_user_id;

    delete from public.request_photos as request_photo
    where request_photo.customer_id = v_user_id;

    delete from public.pet_photos as pet_photo
    where pet_photo.customer_id = v_user_id;
  else
    update public.bookings as booking
    set
      status = 'cancelled_by_groomer',
      cancelled_by = v_user_id,
      cancelled_at = statement_timestamp()
    where booking.groomer_id = v_user_id
      and booking.status = 'confirmed';

    update public.groomer_offers as offer
    set
      status = 'withdrawn_by_groomer',
      withdrawn_at = coalesce(offer.withdrawn_at, statement_timestamp()),
      message = null
    where offer.groomer_id = v_user_id
      and offer.status = 'pending';

    update public.groomer_offers as offer
    set message = null
    where offer.groomer_id = v_user_id
      and offer.status <> 'pending';

    update public.request_matches as request_match
    set
      status = 'hidden',
      match_reason = null,
      dismiss_reason = 'account_deleted',
      dismissed_at = null
    where request_match.groomer_id = v_user_id
      and request_match.status <> 'hidden';

    update public.groomer_profiles as groomer_profile
    set
      business_name = 'Deleted groomer',
      bio = null,
      years_experience = null,
      base_street_address = null,
      base_city = null,
      base_state = null,
      base_zip_code = null,
      service_radius_miles = null,
      service_location_mode = null,
      service_location_modes = null,
      is_active = false,
      is_verified = false
    where groomer_profile.user_id = v_user_id;

    update public.groomer_services as service
    set
      title = 'Deleted service',
      description = null,
      accepted_pet_sizes = '{}'::text[],
      is_active = false
    where service.groomer_id = v_user_id;

    update public.groomer_fit_claims as claim
    set is_active = false
    where claim.groomer_id = v_user_id;

    update public.messages as message
    set body = 'Message removed because this account was deleted.'
    where message.sender_id = v_user_id;

    delete from public.groomer_portfolio_photos as portfolio_photo
    where portfolio_photo.groomer_id = v_user_id;

    delete from public.groomer_availability_windows as availability_window
    where availability_window.groomer_id = v_user_id;

    delete from public.groomer_booking_preferences as booking_preference
    where booking_preference.groomer_id = v_user_id;

    delete from public.groomer_time_off_windows as time_off_window
    where time_off_window.groomer_id = v_user_id;
  end if;

  update public.account_deletion_requests as deletion_request
  set
    status = 'pending_auth_soft_delete',
    anonymized_at = statement_timestamp(),
    last_error = null
  where deletion_request.id = v_deletion_request_id;

  return query
  select
    v_deletion_request_id,
    v_user_id,
    v_role,
    'pending_auth_soft_delete'::text,
    v_requested_at;
end;
$$;

comment on function app_private.request_account_deletion() is
  'Privileged helper for signed-in account deletion. Public API is the security-invoker wrapper and Auth deletion is completed by the Edge Function.';

revoke all on function app_private.request_account_deletion()
from public, anon, authenticated, service_role;
grant execute on function app_private.request_account_deletion()
to authenticated;

create or replace function public.request_account_deletion()
returns table (
  deletion_request_id uuid,
  user_id uuid,
  role public.user_role,
  status text,
  requested_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.request_account_deletion();
$$;

comment on function public.request_account_deletion() is
  'Security-invoker API wrapper for the current user to request account deletion and server-side anonymization.';

revoke all on function public.request_account_deletion()
from public, anon, authenticated;
grant execute on function public.request_account_deletion()
to authenticated;

create or replace function public.record_account_deletion_auth_soft_deleted(
  p_deletion_request_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if p_deletion_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_deletion_request';
  end if;

  update public.account_deletion_requests as deletion_request
  set
    status = 'completed',
    auth_deleted_at = statement_timestamp(),
    anonymized_at = coalesce(
      deletion_request.anonymized_at,
      statement_timestamp()
    ),
    last_error = null
  where deletion_request.id = p_deletion_request_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'deletion_request_not_found';
  end if;
end;
$$;

comment on function public.record_account_deletion_auth_soft_deleted(uuid) is
  'Service-role RPC used by the delete-account Edge Function after Supabase Auth soft deletion succeeds.';

revoke all on function public.record_account_deletion_auth_soft_deleted(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.record_account_deletion_auth_soft_deleted(uuid)
to service_role;

create or replace function public.record_account_deletion_failure(
  p_deletion_request_id uuid,
  p_error text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_error text := left(nullif(btrim(p_error), ''), 500);
begin
  if p_deletion_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_deletion_request';
  end if;

  update public.account_deletion_requests as deletion_request
  set
    status = 'failed',
    last_error = coalesce(v_error, 'account_deletion_failed')
  where deletion_request.id = p_deletion_request_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'deletion_request_not_found';
  end if;
end;
$$;

comment on function public.record_account_deletion_failure(uuid, text) is
  'Service-role RPC used by the delete-account Edge Function when Supabase Auth soft deletion fails.';

revoke all on function public.record_account_deletion_failure(uuid, text)
from public, anon, authenticated, service_role;
grant execute on function public.record_account_deletion_failure(uuid, text)
to service_role;
