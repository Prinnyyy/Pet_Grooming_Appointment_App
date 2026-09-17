create table public.booking_reschedule_proposals (
  id uuid primary key,
  booking_id uuid not null references public.bookings(id) on delete cascade,
  base_revision uuid not null,
  initiator_id uuid not null references public.profiles(id) on delete cascade,
  proposed_start timestamptz not null,
  proposed_end timestamptz not null,
  proposed_occupied_start timestamptz not null,
  proposed_occupied_end timestamptz not null,
  previous_agreement jsonb not null,
  proposed_agreement jsonb not null,
  status text not null default 'pending' check(status in ('pending','accepted','rejected','withdrawn','expired','invalidated')),
  created_at timestamptz not null,
  expires_at timestamptz not null,
  responded_by uuid references public.profiles(id) on delete cascade,
  responded_at timestamptz,
  result_revision uuid,
  check(proposed_start<proposed_end and proposed_occupied_start<=proposed_start
    and proposed_occupied_end>=proposed_end and expires_at>created_at),
  check(status<>'accepted' or (responded_by is not null and responded_by<>initiator_id
    and responded_at is not null))
);
create unique index booking_reschedule_one_pending on public.booking_reschedule_proposals(booking_id) where status='pending';
create index booking_reschedule_booking_created on public.booking_reschedule_proposals(booking_id,created_at desc);
create index booking_reschedule_initiator on public.booking_reschedule_proposals(initiator_id);
create index booking_reschedule_responder on public.booking_reschedule_proposals(responded_by);
alter table public.booking_reschedule_proposals enable row level security;
revoke all on public.booking_reschedule_proposals from public,anon,authenticated,service_role;
grant select on public.booking_reschedule_proposals to authenticated;
create policy booking_reschedule_participant_read on public.booking_reschedule_proposals
for select to authenticated using(exists(select 1 from public.bookings b join public.profiles p
  on p.id=(select auth.uid()) where b.id=booking_id
    and ((b.customer_id=p.id and p.role='customer') or (b.groomer_id=p.id and p.role='groomer'))));

create table app_private.booking_reschedule_operations (
  actor_id uuid not null references public.profiles(id) on delete cascade,
  operation_id uuid not null,
  booking_id uuid not null references public.bookings(id) on delete cascade,
  proposal_id uuid not null references public.booking_reschedule_proposals(id) on delete cascade,
  intent jsonb not null,
  receipt jsonb not null,
  primary key(actor_id,operation_id)
);
create index booking_reschedule_operations_booking on app_private.booking_reschedule_operations(booking_id);
create index booking_reschedule_operations_proposal on app_private.booking_reschedule_operations(proposal_id);
alter table app_private.booking_reschedule_operations enable row level security;
revoke all on app_private.booking_reschedule_operations from public,anon,authenticated,service_role;

create function app_private.require_reschedule_participant(p_booking_id uuid)
returns public.bookings language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required'; end if;
  select booking.* into b from public.bookings booking join public.profiles profile on profile.id=actor
    where booking.id=p_booking_id and ((booking.customer_id=actor and profile.role='customer')
      or (booking.groomer_id=actor and profile.role='groomer'));
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  return b;
end $$;

create function app_private.booking_reschedule_state(p_booking_id uuid,p_proposal_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.bookings%rowtype; proposal public.booking_reschedule_proposals%rowtype; state text; result jsonb;
begin
  b:=app_private.require_reschedule_participant(p_booking_id);
  select * into proposal from public.booking_reschedule_proposals where booking_id=b.id
    and (p_proposal_id is null or id=p_proposal_id) order by created_at desc,id desc limit 1;
  if found then
    state:=proposal.status;
    if state='pending' then
      if b.fulfillment_revision<>proposal.base_revision or b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' then
        state:='invalidated';
      elsif proposal.expires_at<=clock_timestamp() or b.scheduled_start<=clock_timestamp() then state:='expired'; end if;
    end if;
    result:=to_jsonb(proposal)||jsonb_build_object('effective_status',state);
  end if;
  return jsonb_build_object('booking',to_jsonb(b),'proposal',result);
end $$;

create function app_private.get_booking_reschedule(p_booking_id uuid)
returns jsonb language sql security definer set search_path='' as $$
  select app_private.booking_reschedule_state(p_booking_id);
$$;

create function app_private.get_booking_reschedule_operation(p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); operation app_private.booking_reschedule_operations%rowtype;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required'; end if;
  select * into operation from app_private.booking_reschedule_operations where actor_id=actor and operation_id=p_operation_id;
  if not found then return null; end if;
  return app_private.booking_reschedule_state(operation.booking_id,operation.proposal_id)
    ||jsonb_build_object('receipt',operation.receipt,'replayed',true);
end $$;

create function app_private.validate_reschedule_candidate(b public.bookings,p_start timestamptz,p_now timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare ending timestamptz; v_occupied_start timestamptz; v_occupied_end timestamptz;
  zone text; zones integer; windows integer; daily_limit integer; notice integer;
begin
  if b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' or b.scheduled_start<=p_now then
    raise exception using errcode='22023',message='booking_not_reschedulable'; end if;
  if p_start is null or not pg_catalog.isfinite(p_start) or p_start=b.scheduled_start then
    raise exception using errcode='22023',message='invalid_reschedule_time'; end if;
  if b.agreement_snapshot is null or b.agreement_snapshot->>'schema_version' is distinct from '1'
    or b.pet_id is null or b.service_time_zone_identifier is null
    or app_private.valid_timing_buffers(b.applied_timing_buffers) is not true then
    raise exception using errcode='22023',message='reschedule_agreement_verification_required'; end if;
  ending:=p_start+(b.scheduled_end-b.scheduled_start);
  v_occupied_start:=p_start-make_interval(mins=>(b.applied_timing_buffers->>'preparation_minutes')::integer
    +(b.applied_timing_buffers->>'inbound_travel_minutes')::integer);
  v_occupied_end:=ending+make_interval(mins=>(b.applied_timing_buffers->>'cleanup_minutes')::integer
    +(b.applied_timing_buffers->>'outbound_travel_minutes')::integer);
  select min(timezone),count(distinct timezone),count(*) into zone,zones,windows
    from public.groomer_availability_windows where groomer_id=b.groomer_id;
  if zones<>1 or windows<>7 or not exists(select 1 from pg_catalog.pg_timezone_names where name=zone) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required'; end if;
  select coalesce(p.max_appointments_per_day,4),coalesce(p.minimum_advance_notice_days,0) into daily_limit,notice
    from public.groomer_profiles g left join public.groomer_booking_preferences p on p.groomer_id=g.user_id
    where g.user_id=b.groomer_id;
  if not found or p_start<app_private.service_timing_earliest_start(p_now,notice,zone) then
    raise exception using errcode='22023',message='reschedule_notice_required'; end if;
  if app_private.occupied_time_off_conflict(b.groomer_id,v_occupied_start,v_occupied_end)
    or not app_private.occupied_weekly_hours_covered(b.groomer_id,v_occupied_start,v_occupied_end) then
    raise exception using errcode='22023',message='reschedule_outside_availability'; end if;
  if exists(select 1 from public.bookings other where other.id<>b.id
    and other.status in ('confirmed','completed','unfulfilled')
    and ((other.groomer_id=b.groomer_id and coalesce(other.occupied_start,other.scheduled_start)<v_occupied_end
      and v_occupied_start<app_private.booking_resource_end(other.scheduled_start,other.scheduled_end,
        other.occupied_start,other.occupied_end,other.resource_release_at))
      or (other.pet_id=b.pet_id and other.scheduled_start<ending
        and p_start<app_private.booking_pet_end(other.scheduled_start,other.scheduled_end,other.pet_release_at)))) then
    raise exception using errcode='PT409',message='reschedule_resource_conflict'; end if;
  if (select count(*) from public.bookings other where other.id<>b.id and other.groomer_id=b.groomer_id
    and other.status in ('confirmed','completed','unfulfilled')
    and timezone(zone,other.scheduled_start)::date=timezone(zone,p_start)::date)>=daily_limit then
    raise exception using errcode='PT409',message='reschedule_daily_limit'; end if;
  return jsonb_build_object('start',p_start,'end',ending,'occupied_start',v_occupied_start,'occupied_end',v_occupied_end);
end $$;

create function app_private.authorized_reschedule_change(proposed public.bookings,previous public.bookings)
returns boolean language sql stable security definer set search_path='' as $$
  select previous.status='confirmed' and previous.fulfillment_phase='scheduled'
    and to_jsonb(proposed)-array['scheduled_start','scheduled_end','occupied_start','occupied_end','agreement_snapshot','fulfillment_revision','updated_at']
      =to_jsonb(previous)-array['scheduled_start','scheduled_end','occupied_start','occupied_end','agreement_snapshot','fulfillment_revision','updated_at']
    and exists(select 1 from public.booking_reschedule_proposals change
      where change.id::text=current_setting('app.reschedule_proposal',true) and change.booking_id=previous.id
        and change.status='accepted' and change.base_revision=previous.fulfillment_revision
        and change.responded_by<>change.initiator_id
        and change.previous_agreement=previous.agreement_snapshot and change.proposed_agreement=proposed.agreement_snapshot
        and change.proposed_start=proposed.scheduled_start and change.proposed_end=proposed.scheduled_end
        and change.proposed_occupied_start=proposed.occupied_start and change.proposed_occupied_end=proposed.occupied_end);
$$;

create function app_private.mutate_booking_reschedule(p_booking_id uuid,p_expected_revision uuid,p_operation_id uuid,
  p_action text,p_proposal_id uuid,p_new_start timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype; proposal public.booking_reschedule_proposals%rowtype;
  operation app_private.booking_reschedule_operations%rowtype; parent uuid; at_time timestamptz; candidate jsonb;
  intent jsonb; receipt jsonb; deadline timestamptz; conversation uuid; chat_text text;
  prior_change text:=current_setting('app.reschedule_proposal',true); prior_fulfillment text:=current_setting('app.fulfillment_write',true);
begin
  b:=app_private.require_reschedule_participant(p_booking_id);
  if p_expected_revision is null or p_operation_id is null or p_proposal_id is null or p_action is null
    or (p_action<>'propose' and p_new_start is not null) then
    raise exception using errcode='22023',message='invalid_reschedule_operation'; end if;
  intent:=jsonb_build_object('booking_id',p_booking_id,'expected_revision',p_expected_revision,
    'action',p_action,'proposal_id',p_proposal_id,'new_start',p_new_start);
  perform pg_advisory_xact_lock(hashtextextended(actor::text||p_operation_id::text,71378));
  select * into operation from app_private.booking_reschedule_operations where actor_id=actor and operation_id=p_operation_id;
  if found then
    if operation.intent<>intent then raise exception using errcode='22023',message='reschedule_operation_intent_changed'; end if;
    return app_private.get_booking_reschedule_operation(p_operation_id);
  end if;
  select id into parent from public.grooming_requests where id=b.request_id for update;
  select * into strict b from public.bookings where id=p_booking_id for update;
  perform app_private.require_reschedule_participant(b.id);
  perform pg_advisory_xact_lock(hashtextextended(b.groomer_id::text,71071));
  at_time:=clock_timestamp();
  if b.fulfillment_revision<>p_expected_revision then
    raise exception using errcode='PT409',message='booking_revision_changed'; end if;
  if p_action='propose' then
    candidate:=app_private.validate_reschedule_candidate(b,p_new_start,at_time);
    update public.booking_reschedule_proposals set status=case when base_revision<>b.fulfillment_revision then 'invalidated' else 'expired' end
      where booking_id=b.id and status='pending' and (base_revision<>b.fulfillment_revision or expires_at<=at_time);
    if exists(select 1 from public.booking_reschedule_proposals where booking_id=b.id and status='pending') then
      raise exception using errcode='PT409',message='reschedule_proposal_pending'; end if;
    deadline:=least(at_time+interval '24 hours',b.scheduled_start,p_new_start-interval '5 minutes');
    if deadline<=at_time then raise exception using errcode='22023',message='reschedule_deadline_passed'; end if;
    insert into public.booking_reschedule_proposals(id,booking_id,base_revision,initiator_id,
      proposed_start,proposed_end,proposed_occupied_start,proposed_occupied_end,previous_agreement,proposed_agreement,created_at,expires_at)
    values(p_proposal_id,b.id,b.fulfillment_revision,actor,p_new_start,(candidate->>'end')::timestamptz,
      (candidate->>'occupied_start')::timestamptz,(candidate->>'occupied_end')::timestamptz,b.agreement_snapshot,
      b.agreement_snapshot||jsonb_build_object('scheduled_start',p_new_start,'scheduled_end',(candidate->>'end')::timestamptz,
        'reschedule_id',p_proposal_id),at_time,deadline) returning * into proposal;
    chat_text:='A new appointment time was proposed. The original appointment remains confirmed until both participants agree.';
  elsif p_action in ('accept','reject','withdraw') then
    select * into proposal from public.booking_reschedule_proposals where id=p_proposal_id and booking_id=b.id for update;
    if not found or proposal.status<>'pending' or proposal.base_revision<>b.fulfillment_revision
      or b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' then
      raise exception using errcode='PT409',message='reschedule_proposal_changed'; end if;
    if proposal.expires_at<=at_time or b.scheduled_start<=at_time then
      raise exception using errcode='22023',message='reschedule_deadline_passed'; end if;
    if (p_action='withdraw' and actor<>proposal.initiator_id)
      or (p_action<>'withdraw' and actor=proposal.initiator_id) then
      raise exception using errcode='42501',message='reschedule_other_participant_required'; end if;
    if p_action='accept' then
      candidate:=app_private.validate_reschedule_candidate(b,proposal.proposed_start,at_time);
      update public.booking_reschedule_proposals set status='accepted',responded_by=actor,responded_at=at_time where id=proposal.id;
      perform set_config('app.reschedule_proposal',proposal.id::text,true);
      perform set_config('app.fulfillment_write','1',true);
      update public.bookings set scheduled_start=proposal.proposed_start,scheduled_end=proposal.proposed_end,
        occupied_start=proposal.proposed_occupied_start,occupied_end=proposal.proposed_occupied_end,
        agreement_snapshot=proposal.proposed_agreement,fulfillment_revision=gen_random_uuid()
        where id=b.id returning * into b;
      perform set_config('app.reschedule_proposal',coalesce(prior_change,''),true);
      perform set_config('app.fulfillment_write',coalesce(prior_fulfillment,''),true);
      update public.booking_reschedule_proposals set result_revision=b.fulfillment_revision where id=proposal.id;
      chat_text:='The proposed appointment time was accepted. This booking now uses the newly agreed time.';
    else
      update public.booking_reschedule_proposals set status=case p_action when 'reject' then 'rejected' else 'withdrawn' end,
        responded_by=actor,responded_at=at_time where id=proposal.id;
      chat_text:=case p_action when 'reject' then 'The time change was declined. The original appointment remains confirmed.'
        else 'The time change was withdrawn. The original appointment remains confirmed.' end;
    end if;
  else raise exception using errcode='22023',message='invalid_reschedule_operation'; end if;
  receipt:=jsonb_build_object('operation_id',p_operation_id,'booking_id',b.id,'proposal_id',p_proposal_id,
    'action',p_action,'result_revision',b.fulfillment_revision,'recorded_at',at_time);
  insert into app_private.booking_reschedule_operations(actor_id,operation_id,booking_id,proposal_id,intent,receipt)
    values(actor,p_operation_id,b.id,p_proposal_id,intent,receipt);
  select id into conversation from public.conversations where customer_id=b.customer_id and groomer_id=b.groomer_id;
  if conversation is null then raise exception using errcode='P0001',message='conversation_not_found'; end if;
  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at) values(conversation,actor,'booking_card',b.id,at_time);
  insert into public.messages(conversation_id,sender_id,kind,body,created_at) values(conversation,actor,'text',chat_text,at_time+interval '1 microsecond');
  return app_private.booking_reschedule_state(b.id,p_proposal_id)||jsonb_build_object('receipt',receipt,'replayed',false);
end $$;

create function public.get_booking_reschedule(p_booking_id uuid)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.get_booking_reschedule(p_booking_id); $$;
create function public.get_booking_reschedule_operation(p_operation_id uuid)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.get_booking_reschedule_operation(p_operation_id); $$;
create function public.mutate_booking_reschedule(p_booking_id uuid,p_expected_revision uuid,p_operation_id uuid,
  p_action text,p_proposal_id uuid,p_new_start timestamptz default null)
returns jsonb language sql security invoker set search_path='' as $$
  select app_private.mutate_booking_reschedule(p_booking_id,p_expected_revision,p_operation_id,p_action,p_proposal_id,p_new_start);
$$;
revoke all on function app_private.require_reschedule_participant(uuid),app_private.booking_reschedule_state(uuid,uuid),
  app_private.validate_reschedule_candidate(public.bookings,timestamptz,timestamptz),
  app_private.authorized_reschedule_change(public.bookings,public.bookings),
  app_private.get_booking_reschedule(uuid),app_private.get_booking_reschedule_operation(uuid),
  app_private.mutate_booking_reschedule(uuid,uuid,uuid,text,uuid,timestamptz),
  public.get_booking_reschedule(uuid),public.get_booking_reschedule_operation(uuid),
  public.mutate_booking_reschedule(uuid,uuid,uuid,text,uuid,timestamptz) from public,anon,authenticated,service_role;
grant execute on function app_private.get_booking_reschedule(uuid),app_private.get_booking_reschedule_operation(uuid),
  app_private.mutate_booking_reschedule(uuid,uuid,uuid,text,uuid,timestamptz),
  public.get_booking_reschedule(uuid),public.get_booking_reschedule_operation(uuid),
  public.mutate_booking_reschedule(uuid,uuid,uuid,text,uuid,timestamptz) to authenticated;


-- Only accepted, exact bilateral changes may pass the original immutable guards.
CREATE OR REPLACE FUNCTION app_private.guard_booking_admission()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_pet_id uuid;
begin
  if tg_op = 'UPDATE' then
    if app_private.authorized_reschedule_change(new,old) then return new; end if;
    if (new.request_id, new.offer_id, new.customer_id, new.groomer_id,
        new.pet_id, new.scheduled_start, new.scheduled_end)
      is distinct from
       (old.request_id, old.offer_id, old.customer_id, old.groomer_id,
        old.pet_id, old.scheduled_start, old.scheduled_end) then
      raise exception using errcode = 'P0001', message = 'booking_allocation_immutable';
    end if;
    -- Cancellation/completion preserve the original allocation and receipt.
    if new.status <> 'confirmed' or old.status = 'confirmed' then
      return new;
    end if;
    raise exception using errcode = 'P0001', message = 'booking_not_reactivatable';
  end if;

  select request.pet_id into v_pet_id
  from public.grooming_requests as request
  where request.id = new.request_id and request.customer_id = new.customer_id;
  if v_pet_id is null or (new.pet_id is not null and new.pet_id <> v_pet_id) then
    raise exception using errcode = 'P0001', message = 'booking_pet_identity_required';
  end if;
  new.pet_id := v_pet_id;
  if new.status <> 'confirmed' then
    raise exception using errcode = 'P0001', message = 'booking_must_start_confirmed';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.groomer_id::text, 71071)
  );
  if not app_private.groomer_can_admit_service(
    new.groomer_id, new.scheduled_start, new.scheduled_end
  ) then
    raise exception using errcode = 'P0001', message = 'booking_conflict';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION app_private.snapshot_booking_timing()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_offer public.groomer_offers%rowtype;
begin
  if tg_op='UPDATE' then
    if app_private.authorized_reschedule_change(new,old) then return new; end if;
    if row(new.applied_timing_buffers,new.service_time_zone_identifier,new.schedule_time_zone_identifier,
        new.occupied_start,new.occupied_end) is distinct from
       row(old.applied_timing_buffers,old.service_time_zone_identifier,old.schedule_time_zone_identifier,
        old.occupied_start,old.occupied_end) then
      raise exception using errcode='23514',message='booking_timing_snapshot_immutable';
    end if;
    return new;
  end if;
  select * into v_offer from public.groomer_offers where id=new.offer_id and request_id=new.request_id
    and customer_id=new.customer_id and groomer_id=new.groomer_id;
  if not found or new.scheduled_start is distinct from v_offer.proposed_start
    or new.scheduled_end is distinct from v_offer.proposed_end then
    raise exception using errcode='23514',message='booking_offer_timing_mismatch';
  end if;
  if v_offer.occupied_start is null or v_offer.occupied_end is null
    or v_offer.service_time_zone_identifier is null or v_offer.schedule_time_zone_identifier is null
    or not app_private.valid_timing_buffers(v_offer.applied_timing_buffers) then
    raise exception using errcode='P0001',message='updated_timing_offer_required';
  end if;
  new.applied_timing_buffers := v_offer.applied_timing_buffers;
  new.service_time_zone_identifier := v_offer.service_time_zone_identifier;
  new.schedule_time_zone_identifier := v_offer.schedule_time_zone_identifier;
  new.occupied_start := v_offer.occupied_start;
  new.occupied_end := v_offer.occupied_end;
  if app_private.occupied_time_off_conflict(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_time_off_conflict';
  end if;
  if not app_private.occupied_weekly_hours_covered(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_outside_weekly_hours';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION app_private.snapshot_booking_agreement()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.groomer_offers%rowtype; r public.grooming_requests%rowtype; evaluation jsonb;
begin
  if tg_op='UPDATE' then
    if app_private.authorized_reschedule_change(new,old) then return new; end if;
    if row(new.agreement_snapshot,new.price_estimate) is distinct from row(old.agreement_snapshot,old.price_estimate) then
      raise exception using errcode='23514',message='booking_agreement_is_immutable';
    end if;
    return new;
  end if;
  select * into strict r from public.grooming_requests where id=new.request_id for update;
  select * into strict o from public.groomer_offers where id=new.offer_id and request_id=new.request_id
    and customer_id=new.customer_id and groomer_id=new.groomer_id;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.groomer_id::text,71071));
  evaluation:=app_private.evaluate_quote(o.id);
  if evaluation->>'terms_valid' is distinct from 'true' then
    raise exception using errcode='22023',message='quote_terms_invalid',detail=evaluation->>'reason';
  end if;
  -- Existing admission/timing triggers own exact capacity errors and exclusions.
  if o.agreement_snapshot is null then
    raise exception using errcode='22023',message='updated_agreement_offer_required';
  end if;
  if o.terms_invalid_reason is not null or o.agreement_snapshot->>'request_revision'<>r.terms_revision::text
    or o.status<>'pending' or r.status not in ('open','has_offers') then
    raise exception using errcode='22023',message='quote_terms_invalid';
  end if;
  if least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')<=statement_timestamp() then
    raise exception using errcode='P0001',message='offer_expired';
  end if;
  if new.price_estimate is distinct from o.price_estimate then
    raise exception using errcode='23514',message='booking_offer_price_mismatch';
  end if;
  new.agreement_snapshot:=o.agreement_snapshot;
  return new;
end $function$
;

notify pgrst,'reload schema';
