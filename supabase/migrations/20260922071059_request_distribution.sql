-- T-399 / HD-02. One Request, explicit distribution, one first-publication receipt.
alter table public.grooming_requests
  add column pool_enabled boolean not null default true,
  add column distribution_revision uuid not null default gen_random_uuid(),
  add column distribution_version text not null default 'legacy_pool'
    check(distribution_version in ('legacy_pool','discovery_v1'));

create table app_private.request_invitations (
  request_id uuid not null references public.grooming_requests(id) on delete cascade,
  groomer_id uuid not null references public.groomer_profiles(user_id) on delete cascade,
  terms_revision uuid not null,
  sent_at timestamptz not null default statement_timestamp(),
  reply_by timestamptz not null,
  withdrawn_at timestamptz,
  declined_at timestamptz,
  primary key(request_id,groomer_id),
  check(isfinite(reply_by) and reply_by>sent_at and reply_by<=sent_at+interval '24 hours')
);
alter table app_private.request_invitations enable row level security;
revoke all on app_private.request_invitations from public,anon,authenticated,service_role;
create index request_invitations_groomer_idx on app_private.request_invitations(groomer_id,request_id);
create index request_invitations_expiry_idx on app_private.request_invitations(reply_by,request_id)
  where withdrawn_at is null and declined_at is null;

create table app_private.request_distribution_operations (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  operation_id uuid not null,
  kind text not null check(kind in ('invite','pool','withdraw')),
  canonical_hash text not null,
  request_id uuid not null references public.grooming_requests(id) on delete cascade,
  receipt jsonb not null,
  created_at timestamptz not null default statement_timestamp(),
  primary key(customer_id,operation_id)
);
alter table app_private.request_distribution_operations enable row level security;
revoke all on app_private.request_distribution_operations from public,anon,authenticated,service_role;
create index request_distribution_operations_request_idx on app_private.request_distribution_operations(request_id);

create function app_private.require_request_customer()
returns uuid language plpgsql stable set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.customer_profiles c join public.profiles p on p.id=c.user_id
      where c.user_id=actor and p.role='customer') then raise exception using errcode='42501',message='not_allowed';end if;
  return actor;
end $$;
revoke all on function app_private.require_request_customer() from public,anon,authenticated,service_role;

create function app_private.request_distribution_allows_new_quote(p_request uuid,p_groomer uuid,p_now timestamptz default statement_timestamp())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.grooming_requests r where r.id=p_request
    and r.status in ('open','has_offers') and r.expires_at>p_now
    and not exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=p_groomer
      and (m.status='dismissed' or m.dismissed_at is not null))
    and (r.pool_enabled or exists(select 1 from app_private.request_invitations i
      where i.request_id=r.id and i.groomer_id=p_groomer and i.terms_revision=r.terms_revision
        and i.withdrawn_at is null and i.declined_at is null and i.reply_by>p_now)));
$$;
revoke all on function app_private.request_distribution_allows_new_quote(uuid,uuid,timestamptz)
  from public,anon,authenticated,service_role;

create function app_private.guard_match_distribution()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status in ('visible','viewed') then
    perform 1 from public.grooming_requests where id=new.request_id for update;
    if not app_private.request_distribution_allows_new_quote(new.request_id,new.groomer_id) then
      if tg_op='INSERT' then return null;end if;
      if old.status='dismissed' or old.dismissed_at is not null then
        new.status:='dismissed';new.dismissed_at:=old.dismissed_at;new.dismiss_reason:=old.dismiss_reason;
      else new.status:='hidden';end if;
    end if;
  end if;
  return new;
end $$;
revoke all on function app_private.guard_match_distribution() from public,anon,authenticated,service_role;
create trigger request_matches_aaa_distribution before insert or update on public.request_matches
  for each row execute function app_private.guard_match_distribution();

create function app_private.guard_offer_distribution()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.grooming_requests where id=new.request_id for update;
  if not app_private.request_distribution_allows_new_quote(new.request_id,new.groomer_id) then
    raise exception using errcode='42501',message='request_distribution_closed';
  end if;
  return new;
end $$;
revoke all on function app_private.guard_offer_distribution() from public,anon,authenticated,service_role;
create trigger groomer_offers_aaa_distribution before insert on public.groomer_offers
  for each row execute function app_private.guard_offer_distribution();

create function app_private.request_invitation_state(p_request uuid,p_groomer uuid,p_now timestamptz default statement_timestamp())
returns text language plpgsql stable set search_path = '' as $$
declare i app_private.request_invitations%rowtype; r public.grooming_requests%rowtype;
begin
  select * into i from app_private.request_invitations where request_id=p_request and groomer_id=p_groomer;
  if not found then return 'not_sent';end if;
  select * into strict r from public.grooming_requests where id=p_request;
  if r.status not in ('open','has_offers') or r.expires_at<=p_now or i.terms_revision<>r.terms_revision then return 'closed';end if;
  if exists(select 1 from public.groomer_offers o where o.request_id=p_request and o.groomer_id=p_groomer
    and o.status='pending' and app_private.evaluate_quote(o.id,p_now)->>'terms_valid'='true') then return 'offered';end if;
  if i.declined_at is not null or exists(select 1 from public.request_matches m where m.request_id=p_request
    and m.groomer_id=p_groomer and (m.status='dismissed' or m.dismissed_at is not null)) then return 'declined';end if;
  if i.withdrawn_at is not null then return 'withdrawn';end if;
  if i.reply_by<=p_now then return 'expired';end if;
  if exists(select 1 from public.groomer_offers where request_id=p_request and groomer_id=p_groomer) then return 'closed';end if;
  return 'awaiting_response';
end $$;
revoke all on function app_private.request_invitation_state(uuid,uuid,timestamptz) from public,anon,authenticated,service_role;

create function app_private.request_distribution_receipt(p_request uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('request_id',r.id,'terms_revision',r.terms_revision,'distribution_revision',r.distribution_revision,
    'pool_enabled',r.pool_enabled,'invited_groomer_ids',coalesce((select jsonb_agg(i.groomer_id order by i.sent_at,i.groomer_id)
      from app_private.request_invitations i where i.request_id=r.id),'[]'::jsonb))
  from public.grooming_requests r where r.id=p_request;
$$;
revoke all on function app_private.request_distribution_receipt(uuid) from public,anon,authenticated,service_role;

create function app_private.canonical_invitation_targets(p_groomers uuid[])
returns uuid[] language plpgsql immutable set search_path = '' as $$
declare result uuid[];
begin
  if p_groomers is null or coalesce(array_ndims(p_groomers),1)>1 or cardinality(p_groomers)>50
    or array_position(p_groomers,null) is not null then raise exception using errcode='22023',message='invalid_invitation_targets';end if;
  result:=array(select distinct id from unnest(p_groomers) id order by id);
  if cardinality(result)>5 then raise exception using errcode='P0001',message='invitation_limit_reached';end if;
  return result;
end $$;
revoke all on function app_private.canonical_invitation_targets(uuid[]) from public,anon,authenticated,service_role;

create function app_private.insert_request_context(p_context public.grooming_requests,p_pool_enabled boolean,p_version text)
returns uuid language plpgsql volatile set search_path = '' as $$
declare r public.grooming_requests%rowtype:=p_context; result uuid;
begin
  perform 1 from public.customer_profiles where user_id=r.customer_id for update;
  if not found then raise exception using errcode='P0001',message='customer_profile_required';end if;
  if (select count(*) from public.grooming_requests where customer_id=r.customer_id
    and status in ('open','has_offers') and expires_at>statement_timestamp())>=3 then
    raise exception using errcode='P0001',message='open_request_limit_exceeded';end if;
  if r.expires_at<=statement_timestamp() then raise exception using errcode='PT409',message='discovery_expired';end if;
  insert into public.grooming_requests(customer_id,pet_id,pet_snapshot,photo_snapshot,service_type,service_notes,
    preferred_start,preferred_end,preference_time_zone_identifier,location_mode,street_address,address_line_2,city,state,zip_code,
    address_location_id,travel_radius_miles,status,expires_at,pool_enabled,distribution_version)
    values(r.customer_id,r.pet_id,r.pet_snapshot,r.photo_snapshot,r.service_type,r.service_notes,r.preferred_start,r.preferred_end,
      r.preference_time_zone_identifier,r.location_mode,r.street_address,r.address_line_2,r.city,r.state,r.zip_code,
      r.address_location_id,r.travel_radius_miles,'open',r.expires_at,p_pool_enabled,p_version) returning id into result;
  return result;
end $$;
revoke all on function app_private.insert_request_context(public.grooming_requests,boolean,text) from public,anon,authenticated,service_role;

create function app_private.add_request_invitations(p_request uuid,p_groomers uuid[])
returns void language plpgsql volatile set search_path = '' as $$
declare r public.grooming_requests%rowtype; gid uuid; incoming uuid[]; outstanding integer; evaluation jsonb; valid_zones text[];
begin
  select * into strict r from public.grooming_requests where id=p_request for update;
  if r.status not in ('open','has_offers') or r.expires_at<=statement_timestamp() then
    raise exception using errcode='PT409',message='request_changed';end if;
  incoming:=array(select id from unnest(p_groomers) id where not exists(
    select 1 from app_private.request_invitations where request_id=p_request and groomer_id=id));
  select count(*) into outstanding from app_private.request_invitations i where i.request_id=p_request and (
    app_private.request_invitation_state(p_request,i.groomer_id)='awaiting_response'
    or exists(select 1 from public.groomer_offers o where o.request_id=p_request and o.groomer_id=i.groomer_id
      and o.status='pending' and app_private.evaluate_quote(o.id)->>'selectable'='true'));
  if outstanding+cardinality(incoming)>5 then raise exception using errcode='P0001',message='invitation_limit_reached';end if;
  select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names;
  foreach gid in array incoming loop
    evaluation:=app_private.evaluate_context_eligibility(r,gid,statement_timestamp(),valid_zones);
    if evaluation->>'state' not in ('estimated_fit','assessment_required')
      or exists(select 1 from public.request_matches where request_id=p_request and groomer_id=gid
        and (status='dismissed' or dismissed_at is not null)) then
      raise exception using errcode='PT409',message='groomer_unavailable',detail=gid::text;end if;
  end loop;
  foreach gid in array incoming loop
    insert into app_private.request_invitations(request_id,groomer_id,terms_revision,reply_by)
      values(p_request,gid,r.terms_revision,least(statement_timestamp()+interval '24 hours',r.expires_at));
    perform app_private.refresh_candidate_evaluation(p_request,gid,statement_timestamp(),0);
  end loop;
  if cardinality(incoming)>0 then update public.grooming_requests set distribution_revision=gen_random_uuid() where id=p_request;end if;
end $$;
revoke all on function app_private.add_request_invitations(uuid,uuid[]) from public,anon,authenticated,service_role;

create function app_private.publish_request_with_distribution_v1(p_operation_id uuid,p_session_id uuid,
  p_input_digest text,p_pool_enabled boolean,p_groomer_ids uuid[])
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=app_private.require_request_customer(); targets uuid[]; intent text;
  operation app_private.request_publish_operations%rowtype; preview app_private.request_discovery_sessions%rowtype;
  r public.grooming_requests%rowtype; original public.grooming_requests%rowtype; source jsonb; created_request uuid; receipt jsonb;
begin
  if p_operation_id is null or p_session_id is null or p_input_digest is null or p_pool_enabled is null then
    raise exception using errcode='22023',message='invalid_publication';end if;
  targets:=app_private.canonical_invitation_targets(p_groomer_ids);
  if not p_pool_enabled and cardinality(targets)=0 then raise exception using errcode='22023',message='empty_distribution';end if;
  intent:=encode(extensions.digest(convert_to(jsonb_build_array(p_session_id,p_input_digest,p_pool_enabled,targets)::text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(actor::text||':'||p_operation_id::text,0));
  if exists(select 1 from app_private.request_distribution_operations where customer_id=actor and operation_id=p_operation_id) then
    raise exception using errcode='PT409',message='operation_intent_changed';end if;
  select * into operation from app_private.request_publish_operations where customer_id=actor and operation_id=p_operation_id;
  if found then
    if operation.protocol_version<>'discoveryV1' or operation.canonical_hash is distinct from intent then
      raise exception using errcode='PT409',message='operation_intent_changed';end if;
    return operation.distribution_receipt;
  end if;
  -- A second operation still resolves a consumed/expired preview through the durable receipt.
  select * into operation from app_private.request_publish_operations where customer_id=actor and discovery_session_id=p_session_id;
  if found then raise exception using errcode='PT409',message='already_published',detail=operation.request_id::text;end if;
  perform app_private.require_discovery_customer();
  select * into preview from app_private.request_discovery_sessions where id=p_session_id and customer_id=actor for update;
  if not found then raise exception using errcode='PT409',message='discovery_expired';end if;
  select * into operation from app_private.request_publish_operations where customer_id=actor and discovery_session_id=p_session_id;
  if found then raise exception using errcode='PT409',message='already_published',detail=operation.request_id::text;end if;
  if preview.expires_at<=statement_timestamp() then raise exception using errcode='PT409',message='discovery_expired';end if;
  if preview.input_digest is distinct from p_input_digest then raise exception using errcode='PT409',message='discovery_changed';end if;
  perform app_private.normalize_request_discovery_input(preview.normalized_input);
  r:=jsonb_populate_record(null::public.grooming_requests,preview.request_context);
  source:=app_private.discovery_pet_source(actor,r.pet_id);
  if source->>'source_revision' is distinct from preview.source_revision then
    raise exception using errcode='PT409',message='discovery_changed';end if;
  if preview.normalized_input->>'superseding_request_id' is not null then
    select * into original from public.grooming_requests
      where id=(preview.normalized_input->>'superseding_request_id')::uuid and customer_id=actor for update;
    if not found or original.terms_revision::text is distinct from preview.normalized_input->>'expected_request_revision'
      or original.status not in ('open','has_offers') or original.expires_at<=statement_timestamp() then
      raise exception using errcode='PT409',message='request_changed';end if;
    perform app_private.cancel_grooming_request(original.id);
  end if;
  r.expires_at:=least(statement_timestamp()+interval '48 hours',r.preferred_end-interval '5 minutes');
  created_request:=app_private.insert_request_context(r,p_pool_enabled,'discovery_v1');
  if original.id is not null then
    update public.grooming_requests set supersedes_request_id=original.id where id=created_request;
  end if;
  perform app_private.add_request_invitations(created_request,targets);
  receipt:=app_private.request_distribution_receipt(created_request);
  insert into app_private.request_publish_operations(customer_id,operation_id,request_id,match_count,protocol_version,
    discovery_session_id,discovery_draft_id,canonical_hash,distribution_receipt)
    values(actor,p_operation_id,created_request,cardinality(targets),'discoveryV1',preview.id,preview.draft_id,intent,receipt);
  update app_private.request_discovery_sessions set consumed_at=statement_timestamp() where id=preview.id;
  return receipt;
end $$;
create function public.publish_request_with_distribution_v1(p_operation_id uuid,p_session_id uuid,
  p_input_digest text,p_pool_enabled boolean,p_groomer_ids uuid[])
returns jsonb language sql volatile security invoker set search_path = '' as $$
  select app_private.publish_request_with_distribution_v1(p_operation_id,p_session_id,p_input_digest,p_pool_enabled,p_groomer_ids);
$$;
revoke all on function app_private.publish_request_with_distribution_v1(uuid,uuid,text,boolean,uuid[]),
  public.publish_request_with_distribution_v1(uuid,uuid,text,boolean,uuid[]) from public,anon,authenticated,service_role;
grant execute on function app_private.publish_request_with_distribution_v1(uuid,uuid,text,boolean,uuid[]),
  public.publish_request_with_distribution_v1(uuid,uuid,text,boolean,uuid[]) to authenticated;

create function app_private.mutate_request_distribution(p_kind text,p_operation uuid,p_request uuid,
  p_expected uuid,p_targets uuid[],p_enabled boolean,p_groomer uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=app_private.require_request_customer(); r public.grooming_requests%rowtype;
  operation app_private.request_distribution_operations%rowtype; targets uuid[]; intent text; receipt jsonb;
begin
  if p_operation is null or p_request is null or p_kind not in ('invite','pool','withdraw') then
    raise exception using errcode='22023',message='invalid_distribution_operation';end if;
  targets:=app_private.canonical_invitation_targets(coalesce(p_targets,'{}'));
  if (p_kind='invite' and (cardinality(targets)=0 or p_expected is null))
    or (p_kind='pool' and (p_enabled is null or p_expected is null))
    or (p_kind='withdraw' and p_groomer is null) then raise exception using errcode='22023',message='invalid_distribution_operation';end if;
  intent:=encode(extensions.digest(convert_to(jsonb_build_array(p_kind,p_request,p_expected,targets,p_enabled,p_groomer)::text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(actor::text||':'||p_operation::text,0));
  if exists(select 1 from app_private.request_publish_operations where customer_id=actor and operation_id=p_operation) then
    raise exception using errcode='PT409',message='operation_intent_changed';end if;
  select * into operation from app_private.request_distribution_operations where customer_id=actor and operation_id=p_operation;
  if found then
    if operation.canonical_hash is distinct from intent then raise exception using errcode='PT409',message='operation_intent_changed';end if;
    return operation.receipt;
  end if;
  select * into r from public.grooming_requests where id=p_request and customer_id=actor for update;
  if not found then raise exception using errcode='42501',message='not_allowed';end if;
  if r.status not in ('open','has_offers') or r.expires_at<=statement_timestamp() then
    raise exception using errcode='PT409',message='request_changed';end if;
  if p_kind='invite' then
    perform app_private.require_discovery_customer();
    if r.terms_revision is distinct from p_expected then raise exception using errcode='PT409',message='request_changed';end if;
    perform app_private.add_request_invitations(p_request,targets);
  elsif p_kind='pool' then
    if r.distribution_revision is distinct from p_expected then raise exception using errcode='PT409',message='distribution_changed';end if;
    if r.pool_enabled is distinct from p_enabled then
      update public.grooming_requests set pool_enabled=p_enabled,distribution_revision=gen_random_uuid() where id=p_request;
      if p_enabled then perform app_private.enqueue_request_match_refresh(p_request);
      else
        update public.request_matches m set status='hidden' where m.request_id=p_request and m.status in ('visible','viewed')
          and not app_private.request_distribution_allows_new_quote(p_request,m.groomer_id);
      end if;
    end if;
  else
    update app_private.request_invitations set withdrawn_at=statement_timestamp()
      where request_id=p_request and groomer_id=p_groomer and withdrawn_at is null;
    if found then
      update public.grooming_requests set distribution_revision=gen_random_uuid() where id=p_request;
      update public.request_matches set status='hidden' where request_id=p_request and groomer_id=p_groomer
        and status in ('visible','viewed') and not app_private.request_distribution_allows_new_quote(p_request,p_groomer);
    end if;
  end if;
  receipt:=app_private.request_distribution_receipt(p_request);
  insert into app_private.request_distribution_operations(customer_id,operation_id,kind,canonical_hash,request_id,receipt)
    values(actor,p_operation,p_kind,intent,p_request,receipt);
  return receipt;
end $$;
revoke all on function app_private.mutate_request_distribution(text,uuid,uuid,uuid,uuid[],boolean,uuid)
  from public,anon,authenticated,service_role;

create function app_private.invite_request_groomers_v1(p_operation_id uuid,p_request_id uuid,p_expected_terms_revision uuid,p_groomer_ids uuid[])
returns jsonb language sql volatile security definer set search_path = '' as $$
  select app_private.mutate_request_distribution('invite',p_operation_id,p_request_id,p_expected_terms_revision,p_groomer_ids,null,null);
$$;
create function public.invite_request_groomers_v1(p_operation_id uuid,p_request_id uuid,p_expected_terms_revision uuid,p_groomer_ids uuid[])
returns jsonb language sql volatile security invoker set search_path = '' as $$
  select app_private.invite_request_groomers_v1(p_operation_id,p_request_id,p_expected_terms_revision,p_groomer_ids);
$$;
create function app_private.set_request_pool_v1(p_operation_id uuid,p_request_id uuid,p_expected_distribution_revision uuid,p_enabled boolean)
returns jsonb language sql volatile security definer set search_path = '' as $$
  select app_private.mutate_request_distribution('pool',p_operation_id,p_request_id,p_expected_distribution_revision,null,p_enabled,null);
$$;
create function public.set_request_pool_v1(p_operation_id uuid,p_request_id uuid,p_expected_distribution_revision uuid,p_enabled boolean)
returns jsonb language sql volatile security invoker set search_path = '' as $$
  select app_private.set_request_pool_v1(p_operation_id,p_request_id,p_expected_distribution_revision,p_enabled);
$$;
create function app_private.withdraw_request_invitation_v1(p_operation_id uuid,p_request_id uuid,p_groomer_id uuid)
returns jsonb language sql volatile security definer set search_path = '' as $$
  select app_private.mutate_request_distribution('withdraw',p_operation_id,p_request_id,null,null,null,p_groomer_id);
$$;
create function public.withdraw_request_invitation_v1(p_operation_id uuid,p_request_id uuid,p_groomer_id uuid)
returns jsonb language sql volatile security invoker set search_path = '' as $$
  select app_private.withdraw_request_invitation_v1(p_operation_id,p_request_id,p_groomer_id);
$$;
revoke all on function app_private.invite_request_groomers_v1(uuid,uuid,uuid,uuid[]),public.invite_request_groomers_v1(uuid,uuid,uuid,uuid[]),
  app_private.set_request_pool_v1(uuid,uuid,uuid,boolean),public.set_request_pool_v1(uuid,uuid,uuid,boolean),
  app_private.withdraw_request_invitation_v1(uuid,uuid,uuid),public.withdraw_request_invitation_v1(uuid,uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function app_private.invite_request_groomers_v1(uuid,uuid,uuid,uuid[]),public.invite_request_groomers_v1(uuid,uuid,uuid,uuid[]),
  app_private.set_request_pool_v1(uuid,uuid,uuid,boolean),public.set_request_pool_v1(uuid,uuid,uuid,boolean),
  app_private.withdraw_request_invitation_v1(uuid,uuid,uuid),public.withdraw_request_invitation_v1(uuid,uuid,uuid) to authenticated;

create function app_private.get_customer_request_progress_v1(p_request_ids uuid[])
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
      and exists(select 1 from app_private.match_refresh_queue q where q.request_id=r.id and q.reason='hard_eligibility'),
    'valid_offer_count',(select count(*) from public.groomer_offers o where o.request_id=r.id and o.status='pending'
      and app_private.evaluate_quote(o.id)->>'selectable'='true'),
    'invitations',coalesce((select jsonb_agg(jsonb_build_object('groomer_id',i.groomer_id,
      'safe_profile',app_private.marketplace_groomer_summary(i.groomer_id),'sent_at',i.sent_at,'reply_by',i.reply_by,
      'state',app_private.request_invitation_state(r.id,i.groomer_id)) order by i.sent_at,i.groomer_id)
      from app_private.request_invitations i where i.request_id=r.id),'[]'::jsonb)) order by r.created_at desc,r.id),'[]') into result
    from public.grooming_requests r where r.id=any(p_request_ids) and r.customer_id=actor;
  return result;
end $$;
create function public.get_customer_request_progress_v1(p_request_ids uuid[])
returns jsonb language sql stable security invoker set search_path = '' as $$
  select app_private.get_customer_request_progress_v1(p_request_ids);
$$;
revoke all on function app_private.get_customer_request_progress_v1(uuid[]),public.get_customer_request_progress_v1(uuid[])
  from public,anon,authenticated,service_role;
grant execute on function app_private.get_customer_request_progress_v1(uuid[]),public.get_customer_request_progress_v1(uuid[]) to authenticated;

create or replace function app_private.discovery_candidate_actions(p_customer uuid,p_request uuid,p_groomer uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('favorite_state',jsonb_build_object('is_favorite',false,'revision',null),
    'invitation_state',app_private.request_invitation_state(p_request,p_groomer));
$$;

create or replace function app_private.create_grooming_request_v2(
  p_pet_id uuid,
  p_service_type text,
  p_service_notes text,
  p_preferred_start timestamptz,
  p_preferred_end timestamptz,
  p_location_mode text,
  p_street_address text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_address_line_2 text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz,
  p_travel_radius_miles integer
)
returns table (
  request_id uuid,
  match_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_service_type text := lower(btrim(p_service_type));
  v_service_notes text := nullif(btrim(p_service_notes), '');
  v_location_mode text := lower(btrim(p_location_mode));
  v_street_address text := btrim(p_street_address);
  v_city text := btrim(p_city);
  v_state text := upper(btrim(p_state));
  v_zip_code text := btrim(p_zip_code);
  v_address_line_2 text := nullif(btrim(p_address_line_2), '');
  v_travel_radius_miles integer := p_travel_radius_miles;
  v_request_id uuid;
  v_location_id uuid;
  v_match_count integer := 0;
  v_source jsonb;
  v_context public.grooming_requests%rowtype;
  v_pet_snapshot jsonb;
  v_photo_snapshot jsonb;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  perform 1
  from public.customer_profiles as customer_profile
  join public.profiles as profile
    on profile.id = customer_profile.user_id
  where customer_profile.user_id = v_user_id
    and profile.role = 'customer'::public.user_role
  for update of customer_profile;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'customer_profile_required';
  end if;

  if p_pet_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_pet';
  end if;

  if v_service_type not in (
    'full_groom',
    'bath_and_brush',
    'haircut_only',
    'nail_trim',
    'de_shedding',
    'custom_request'
  ) then
    raise exception using
      errcode = '22023',
      message = 'invalid_service_type';
  end if;

  if v_service_notes is not null
    and char_length(v_service_notes) > 2000
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_service_notes';
  end if;

  if p_preferred_start is null
    or p_preferred_end is null
    or p_preferred_start <= statement_timestamp()
    or p_preferred_end <= p_preferred_start
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_preferred_range';
  end if;

  if v_location_mode not in (
    'groomer_comes_to_customer',
    'customer_comes_to_groomer'
  ) then
    raise exception using
      errcode = '22023',
      message = 'invalid_location_mode';
  end if;

  if v_street_address is null
    or char_length(v_street_address) not between 1 and 160
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_street_address';
  end if;

  if v_city is null
    or char_length(v_city) not between 1 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_city';
  end if;

  if v_state is null
    or v_state !~ '^[A-Z]{2}$'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_state';
  end if;

  if v_zip_code is null
    or v_zip_code !~ '^[0-9]{5}(-[0-9]{4})?$'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_zip_code';
  end if;

  if v_address_line_2 is not null
    and char_length(v_address_line_2) > 60
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_address_line_2';
  end if;

  if v_location_mode = 'groomer_comes_to_customer' then
    v_travel_radius_miles := null;
  elsif v_travel_radius_miles is null
    or v_travel_radius_miles not between 5 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_travel_radius';
  end if;

  v_source:=app_private.discovery_pet_source(v_user_id,p_pet_id);
  v_pet_snapshot:=(v_source->'pet_snapshot')||jsonb_build_object('snapshot_at',statement_timestamp());
  v_photo_snapshot:=v_source->'photo_snapshot';

  v_location_id := app_private.save_address_location_v2(
    v_user_id,
    null,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolution_source,
    p_user_confirmed_at
  );

  v_context:=jsonb_populate_record(null::public.grooming_requests,jsonb_build_object(
    'customer_id',v_user_id,'pet_id',p_pet_id,'pet_snapshot',v_pet_snapshot,'photo_snapshot',v_photo_snapshot,
    'service_type',v_service_type,'service_notes',v_service_notes,'preferred_start',p_preferred_start,'preferred_end',p_preferred_end,
    'location_mode',v_location_mode,'street_address',v_street_address,'city',v_city,'state',v_state,
    'zip_code',v_zip_code,'address_line_2',v_address_line_2,'address_location_id',v_location_id,
    'travel_radius_miles',v_travel_radius_miles,'expires_at',statement_timestamp()+interval '48 hours'));
  v_request_id:=app_private.insert_request_context(v_context,true,'legacy_pool');

  v_match_count := app_private.create_request_matches_for_request(
    v_request_id,
    null
  );

  return query
  select v_request_id, v_match_count;
end;
$$;

create or replace function app_private.refresh_candidate_evaluation(p_request uuid, p_groomer uuid, p_now timestamp with time zone, p_source bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.grooming_requests%rowtype; result jsonb; future_result jsonb; witness jsonb;
  proof_clock timestamptz; deadline timestamptz; due timestamptz; zone text; notice integer;
begin
  if p_now is null or not isfinite(p_now) then raise exception using errcode='22023',message='invalid_clock'; end if;
  select * into r from public.grooming_requests where id=p_request for update;
  if not found then return; end if;
  if r.status not in ('open','has_offers') or r.expires_at<=p_now
    or not app_private.request_distribution_allows_new_quote(p_request,p_groomer,p_now)
    or not exists(select 1 from public.groomer_profiles where user_id=p_groomer)
    or exists(select 1 from public.request_matches where request_id=p_request and groomer_id=p_groomer and status='dismissed') then
    update public.request_matches set status='hidden' where request_id=p_request and groomer_id=p_groomer and status in ('visible','viewed');
    delete from app_private.match_candidate_evaluations where request_id=p_request and groomer_id=p_groomer;
    return;
  end if;
  result:=app_private.evaluate_match_eligibility(p_request,p_groomer,p_now);
  deadline:=least(r.expires_at,p_now+interval '60 seconds');
  due:=deadline;
  if result->>'state' in ('estimated_fit','assessment_required')
    and result ?& array['service_start','service_end','occupied_start','occupied_end'] then
    proof_clock:=least(p_now+interval '15 minutes',r.expires_at-interval '1 microsecond');
    if proof_clock>p_now then
      future_result:=app_private.evaluate_match_eligibility(p_request,p_groomer,proof_clock);
      if future_result->>'state'=result->>'state'
        and future_result ?& array['service_start','service_end','occupied_start','occupied_end'] then
        result:=future_result;
      end if;
    end if;
    select min(timezone) into zone from public.groomer_availability_windows where groomer_id=p_groomer;
    select minimum_advance_notice_days into notice from public.groomer_booking_preferences where groomer_id=p_groomer;
    deadline:=least(r.expires_at,(result->>'service_start')::timestamptz-interval '5 minutes');
    if notice>0 then deadline:=least(deadline,timezone(zone,(timezone(zone,p_now)::date+1)::timestamp)); end if;
    due:=deadline;
    witness:=jsonb_build_object('service_start',result->'service_start','service_end',result->'service_end',
      'occupied_start',result->'occupied_start','occupied_end',result->'occupied_end','kind',case when result->>'state'='assessment_required' then 'optimistic_source_interval'
        else 'fixed_source_interval' end);
  elsif result->>'state'='excluded' and result->>'reason' in (
    'no_continuous_opening','pet_species_excluded','pet_size_excluded','location_excluded',
    'service_unavailable','groomer_unavailable','request_species_confirmation_required',
    'schedule_confirmation_required','service_timezone_confirmation_required','request_unavailable') then
    deadline:=r.expires_at; due:=null;
    witness:=jsonb_build_object('kind','monotone_or_source_only_exclusion','reason',result->>'reason');
  end if;
  result:=result||jsonb_build_object('evaluated_at',p_now,'valid_until',deadline,'source_revision',p_source::text);
  insert into app_private.match_candidate_evaluations(request_id,groomer_id,result,witness,source_revision,evaluated_at,valid_until,next_evaluation_at)
    values(p_request,p_groomer,result,witness,p_source,p_now,deadline,due)
    on conflict(request_id,groomer_id) do update set result=excluded.result,witness=excluded.witness,
      source_revision=greatest(app_private.match_candidate_evaluations.source_revision,excluded.source_revision),
      evaluated_at=excluded.evaluated_at,valid_until=excluded.valid_until,next_evaluation_at=excluded.next_evaluation_at,
      ranking_revision=gen_random_uuid();
  if result->>'state'='excluded' then
    update public.request_matches set status=case when status in ('visible','viewed') then 'hidden' else status end,
      eligibility_evaluation=result where request_id=p_request and groomer_id=p_groomer and status in ('visible','viewed','offered','hidden');
  else
    insert into public.request_matches(request_id,groomer_id,customer_id,status,eligibility_evaluation)
      values(p_request,p_groomer,r.customer_id,'visible',result)
      on conflict on constraint request_matches_request_groomer_key do update set
        eligibility_evaluation=excluded.eligibility_evaluation,
        status=case when public.request_matches.status='hidden' then 'visible' else public.request_matches.status end
      where public.request_matches.status in ('visible','viewed','offered')
        or (public.request_matches.status='hidden' and public.request_matches.eligibility_evaluation->>'state'='excluded');
  end if;
end $function$;

create or replace function app_private.read_candidate_evaluation(p_request uuid,p_groomer uuid,p_now timestamptz)
returns jsonb language sql stable set search_path = '' as $$
  select case when not app_private.request_distribution_allows_new_quote(p_request,p_groomer,p_now)
    then jsonb_build_object('state','excluded','reason','request_unavailable')
    when p_now is null or not isfinite(p_now) or c.request_id is null or c.valid_until<=p_now
    or exists(select 1 from app_private.match_refresh_queue q where q.request_id=p_request and q.groomer_id=p_groomer
      and q.reason='hard_eligibility') then jsonb_build_object('state','pending','reason','refresh_pending')
    else c.result end from (select 1) singleton left join app_private.match_candidate_evaluations c
      on c.request_id=p_request and c.groomer_id=p_groomer;
$$;

create or replace function app_private.enqueue_request_match_refresh(p_request uuid)
returns void language plpgsql set search_path = '' as $$
begin
  insert into app_private.match_refresh_queue(request_id,groomer_id)
  select r.id,g.user_id from public.grooming_requests r cross join public.groomer_profiles g
  where r.id=p_request and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
    and app_private.request_distribution_allows_new_quote(r.id,g.user_id)
    and not exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=g.user_id and m.status='dismissed')
    and (exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=g.user_id)
      or exists(select 1 from app_private.match_candidate_evaluations c where c.request_id=r.id and c.groomer_id=g.user_id)
      or (g.is_active and exists(select 1 from public.groomer_services s
        where s.groomer_id=g.user_id and s.service_type=r.service_type and s.is_active)
        and exists(select 1 from app_private.address_locations a join app_private.address_locations b
          on b.id=g.address_location_id and b.owner_id=g.user_id
          cross join lateral app_private.evaluate_request_location_fit(a.location,b.location,r.location_mode,
            r.travel_radius_miles,g.service_radius_miles,r.state,r.city,g.base_state,g.base_city) fit
          where a.id=r.address_location_id and a.owner_id=r.customer_id and fit.is_eligible)));
end $$;

-- Safe projections replace raw groomer Request SELECTs. Existing owner reads stay unchanged.
create function app_private.request_has_current_offer(p_request uuid,p_groomer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.groomer_offers o join public.grooming_requests r on r.id=o.request_id
    where o.request_id=p_request and o.groomer_id=p_groomer and o.status='pending'
      and o.expires_at>statement_timestamp() and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
      and app_private.evaluate_quote(o.id)->>'terms_valid'='true');
$$;
revoke all on function app_private.request_has_current_offer(uuid,uuid) from public,anon,authenticated,service_role;

create function app_private.can_read_request_details(p_request uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null
    and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    and exists(select 1 from public.grooming_requests r where r.id=p_request and (
      r.customer_id=(select auth.uid())
      or exists(select 1 from public.bookings b where b.request_id=r.id and b.groomer_id=(select auth.uid()))
      or (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='groomer') and (
        app_private.request_has_current_offer(r.id,(select auth.uid()))
        or (app_private.request_distribution_allows_new_quote(r.id,(select auth.uid()))
          and app_private.read_candidate_evaluation(r.id,(select auth.uid()),statement_timestamp())->>'state'
            in ('estimated_fit','assessment_required'))))));
$$;
revoke all on function app_private.can_read_request_details(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.can_read_request_details(uuid) to authenticated;

create function app_private.safe_groomer_request(p_request public.grooming_requests,p_detail boolean default false)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id',p_request.id,'customer_id',p_request.customer_id,'pet_id',p_request.pet_id,
    'pet_snapshot',case when p_detail then p_request.pet_snapshot else
      (select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(p_request.pet_snapshot)
        where key=any(array['id','name','species','breed','coat_type','size','weight_lbs','coat_type_source','matting_confirmed','facts_version'])) end,
    'photo_snapshot',case when p_detail then p_request.photo_snapshot else '[]'::jsonb end,
    'service_type',p_request.service_type,'service_notes',case when p_detail then p_request.service_notes else null end,
    'preferred_start',p_request.preferred_start,'preferred_end',p_request.preferred_end,
    'preference_time_zone_identifier',p_request.preference_time_zone_identifier,'terms_revision',p_request.terms_revision,
    'location_mode',p_request.location_mode,'city',p_request.city,'state',p_request.state,
    'travel_radius_miles',p_request.travel_radius_miles,'status',p_request.status,'expires_at',p_request.expires_at,
    'created_at',p_request.created_at,'updated_at',p_request.updated_at,
    'invitation_state',app_private.request_invitation_state(p_request.id,(select auth.uid())));
$$;
revoke all on function app_private.safe_groomer_request(public.grooming_requests,boolean) from public,anon,authenticated,service_role;

create function app_private.get_groomer_request_summaries_v1(p_request_ids uuid[])
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles where id=actor and role='groomer') then
    raise exception using errcode='42501',message='not_allowed';end if;
  if p_request_ids is null or cardinality(p_request_ids)>50 or array_position(p_request_ids,null) is not null then
    raise exception using errcode='22023',message='invalid_page';end if;
  return query select app_private.safe_groomer_request(r,false) from public.grooming_requests r
    where r.id=any(p_request_ids) and (
      app_private.can_read_request_details(r.id)
      or exists(select 1 from public.groomer_offers o where o.request_id=r.id and o.groomer_id=actor)
      or (app_private.request_distribution_allows_new_quote(r.id,actor)
        and exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=actor
          and m.status in ('visible','viewed','offered'))));
end $$;
create function public.get_groomer_request_summaries_v1(p_request_ids uuid[])
returns setof jsonb language sql stable security invoker set search_path = '' as $$
  select * from app_private.get_groomer_request_summaries_v1(p_request_ids);
$$;
create function app_private.get_groomer_request_detail_v1(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare r public.grooming_requests%rowtype;
begin
  if not exists(select 1 from public.profiles where id=(select auth.uid()) and role='groomer')
    or not app_private.can_read_request_details(p_request_id) then
    raise exception using errcode='42501',message='not_allowed';end if;
  select * into strict r from public.grooming_requests where id=p_request_id;
  return app_private.safe_groomer_request(r,true);
end $$;
create function public.get_groomer_request_detail_v1(p_request_id uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select app_private.get_groomer_request_detail_v1(p_request_id);
$$;

create function app_private.get_booking_request_locations_v1(p_request_ids uuid[])
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='42501',message='not_allowed';end if;
  if p_request_ids is null or cardinality(p_request_ids)>50 or array_position(p_request_ids,null) is not null then
    raise exception using errcode='22023',message='invalid_page';end if;
  return query select jsonb_build_object('id',r.id,'location_mode',r.location_mode,'street_address',r.street_address,
    'address_line_2',r.address_line_2,'city',r.city,'state',r.state,'zip_code',r.zip_code)
    from public.grooming_requests r where r.id=any(p_request_ids) and exists(select 1 from public.bookings b
      where b.request_id=r.id and actor in (b.customer_id,b.groomer_id));
end $$;
create function public.get_booking_request_locations_v1(p_request_ids uuid[])
returns setof jsonb language sql stable security invoker set search_path = '' as $$
  select * from app_private.get_booking_request_locations_v1(p_request_ids);
$$;
revoke all on function app_private.get_groomer_request_summaries_v1(uuid[]),public.get_groomer_request_summaries_v1(uuid[]),
  app_private.get_groomer_request_detail_v1(uuid),public.get_groomer_request_detail_v1(uuid),
  app_private.get_booking_request_locations_v1(uuid[]),public.get_booking_request_locations_v1(uuid[])
  from public,anon,authenticated,service_role;
grant execute on function app_private.get_groomer_request_summaries_v1(uuid[]),public.get_groomer_request_summaries_v1(uuid[]),
  app_private.get_groomer_request_detail_v1(uuid),public.get_groomer_request_detail_v1(uuid),
  app_private.get_booking_request_locations_v1(uuid[]),public.get_booking_request_locations_v1(uuid[]) to authenticated;

drop policy grooming_requests_select_customer_or_matched_groomer on public.grooming_requests;
create policy grooming_requests_select_owner on public.grooming_requests for select to authenticated
using (customer_id=(select auth.uid()) and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false));

-- Keep ordering/cursors in the existing ranking core; only its wire projection changes.
create function app_private.safe_groomer_ranked_page(p_page jsonb)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_set(p_page,'{items}',coalesce((select jsonb_agg(jsonb_set(item,'{request}',
    app_private.safe_groomer_request(r,false)) order by ordinal)
    from jsonb_array_elements(p_page->'items') with ordinality x(item,ordinal)
    join public.grooming_requests r on r.id=(item->'request'->>'id')::uuid),'[]'::jsonb));
$$;
revoke all on function app_private.safe_groomer_ranked_page(jsonb) from public,anon,authenticated,service_role;
create or replace function app_private.get_ranked_matched_requests(p_sort text,p_limit integer default 25,p_cursor text default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select app_private.safe_groomer_ranked_page(app_private.ranked_marketplace_page('groomer',null,p_sort,p_limit,p_cursor));
$$;
create or replace function app_private.get_ranked_matched_requests_v2(p_sort text,p_limit integer default 25,p_cursor text default null)
returns jsonb language sql volatile security definer set search_path = '' as $$
  select app_private.safe_groomer_ranked_page(app_private.ranked_marketplace_browse('groomer',null,p_sort,p_limit,p_cursor));
$$;
create or replace function app_private.get_my_matched_request(p_groomer_id uuid,p_request_id uuid)
returns setof public.request_matches language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or actor is distinct from p_groomer_id
    or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles where id=actor and role='groomer') then
    raise exception using errcode='42501',message='groomer_profile_required';end if;
  return query select display.* from public.request_matches m
    cross join lateral jsonb_populate_record(null::public.request_matches,to_jsonb(m)||
      jsonb_build_object('eligibility_evaluation',app_private.read_candidate_evaluation(m.request_id,actor,statement_timestamp()))) display
    where m.request_id=p_request_id and m.groomer_id=actor and m.status in ('visible','viewed','offered')
      and app_private.request_distribution_allows_new_quote(m.request_id,actor);
end $$;

drop policy request_photos_select_customer_or_matched_groomer on public.request_photos;
create policy request_photos_select_authorized_participant on public.request_photos for select to authenticated
using (app_private.can_read_request_details(request_id));
drop policy request_photos_objects_select_customer_or_matched_groomer on storage.objects;
create policy request_photos_objects_select_authorized_participant on storage.objects for select to authenticated
using (bucket_id='request-photos' and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
  and array_length(storage.foldername(name),1)=2
  and ((storage.foldername(name))[1]=(select auth.uid())::text
    or exists(select 1 from public.request_photos p where p.storage_bucket=bucket_id and p.storage_path=name
      and app_private.can_read_request_details(p.request_id))));

create or replace function app_private.get_my_matched_requests(p_groomer_id uuid,p_limit integer default 25,p_offset integer default 0)
returns setof public.request_matches language plpgsql stable security definer set search_path = ''
as $$
declare owner uuid:=(select auth.uid());
begin
  if owner is null or owner is distinct from p_groomer_id
    or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles where id=owner and role='groomer') then
    raise exception using errcode='42501',message='groomer_profile_required';
  end if;
  if p_limit is null or p_limit not between 1 and 100 or p_offset is null or p_offset<0 then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  return query
    select display.*
    from public.request_matches m join public.grooming_requests r on r.id=m.request_id
    cross join lateral jsonb_populate_record(null::public.request_matches,to_jsonb(m)||
      jsonb_build_object('eligibility_evaluation',
        app_private.read_candidate_evaluation(m.request_id,m.groomer_id,statement_timestamp()))) display
    where m.groomer_id=owner and m.status in ('visible','viewed','offered')
      and app_private.request_distribution_allows_new_quote(r.id,owner)
      and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
    order by m.created_at desc,m.id desc limit p_limit offset p_offset;
end $$;

create or replace function app_private.enqueue_match_refresh(
  p_groomer_id uuid,p_pet_id uuid default null
)
returns integer language plpgsql security definer set search_path = ''
as $$
declare enqueued integer;
begin
  -- The consumer is bounded; no affected request is dropped at enqueue time.
  insert into app_private.match_refresh_queue(request_id,groomer_id)
  select r.id,p_groomer_id from public.grooming_requests r
    join public.groomer_profiles g on g.user_id=p_groomer_id
    where r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
      and app_private.request_distribution_allows_new_quote(r.id,p_groomer_id)
      and (p_pet_id is null or r.pet_id=p_pet_id)
      and not exists(select 1 from public.request_matches m
        where m.request_id=r.id and m.groomer_id=p_groomer_id and m.status='dismissed')
      and (exists(select 1 from public.request_matches m
        where m.request_id=r.id and m.groomer_id=p_groomer_id)
        or (g.is_active and coalesce(g.service_location_modes @> array[r.location_mode]::text[],
          g.service_location_mode=r.location_mode,false)
          and exists(select 1 from public.groomer_services s where s.groomer_id=p_groomer_id
            and s.is_active and s.service_type=r.service_type)
          and exists(select 1 from app_private.address_locations a
            join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=p_groomer_id
            cross join lateral app_private.evaluate_request_location_fit(a.location,b.location,r.location_mode,
              r.travel_radius_miles,g.service_radius_miles,r.state,r.city,g.base_state,g.base_city) fit
            where a.id=r.address_location_id and a.owner_id=r.customer_id and fit.is_eligible)))
  ;
  get diagnostics enqueued=row_count;
  return enqueued;
end $$;

create or replace function app_private.create_request_matches_for_request(
  p_request_id uuid,
  p_only_groomer_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_match_count integer := 0;
begin
  if p_request_id is null then
    return 0;
  end if;

  with selected_request as materialized (
    select request.*
    from public.grooming_requests as request
    where request.id = p_request_id
      and request.status in ('open', 'has_offers')
      and request.expires_at > statement_timestamp()
    for update of request
  ),
  request_traits as materialized (
    select trait.trait_type, trait.trait_value
    from selected_request
    cross join lateral app_private.pet_fit_traits_from_snapshot(
      selected_request.pet_snapshot,
      selected_request.service_type,
      timezone(coalesce(selected_request.preference_time_zone_identifier,'UTC'),selected_request.preferred_start)::date
    ) as trait
  ),
  location_candidates as materialized (
    select
      selected_request.id as request_id,
      selected_request.customer_id,
      selected_request.service_type,
      selected_request.preferred_start,
      selected_request.preferred_end,
      groomer_profile.user_id,
      location_fit.location_score,
      location_fit.location_reason
    from selected_request
    join public.groomer_profiles as groomer_profile
      on true
    join public.profiles as profile
      on profile.id = groomer_profile.user_id
    left join app_private.address_locations as request_location
      on request_location.id = selected_request.address_location_id
     and request_location.owner_id = selected_request.customer_id
    left join app_private.address_locations as groomer_location
      on groomer_location.id = groomer_profile.address_location_id
     and groomer_location.owner_id = groomer_profile.user_id
    cross join lateral app_private.evaluate_request_location_fit(
      request_location.location,
      groomer_location.location,
      selected_request.location_mode,
      selected_request.travel_radius_miles,
      groomer_profile.service_radius_miles,
      selected_request.state,
      selected_request.city,
      groomer_profile.base_state,
      groomer_profile.base_city
    ) as location_fit
    where profile.role = 'groomer'::public.user_role
      and groomer_profile.is_active
      and app_private.request_distribution_allows_new_quote(selected_request.id,groomer_profile.user_id)
      and location_fit.is_eligible
      and (
        p_only_groomer_id is null
        or groomer_profile.user_id = p_only_groomer_id
      )
      and (
        groomer_profile.service_location_modes @>
          array[selected_request.location_mode]::text[]
        or (
          groomer_profile.service_location_modes is null
          and groomer_profile.service_location_mode = selected_request.location_mode
        )
      )
      and exists (
        select 1
        from public.groomer_services as groomer_service
        where groomer_service.groomer_id = groomer_profile.user_id
          and groomer_service.is_active
          and groomer_service.service_type = selected_request.service_type
      )
  ),
  zone_registry as materialized (
    select array(select name from pg_catalog.pg_timezone_names) as names
    where exists(select 1 from location_candidates)
  ),
  evaluated_candidates as materialized (
    select candidate.*, app_private.evaluate_match_eligibility_with_zones(
      candidate.request_id,candidate.user_id,statement_timestamp(),zone_registry.names) as evaluation
    from location_candidates candidate cross join zone_registry
  ),
  eligible_groomers as (
    select candidate.*,
      case when evaluation->>'state'='estimated_fit'
        then 'Estimated opening within your preferred window; confirm in the offer'
        else 'Service details need assessment before a time can be confirmed'
      end as availability_reason
    from evaluated_candidates candidate
    where evaluation->>'state' in ('estimated_fit','assessment_required')
  )
  insert into public.request_matches (
    request_id,
    groomer_id,
    customer_id,
    match_score,
    match_reason,
    eligibility_evaluation,
    status
  )
  select
    eligible_groomer.request_id,
    eligible_groomer.user_id,
    eligible_groomer.customer_id,
    greatest(
      0,
      least(
        100,
        eligible_groomer.location_score +
          coalesce(pet_fit.adjustment, 0) +
          case
            when coalesce(pet_fit.has_negative_evidence, false) then 0
            else coalesce(claim_tag_fit.adjustment, 0)
          end
      )
    )::numeric(5, 2),
    left(
      case
        when pet_fit.reason_text is null
          and (
            claim_tag_fit.reason_text is null
            or coalesce(pet_fit.has_negative_evidence, false)
          )
        then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '.'
        when pet_fit.reason_text is not null
          and claim_tag_fit.reason_text is not null
          and not coalesce(pet_fit.has_negative_evidence, false)
        then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
        when pet_fit.reason_text is not null then
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Pet-fit evidence: ' ||
          pet_fit.reason_text ||
          '.'
        else
          eligible_groomer.location_reason ||
          '. ' ||
          eligible_groomer.availability_reason ||
          '. Groomer fit signals: ' ||
          claim_tag_fit.reason_text ||
          '.'
      end,
      500
    ),
    eligible_groomer.evaluation || jsonb_build_object('evaluated_at',statement_timestamp()),
    'visible'
  from eligible_groomers as eligible_groomer
  left join lateral (
    select
      greatest(
        -10,
        least(20, coalesce(sum(ranked_evidence.evidence_points), 0))
      )::integer as adjustment,
      coalesce(
        bool_or(ranked_evidence.evidence_points < 0),
        false
      ) as has_negative_evidence,
      string_agg(
        ranked_evidence.reason_label,
        ', '
        order by
          case
            when ranked_evidence.evidence_points < 0 then 0
            else 1
          end,
          case
            when ranked_evidence.evidence_points < 0
            then ranked_evidence.evidence_points
            else -ranked_evidence.evidence_points
          end,
          ranked_evidence.trait_sort,
          ranked_evidence.trait_value
      ) as reason_text
    from (
      select prioritized_evidence.*
      from (
        select
          evidence.*,
          row_number() over (
            order by
              case
                when evidence.evidence_points < 0 then 0
                else 1
              end,
              case
                when evidence.evidence_points < 0 then evidence.evidence_points
                else -evidence.evidence_points
              end,
              evidence.trait_sort,
              evidence.trait_value
          ) as fairness_rank
        from (
          select
            summary.trait_type,
            summary.trait_value,
            app_private.pet_fit_trait_sort(summary.trait_type) as trait_sort,
            case
              when summary.negative_review_outcome_count >
                summary.positive_review_outcome_count
              then -4
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
                and summary.confidence_tier = 'high'
              then 8
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
                and summary.confidence_tier = 'medium'
              then 6
              when summary.positive_review_outcome_count >
                summary.negative_review_outcome_count
              then 4
              when summary.positive_review_outcome_count =
                summary.negative_review_outcome_count
                and summary.positive_review_outcome_count > 0
              then 2
              when summary.completed_booking_count >= 2
              then 3
              when summary.completed_booking_count >= 1
              then 1
              else 0
            end as evidence_points,
            case
              when summary.negative_review_outcome_count >
                summary.positive_review_outcome_count
              then 'mixed feedback for ' ||
                app_private.pet_fit_trait_label(
                  summary.trait_type,
                  summary.trait_value
                )
              when summary.positive_review_outcome_count > 0
              then app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              ) || ' with positive reviews'
              when summary.completed_booking_count >= 2
              then app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              ) || ' from completed bookings'
              else app_private.pet_fit_trait_label(
                summary.trait_type,
                summary.trait_value
              )
            end as reason_label
          from request_traits as request_trait
          join public.groomer_pet_fit_evidence_summary as summary
            on summary.groomer_id = eligible_groomer.user_id
           and summary.trait_type = request_trait.trait_type
           and summary.trait_value = request_trait.trait_value
          where summary.completed_booking_count > 0
            or summary.structured_review_outcome_count > 0
        ) as evidence
        where evidence.evidence_points <> 0
      ) as prioritized_evidence
      where prioritized_evidence.fairness_rank <= 3
      order by prioritized_evidence.fairness_rank
    ) as ranked_evidence
  ) as pet_fit
    on true
  left join lateral (
    select
      least(
        6,
        coalesce(sum(ranked_signal.signal_points), 0)
      )::integer as adjustment,
      string_agg(
        ranked_signal.reason_label,
        ', '
        order by
          ranked_signal.signal_points desc,
          ranked_signal.signal_sort,
          ranked_signal.trait_sort,
          ranked_signal.trait_value
      ) as reason_text
    from (
      select signal.*
      from (
        select
          request_trait.trait_type,
          request_trait.trait_value,
          1 as signal_sort,
          app_private.pet_fit_trait_sort(request_trait.trait_type) as trait_sort,
          2 as signal_points,
          'portfolio tag for ' ||
            app_private.pet_fit_trait_label(
              request_trait.trait_type,
              request_trait.trait_value
            ) as reason_label
        from request_traits as request_trait
        where exists (
          select 1
          from public.groomer_portfolio_fit_tags as portfolio_tag
          where portfolio_tag.groomer_id = eligible_groomer.user_id
            and portfolio_tag.trait_type = request_trait.trait_type
            and portfolio_tag.trait_value = request_trait.trait_value
        )

        union all

        select
          request_trait.trait_type,
          request_trait.trait_value,
          2 as signal_sort,
          app_private.pet_fit_trait_sort(request_trait.trait_type) as trait_sort,
          1 as signal_points,
          'self-claimed fit for ' ||
            app_private.pet_fit_trait_label(
              request_trait.trait_type,
              request_trait.trait_value
            ) as reason_label
        from request_traits as request_trait
        where exists (
          select 1
          from public.groomer_fit_claims as claim
          where claim.groomer_id = eligible_groomer.user_id
            and claim.trait_type = request_trait.trait_type
            and claim.trait_value = request_trait.trait_value
            and claim.is_active
        )
      ) as signal
      order by
        signal.signal_points desc,
        signal.signal_sort,
        signal.trait_sort,
        signal.trait_value
      limit 3
    ) as ranked_signal
  ) as claim_tag_fit
    on true
  on conflict on constraint request_matches_request_groomer_key do update
    set match_score=excluded.match_score, match_reason=excluded.match_reason,
      eligibility_evaluation=excluded.eligibility_evaluation,
      status=case when public.request_matches.status='hidden' then 'visible'
        else public.request_matches.status end
    where public.request_matches.status in ('visible','viewed','offered')
      or (public.request_matches.status='hidden'
        and public.request_matches.eligibility_evaluation->>'state'='excluded');

  get diagnostics v_match_count = row_count;
  return v_match_count;
end;
$$;

notify pgrst,'reload schema';
