create or replace function public.get_my_reminder_snapshot(p_participant_id uuid, p_role text)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  owner uuid := auth.uid();
  as_of timestamptz := statement_timestamp();
  horizon_end timestamptz := as_of + interval '30 days';
  items jsonb;
begin
  if owner is null or owner is distinct from p_participant_id
     or coalesce((auth.jwt()->>'is_anonymous')::boolean, false)
     or p_role is null or p_role not in ('customer','groomer')
     or not exists (select 1 from public.profiles p where p.id=owner and p.role::text=p_role) then
    raise exception using errcode='42501', message='participant_profile_required';
  end if;
  select coalesce(jsonb_agg(to_jsonb(b) order by b.scheduled_start,b.id),'[]'::jsonb) into items
  from (
    select id,customer_id,groomer_id,scheduled_start,updated_at
    from public.bookings
    where case when p_role='customer' then customer_id=owner else groomer_id=owner end
      and status='confirmed' and scheduled_start>=as_of and scheduled_start<horizon_end
    order by scheduled_start,id limit 4097
  ) b;
  if jsonb_array_length(items)>4096 then
    raise exception using errcode='54000', message='reminder_snapshot_too_large';
  end if;
  return jsonb_build_object('participant_id',owner,'role',p_role,'as_of',as_of,
    'horizon_end',horizon_end,'complete',true,'bookings',items);
end;
$$;
revoke all on function public.get_my_reminder_snapshot(uuid,text) from public, anon;
grant execute on function public.get_my_reminder_snapshot(uuid,text) to authenticated;
