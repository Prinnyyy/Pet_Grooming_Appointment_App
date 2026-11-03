-- Display names are shared only with an authenticated conversation participant.
-- Do not broaden profiles RLS or expose any other profile attributes.
create function public.get_chat_counterpart_names(p_conversation_ids uuid[])
returns table (conversation_id uuid, display_name text)
language plpgsql stable security definer set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    raise exception using errcode = '42501', message = 'not_allowed';
  end if;
  if p_conversation_ids is null or cardinality(p_conversation_ids) > 100
     or array_position(p_conversation_ids, null) is not null then
    raise exception using errcode = '22023', message = 'invalid_conversation_scope';
  end if;
  if exists (
    select 1 from unnest(p_conversation_ids) requested(id)
    where not exists (
      select 1 from public.conversations c
      where c.id = requested.id and actor in (c.customer_id, c.groomer_id)
    )
  ) then
    raise exception using errcode = '42501', message = 'conversation_not_available';
  end if;
  return query
    select c.id, nullif(btrim(p.display_name), '')
    from public.conversations c
    join public.profiles p on p.id = case when c.customer_id = actor then c.groomer_id else c.customer_id end
    where c.id = any(p_conversation_ids) and actor in (c.customer_id, c.groomer_id)
    order by c.id;
end;
$$;
revoke all on function public.get_chat_counterpart_names(uuid[]) from public, anon;
grant execute on function public.get_chat_counterpart_names(uuid[]) to authenticated;
