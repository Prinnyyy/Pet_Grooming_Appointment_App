create index bookings_participant_pair_latest_idx
  on public.bookings (customer_id, groomer_id, scheduled_start desc, id desc);

create or replace function public.get_conversation_summaries(p_conversation_ids uuid[])
returns table (conversation_id uuid, latest_message jsonb, booking_summary jsonb)
language plpgsql stable security invoker set search_path = ''
as $$
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    raise exception using errcode = '42501', message = 'not_allowed';
  end if;
  if p_conversation_ids is null or cardinality(p_conversation_ids) > 100
     or array_position(p_conversation_ids, null) is not null then
    raise exception using errcode = '22023', message = 'invalid_conversation_scope';
  end if;
  -- Missing and inaccessible IDs deliberately share the same result.
  if exists (
    select 1 from unnest(p_conversation_ids) as requested(id)
    where not exists (select 1 from public.conversations c where c.id = requested.id)
  ) then
    raise exception using errcode = '42501', message = 'conversation_not_available';
  end if;
  return query
  select c.id, to_jsonb(latest), to_jsonb(booking)
  from public.conversations c
  left join lateral (
    select m.id, m.conversation_id, m.sender_id, m.kind, m.body, m.booking_id, m.created_at
    from public.messages m where m.conversation_id = c.id
    order by m.created_at desc, m.id desc
    limit 1
  ) latest on true
  left join lateral (
    select b.id, b.request_id, b.customer_id, b.groomer_id, b.scheduled_start,
      b.scheduled_end, b.price_estimate, b.status, b.completed_at, b.service_time_zone_identifier
    from public.bookings b
    where b.customer_id = c.customer_id and b.groomer_id = c.groomer_id
    order by b.scheduled_start desc, b.id desc
    limit 1
  ) booking on true
  where c.id = any(p_conversation_ids)
  order by c.id;
end;
$$;

revoke all on function public.get_conversation_summaries(uuid[]) from public, anon;
grant execute on function public.get_conversation_summaries(uuid[]) to authenticated;
