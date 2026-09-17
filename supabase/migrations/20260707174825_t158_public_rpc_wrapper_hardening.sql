alter function public.accept_groomer_offer(uuid) set schema app_private;
revoke all on function app_private.accept_groomer_offer(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.accept_groomer_offer(uuid) to authenticated;

create or replace function public.accept_groomer_offer(
  p_offer_id uuid
)
returns table (
  booking_id uuid,
  conversation_id uuid,
  request_id uuid,
  offer_id uuid,
  booking_status text,
  offer_status text,
  request_status text
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.accept_groomer_offer(p_offer_id);
$$;

comment on function public.accept_groomer_offer(uuid) is
  'Security-invoker API wrapper for accepting a groomer offer; privileged logic lives in app_private.';

revoke all on function public.accept_groomer_offer(uuid)
from public, anon, authenticated;
grant execute on function public.accept_groomer_offer(uuid) to authenticated;

alter function public.cancel_booking(uuid) set schema app_private;
revoke all on function app_private.cancel_booking(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.cancel_booking(uuid) to authenticated;

create or replace function public.cancel_booking(
  p_booking_id uuid
)
returns table (
  booking_id uuid,
  booking_status text,
  cancelled_timestamp timestamptz,
  cancelled_by uuid
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.cancel_booking(p_booking_id);
$$;

comment on function public.cancel_booking(uuid) is
  'Security-invoker API wrapper for booking cancellation; privileged logic lives in app_private.';

revoke all on function public.cancel_booking(uuid)
from public, anon, authenticated;
grant execute on function public.cancel_booking(uuid) to authenticated;

alter function public.cancel_grooming_request(uuid) set schema app_private;
revoke all on function app_private.cancel_grooming_request(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.cancel_grooming_request(uuid) to authenticated;

create or replace function public.cancel_grooming_request(
  p_request_id uuid
)
returns table (
  request_id uuid,
  request_status text,
  cancelled_timestamp timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.cancel_grooming_request(p_request_id);
$$;

comment on function public.cancel_grooming_request(uuid) is
  'Security-invoker API wrapper for request cancellation; privileged logic lives in app_private.';

revoke all on function public.cancel_grooming_request(uuid)
from public, anon, authenticated;
grant execute on function public.cancel_grooming_request(uuid) to authenticated;

alter function public.complete_booking(uuid) set schema app_private;
revoke all on function app_private.complete_booking(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.complete_booking(uuid) to authenticated;

create or replace function public.complete_booking(
  p_booking_id uuid
)
returns table (
  booking_id uuid,
  booking_status text,
  completed_timestamp timestamptz,
  completed_by uuid
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.complete_booking(p_booking_id);
$$;

comment on function public.complete_booking(uuid) is
  'Security-invoker API wrapper for groomer booking completion; privileged logic lives in app_private.';

revoke all on function public.complete_booking(uuid)
from public, anon, authenticated;
grant execute on function public.complete_booking(uuid) to authenticated;

alter function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text) set schema app_private;
revoke all on function app_private.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text)
from public, anon, authenticated, service_role;
grant execute on function app_private.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text) to authenticated;

create or replace function public.create_groomer_offer(
  p_request_id uuid,
  p_proposed_start timestamptz,
  p_proposed_end timestamptz,
  p_price_estimate numeric,
  p_message text default null::text
)
returns table (
  offer_id uuid,
  offer_status text,
  request_status text
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.create_groomer_offer(
    p_request_id,
    p_proposed_start,
    p_proposed_end,
    p_price_estimate,
    p_message
  );
$$;

comment on function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text) is
  'Security-invoker API wrapper for groomer offer creation; privileged logic lives in app_private.';

revoke all on function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text)
from public, anon, authenticated;
grant execute on function public.create_groomer_offer(uuid, timestamptz, timestamptz, numeric, text) to authenticated;

alter function public.create_grooming_request(uuid, text, text, timestamptz, timestamptz, text, text, text, text, text, integer) set schema app_private;
revoke all on function app_private.create_grooming_request(uuid, text, text, timestamptz, timestamptz, text, text, text, text, text, integer)
from public, anon, authenticated, service_role;
grant execute on function app_private.create_grooming_request(uuid, text, text, timestamptz, timestamptz, text, text, text, text, text, integer) to authenticated;

create or replace function public.create_grooming_request(
  p_pet_id uuid,
  p_service_type text,
  p_service_notes text,
  p_preferred_start timestamptz,
  p_preferred_end timestamptz,
  p_location_mode text,
  p_street_address text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_travel_radius_miles integer default null::integer
)
returns table (
  request_id uuid,
  match_count integer
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.create_grooming_request(
    p_pet_id,
    p_service_type,
    p_service_notes,
    p_preferred_start,
    p_preferred_end,
    p_location_mode,
    p_street_address,
    p_city,
    p_state,
    p_zip_code,
    p_travel_radius_miles
  );
$$;

comment on function public.create_grooming_request(uuid, text, text, timestamptz, timestamptz, text, text, text, text, text, integer) is
  'Security-invoker API wrapper for customer request creation; privileged logic lives in app_private.';

revoke all on function public.create_grooming_request(uuid, text, text, timestamptz, timestamptz, text, text, text, text, text, integer)
from public, anon, authenticated;
grant execute on function public.create_grooming_request(uuid, text, text, timestamptz, timestamptz, text, text, text, text, text, integer) to authenticated;

alter function public.create_review(uuid, integer, text, jsonb) set schema app_private;
revoke all on function app_private.create_review(uuid, integer, text, jsonb)
from public, anon, authenticated, service_role;
grant execute on function app_private.create_review(uuid, integer, text, jsonb) to authenticated;

create or replace function public.create_review(
  p_booking_id uuid,
  p_rating integer,
  p_content text default null::text,
  p_pet_fit_outcomes jsonb default '[]'::jsonb
)
returns table (
  review_id uuid,
  booking_id uuid,
  customer_id uuid,
  groomer_id uuid,
  rating integer,
  content text,
  created_at timestamptz,
  groomer_rating_avg numeric,
  groomer_rating_count integer
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.create_review(
    p_booking_id,
    p_rating,
    p_content,
    p_pet_fit_outcomes
  );
$$;

comment on function public.create_review(uuid, integer, text, jsonb) is
  'Security-invoker API wrapper for customer review creation; privileged logic lives in app_private.';

revoke all on function public.create_review(uuid, integer, text, jsonb)
from public, anon, authenticated;
grant execute on function public.create_review(uuid, integer, text, jsonb) to authenticated;

alter function public.dismiss_request_match(uuid, text) set schema app_private;
revoke all on function app_private.dismiss_request_match(uuid, text)
from public, anon, authenticated, service_role;
grant execute on function app_private.dismiss_request_match(uuid, text) to authenticated;

create or replace function public.dismiss_request_match(
  p_match_id uuid,
  p_reason text default null::text
)
returns table (
  match_id uuid,
  status text,
  dismissed_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.dismiss_request_match(
    p_match_id,
    p_reason
  );
$$;

comment on function public.dismiss_request_match(uuid, text) is
  'Security-invoker API wrapper for groomer match dismissal; privileged logic lives in app_private.';

revoke all on function public.dismiss_request_match(uuid, text)
from public, anon, authenticated;
grant execute on function public.dismiss_request_match(uuid, text) to authenticated;

alter function public.get_my_groomer_pet_fit_evidence_summary() set schema app_private;
revoke all on function app_private.get_my_groomer_pet_fit_evidence_summary()
from public, anon, authenticated, service_role;
grant execute on function app_private.get_my_groomer_pet_fit_evidence_summary() to authenticated;

create or replace function public.get_my_groomer_pet_fit_evidence_summary()
returns table (
  groomer_id uuid,
  trait_type text,
  trait_value text,
  completed_booking_count bigint,
  positive_review_outcome_count bigint,
  negative_review_outcome_count bigint,
  structured_review_outcome_count bigint,
  last_completed_at timestamptz,
  last_review_outcome_at timestamptz,
  evidence_updated_at timestamptz,
  confidence_tier text
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.get_my_groomer_pet_fit_evidence_summary();
$$;

comment on function public.get_my_groomer_pet_fit_evidence_summary() is
  'Security-invoker API wrapper for the current groomer evidence summary; privileged logic lives in app_private.';

revoke all on function public.get_my_groomer_pet_fit_evidence_summary()
from public, anon, authenticated;
grant execute on function public.get_my_groomer_pet_fit_evidence_summary() to authenticated;

alter function public.withdraw_groomer_offer(uuid) set schema app_private;
revoke all on function app_private.withdraw_groomer_offer(uuid)
from public, anon, authenticated, service_role;
grant execute on function app_private.withdraw_groomer_offer(uuid) to authenticated;

create or replace function public.withdraw_groomer_offer(
  p_offer_id uuid
)
returns table (
  offer_id uuid,
  offer_status text,
  withdrawn_timestamp timestamptz,
  request_status text
)
language sql
security invoker
set search_path = ''
as $$
  select *
  from app_private.withdraw_groomer_offer(p_offer_id);
$$;

comment on function public.withdraw_groomer_offer(uuid) is
  'Security-invoker API wrapper for groomer offer withdrawal; privileged logic lives in app_private.';

revoke all on function public.withdraw_groomer_offer(uuid)
from public, anon, authenticated;
grant execute on function public.withdraw_groomer_offer(uuid) to authenticated;
