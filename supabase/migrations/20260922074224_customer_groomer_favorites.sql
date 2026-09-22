-- T-399 / HD-03. Private favorites are not matching or distribution signals.
create table app_private.customer_groomer_favorites (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  groomer_id uuid not null references public.groomer_profiles(user_id) on delete cascade,
  is_favorite boolean not null,
  favorited_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  revision uuid not null default gen_random_uuid(),
  primary key(customer_id,groomer_id)
);
alter table app_private.customer_groomer_favorites enable row level security;
revoke all on app_private.customer_groomer_favorites from public,anon,authenticated,service_role;
create index customer_groomer_favorites_page_idx on app_private.customer_groomer_favorites(customer_id,favorited_at desc,groomer_id)
  where is_favorite;
create index customer_groomer_favorites_groomer_idx on app_private.customer_groomer_favorites(groomer_id);
create index customer_groomer_favorites_tombstone_idx on app_private.customer_groomer_favorites(updated_at)
  where not is_favorite;

create or replace function app_private.require_request_customer()
returns uuid language plpgsql stable set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.customer_profiles c join public.profiles p on p.id=c.user_id
      where c.user_id=actor and p.role='customer')
    or exists(select 1 from public.account_deletion_requests where user_id=actor and anonymized_at is not null) then
    raise exception using errcode='42501',message='not_allowed';end if;
  return actor;
end $$;
create or replace function app_private.require_discovery_customer()
returns uuid language plpgsql stable set search_path = '' as $$
declare actor uuid:=app_private.require_request_customer();
begin
  if not exists(select 1 from app_private.match_ranking_config where singleton
    and (discovery_enabled or actor=any(discovery_validation_actor_ids))) then
    raise exception using errcode='P0001',message='discovery_unavailable';end if;
  return actor;
end $$;

create function app_private.groomer_favorite_state(p_customer uuid,p_groomer uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('is_favorite',coalesce(f.is_favorite,false),'revision',f.revision)
    from (select 1) singleton left join app_private.customer_groomer_favorites f
      on f.customer_id=p_customer and f.groomer_id=p_groomer;
$$;
revoke all on function app_private.groomer_favorite_state(uuid,uuid) from public,anon,authenticated,service_role;

create function app_private.set_groomer_favorite_v1(p_groomer_id uuid,p_is_favorite boolean,p_expected_revision uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=app_private.require_request_customer(); existing app_private.customer_groomer_favorites%rowtype;
begin
  if p_groomer_id is null or p_is_favorite is null then raise exception using errcode='22023',message='invalid_favorite';end if;
  -- One account lock serializes the cap and opposite writes across devices.
  perform 1 from public.customer_profiles where user_id=actor for update;
  perform app_private.require_request_customer();
  select * into existing from app_private.customer_groomer_favorites where customer_id=actor and groomer_id=p_groomer_id;
  if found and existing.is_favorite=p_is_favorite then return app_private.groomer_favorite_state(actor,p_groomer_id);end if;
  if existing.revision is distinct from p_expected_revision then raise exception using errcode='PT409',message='favorite_changed',
    detail=app_private.groomer_favorite_state(actor,p_groomer_id)::text;end if;
  if p_is_favorite then
    perform app_private.require_discovery_customer();
    perform 1 from public.groomer_profiles g join public.profiles p on p.id=g.user_id and p.role='groomer'
      where g.user_id=p_groomer_id and g.is_active and not exists(select 1 from public.account_deletion_requests
        where user_id=g.user_id and anonymized_at is not null) for share of g;
    if not found then raise exception using errcode='PT409',message='groomer_unavailable';end if;
    if (select count(*) from app_private.customer_groomer_favorites where customer_id=actor and is_favorite)>=500 then
      raise exception using errcode='P0001',message='favorite_limit_reached';end if;
  elsif existing.customer_id is null then
    return jsonb_build_object('is_favorite',false,'revision',null);
  end if;
  insert into app_private.customer_groomer_favorites(customer_id,groomer_id,is_favorite)
    values(actor,p_groomer_id,p_is_favorite)
    on conflict(customer_id,groomer_id) do update set is_favorite=excluded.is_favorite,
      favorited_at=case when excluded.is_favorite then statement_timestamp() else app_private.customer_groomer_favorites.favorited_at end,
      updated_at=statement_timestamp(),revision=gen_random_uuid();
  return app_private.groomer_favorite_state(actor,p_groomer_id);
end $$;
create function public.set_groomer_favorite_v1(p_groomer_id uuid,p_is_favorite boolean,p_expected_revision uuid default null)
returns jsonb language sql volatile security invoker set search_path = '' as $$
  select app_private.set_groomer_favorite_v1(p_groomer_id,p_is_favorite,p_expected_revision);
$$;

create function app_private.get_my_favorite_groomers_v1(p_scope jsonb default null,p_limit integer default 25,p_cursor text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=app_private.require_request_customer(); config app_private.match_ranking_config%rowtype;
  resolved jsonb; r public.grooming_requests%rowtype; zones text[]; item record; profile jsonb; evaluation jsonb;
  rows jsonb:='[]'; revision text; scope_key text:=coalesce(p_scope::text,'none'); cursor_data jsonb;
  as_of timestamptz:=statement_timestamp(); deadline timestamptz:=as_of+interval '5 minutes';
  last_at timestamptz; last_id uuid; next_cursor text; last_item jsonb; availability text; more boolean:=false;
begin
  if p_limit is null or p_limit not between 1 and 50 then raise exception using errcode='22023',message='invalid_page';end if;
  select * into strict config from app_private.match_ranking_config where singleton;
  if p_scope is not null then
    resolved:=app_private.resolve_request_discovery_scope(p_scope);
    r:=jsonb_populate_record(null::public.grooming_requests,resolved->'context');
    deadline:=least(deadline,(resolved->>'valid_until')::timestamptz);
    select array_agg(name) into zones from pg_catalog.pg_timezone_names;
  end if;
  select md5(coalesce(jsonb_agg(jsonb_build_array(groomer_id,favorited_at) order by favorited_at desc,groomer_id),'[]')::text)
    into revision from app_private.customer_groomer_favorites where customer_id=actor and is_favorite;
  if p_cursor is not null then
    cursor_data:=app_private.match_cursor_decode(p_cursor,config.signing_key);
    if cursor_data->>'purpose' is distinct from 'favorites_v1' or cursor_data->>'viewer' is distinct from actor::text
      or cursor_data->>'scope' is distinct from scope_key then raise exception using errcode='22023',message='invalid_cursor';end if;
    if cursor_data->>'revision' is distinct from revision then raise exception using errcode='PT409',message='list_changed';end if;
    as_of:=(cursor_data->>'as_of')::timestamptz;deadline:=least(deadline,(cursor_data->>'valid_until')::timestamptz);
    last_at:=(cursor_data->>'last_at')::timestamptz;last_id:=(cursor_data->>'last_id')::uuid;
    if as_of is null or deadline is null or last_at is null or last_id is null or not isfinite(as_of)
      or not isfinite(deadline) or not isfinite(last_at) or deadline>as_of+interval '5 minutes' then
      raise exception using errcode='22023',message='invalid_cursor';end if;
    if deadline<=statement_timestamp() then raise exception using errcode='PT409',message='list_changed';end if;
  end if;
  for item in select f.* from app_private.customer_groomer_favorites f where f.customer_id=actor and f.is_favorite
    and (last_at is null or f.favorited_at<last_at or (f.favorited_at=last_at and f.groomer_id>last_id))
    order by f.favorited_at desc,f.groomer_id limit p_limit+1
  loop
    if jsonb_array_length(rows)=p_limit then more:=true;exit;end if;
    profile:=app_private.marketplace_groomer_summary(item.groomer_id);
    availability:=case when profile is not null then 'available'
      when exists(select 1 from public.groomer_profiles g join public.profiles p on p.id=g.user_id and p.role='groomer'
        where g.user_id=item.groomer_id and not g.is_active and not exists(select 1 from public.account_deletion_requests
          where user_id=g.user_id and anonymized_at is not null)) then 'paused' else 'unavailable' end;
    evaluation:=null;
    if p_scope is not null then evaluation:=app_private.evaluate_context_eligibility(r,item.groomer_id,statement_timestamp(),zones);end if;
    last_item:=jsonb_build_object('groomer_id',item.groomer_id,'favorited_at',item.favorited_at,'safe_profile',profile,
      'availability',availability,'eligibility',evaluation,'favorite_state',app_private.groomer_favorite_state(actor,item.groomer_id),
      'invitation_state',case when r.id is null then 'not_sent' else app_private.request_invitation_state(r.id,item.groomer_id) end);
    rows:=rows||jsonb_build_array(last_item);
  end loop;
  if more then next_cursor:=app_private.match_cursor_encode(jsonb_build_object('purpose','favorites_v1','viewer',actor,
    'scope',scope_key,'revision',revision,'as_of',as_of,'valid_until',deadline,
    'last_at',last_item->>'favorited_at','last_id',last_item->>'groomer_id'),config.signing_key);end if;
  return jsonb_build_object('items',rows,'revision',revision,'as_of',as_of,'next_cursor',next_cursor);
end $$;
create function public.get_my_favorite_groomers_v1(p_scope jsonb default null,p_limit integer default 25,p_cursor text default null)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select app_private.get_my_favorite_groomers_v1(p_scope,p_limit,p_cursor);
$$;
revoke all on function app_private.set_groomer_favorite_v1(uuid,boolean,uuid),public.set_groomer_favorite_v1(uuid,boolean,uuid),
  app_private.get_my_favorite_groomers_v1(jsonb,integer,text),public.get_my_favorite_groomers_v1(jsonb,integer,text)
  from public,anon,authenticated,service_role;
grant execute on function app_private.set_groomer_favorite_v1(uuid,boolean,uuid),public.set_groomer_favorite_v1(uuid,boolean,uuid),
  app_private.get_my_favorite_groomers_v1(jsonb,integer,text),public.get_my_favorite_groomers_v1(jsonb,integer,text) to authenticated;

create or replace function app_private.discovery_candidate_actions(p_customer uuid,p_request uuid,p_groomer uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('favorite_state',app_private.groomer_favorite_state(p_customer,p_groomer),
    'invitation_state',case when p_request is null then 'not_sent' else app_private.request_invitation_state(p_request,p_groomer) end);
$$;

-- Exact profile path only; no prefix enumeration and no broader profiles SELECT grant.
create function app_private.customer_can_read_marketplace_avatar(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    and exists(select 1 from public.profiles where id=(select auth.uid()) and role='customer')
    and not exists(select 1 from public.account_deletion_requests where user_id=(select auth.uid()) and anonymized_at is not null)
    and exists(select 1 from public.profiles p join public.groomer_profiles g on g.user_id=p.id and g.is_active
      where p.role='groomer' and p.avatar_path=p_path and split_part(p_path,'/',1)=p.id::text
        and not exists(select 1 from public.account_deletion_requests where user_id=p.id and anonymized_at is not null));
$$;
revoke all on function app_private.customer_can_read_marketplace_avatar(text) from public,anon,authenticated,service_role;
grant execute on function app_private.customer_can_read_marketplace_avatar(text) to authenticated;
create policy groomer_avatar_objects_discovery_read on storage.objects for select to authenticated
using (bucket_id='groomer-avatars'
  and storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info','object.sign'])
  and app_private.customer_can_read_marketplace_avatar(name));

create function app_private.cleanup_favorite_tombstones()
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare removed integer;
begin
  delete from app_private.customer_groomer_favorites where (customer_id,groomer_id) in (
    select customer_id,groomer_id from app_private.customer_groomer_favorites where not is_favorite
      and updated_at<statement_timestamp()-interval '30 days' order by updated_at limit 500 for update skip locked);
  get diagnostics removed=row_count;return removed;
end $$;
revoke all on function app_private.cleanup_favorite_tombstones() from public,anon,authenticated,service_role;
select cron.schedule('cleanup-groomer-favorite-tombstones','17 * * * *','select app_private.cleanup_favorite_tombstones();');

create function app_private.redact_request_discovery_data()
returns trigger language plpgsql volatile security definer set search_path = '' as $$
begin
  if new.anonymized_at is null then return new;end if;
  delete from app_private.customer_groomer_favorites where customer_id=new.user_id or groomer_id=new.user_id;
  delete from app_private.request_discovery_sessions where customer_id=new.user_id;
  delete from app_private.request_invitations where groomer_id=new.user_id
    or request_id in(select id from public.grooming_requests where customer_id=new.user_id);
  delete from app_private.request_distribution_operations where customer_id=new.user_id;
  delete from app_private.request_publish_operations where customer_id=new.user_id;
  delete from app_private.match_browse_snapshots where viewer_id=new.user_id;
  return new;
end $$;
revoke all on function app_private.redact_request_discovery_data() from public,anon,authenticated,service_role;
create trigger account_deletion_redact_discovery after insert or update of anonymized_at on public.account_deletion_requests
  for each row execute function app_private.redact_request_discovery_data();

notify pgrst,'reload schema';
