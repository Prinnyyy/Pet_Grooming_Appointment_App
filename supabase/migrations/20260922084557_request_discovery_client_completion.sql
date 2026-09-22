-- T-399: keep rollout and legacy retirement independent so a UI rollback cannot broadcast requests.
alter table app_private.match_ranking_config
  add column legacy_publish_retired boolean not null default false;

create function app_private.guard_legacy_request_publication()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.distribution_version='legacy_pool'
    and exists(select 1 from app_private.match_ranking_config where singleton and legacy_publish_retired) then
    raise exception using errcode='PT409',message='client_update_required';
  end if;
  return new;
end $$;
revoke all on function app_private.guard_legacy_request_publication() from public,anon,authenticated,service_role;
create trigger grooming_requests_aaa_legacy_publication before insert on public.grooming_requests
  for each row execute function app_private.guard_legacy_request_publication();

-- Only viewer-specific invitation state and the pool flag are added to the existing safe projection.
create or replace function app_private.safe_groomer_request(p_request public.grooming_requests,p_detail boolean default false)
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
    'created_at',p_request.created_at,'updated_at',p_request.updated_at,'pool_enabled',p_request.pool_enabled,
    'invitation_state',app_private.request_invitation_state(p_request.id,(select auth.uid())));
$$;
revoke all on function app_private.safe_groomer_request(public.grooming_requests,boolean) from public,anon,authenticated,service_role;
