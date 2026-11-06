-- T-466: scheduled service start and single-participant completion.
-- No historical rows are rewritten. Existing participant checks, locks, operation
-- receipts, revision conflicts and chat-event notifications remain authoritative.
BEGIN;
ALTER TABLE public.bookings DROP CONSTRAINT bookings_completion_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_completion_check CHECK (
  (status = 'completed' AND completed_at IS NOT NULL AND completed_by IS NOT NULL AND completed_by IN (customer_id, groomer_id))
  OR (status <> 'completed' AND completed_at IS NULL AND completed_by IS NULL)
);

CREATE OR REPLACE FUNCTION app_private.mutate_booking_fulfillment(p_booking_id uuid, p_expected_revision uuid, p_operation_id uuid, p_action text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype; event public.booking_fulfillment_events%rowtype;
  parent uuid; at_time timestamptz:=statement_timestamp(); note text:=nullif(btrim(p_note),'');
  receipt jsonb; event_id uuid:=gen_random_uuid(); conversation uuid; chat_text text;
  old_write text:=current_setting('app.fulfillment_write',true);
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_booking_id is null or p_expected_revision is null or p_operation_id is null
    or p_action is null or char_length(coalesce(note,''))>500 then
    raise exception using errcode='22023',message='invalid_fulfillment_operation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||p_operation_id::text,71377));
  select * into event from public.booking_fulfillment_events where actor_id=actor and operation_id=p_operation_id;
  if found then
    if row(event.booking_id,event.expected_revision,event.action,event.note)
      is distinct from row(p_booking_id,p_expected_revision,p_action,note) then
      raise exception using errcode='22023',message='fulfillment_operation_intent_changed';
    end if;
    return app_private.get_booking_fulfillment_operation(p_operation_id);
  end if;
  select r.id into parent from public.grooming_requests r join public.bookings booking on booking.request_id=r.id
    where booking.id=p_booking_id and (booking.customer_id=actor or booking.groomer_id=actor) for update of r;
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  select * into strict b from public.bookings where id=p_booking_id for update;
  if not exists(select 1 from public.profiles where id=actor
    and ((actor=b.customer_id and role='customer') or (actor=b.groomer_id and role='groomer'))) then
    raise exception using errcode='42501',message='booking_participant_required';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(b.groomer_id::text,71071));
  -- Evaluate boundaries after lock waits, not at the request's earlier arrival time.
  at_time:=clock_timestamp();
  if b.fulfillment_revision is distinct from p_expected_revision then
    raise exception using errcode='PT409',message='booking_revision_changed';
  end if;
  -- Service progresses by the scheduled clock; no fabricated start event is written.
  -- Retired actions cannot be used by an older client to bypass completion/review.
  case p_action
  when 'complete' then
    if b.status<>'confirmed' or b.fulfillment_phase not in ('scheduled','in_service','outcome_reported') then
      raise exception using errcode='P0001',message='service_not_completable'; end if;
    if at_time<b.scheduled_start then
      raise exception using errcode='22023',message='completion_too_early'; end if;
    b.status:='completed'; b.fulfillment_phase:='completed';
    -- Actual times remain evidence: automatic entry is not an observed start.
    if b.actual_started_at is not null then b.actual_ended_at:=at_time; end if;
    b.completed_at:=at_time; b.completed_by:=actor;
    b.reported_outcome:=null; b.reported_by:=null; b.reported_at:=null;
    b.report_previous_phase:=null; b.report_note:=null;
    b.pet_release_at:=greatest(b.scheduled_start,least(b.scheduled_end,at_time));
    b.resource_release_at:=greatest(b.scheduled_start,least(b.scheduled_end,at_time));
    chat_text:='Service is completed. The customer can leave a review.';
  when 'cancel' then
    if b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' or at_time>=b.scheduled_start then
      raise exception using errcode='P0001',message='cancellation_after_start_not_allowed'; end if;
    b.status:=case when actor=b.customer_id then 'cancelled_by_customer' else 'cancelled_by_groomer' end;
    b.fulfillment_phase:='cancelled'; b.cancelled_at:=at_time; b.cancelled_by:=actor;
    chat_text:='This booking was cancelled before service. The original request remains closed.';
  else raise exception using errcode='22023',message='invalid_fulfillment_action';
  end case;
  perform set_config('app.fulfillment_write','1',true);
  update public.bookings set status=b.status,fulfillment_phase=b.fulfillment_phase,fulfillment_basis=b.fulfillment_basis,
    fulfillment_revision=b.fulfillment_revision,actual_started_at=b.actual_started_at,actual_ended_at=b.actual_ended_at,
    pet_release_at=b.pet_release_at,resource_release_at=b.resource_release_at,reported_outcome=b.reported_outcome,
    reported_by=b.reported_by,reported_at=b.reported_at,report_previous_phase=b.report_previous_phase,report_note=b.report_note,
    cancelled_at=b.cancelled_at,cancelled_by=b.cancelled_by,completed_at=b.completed_at,completed_by=b.completed_by
    where id=b.id returning * into b;
  perform set_config('app.fulfillment_write',coalesce(old_write,''),true);
  receipt:=jsonb_build_object('id',event_id,'operation_id',p_operation_id,'booking_id',b.id,'action',p_action,
    'result_revision',b.fulfillment_revision,'recorded_at',at_time);
  insert into public.booking_fulfillment_events(id,booking_id,actor_id,operation_id,expected_revision,result_revision,action,note,receipt,recorded_at)
    values(event_id,b.id,actor,p_operation_id,p_expected_revision,b.fulfillment_revision,p_action,note,receipt,at_time);
  select id into conversation from public.conversations where customer_id=b.customer_id and groomer_id=b.groomer_id;
  if conversation is null then raise exception using errcode='P0001',message='conversation_not_found'; end if;
  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at,booking_event)
    values(conversation,actor,'booking_card',b.id,at_time,app_private.booking_chat_event(b.id,p_action,actor));

  return jsonb_build_object('receipt',receipt,'booking',to_jsonb(b),'replayed',false);
end $function$
;

-- Review eligibility is based on explicit completion, not the day boundary.
CREATE OR REPLACE FUNCTION app_private.grooming_finished_at(b public.bookings)
RETURNS timestamptz LANGUAGE sql STABLE SET search_path TO '' AS $function$
  SELECT CASE WHEN b.status = 'completed'
    THEN coalesce(b.completed_at, b.actual_ended_at, b.scheduled_end) ELSE NULL END;
$function$;

-- Reuse the participant-scoped state read; immutable operation receipts own Activity.
CREATE OR REPLACE FUNCTION app_private.booking_reschedule_state(p_booking_id uuid, p_proposal_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  return jsonb_build_object('booking',to_jsonb(b),'proposal',result,
    'history',coalesce((select jsonb_agg(jsonb_build_object(
      'id',o.operation_id,'action',o.receipt->>'action','actor',o.actor_id,
      'recorded_at',o.receipt->>'recorded_at',
      'proposal',to_jsonb(p)||jsonb_build_object('effective_status',p.status))
      order by (o.receipt->>'recorded_at')::timestamptz,o.operation_id)
      from app_private.booking_reschedule_operations o
      join public.booking_reschedule_proposals p on p.id=o.proposal_id and p.booking_id=o.booking_id
      where o.booking_id=b.id),'[]'::jsonb));
end $function$
;

COMMIT;
