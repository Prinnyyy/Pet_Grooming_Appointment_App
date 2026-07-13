-- T-351 remote verification. This script must end in ROLLBACK.

begin;

do $validation$
declare
  v_duplicate_pairs bigint;
  v_conversation_count bigint;
  v_message_count bigint;
begin
  select count(*)
  into v_duplicate_pairs
  from (
    select conversation.customer_id, conversation.groomer_id
    from public.conversations as conversation
    group by conversation.customer_id, conversation.groomer_id
    having count(*) > 1
  ) as duplicates;

  select count(*) into v_conversation_count from public.conversations;
  select count(*) into v_message_count from public.messages;

  if v_duplicate_pairs <> 0 then
    raise exception 'T-351 duplicate participant pairs remain: %', v_duplicate_pairs;
  end if;
  if v_conversation_count <> 1 then
    raise exception 'T-351 expected one merged conversation, found %', v_conversation_count;
  end if;
  if v_message_count <> 7 then
    raise exception 'T-351 expected seven preserved messages, found %', v_message_count;
  end if;
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.conversations'::regclass
      and conname = 'conversations_customer_groomer_key'
  ) then
    raise exception 'T-351 participant-pair unique constraint is missing';
  end if;
  if pg_catalog.has_column_privilege(
    'authenticated',
    'public.messages',
    'kind',
    'INSERT'
  ) then
    raise exception 'authenticated must not insert message kind';
  end if;
  if not pg_catalog.has_column_privilege(
    'authenticated',
    'public.messages',
    'body',
    'INSERT'
  ) then
    raise exception 'authenticated text-body insert grant is missing';
  end if;
end;
$validation$;

select set_config('t351.conversation_id', conversation.id::text, true),
       set_config('t351.customer_id', conversation.customer_id::text, true),
       set_config('t351.groomer_id', conversation.groomer_id::text, true),
       set_config('t351.booking_id', booking.id::text, true)
from public.conversations as conversation
join public.bookings as booking
  on booking.customer_id = conversation.customer_id
 and booking.groomer_id = conversation.groomer_id
order by booking.created_at asc
limit 1;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', current_setting('t351.customer_id'),
    'role', 'authenticated',
    'is_anonymous', false
  )::text,
  true
);

set local role authenticated;

do $customer_validation$
begin
  if (
    select count(*)
    from public.conversations
    where id = current_setting('t351.conversation_id')::uuid
  ) <> 1 then
    raise exception 'Customer participant cannot read the merged conversation';
  end if;

  if (
    select count(*)
    from public.messages
    where conversation_id = current_setting('t351.conversation_id')::uuid
  ) <> 7 then
    raise exception 'Customer participant cannot read all preserved messages';
  end if;

  begin
    insert into public.messages (
      conversation_id,
      sender_id,
      kind,
      booking_id,
      body
    )
    values (
      current_setting('t351.conversation_id')::uuid,
      current_setting('t351.customer_id')::uuid,
      'booking_card',
      current_setting('t351.booking_id')::uuid,
      null
    );
    raise exception 'authenticated participant forged a booking card';
  exception
    when insufficient_privilege or check_violation then
      null;
  end;
end;
$customer_validation$;

reset role;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', gen_random_uuid(),
    'role', 'authenticated',
    'is_anonymous', false
  )::text,
  true
);

set local role authenticated;

do $outsider_validation$
begin
  if (select count(*) from public.conversations) <> 0 then
    raise exception 'Non-participant can read a conversation';
  end if;
  if (select count(*) from public.messages) <> 0 then
    raise exception 'Non-participant can read messages';
  end if;
end;
$outsider_validation$;

reset role;
rollback;
