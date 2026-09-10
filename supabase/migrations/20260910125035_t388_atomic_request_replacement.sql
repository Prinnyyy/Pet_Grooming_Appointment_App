-- Retire the original inside the same transaction as quota-checked publication.
create or replace function app_private.supersede_grooming_request(p_request_id uuid,p_expected_request_revision uuid,
  p_publish_operation_id uuid,p_request jsonb,p_preference_time_zone_identifier text)
returns table(request_id uuid,match_count integer)
language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); original public.grooming_requests%rowtype;
  replacement uuid; matches integer;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_publish_operation_id is null then raise exception using errcode='22023',message='invalid_publish_operation'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||':'||p_publish_operation_id::text,0));
  select o.request_id,o.match_count into replacement,matches from app_private.request_publish_operations o
    where o.customer_id=actor and o.operation_id=p_publish_operation_id;
  if found then
    if not exists(select 1 from public.grooming_requests r where r.id=replacement and r.customer_id=actor
      and r.supersedes_request_id=p_request_id) then
      raise exception using errcode='22023',message='publish_operation_intent_changed';
    end if;
    return query select replacement,matches;
    return;
  end if;
  select * into original from public.grooming_requests r where r.id=p_request_id and r.customer_id=actor for update;
  if not found then raise exception using errcode='P0001',message='request_not_found'; end if;
  if original.terms_revision is distinct from p_expected_request_revision then
    raise exception using errcode='22023',message='request_revision_changed';
  end if;
  if original.status not in ('open','has_offers') or original.expires_at<=statement_timestamp() then
    raise exception using errcode='P0001',message='request_not_cancellable';
  end if;
  perform app_private.cancel_grooming_request(original.id);
  select created.request_id,created.match_count into strict replacement,matches
    from app_private.create_grooming_request_v4(p_publish_operation_id,p_request,p_preference_time_zone_identifier) created;
  update public.grooming_requests set supersedes_request_id=original.id where id=replacement and customer_id=actor;
  return query select replacement,matches;
end $$;

revoke all on function app_private.supersede_grooming_request(uuid,uuid,uuid,jsonb,text)
  from public,anon,authenticated,service_role;
grant execute on function app_private.supersede_grooming_request(uuid,uuid,uuid,jsonb,text) to authenticated;

notify pgrst, 'reload schema';
