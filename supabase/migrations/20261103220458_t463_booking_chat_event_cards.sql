-- Event-time display facts on server-created booking cards. No new client writer or RLS grant.
begin;
alter table public.messages add column booking_event jsonb;
alter table public.messages add constraint messages_booking_event_check check (
  booking_event is null or ((kind='booking_card' and jsonb_typeof(booking_event)='object'
    and booking_event->>'version'='1' and booking_event->>'booking_id'=booking_id::text
    and booking_event->>'actor_id'=sender_id::text and booking_event->>'actor_role' in ('customer','groomer')
    and char_length(booking_event::text)<=4096) is true)
);
comment on column public.messages.booking_event is 'Immutable action and event-time card display facts; never authorizes booking/review actions.';

create function app_private.booking_chat_event(p_booking_id uuid,p_action text,p_actor uuid,
  p_proposed_start timestamptz default null,p_proposed_end timestamptz default null)
returns jsonb language sql stable security invoker set search_path='' as $event$
  select jsonb_strip_nulls(jsonb_build_object(
    'version',1,'action',p_action,'booking_id',b.id,'actor_id',p_actor,
    'actor_role',case when p_actor=b.customer_id then 'customer' else 'groomer' end,
    'scheduled_start',coalesce(p_proposed_start,b.scheduled_start),
    'scheduled_end',coalesce(p_proposed_end,b.scheduled_end),
    'previous_start',case when p_proposed_start is not null then b.scheduled_start end,
    'price',b.price_estimate,'status',b.status,
    'pet_name',coalesce(b.agreement_snapshot#>>'{pet_snapshot,name}',r.pet_snapshot->>'name'),
    'service_type',coalesce(b.agreement_snapshot->>'service_type',r.service_type::text),
    'location_mode',coalesce(b.agreement_snapshot->>'location_mode',r.location_mode::text),
    'time_zone',coalesce(b.agreement_snapshot->>'service_time_zone_identifier',b.service_time_zone_identifier)
  )) from public.bookings b join public.grooming_requests r on r.id=b.request_id
  where b.id=p_booking_id and p_actor in (b.customer_id,b.groomer_id);
$event$;
revoke all on function app_private.booking_chat_event(uuid,text,uuid,timestamptz,timestamptz)
  from public,anon,authenticated,service_role;

-- Patch only the reviewed message INSERTs. Abort on writer drift; retain admission/ownership/receipts/locks.
do $patch$
declare definition text:=pg_get_functiondef('app_private.accept_groomer_offer(uuid)'::regprocedure);
  old_sql text:=$old$  insert into public.messages(conversation_id,sender_id,body,kind,booking_id,created_at)
  values(v_conversation_id,v_user_id,null,'booking_card',v_booking_id,v_event_created_at),
    (v_conversation_id,v_user_id,
      'Hi! I''ve accepted your offer and confirmed this booking. Looking forward to working with you!',
      'text',null,v_event_created_at + interval '1 microsecond');$old$;
  new_sql text:=$new$  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at,booking_event)
    values(v_conversation_id,v_user_id,'booking_card',v_booking_id,v_event_created_at,app_private.booking_chat_event(v_booking_id,'confirmed',v_user_id));$new$;
begin
  if strpos(definition,old_sql)=0 or length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'T463 message writer drift: accept_groomer_offer (0)';
  end if;
  execute replace(definition,old_sql,new_sql);
end $patch$;
do $patch$
declare definition text:=pg_get_functiondef('app_private.cancel_booking(uuid)'::regprocedure);
  old_sql text:=$old$  insert into public.messages (
    conversation_id,
    sender_id,
    body,
    kind,
    booking_id,
    created_at
  )
  values (
    v_conversation_id,
    v_user_id,
    null,
    'booking_card',
    v_booking_id,
    v_event_created_at
  );$old$;
  new_sql text:=$new$  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at,booking_event)
    values(v_conversation_id,v_user_id,'booking_card',v_booking_id,v_event_created_at,app_private.booking_chat_event(v_booking_id,'cancel',v_user_id));$new$;
begin
  if strpos(definition,old_sql)=0 or length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'T463 message writer drift: cancel_booking (0)';
  end if;
  execute replace(definition,old_sql,new_sql);
end $patch$;
do $patch$
declare definition text:=pg_get_functiondef('app_private.cancel_booking(uuid)'::regprocedure);
  old_sql text:=$old$  insert into public.messages (
    conversation_id,
    sender_id,
    body,
    kind,
    booking_id,
    created_at
  )
  values (
    v_conversation_id,
    v_user_id,
    'Hi, I''m sorry, but I''ve had to cancel this booking. Thank you for understanding.',
    'text',
    null,
    v_event_created_at + interval '1 microsecond'
  );$old$;
  new_sql text:=$new$$new$;
begin
  if strpos(definition,old_sql)=0 or length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'T463 message writer drift: cancel_booking (1)';
  end if;
  execute replace(definition,old_sql,new_sql);
end $patch$;
do $patch$
declare definition text:=pg_get_functiondef('app_private.mutate_booking_fulfillment(uuid,uuid,uuid,text,text)'::regprocedure);
  old_sql text:=$old$  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at)
    values(conversation,actor,'booking_card',b.id,at_time);$old$;
  new_sql text:=$new$  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at,booking_event)
    values(conversation,actor,'booking_card',b.id,at_time,app_private.booking_chat_event(b.id,p_action,actor));$new$;
begin
  if strpos(definition,old_sql)=0 or length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'T463 message writer drift: mutate_booking_fulfillment (0)';
  end if;
  execute replace(definition,old_sql,new_sql);
end $patch$;
do $patch$
declare definition text:=pg_get_functiondef('app_private.mutate_booking_fulfillment(uuid,uuid,uuid,text,text)'::regprocedure);
  old_sql text:=$old$  insert into public.messages(conversation_id,sender_id,kind,body,created_at)
    values(conversation,actor,'text',chat_text,at_time+interval '1 microsecond');$old$;
  new_sql text:=$new$$new$;
begin
  if strpos(definition,old_sql)=0 or length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'T463 message writer drift: mutate_booking_fulfillment (1)';
  end if;
  execute replace(definition,old_sql,new_sql);
end $patch$;
do $patch$
declare definition text:=pg_get_functiondef('app_private.mutate_booking_reschedule(uuid,uuid,uuid,text,uuid,timestamptz)'::regprocedure);
  old_sql text:=$old$  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at) values(conversation,actor,'booking_card',b.id,at_time);$old$;
  new_sql text:=$new$  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at,booking_event)
    values(conversation,actor,'booking_card',b.id,at_time,app_private.booking_chat_event(b.id,'reschedule_'||p_action,actor,case when p_action='propose' then proposal.proposed_start end,case when p_action='propose' then proposal.proposed_end end));$new$;
begin
  if strpos(definition,old_sql)=0 or length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'T463 message writer drift: mutate_booking_reschedule (0)';
  end if;
  execute replace(definition,old_sql,new_sql);
end $patch$;
do $patch$
declare definition text:=pg_get_functiondef('app_private.mutate_booking_reschedule(uuid,uuid,uuid,text,uuid,timestamptz)'::regprocedure);
  old_sql text:=$old$  insert into public.messages(conversation_id,sender_id,kind,body,created_at) values(conversation,actor,'text',chat_text,at_time+interval '1 microsecond');$old$;
  new_sql text:=$new$$new$;
begin
  if strpos(definition,old_sql)=0 or length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'T463 message writer drift: mutate_booking_reschedule (1)';
  end if;
  execute replace(definition,old_sql,new_sql);
end $patch$;

-- The card replaces the automatic text, so reuse its one existing message notification.
do $notification$
declare definition text:=pg_get_functiondef('app_private.groomer_notifications_after_customer_message_insert()'::regprocedure);
begin
  if strpos(definition,$old$if new.kind <> 'text' then return new; end if;$old$)=0 then raise exception 'T463 notification writer drift: groomer_notifications_after_customer_message_insert'; end if;
  execute replace(definition,$old$if new.kind <> 'text' then return new; end if;$old$,$new$if new.kind not in ('text','booking_card') then return new; end if;$new$);
end $notification$;
-- The card replaces the automatic text, so reuse its one existing message notification.
do $notification$
declare definition text:=pg_get_functiondef('app_private.customer_notifications_after_groomer_message_insert()'::regprocedure);
begin
  if strpos(definition,$old$if new.kind <> 'text' then return new; end if;$old$)=0 then raise exception 'T463 notification writer drift: customer_notifications_after_groomer_message_insert'; end if;
  execute replace(definition,$old$if new.kind <> 'text' then return new; end if;$old$,$new$if new.kind not in ('text','booking_card') then return new; end if;$new$);
end $notification$;

commit;
