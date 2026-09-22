-- T-399: preserve the existing Booking hydration contract after the safe-read cutover.
create or replace function app_private.get_booking_request_locations_v1(p_request_ids uuid[])
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='42501',message='not_allowed';end if;
  if p_request_ids is null or cardinality(p_request_ids)>50 or array_position(p_request_ids,null) is not null then
    raise exception using errcode='22023',message='invalid_page';end if;
  return query select jsonb_build_object('id',r.id,'service_type',r.service_type,'pet_snapshot',r.pet_snapshot,
    'location_mode',r.location_mode,'street_address',r.street_address,
    'address_line_2',r.address_line_2,'city',r.city,'state',r.state,'zip_code',r.zip_code)
    from public.grooming_requests r where r.id=any(p_request_ids) and exists(select 1 from public.bookings b
      where b.request_id=r.id and actor in (b.customer_id,b.groomer_id));
end $$;

-- Media/detail participation does not promise that an offer can still win resource admission.
-- Check persisted terms and revocation facts, not full schedules, scoring or capacity per image.
create or replace function app_private.request_has_current_offer(p_request uuid,p_groomer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.groomer_offers o join public.grooming_requests r on r.id=o.request_id
    join public.groomer_profiles g on g.user_id=o.groomer_id
    join lateral app_private.offer_service_configuration(r.id,o.groomer_id,
      (o.agreement_snapshot->>'service_eligibility_revision')::uuid) s on true
    join app_private.address_locations a on a.id=(o.agreement_snapshot->'address'->>'source_location_id')::uuid
    where o.request_id=p_request and o.groomer_id=p_groomer and o.status='pending' and o.terms_invalid_reason is null
      and r.status in ('open','has_offers') and g.is_active
      and least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')>statement_timestamp()
      and o.agreement_snapshot->>'request_revision'=r.terms_revision::text
      and o.agreement_snapshot->>'groomer_eligibility_revision'=g.eligibility_revision::text
      and o.agreement_snapshot->>'service_eligibility_revision'=s.eligibility_revision::text
      and (o.agreement_snapshot->'address'->>'source_updated_at')::timestamptz=a.updated_at);
$$;

notify pgrst,'reload schema';
