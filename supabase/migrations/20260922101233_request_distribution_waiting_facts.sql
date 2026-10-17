-- Reuse current eligibility projections; waiting progress never recomputes ranking.
create or replace function app_private.get_customer_request_progress_v1(p_request_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=app_private.require_request_customer(); result jsonb;
begin
  if p_request_ids is null or cardinality(p_request_ids) not between 1 and 25 or array_ndims(p_request_ids)>1
    or array_position(p_request_ids,null) is not null then raise exception using errcode='22023',message='invalid_request_ids';end if;
  if exists(select 1 from unnest(p_request_ids) id where not exists(
    select 1 from public.grooming_requests r where r.id=id and r.customer_id=actor)) then
    raise exception using errcode='42501',message='not_allowed';end if;
  select coalesce(jsonb_agg(jsonb_build_object('request_id',r.id,'terms_revision',r.terms_revision,
    'distribution_revision',r.distribution_revision,'pool_enabled',r.pool_enabled,
    'status',case when r.status in ('open','has_offers') and r.expires_at<=statement_timestamp() then 'expired' else r.status end,
    'expires_at',r.expires_at,'checked_at',statement_timestamp(),
    'evaluation_pending',r.pool_enabled and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
      and (exists(select 1 from app_private.match_refresh_queue q where q.request_id=r.id and q.reason='hard_eligibility')
        or exists(select 1 from app_private.match_candidate_evaluations c
          join public.groomer_profiles g on g.user_id=c.groomer_id and g.is_active
          where c.request_id=r.id and app_private.request_distribution_allows_new_quote(r.id,c.groomer_id)
          and not exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=c.groomer_id and m.status='dismissed')
          and (c.valid_until<=statement_timestamp() or c.result->>'state'='pending'))),
    'pool_candidate_count',case when r.pool_enabled and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
      then (select count(*) from app_private.match_candidate_evaluations c
        join public.groomer_profiles g on g.user_id=c.groomer_id and g.is_active
        where c.request_id=r.id and c.valid_until>statement_timestamp()
          and c.result->>'state' in ('estimated_fit','assessment_required')
          and not exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=c.groomer_id and m.status='dismissed')
          and app_private.request_distribution_allows_new_quote(r.id,c.groomer_id)) else null end,
    'valid_offer_count',(select count(*) from public.groomer_offers o where o.request_id=r.id and o.status='pending'
      and app_private.evaluate_quote(o.id)->>'selectable'='true'),
    'invitations',coalesce((select jsonb_agg(jsonb_build_object('groomer_id',i.groomer_id,
      'safe_profile',app_private.marketplace_groomer_summary(i.groomer_id),'sent_at',i.sent_at,'reply_by',i.reply_by,
      'state',app_private.request_invitation_state(r.id,i.groomer_id)) order by i.sent_at,i.groomer_id)
      from app_private.request_invitations i where i.request_id=r.id),'[]'::jsonb)) order by r.created_at desc,r.id),'[]') into result
    from public.grooming_requests r where r.id=any(p_request_ids) and r.customer_id=actor;
  return result;
end $$;
