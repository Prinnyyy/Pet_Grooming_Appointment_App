create or replace function app_private.get_my_matched_request(p_groomer_id uuid,p_request_id uuid)
returns setof public.request_matches language plpgsql stable security definer set search_path=''
as $$
declare owner uuid:=(select auth.uid());
begin
  if owner is null or owner is distinct from p_groomer_id
    or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles where id=owner and role='groomer') then
    raise exception using errcode='42501',message='groomer_profile_required';
  end if;
  if p_request_id is null then raise exception using errcode='22023',message='request_id_required'; end if;
  return query
    select display.* from public.request_matches m
    join public.grooming_requests r on r.id=m.request_id
    cross join lateral jsonb_populate_record(null::public.request_matches,to_jsonb(m)||
      case when m.eligibility_evaluation is null or exists(
        select 1 from app_private.match_refresh_queue q where q.request_id=m.request_id and q.groomer_id=m.groomer_id
      ) then jsonb_build_object('match_reason','Service and availability are being checked.',
        'eligibility_evaluation',jsonb_build_object('state','pending','reason','refresh_pending'))
      else '{}'::jsonb end) display
    where m.groomer_id=owner and m.request_id=p_request_id and m.status in ('visible','viewed','offered')
      and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
    order by m.created_at desc,m.id desc limit 1;
end;
$$;

create or replace function public.get_my_matched_request(p_groomer_id uuid,p_request_id uuid)
returns setof public.request_matches language sql stable security invoker set search_path=''
as $$ select * from app_private.get_my_matched_request(p_groomer_id,p_request_id); $$;

revoke all on function app_private.get_my_matched_request(uuid,uuid) from public, anon;
revoke all on function public.get_my_matched_request(uuid,uuid) from public, anon;
grant execute on function app_private.get_my_matched_request(uuid,uuid) to authenticated;
grant execute on function public.get_my_matched_request(uuid,uuid) to authenticated;
