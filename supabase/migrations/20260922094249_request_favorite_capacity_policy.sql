-- Keep the boundary executable independently of the number of available identities.
create function app_private.require_groomer_favorite_capacity(p_current_count bigint)
returns void language plpgsql immutable set search_path = '' as $$
begin
  if p_current_count is null or p_current_count<0 then
    raise exception using errcode='22023',message='invalid_favorite_count';end if;
  if p_current_count>=500 then
    raise exception using errcode='P0001',message='favorite_limit_reached';end if;
end $$;
revoke all on function app_private.require_groomer_favorite_capacity(bigint) from public,anon,authenticated,service_role;

create or replace function app_private.set_groomer_favorite_v1(p_groomer_id uuid,p_is_favorite boolean,p_expected_revision uuid default null)
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
    perform app_private.require_groomer_favorite_capacity(
      (select count(*) from app_private.customer_groomer_favorites where customer_id=actor and is_favorite));
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
