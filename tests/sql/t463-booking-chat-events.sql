-- Authorized transactional acceptance only. No account or booking mutations; all messages/notifications roll back.
begin;
do $test$
declare b public.bookings%rowtype; c public.conversations%rowtype; payload jsonb; proposed jsonb;
  first_message uuid:='f4630000-0000-4000-8000-000000000001'; second_message uuid:='f4630000-0000-4000-8000-000000000002'; outsider uuid:=gen_random_uuid();
  actual jsonb; notifications integer; definition text; writer text;
begin
  if exists(select 1 from public.messages where id in (first_message,second_message)) then
    raise exception 'T463 verification IDs already exist; stop without modifying existing messages';
  end if;
  select booking.* into b from public.bookings booking
    join public.conversations cv on cv.customer_id=booking.customer_id and cv.groomer_id=booking.groomer_id
    join public.profiles cp on cp.id=booking.customer_id and cp.role='customer'
    join public.profiles gp on gp.id=booking.groomer_id and gp.role='groomer'
    order by booking.created_at desc limit 1;
  if not found then raise exception 'T463 requires an existing participant booking'; end if;
  select * into strict c from public.conversations where customer_id=b.customer_id and groomer_id=b.groomer_id;
  payload:=app_private.booking_chat_event(b.id,'confirmed',b.customer_id);
  if payload->>'actor_role'<>'customer' or payload->>'actor_id'<>b.customer_id::text
    or payload->>'booking_id'<>b.id::text or payload->>'version'<>'1' then
    raise exception 'T463 snapshot identity mismatch'; end if;
  proposed:=app_private.booking_chat_event(b.id,'reschedule_propose',b.groomer_id,
    b.scheduled_start+interval '1 day',b.scheduled_end+interval '1 day');
  if (proposed->>'scheduled_start')::timestamptz<>b.scheduled_start+interval '1 day'
    or (payload->>'scheduled_start')::timestamptz<>b.scheduled_start
    or proposed->>'actor_role'<>'groomer' then raise exception 'T463 event time must be independent'; end if;

  insert into public.messages(id,conversation_id,sender_id,kind,booking_id,booking_event)
    values(first_message,c.id,b.customer_id,'booking_card',b.id,payload),
      (second_message,c.id,b.groomer_id,'booking_card',b.id,proposed);
  select count(*) into notifications from public.groomer_notifications
    where related_conversation_id=c.id and kind='new_message' and xmin::text=pg_current_xact_id()::text;
  if notifications<>1 then raise exception 'T463 customer card must notify groomer exactly once'; end if;
  select count(*) into notifications from public.customer_notifications
    where related_conversation_id=c.id and kind='new_message' and xmin::text=pg_current_xact_id()::text;
  if notifications<>1 then raise exception 'T463 groomer card must notify customer exactly once'; end if;

  begin
    insert into public.messages(conversation_id,sender_id,kind,booking_id,booking_event)
      values(c.id,b.customer_id,'booking_card',b.id,payload-'version');
    raise exception 'T463 incomplete event must fail';
  exception when check_violation then null; end;
  begin
    insert into public.messages(conversation_id,sender_id,kind,booking_id,booking_event)
      values(c.id,b.customer_id,'booking_card',b.id,payload||jsonb_build_object('actor_id',b.groomer_id));
    raise exception 'T463 forged actor must fail';
  exception when check_violation then null; end;

  if has_column_privilege('authenticated','public.messages','booking_event','INSERT')
    or has_column_privilege('authenticated','public.messages','booking_event','UPDATE')
    or has_function_privilege('authenticated','app_private.booking_chat_event(uuid,text,uuid,timestamptz,timestamptz)','EXECUTE')
    or has_function_privilege('anon','app_private.booking_chat_event(uuid,text,uuid,timestamptz,timestamptz)','EXECUTE') then
    raise exception 'T463 event writer must remain private'; end if;

  perform set_config('request.jwt.claims',jsonb_build_object('sub',b.customer_id,'role','authenticated','is_anonymous',false)::text,true);
  set local role authenticated;
  select booking_event into actual from public.messages where id=second_message;
  if actual is distinct from proposed then raise exception 'T463 customer cannot read counterpart event'; end if;
  begin
    insert into public.messages(conversation_id,sender_id,body,booking_event)
      values(c.id,b.customer_id,'forged event',payload);
    raise exception 'T463 client event insert must fail';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b.groomer_id,'role','authenticated','is_anonymous',false)::text,true);
  set local role authenticated;
  select booking_event into actual from public.messages where id=first_message;
  if actual is distinct from payload then raise exception 'T463 groomer cannot read counterpart event'; end if;
  reset role;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'role','authenticated','is_anonymous',false)::text,true);
  set local role authenticated;
  if exists(select 1 from public.messages where id in (first_message,second_message)) then
    raise exception 'T463 outsider must not read events'; end if;
  reset role;

  foreach writer in array array['app_private.accept_groomer_offer(uuid)','app_private.cancel_booking(uuid)',
    'app_private.mutate_booking_fulfillment(uuid,uuid,uuid,text,text)',
    'app_private.mutate_booking_reschedule(uuid,uuid,uuid,text,uuid,timestamptz)'] loop
    definition:=pg_get_functiondef(writer::regprocedure);
    if (length(definition)-length(replace(definition,'insert into public.messages','')))/length('insert into public.messages')<>1
      or strpos(definition,'app_private.booking_chat_event(')=0 then
      raise exception 'T463 writer must create one event card, not automatic text: %',writer;
    end if;
  end loop;
end $test$;
select 'T463 event snapshots, one counterpart notification, participant reads and negative writes passed; rolling back all verification rows' as result;
rollback;

-- Independent read after rollback confirms the synthetic messages did not persist.
do $rollback_check$
begin
  if exists(select 1 from public.messages where id in
    ('f4630000-0000-4000-8000-000000000001'::uuid,'f4630000-0000-4000-8000-000000000002'::uuid)) then
    raise exception 'T463 verification messages must not persist';
  end if;
end $rollback_check$;
select 'T463 rollback verified: no synthetic messages persisted' as result;
