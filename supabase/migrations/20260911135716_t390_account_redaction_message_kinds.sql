-- Booking cards retain a null body and read their now-redacted booking.
create or replace function app_private.request_account_deletion()
returns table(deletion_request_id uuid,user_id uuid,role public.user_role,status text,requested_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); actor_role public.user_role; deletion uuid; requested timestamptz:=statement_timestamp();
  item record; previous_redaction text:=current_setting('app.account_redaction_actor',true);
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  -- Order existing marketplace locks before identity/FK locks, including review writers' booking lock.
  perform 1 from public.grooming_requests r where r.customer_id=actor
    or exists(select 1 from public.groomer_offers o where o.request_id=r.id and o.groomer_id=actor)
    order by r.id for update;
  perform 1 from public.bookings b where actor in (b.customer_id,b.groomer_id) order by b.id for update;
  for item in select groomer_id from (
    select b.groomer_id from public.bookings b where actor in (b.customer_id,b.groomer_id)
    union select o.groomer_id from public.groomer_offers o where actor in (o.customer_id,o.groomer_id)
    union select actor where exists(select 1 from public.groomer_profiles where public.groomer_profiles.user_id=actor)
  ) groomers order by groomer_id loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(item.groomer_id::text,71071));
  end loop;
  select p.role into actor_role from public.profiles p where p.id=actor for update;
  if not found then raise exception using errcode='P0001',message='profile_required'; end if;
  insert into public.account_deletion_requests as d(user_id,role,status,requested_at,last_error)
    values(actor,actor_role,'pending_auth_soft_delete',requested,null)
    on conflict on constraint account_deletion_requests_user_key do update
      set role=excluded.role,status='pending_auth_soft_delete',requested_at=excluded.requested_at,
        auth_deleted_at=null,last_error=null returning d.id into deletion;
  perform set_config('app.account_redaction_actor',actor::text,true);

  for item in select b.id,b.fulfillment_revision from public.bookings b
    where actor in (b.customer_id,b.groomer_id) and b.status='confirmed'
      and b.fulfillment_phase='scheduled' and b.scheduled_start>clock_timestamp() order by b.id loop
    begin
      perform app_private.mutate_booking_fulfillment(item.id,item.fulfillment_revision,gen_random_uuid(),'cancel',null);
    exception when sqlstate 'P0001' then
      if sqlerrm<>'use_service_outcome_report' then raise; end if;
    end;
  end loop;
  -- Ongoing service retains its actual allocation/phase; account deletion is not an outcome report.
  update public.groomer_offers o set message=null,
    agreement_snapshot=app_private.redacted_agreement(o.agreement_snapshot,o.customer_id,o.groomer_id),
    status=case when o.status='pending' then case when actor=o.customer_id then 'declined_by_customer' else 'withdrawn_by_groomer' end else o.status end,
    withdrawn_at=case when o.status='pending' and actor=o.groomer_id then coalesce(o.withdrawn_at,statement_timestamp()) else o.withdrawn_at end
    where actor in (o.customer_id,o.groomer_id);
  update public.bookings b set agreement_snapshot=app_private.redacted_agreement(b.agreement_snapshot,b.customer_id,b.groomer_id)
    where actor in (b.customer_id,b.groomer_id);
  update public.booking_reschedule_proposals p set
    previous_agreement=app_private.redacted_agreement(p.previous_agreement,b.customer_id,b.groomer_id),
    proposed_agreement=app_private.redacted_agreement(p.proposed_agreement,b.customer_id,b.groomer_id)
    from public.bookings b where p.booking_id=b.id and actor in (b.customer_id,b.groomer_id);
  update public.request_matches m set status='hidden',match_reason=null,dismiss_reason='account_deleted',dismissed_at=null
    where actor in (m.customer_id,m.groomer_id) and m.status<>'hidden';
  update public.profiles p set display_name=case when actor_role='customer' then 'Deleted customer' else 'Deleted groomer' end,
    avatar_path=null where p.id=actor;
  update public.messages m set body='Message removed because this account was deleted.' where m.sender_id=actor and m.kind='text';

  if actor_role='customer' then
    update public.grooming_requests r set
      pet_snapshot=jsonb_build_object('id',r.pet_id,'name','Deleted pet','species','pet'),photo_snapshot='[]',service_notes=null,
      street_address='Address removed',address_line_2=null,city='Deleted',state='NA',zip_code='00000',address_location_id=null,
      status=case when r.status in ('open','has_offers') then 'cancelled' else r.status end where r.customer_id=actor;
    update public.pets p set name='Deleted pet',breed='Unspecified',coat_type=null,coat_type_source='unknown',matting_confirmed=null,
      size=null,weight_lbs=null,birthday=null,temperament='Not Sure',medical_notes=null,grooming_notes=null,is_active=false,
      deleted_at=coalesce(p.deleted_at,statement_timestamp()) where p.customer_id=actor;
    update public.customer_profiles p set street_address=null,address_line_2=null,city=null,state=null,zip_code=null,
      address_location_id=null,contact_email=null,phone_number=null where p.user_id=actor;
    update public.reviews r set content=null where r.customer_id=actor;
    delete from public.customer_notifications where customer_id=actor;
    delete from public.customer_push_tokens where customer_id=actor;
    delete from public.customer_booking_handoff_acknowledgements where customer_id=actor;
    delete from public.request_photos where customer_id=actor;
    delete from public.pet_photos where customer_id=actor;
  else
    update public.groomer_profiles p set business_name='Deleted groomer',bio=null,years_experience=null,
      base_street_address=null,base_address_line_2=null,base_city=null,base_state=null,base_zip_code=null,address_location_id=null,
      service_radius_miles=null,service_location_mode=null,service_location_modes=null,is_active=false,is_verified=false where p.user_id=actor;
    update public.groomer_services set title='Deleted service',description=null,accepted_pet_sizes='{}',is_active=false where groomer_id=actor;
    update public.groomer_fit_claims set is_active=false where groomer_id=actor;
    delete from public.groomer_portfolio_photos where groomer_id=actor;
    if not exists(select 1 from public.bookings b where b.groomer_id=actor and b.status='confirmed') then
      delete from public.groomer_availability_windows where groomer_id=actor;
      delete from public.groomer_booking_preferences where groomer_id=actor;
      delete from public.groomer_time_off_windows where groomer_id=actor;
    end if;
  end if;
  delete from app_private.address_locations where owner_id=actor;
  update public.account_deletion_requests d set anonymized_at=statement_timestamp(),last_error=null where d.id=deletion;
  perform set_config('app.account_redaction_actor',coalesce(previous_redaction,''),true);
  return query select deletion,actor,actor_role,'pending_auth_soft_delete'::text,requested;
end $$;
revoke all on function app_private.request_account_deletion() from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
