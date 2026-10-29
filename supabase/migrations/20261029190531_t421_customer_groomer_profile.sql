-- Customer-facing profile projection. Existing tables and storage RLS remain unchanged.
create function app_private.get_customer_groomer_profile_v1(p_groomer_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := app_private.require_discovery_customer(); summary jsonb; result jsonb;
begin
  if p_groomer_id is null then raise exception using errcode='22023', message='invalid_groomer'; end if;
  summary := app_private.marketplace_groomer_summary(p_groomer_id);
  if summary is null then raise exception using errcode='PT409', message='groomer_unavailable'; end if;
  select jsonb_build_object('profile', summary,
    'modes', g.service_location_modes, 'radius_miles', g.service_radius_miles,
    'notice_days', (select p.minimum_advance_notice_days from public.groomer_booking_preferences p where p.groomer_id=g.user_id),
    'services', coalesce((select jsonb_agg(jsonb_build_object(
      'id',s.id,'groomer_id',s.groomer_id,'service_type',s.service_type,'title',s.title,'description',s.description,
      'base_price',s.base_price,'duration_minutes',s.duration_minutes,'accepted_pet_sizes',s.accepted_pet_sizes,
      'accepted_species',s.accepted_species,'is_active',s.is_active) order by s.title,s.id)
      from public.groomer_services s where s.groomer_id=g.user_id and s.is_active),'[]'::jsonb),
    'photos', coalesce((select jsonb_agg(jsonb_build_object(
      'id',p.id,'groomer_id',p.groomer_id,'storage_bucket',p.storage_bucket,'storage_path',p.storage_path,
      'caption',p.caption,'sort_order',p.sort_order) order by p.sort_order,p.id)
      from public.groomer_portfolio_photos p where p.groomer_id=g.user_id),'[]'::jsonb),
    'tags', coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'portfolio_photo_id',t.portfolio_photo_id,
      'groomer_id',t.groomer_id,'trait_type',t.trait_type,'trait_value',t.trait_value) order by t.id)
      from public.groomer_portfolio_fit_tags t join public.groomer_portfolio_photos p on p.id=t.portfolio_photo_id
      and p.groomer_id=t.groomer_id where t.groomer_id=g.user_id),'[]'::jsonb),
    'claims', coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'groomer_id',c.groomer_id,
      'trait_type',c.trait_type,'trait_value',c.trait_value,'is_active',c.is_active) order by c.id)
      from public.groomer_fit_claims c where c.groomer_id=g.user_id and c.is_active),'[]'::jsonb),
    'windows', coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'groomer_id',w.groomer_id,
      'weekday',w.weekday,'start_time',w.start_time,'end_time',w.end_time,'is_enabled',w.is_enabled,'timezone',w.timezone)
      order by w.weekday,w.start_time,w.id)
      from public.groomer_availability_windows w where w.groomer_id=g.user_id and w.is_enabled),'[]'::jsonb),
    -- Dates are a public schedule summary; the owner's private title is never selected.
    'time_off', (select jsonb_build_object('id',t.id,'groomer_id',t.groomer_id,'title','Unavailable',
      'start_date',t.start_date,'end_date',t.end_date)
      from public.groomer_time_off_windows t where t.groomer_id=g.user_id
      and t.end_date >= (statement_timestamp() at time zone coalesce((select w.timezone
        from public.groomer_availability_windows w join pg_catalog.pg_timezone_names z on z.name=w.timezone
        where w.groomer_id=g.user_id order by w.weekday,w.id limit 1),'UTC'))::date
      order by t.start_date,t.id limit 1)) into result
  from public.groomer_profiles g where g.user_id=p_groomer_id;
  return result;
end $$;
create function public.get_customer_groomer_profile_v1(p_groomer_id uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select app_private.get_customer_groomer_profile_v1(p_groomer_id);
$$;
revoke all on function app_private.get_customer_groomer_profile_v1(uuid),
  public.get_customer_groomer_profile_v1(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.get_customer_groomer_profile_v1(uuid),
  public.get_customer_groomer_profile_v1(uuid) to authenticated;
