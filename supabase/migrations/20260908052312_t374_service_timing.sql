-- T-374 / WP-03 timing foundation. Prepared only; admission/schema integration is pending.
create or replace function app_private.service_timing_allocation(
  p_start timestamptz, p_duration_minutes integer, p_preparation integer,
  p_cleanup integer, p_inbound_travel integer, p_outbound_travel integer, p_location_mode text
)
returns table(service_start timestamptz, service_end timestamptz,
  occupied_start timestamptz, occupied_end timestamptz)
language plpgsql immutable set search_path = ''
as $$
declare
  v_end timestamptz;
  v_before integer;
  v_after integer;
begin
  if p_start is null or not pg_catalog.isfinite(p_start)
    or p_duration_minutes is null or p_duration_minutes not between 15 and 720 then
    raise exception using errcode='22023', message='invalid_service_duration';
  end if;
  if p_preparation is null or p_preparation not between 0 and 120
    or p_cleanup is null or p_cleanup not between 0 and 120
    or p_inbound_travel is null or p_inbound_travel not between 0 and 180
    or p_outbound_travel is null or p_outbound_travel not between 0 and 180 then
    raise exception using errcode='22023', message='invalid_timing_buffers';
  end if;
  if p_location_mode is null or p_location_mode not in
    ('groomer_comes_to_customer','customer_comes_to_groomer') then
    raise exception using errcode='22023', message='invalid_location_mode';
  end if;
  v_end := p_start + pg_catalog.make_interval(mins => p_duration_minutes);
  v_before := p_preparation + case when p_location_mode='groomer_comes_to_customer' then p_inbound_travel else 0 end;
  v_after := p_cleanup + case when p_location_mode='groomer_comes_to_customer' then p_outbound_travel else 0 end;
  return query select p_start, v_end,
    p_start - pg_catalog.make_interval(mins => v_before),
    v_end + pg_catalog.make_interval(mins => v_after);
end $$;

create or replace function app_private.service_timing_earliest_start(
  p_now timestamptz, p_notice_days integer, p_schedule_timezone text
)
returns timestamptz
language plpgsql stable set search_path = ''
as $$
declare v_day date;
begin
  if p_now is null or not pg_catalog.isfinite(p_now)
    or p_notice_days is null or p_notice_days not between 0 and 2 then
    raise exception using errcode='22023', message='invalid_advance_notice';
  end if;
  if p_schedule_timezone is null or not exists (
    select 1 from pg_catalog.pg_timezone_names where name=p_schedule_timezone
  ) then
    raise exception using errcode='22023', message='invalid_schedule_timezone';
  end if;
  v_day := pg_catalog.timezone(p_schedule_timezone,p_now)::date + p_notice_days;
  return greatest(p_now + interval '5 minutes', pg_catalog.timezone(p_schedule_timezone,v_day::timestamp));
end $$;

create or replace function app_private.remaining_service_window(
  p_start timestamptz, p_end timestamptz, p_now timestamptz
)
returns table(window_start timestamptz, window_end timestamptz)
language sql immutable set search_path = ''
as $$
  select greatest(p_start,p_now + interval '5 minutes'),p_end
  where p_start is not null and p_end is not null and p_now is not null
    and pg_catalog.isfinite(p_start) and pg_catalog.isfinite(p_end) and pg_catalog.isfinite(p_now)
    and p_start < p_end and greatest(p_start,p_now + interval '5 minutes') < p_end;
$$;

revoke all on function app_private.service_timing_allocation(timestamptz,integer,integer,integer,integer,integer,text)
  from public, anon, authenticated;
revoke all on function app_private.service_timing_earliest_start(timestamptz,integer,text)
  from public, anon, authenticated;
revoke all on function app_private.remaining_service_window(timestamptz,timestamptz,timestamptz)
  from public, anon, authenticated;

create or replace function app_private.valid_timing_buffers(p_buffers jsonb)
returns boolean language plpgsql immutable set search_path = ''
as $$
declare v record; v_value numeric;
begin
  if p_buffers is null or jsonb_typeof(p_buffers) is distinct from 'object' then return false; end if;
  if p_buffers - array['preparation_minutes','cleanup_minutes','inbound_travel_minutes','outbound_travel_minutes']
    <> '{}'::jsonb then return false; end if;
  for v in select * from (values ('preparation_minutes',120),('cleanup_minutes',120),
    ('inbound_travel_minutes',180),('outbound_travel_minutes',180)) as bounds(name,maximum)
  loop
    if jsonb_typeof(p_buffers->v.name) is distinct from 'number' then return false; end if;
    v_value := (p_buffers->>v.name)::numeric;
    if v_value < 0 or v_value > v.maximum or v_value <> trunc(v_value) then return false; end if;
  end loop;
  return true;
end $$;
revoke all on function app_private.valid_timing_buffers(jsonb) from public, anon, authenticated;

alter table public.groomer_booking_preferences add column timing_buffers jsonb;
alter table public.groomer_booking_preferences add constraint groomer_booking_preferences_timing_buffers_check
  check (timing_buffers is null or app_private.valid_timing_buffers(timing_buffers));

create or replace function app_private.get_groomer_availability()
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_payload jsonb;
begin
  if v_user_id is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists (select 1 from public.profiles p join public.groomer_profiles g on g.user_id=p.id
      where p.id=v_user_id and p.role='groomer'::public.user_role) then
    raise exception using errcode='42501', message='groomer_profile_required';
  end if;
  select jsonb_build_object(
    'timing_version',1,
    'windows',coalesce((select jsonb_agg(to_jsonb(w) order by w.weekday)
      from public.groomer_availability_windows w where w.groomer_id=v_user_id),'[]'::jsonb),
    'preferences',coalesce((select to_jsonb(p) from public.groomer_booking_preferences p
      where p.groomer_id=v_user_id),jsonb_build_object('groomer_id',v_user_id,
        'max_appointments_per_day',4,'minimum_advance_notice_days',0,'auto_accept_bookings',false,'timing_buffers',null)),
    'time_off',coalesce((select jsonb_agg(to_jsonb(t) order by t.start_date,t.id)
      from public.groomer_time_off_windows t where t.groomer_id=v_user_id),'[]'::jsonb)
  ) into v_payload;
  return v_payload || jsonb_build_object('revision',md5(v_payload::text));
end $$;

create or replace function app_private.save_groomer_availability(
  p_expected_revision text,p_windows jsonb,p_preferences jsonb,p_time_off jsonb
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_snapshot jsonb;
  v_buffers jsonb;
  v_previous_batch text := current_setting('app.availability_batch',true);
begin
  if v_user_id is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='42501', message='authenticated_user_required';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user_id::text,71071));
  v_snapshot := app_private.get_groomer_availability();
  if p_expected_revision is null or p_expected_revision <> v_snapshot->>'revision' then
    raise exception using errcode='40001', message='availability_revision_conflict';
  end if;
  if jsonb_typeof(p_windows) is distinct from 'array'
    or jsonb_typeof(p_preferences) is distinct from 'object'
    or jsonb_typeof(p_time_off) is distinct from 'array' then
    raise exception using errcode='22023', message='invalid_availability_payload';
  end if;
  if jsonb_array_length(p_time_off) <> (select count(distinct t.id)
    from jsonb_to_recordset(p_time_off) as t(id uuid)) then
    raise exception using errcode='22023',message='invalid_time_off_entries';
  end if;
  if jsonb_array_length(p_windows) <> 7
    or (select count(distinct w.weekday) from jsonb_to_recordset(p_windows) as w(weekday integer)) <> 7
    or (select count(distinct w.timezone) from jsonb_to_recordset(p_windows) as w(timezone text)) <> 1
    or exists (select 1 from jsonb_to_recordset(p_windows) as w(timezone text)
      where not exists (select 1 from pg_catalog.pg_timezone_names n where n.name=w.timezone)) then
    raise exception using errcode='22023', message='invalid_availability_windows';
  end if;
  if p_preferences ? 'timing_buffers' then
    v_buffers := p_preferences->'timing_buffers';
    if not app_private.valid_timing_buffers(v_buffers) then
      raise exception using errcode='22023', message='invalid_timing_buffers';
    end if;
  else
    -- Older clients may save other settings, but cannot erase confirmed buffers.
    v_buffers := nullif(v_snapshot#>'{preferences,timing_buffers}','null'::jsonb);
  end if;

  perform set_config('app.availability_batch','1',true);
  insert into public.groomer_availability_windows(groomer_id,weekday,start_time,end_time,is_enabled,timezone)
    select v_user_id,w.weekday,w.start_time,w.end_time,w.is_enabled,w.timezone
    from jsonb_to_recordset(p_windows) as w(weekday smallint,start_time time,end_time time,is_enabled boolean,timezone text)
    on conflict(groomer_id,weekday) do update set start_time=excluded.start_time,end_time=excluded.end_time,
      is_enabled=excluded.is_enabled,timezone=excluded.timezone
    where row(groomer_availability_windows.start_time,groomer_availability_windows.end_time,
      groomer_availability_windows.is_enabled,groomer_availability_windows.timezone)
      is distinct from row(excluded.start_time,excluded.end_time,excluded.is_enabled,excluded.timezone);
  insert into public.groomer_booking_preferences(groomer_id,max_appointments_per_day,
    minimum_advance_notice_days,auto_accept_bookings,timing_buffers)
    values(v_user_id,(p_preferences->>'max_appointments_per_day')::smallint,
      (p_preferences->>'minimum_advance_notice_days')::smallint,(p_preferences->>'auto_accept_bookings')::boolean,v_buffers)
    on conflict(groomer_id) do update set
      max_appointments_per_day=excluded.max_appointments_per_day,
      minimum_advance_notice_days=excluded.minimum_advance_notice_days,
      auto_accept_bookings=excluded.auto_accept_bookings,
      timing_buffers=excluded.timing_buffers;
  delete from public.groomer_time_off_windows existing where existing.groomer_id=v_user_id
    and not exists(select 1 from jsonb_to_recordset(p_time_off) as t(id uuid) where t.id=existing.id);
  update public.groomer_time_off_windows existing
    set title=t.title,start_date=t.start_date,end_date=t.end_date
    from jsonb_to_recordset(p_time_off) as t(id uuid,title text,start_date date,end_date date)
    where existing.groomer_id=v_user_id and existing.id=t.id
      and row(existing.title,existing.start_date,existing.end_date)
        is distinct from row(t.title,t.start_date,t.end_date);
  insert into public.groomer_time_off_windows(id,groomer_id,title,start_date,end_date)
    select t.id,v_user_id,t.title,t.start_date,t.end_date
    from jsonb_to_recordset(p_time_off) as t(id uuid,title text,start_date date,end_date date)
    where not exists(select 1 from public.groomer_time_off_windows existing
      where existing.groomer_id=v_user_id and existing.id=t.id);
  perform app_private.validate_booked_coverage(v_user_id);
  perform set_config('app.availability_batch',coalesce(v_previous_batch,''),true);
  perform app_private.backfill_request_matches_for_groomer(v_user_id,250);
  return app_private.get_groomer_availability();
end $$;
-- Existing authenticated grants and the public PT409 conflict wrapper are preserved by replacement.

alter table app_private.address_locations add column time_zone_identifier text;

create function app_private.guard_address_time_zone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Versioned writers first save the location, then attach its newly resolved zone
  -- in the same transaction. Old writers must never retain prior zone evidence.
  if tg_op = 'UPDATE' then
    if row(new.owner_id,new.provider,new.place_id,new.country_code,new.latitude,new.longitude,
           new.resolution_source,new.user_confirmed_at)
       is distinct from
       row(old.owner_id,old.provider,old.place_id,old.country_code,old.latitude,old.longitude,
           old.resolution_source,old.user_confirmed_at) then
      new.time_zone_identifier := null;
    end if;
  end if;
  if new.time_zone_identifier is not null and not exists (
    select 1 from pg_catalog.pg_timezone_names where name=new.time_zone_identifier
  ) then
    raise exception using errcode='22023',message='invalid_location_time_zone';
  end if;
  return new;
end $$;
revoke all on function app_private.guard_address_time_zone() from public,anon,authenticated;
create trigger address_locations_guard_time_zone
before insert or update on app_private.address_locations
for each row execute function app_private.guard_address_time_zone();

create function app_private.save_my_profile_address_v3(p_address jsonb)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_role public.user_role;
  v_location uuid;
  v_zone text := p_address->>'time_zone_identifier';
begin
  if v_user is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  select role into v_role from public.profiles where id=v_user;
  if v_role is null or v_role::text not in ('customer','groomer') then
    raise exception using errcode='42501',message='profile_required';
  end if;
  if jsonb_typeof(p_address) is distinct from 'object' or v_zone is null
     or not exists (select 1 from pg_catalog.pg_timezone_names where name=v_zone) then
    raise exception using errcode='22023',message='confirmed_location_time_zone_required';
  end if;
  -- Existing role-specific writers retain their ownership, row lock and address validation.
  if v_role='customer'::public.user_role then
    v_location := app_private.save_customer_profile_address_v2(
      p_address->>'line_1',p_address->>'line_2',p_address->>'city',p_address->>'state',
      p_address->>'zip_code',p_address->>'provider',p_address->>'place_id',p_address->>'country_code',
      (p_address->>'latitude')::double precision,(p_address->>'longitude')::double precision,
      p_address->>'resolution_source',(p_address->>'user_confirmed_at')::timestamptz);
  else
    v_location := app_private.save_groomer_profile_address_v2(
      p_address->>'line_1',p_address->>'line_2',p_address->>'city',p_address->>'state',
      p_address->>'zip_code',p_address->>'provider',p_address->>'place_id',p_address->>'country_code',
      (p_address->>'latitude')::double precision,(p_address->>'longitude')::double precision,
      p_address->>'resolution_source',(p_address->>'user_confirmed_at')::timestamptz);
  end if;
  update app_private.address_locations set time_zone_identifier=v_zone
    where id=v_location and owner_id=v_user;
  if not found then
    raise exception using errcode='42501',message='owned_address_required';
  end if;
  return v_location;
end $$;

create function app_private.get_my_profile_address_v3()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_role public.user_role;
  v_address jsonb;
  v_zone text;
begin
  if v_user is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  select role into v_role from public.profiles where id=v_user;
  if v_role='customer'::public.user_role then
    select to_jsonb(a) into v_address from app_private.get_my_customer_profile_address_v2() a;
    select a.time_zone_identifier into v_zone from public.customer_profiles p
      join app_private.address_locations a on a.id=p.address_location_id and a.owner_id=p.user_id
      where p.user_id=v_user;
  elsif v_role='groomer'::public.user_role then
    select to_jsonb(a) into v_address from app_private.get_my_groomer_profile_address_v2() a;
    select a.time_zone_identifier into v_zone from public.groomer_profiles p
      join app_private.address_locations a on a.id=p.address_location_id and a.owner_id=p.user_id
      where p.user_id=v_user;
  else
    raise exception using errcode='42501',message='profile_required';
  end if;
  return jsonb_build_object('timing_version',1,'address',
    case when v_address is null then null else
      v_address || jsonb_build_object('time_zone_identifier',v_zone) end);
end $$;

create function public.save_my_profile_address_v3(p_address jsonb)
returns uuid language sql security invoker set search_path = ''
as $$ select app_private.save_my_profile_address_v3(p_address); $$;
create function public.get_my_profile_address_v3()
returns jsonb language sql stable security invoker set search_path = ''
as $$ select app_private.get_my_profile_address_v3(); $$;

revoke all on function app_private.save_my_profile_address_v3(jsonb),
  app_private.get_my_profile_address_v3(),public.save_my_profile_address_v3(jsonb),
  public.get_my_profile_address_v3() from public,anon,authenticated;
grant execute on function app_private.save_my_profile_address_v3(jsonb),
  app_private.get_my_profile_address_v3(),public.save_my_profile_address_v3(jsonb),
  public.get_my_profile_address_v3() to authenticated;

alter table public.grooming_requests add column preference_time_zone_identifier text;

create function app_private.create_grooming_request_v4(
  p_publish_operation_id uuid,p_request jsonb,p_preference_time_zone_identifier text
)
returns table(request_id uuid,match_count integer)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_request uuid;
  v_count integer;
begin
  if v_user is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_publish_operation_id is null then
    raise exception using errcode='22023',message='invalid_publish_operation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_user::text || ':' || p_publish_operation_id::text,0));
  select o.request_id,o.match_count into v_request,v_count
    from app_private.request_publish_operations o
    where o.customer_id=v_user and o.operation_id=p_publish_operation_id;
  if found then
    return query select v_request,v_count;
    return;
  end if;
  if jsonb_typeof(p_request) is distinct from 'object'
     or p_preference_time_zone_identifier is null or not exists (
       select 1 from pg_catalog.pg_timezone_names where name=p_preference_time_zone_identifier
     ) then
    raise exception using errcode='22023',message='request_reference_time_zone_required';
  end if;
  select r.request_id,r.match_count into strict v_request,v_count
    from app_private.create_grooming_request_v3(p_publish_operation_id,
      (p_request->>'pet_id')::uuid,p_request->>'service_type',p_request->>'service_notes',
      (p_request->>'preferred_start')::timestamptz,(p_request->>'preferred_end')::timestamptz,
      p_request->>'location_mode',p_request->>'street_address',p_request->>'city',
      p_request->>'state',p_request->>'zip_code',p_request->>'address_line_2',
      p_request->>'provider',p_request->>'place_id',p_request->>'country_code',
      (p_request->>'latitude')::double precision,(p_request->>'longitude')::double precision,
      p_request->>'resolution_source',(p_request->>'user_confirmed_at')::timestamptz,
      (p_request->>'travel_radius_miles')::integer) r;
  update public.grooming_requests set preference_time_zone_identifier=p_preference_time_zone_identifier
    where id=v_request and customer_id=v_user;
  return query select v_request,v_count;
end $$;

create function public.create_grooming_request_v4(
  p_publish_operation_id uuid,p_request jsonb,p_preference_time_zone_identifier text
)
returns table(request_id uuid,match_count integer)
language sql security invoker set search_path = ''
as $$ select * from app_private.create_grooming_request_v4(
  p_publish_operation_id,p_request,p_preference_time_zone_identifier); $$;
revoke all on function app_private.create_grooming_request_v4(uuid,jsonb,text),
  public.create_grooming_request_v4(uuid,jsonb,text) from public,anon,authenticated;
grant execute on function app_private.create_grooming_request_v4(uuid,jsonb,text),
  public.create_grooming_request_v4(uuid,jsonb,text) to authenticated;

create function app_private.guard_request_timing_intent()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op='UPDATE' then
    if row(new.preferred_start,new.preferred_end,new.location_mode)
       is distinct from row(old.preferred_start,old.preferred_end,old.location_mode)
       or (old.preference_time_zone_identifier is not null and
           new.preference_time_zone_identifier is distinct from old.preference_time_zone_identifier) then
      raise exception using errcode='23514',message='published_request_timing_is_immutable';
    end if;
  end if;
  if new.preference_time_zone_identifier is not null and not exists (
    select 1 from pg_catalog.pg_timezone_names where name=new.preference_time_zone_identifier
  ) then
    raise exception using errcode='23514',message='invalid_request_reference_time_zone';
  end if;
  return new;
end $$;
revoke all on function app_private.guard_request_timing_intent() from public,anon,authenticated;
create trigger grooming_requests_guard_timing_intent
before insert or update on public.grooming_requests
for each row execute function app_private.guard_request_timing_intent();

create or replace function app_private.guard_offer_timing_consent()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_start timestamptz;
  v_end timestamptz;
  v_seconds numeric;
begin
  -- Historical status transitions do not renegotiate service times.
  if tg_op='UPDATE' then
    if row(new.request_id,new.customer_id,new.proposed_start,new.proposed_end)
       is not distinct from row(old.request_id,old.customer_id,old.proposed_start,old.proposed_end) then
      return new;
    end if;
  end if;
  if new.proposed_start is null or new.proposed_end is null
    or not pg_catalog.isfinite(new.proposed_start) or not pg_catalog.isfinite(new.proposed_end) then
    raise exception using errcode='22023',message='invalid_proposed_range';
  end if;
  v_seconds := extract(epoch from new.proposed_end-new.proposed_start);
  if v_seconds < 900 or v_seconds > 43200 or mod(v_seconds,60) <> 0 then
    raise exception using errcode='22023',message='invalid_service_duration';
  end if;
  select preferred_start,preferred_end into v_start,v_end
    from public.grooming_requests where id=new.request_id and customer_id=new.customer_id;
  if not found or new.proposed_start < v_start or new.proposed_end > v_end then
    raise exception using errcode='22023',message='offer_outside_customer_window';
  end if;
  return new;
end $$;
revoke all on function app_private.guard_offer_timing_consent() from public,anon,authenticated;
create trigger groomer_offers_guard_timing_consent
before insert or update on public.groomer_offers
for each row execute function app_private.guard_offer_timing_consent();

alter table public.groomer_offers
  add column applied_timing_buffers jsonb,
  add column service_time_zone_identifier text,
  add column schedule_time_zone_identifier text,
  add column occupied_start timestamptz,
  add column occupied_end timestamptz;

create or replace function app_private.weekly_hours_cover_interval(
  p_start timestamptz,p_end timestamptz,v_zone text,v_starts time[],v_ends time[]
)
returns boolean language plpgsql stable set search_path = ''
as $$
begin
  if p_start is null or p_end is null or not pg_catalog.isfinite(p_start)
    or not pg_catalog.isfinite(p_end) or p_start>=p_end then
    raise exception using errcode='22023',message='invalid_occupied_range';
  end if;
  -- TZif transitions occur on integer UTC seconds (RFC 8536 section 2).
  -- Each segment is affine in local time; check its entire fractional interval,
  -- not a sampled point. Repeated clock ranges can contain a real closed gap.
  return not exists(
    with segments as (
      select greatest(t,p_start) as starts,least(t+interval '1 second',p_end) as ends
      from pg_catalog.generate_series(pg_catalog.date_trunc('second',p_start),
        p_end,interval '1 second') t where t<p_end
    ), wall as materialized (
      select pg_catalog.timezone(v_zone,starts) as starts,ends-starts as elapsed from segments
    ), days as (
      -- Each date has one opening interval: containing every segment is equivalent
      -- to containing their local minimum start and maximum exclusive end.
      select starts::date as local_date,min(starts) as starts,max(starts+elapsed) as ends
      from wall group by starts::date
    )
    select 1 from days d
    where v_starts[extract(isodow from d.local_date)::integer] is null
      or d.starts<d.local_date+v_starts[extract(isodow from d.local_date)::integer]
      or d.ends>d.local_date+v_ends[extract(isodow from d.local_date)::integer]
  );
end $$;
revoke all on function app_private.weekly_hours_cover_interval(timestamptz,timestamptz,text,time[],time[])
  from public,anon,authenticated,service_role;

create or replace function app_private.occupied_weekly_hours_covered(
  p_groomer_id uuid,p_start timestamptz,p_end timestamptz
)
returns boolean language plpgsql stable set search_path = ''
as $$
declare v_zone text; v_zone_count integer; v_window_count integer; v_starts time[]; v_ends time[];
begin
  if p_start is null or p_end is null or not pg_catalog.isfinite(p_start)
    or not pg_catalog.isfinite(p_end) or p_start>=p_end then
    raise exception using errcode='22023',message='invalid_occupied_range';
  end if;
  select min(timezone),count(distinct timezone),count(*),
    array_agg(case when is_enabled then start_time end order by weekday),
    array_agg(case when is_enabled then end_time end order by weekday)
    into v_zone,v_zone_count,v_window_count,v_starts,v_ends
    from public.groomer_availability_windows where groomer_id=p_groomer_id;
  if v_zone_count<>1 or v_window_count<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=v_zone
  ) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required';
  end if;
  return app_private.weekly_hours_cover_interval(p_start,p_end,v_zone,v_starts,v_ends);
end $$;
revoke all on function app_private.occupied_weekly_hours_covered(uuid,timestamptz,timestamptz)
  from public,anon,authenticated;

create or replace function app_private.occupied_time_off_conflict(
  p_groomer_id uuid,p_start timestamptz,p_end timestamptz
)
returns boolean language plpgsql stable set search_path = ''
as $$
declare v_zone text; v_zone_count integer; v_window_count integer;
begin
  if p_start is null or p_end is null or not pg_catalog.isfinite(p_start)
    or not pg_catalog.isfinite(p_end) or p_start>=p_end then
    raise exception using errcode='22023',message='invalid_occupied_range';
  end if;
  select min(timezone),count(distinct timezone),count(*) into v_zone,v_zone_count,v_window_count
    from public.groomer_availability_windows where groomer_id=p_groomer_id;
  if v_zone_count<>1 or v_window_count<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=v_zone
  ) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required';
  end if;
  return exists(select 1 from public.groomer_time_off_windows t where t.groomer_id=p_groomer_id
    and tstzrange(pg_catalog.timezone(v_zone,t.start_date::timestamp),
      pg_catalog.timezone(v_zone,(t.end_date+1)::timestamp),'[)') && tstzrange(p_start,p_end,'[)'));
end $$;
revoke all on function app_private.occupied_time_off_conflict(uuid,timestamptz,timestamptz)
  from public,anon,authenticated;

create or replace function app_private.snapshot_offer_timing()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_request public.grooming_requests%rowtype;
  v_buffers jsonb;
  v_zone text;
  v_schedule_zone text;
  v_zone_count integer;
  v_window_count integer;
  v_allocation record;
begin
  if tg_op='UPDATE' then
    if row(new.request_id,new.customer_id,new.groomer_id,new.proposed_start,new.proposed_end,
      new.applied_timing_buffers,new.service_time_zone_identifier,new.schedule_time_zone_identifier,
      new.occupied_start,new.occupied_end) is distinct from
      row(old.request_id,old.customer_id,old.groomer_id,old.proposed_start,old.proposed_end,
      old.applied_timing_buffers,old.service_time_zone_identifier,old.schedule_time_zone_identifier,
      old.occupied_start,old.occupied_end) then
      raise exception using errcode='23514',message='offer_timing_snapshot_immutable';
    end if;
    return new;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.groomer_id::text,71071));
  select * into strict v_request from public.grooming_requests
    where id=new.request_id and customer_id=new.customer_id;
  select timing_buffers into v_buffers from public.groomer_booking_preferences where groomer_id=new.groomer_id;
  if not app_private.valid_timing_buffers(v_buffers) then
    raise exception using errcode='22023',message='timing_buffers_confirmation_required';
  end if;
  select min(timezone),count(distinct timezone),count(*) into v_schedule_zone,v_zone_count,v_window_count
    from public.groomer_availability_windows where groomer_id=new.groomer_id;
  if v_zone_count <> 1 or v_window_count <> 7 or not exists (
    select 1 from pg_catalog.pg_timezone_names where name=v_schedule_zone
  ) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required';
  end if;
  if v_request.location_mode='groomer_comes_to_customer' then
    v_zone := v_request.preference_time_zone_identifier;
  else
    select a.time_zone_identifier into v_zone from public.groomer_profiles g
      join app_private.address_locations a on a.id=g.address_location_id and a.owner_id=g.user_id
      where g.user_id=new.groomer_id;
  end if;
  if v_zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=v_zone) then
    raise exception using errcode='22023',message='service_timezone_confirmation_required';
  end if;
  if new.proposed_end > pg_catalog.timezone(v_zone,
      (pg_catalog.timezone(v_zone,new.proposed_start)::date+1)::timestamp) then
    raise exception using errcode='22023',message='service_crosses_local_day';
  end if;
  select * into strict v_allocation from app_private.service_timing_allocation(new.proposed_start,
    (extract(epoch from new.proposed_end-new.proposed_start)/60)::integer,
    (v_buffers->>'preparation_minutes')::integer,(v_buffers->>'cleanup_minutes')::integer,
    (v_buffers->>'inbound_travel_minutes')::integer,(v_buffers->>'outbound_travel_minutes')::integer,
    v_request.location_mode);
  new.applied_timing_buffers := v_buffers;
  new.service_time_zone_identifier := v_zone;
  new.schedule_time_zone_identifier := v_schedule_zone;
  new.occupied_start := v_allocation.occupied_start;
  new.occupied_end := v_allocation.occupied_end;
  if exists(select 1 from public.bookings b where b.groomer_id=new.groomer_id
      and b.status in ('confirmed','completed')
      and coalesce(b.occupied_start,b.scheduled_start)<new.occupied_end
      and new.occupied_start<coalesce(b.occupied_end,b.scheduled_end)) then
    raise exception using errcode='P0001',message='groomer_unavailable';
  end if;
  if app_private.occupied_time_off_conflict(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_time_off_conflict';
  end if;
  if not app_private.occupied_weekly_hours_covered(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_outside_weekly_hours';
  end if;
  return new;
end $$;
revoke all on function app_private.snapshot_offer_timing() from public,anon,authenticated;
create trigger groomer_offers_snapshot_timing
before insert or update on public.groomer_offers
for each row execute function app_private.snapshot_offer_timing();

alter table public.bookings
  add column applied_timing_buffers jsonb,
  add column service_time_zone_identifier text,
  add column schedule_time_zone_identifier text,
  add column occupied_start timestamptz,
  add column occupied_end timestamptz;

create or replace function app_private.snapshot_booking_timing()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_offer public.groomer_offers%rowtype;
begin
  if tg_op='UPDATE' then
    if row(new.applied_timing_buffers,new.service_time_zone_identifier,new.schedule_time_zone_identifier,
        new.occupied_start,new.occupied_end) is distinct from
       row(old.applied_timing_buffers,old.service_time_zone_identifier,old.schedule_time_zone_identifier,
        old.occupied_start,old.occupied_end) then
      raise exception using errcode='23514',message='booking_timing_snapshot_immutable';
    end if;
    return new;
  end if;
  select * into v_offer from public.groomer_offers where id=new.offer_id and request_id=new.request_id
    and customer_id=new.customer_id and groomer_id=new.groomer_id;
  if not found or new.scheduled_start is distinct from v_offer.proposed_start
    or new.scheduled_end is distinct from v_offer.proposed_end then
    raise exception using errcode='23514',message='booking_offer_timing_mismatch';
  end if;
  if v_offer.occupied_start is null or v_offer.occupied_end is null
    or v_offer.service_time_zone_identifier is null or v_offer.schedule_time_zone_identifier is null
    or not app_private.valid_timing_buffers(v_offer.applied_timing_buffers) then
    raise exception using errcode='P0001',message='updated_timing_offer_required';
  end if;
  new.applied_timing_buffers := v_offer.applied_timing_buffers;
  new.service_time_zone_identifier := v_offer.service_time_zone_identifier;
  new.schedule_time_zone_identifier := v_offer.schedule_time_zone_identifier;
  new.occupied_start := v_offer.occupied_start;
  new.occupied_end := v_offer.occupied_end;
  if app_private.occupied_time_off_conflict(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_time_off_conflict';
  end if;
  if not app_private.occupied_weekly_hours_covered(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_outside_weekly_hours';
  end if;
  return new;
end $$;
revoke all on function app_private.snapshot_booking_timing() from public,anon,authenticated;
create trigger bookings_snapshot_timing
before insert or update on public.bookings
for each row execute function app_private.snapshot_booking_timing();

-- Unknown legacy buffers retain at least the original service allocation.
alter table public.bookings add constraint bookings_no_groomer_occupied_overlap
  exclude using gist (groomer_id with =,
    tstzrange(coalesce(occupied_start,scheduled_start),coalesce(occupied_end,scheduled_end),'[)') with &&)
  where (status in ('confirmed','completed'));

create or replace function app_private.validate_booked_coverage(p_groomer_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_zone text; v_zone_count integer; v_window_count integer; v_starts time[]; v_ends time[];
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_groomer_id::text,71071));
  if not exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed')
      and coalesce(b.occupied_end,b.scheduled_end)>statement_timestamp()) then return; end if;
  -- Validate the shared schedule once, not once per future booking.
  select min(timezone),count(distinct timezone),count(*),
    array_agg(case when is_enabled then start_time end order by weekday),
    array_agg(case when is_enabled then end_time end order by weekday)
    into v_zone,v_zone_count,v_window_count,v_starts,v_ends
    from public.groomer_availability_windows where groomer_id=p_groomer_id;
  if v_zone_count<>1 or v_window_count<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=v_zone
  ) then
    raise exception using errcode='22023',message='schedule_timezone_confirmation_required';
  end if;
  if exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed')
      and coalesce(b.occupied_end,b.scheduled_end)>statement_timestamp()
      and exists(select 1 from public.groomer_time_off_windows t where t.groomer_id=p_groomer_id
        and tstzrange(pg_catalog.timezone(v_zone,t.start_date::timestamp),
          pg_catalog.timezone(v_zone,(t.end_date+1)::timestamp),'[)')
          && tstzrange(coalesce(b.occupied_start,b.scheduled_start),
            coalesce(b.occupied_end,b.scheduled_end),'[)'))) then
    raise exception using errcode='22023',message='time_off_conflicts_with_booking_occupancy';
  end if;
  if exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed')
      and coalesce(b.occupied_end,b.scheduled_end)>statement_timestamp()
      and not app_private.weekly_hours_cover_interval(
        coalesce(b.occupied_start,b.scheduled_start),coalesce(b.occupied_end,b.scheduled_end),
        v_zone,v_starts,v_ends)) then
    raise exception using errcode='22023',message='weekly_hours_conflict_with_booking_occupancy';
  end if;
end $$;
revoke all on function app_private.validate_booked_coverage(uuid) from public,anon,authenticated,service_role;

create or replace function app_private.guard_changed_booked_coverage()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_old uuid; v_new uuid; v_owner uuid;
begin
  if tg_op<>'INSERT' then v_old := old.groomer_id; end if;
  if tg_op<>'DELETE' then v_new := new.groomer_id; end if;
  for v_owner in select distinct id from unnest(array[v_old,v_new]) id where id is not null order by id loop
    perform app_private.validate_booked_coverage(v_owner);
  end loop;
  return null;
end $$;
revoke all on function app_private.guard_changed_booked_coverage() from public,anon,authenticated,service_role;
create constraint trigger groomer_weekly_hours_preserve_booking_coverage
after insert or update or delete on public.groomer_availability_windows
deferrable initially deferred for each row execute function app_private.guard_changed_booked_coverage();
create constraint trigger groomer_time_off_preserve_booking_coverage
after insert or update or delete on public.groomer_time_off_windows
deferrable initially deferred for each row execute function app_private.guard_changed_booked_coverage();

create or replace function app_private.groomer_can_admit_service(
  p_groomer_id uuid,p_start timestamptz,p_end timestamptz,p_now timestamptz default statement_timestamp()
)
returns boolean language plpgsql stable set search_path = ''
as $$
declare v_zone text; v_zones integer; v_windows integer; v_limit integer; v_notice integer;
begin
  if p_start is null or p_end is null or p_now is null
    or not pg_catalog.isfinite(p_start) or not pg_catalog.isfinite(p_end)
    or not pg_catalog.isfinite(p_now) or p_start>=p_end then return false; end if;
  select min(timezone),count(distinct timezone),count(*) into v_zone,v_zones,v_windows
    from public.groomer_availability_windows where groomer_id=p_groomer_id;
  if v_zones<>1 or v_windows<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=v_zone
  ) then return false; end if;
  select coalesce(p.max_appointments_per_day,4),coalesce(p.minimum_advance_notice_days,0)
    into v_limit,v_notice from public.groomer_profiles g
    left join public.groomer_booking_preferences p on p.groomer_id=g.user_id where g.user_id=p_groomer_id;
  if not found or p_start<app_private.service_timing_earliest_start(p_now,v_notice,v_zone) then
    return false;
  end if;
  return not exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed') and coalesce(b.occupied_start,b.scheduled_start)<p_end
      and p_start<coalesce(b.occupied_end,b.scheduled_end))
    and (select count(*) from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed')
      and pg_catalog.timezone(v_zone,b.scheduled_start)::date=pg_catalog.timezone(v_zone,p_start)::date)<v_limit;
end $$;
revoke all on function app_private.groomer_can_admit_service(uuid,timestamptz,timestamptz,timestamptz)
  from public,anon,authenticated,service_role;

-- Preserve the deployed authorization, parent locks, receipts and state transitions.
CREATE OR REPLACE FUNCTION app_private.create_groomer_offer(p_request_id uuid, p_proposed_start timestamp with time zone, p_proposed_end timestamp with time zone, p_price_estimate numeric, p_message text DEFAULT NULL::text)
 RETURNS TABLE(offer_id uuid, offer_status text, request_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_message text := nullif(
    regexp_replace(coalesce(p_message, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g'),
    ''
  );
  v_match_id uuid;
  v_match_status text;
  v_customer_id uuid;
  v_request_status text;
  v_request_expires_at timestamptz;
  v_offer_id uuid;
  v_offer_status text;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  perform 1
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile
    on profile.id = groomer_profile.user_id
  where groomer_profile.user_id = v_user_id
    and profile.role = 'groomer'::public.user_role;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_profile_required';
  end if;

  if p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_request';
  end if;

  if p_proposed_start is null
    or p_proposed_end is null
    or p_proposed_start <= statement_timestamp()
    or p_proposed_end <= p_proposed_start
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_proposed_range';
  end if;

  if p_price_estimate is null
    or p_price_estimate < 0
    or p_price_estimate > 100000
    or p_price_estimate <> round(p_price_estimate, 2)
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_price_estimate';
  end if;

  if v_message is not null
    and char_length(v_message) > 2000
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_message';
  end if;

  perform 1 from public.grooming_requests as parent_request
  where parent_request.id = p_request_id and exists (
      select 1 from public.request_matches m
      where m.request_id=parent_request.id and m.groomer_id=v_user_id
    )
  for update of parent_request;
  if not found then
    raise exception using errcode='P0001', message='match_not_found';
  end if;

  select
    request_match.id,
    request_match.status,
    request_match.customer_id,
    grooming_request.status,
    grooming_request.expires_at
  into
    v_match_id,
    v_match_status,
    v_customer_id,
    v_request_status,
    v_request_expires_at
  from public.request_matches as request_match
  join public.grooming_requests as grooming_request
    on grooming_request.id = request_match.request_id
   and grooming_request.customer_id = request_match.customer_id
  where request_match.request_id = p_request_id
    and request_match.groomer_id = v_user_id
  for update of request_match, grooming_request;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_found';
  end if;

  if v_match_status not in ('visible', 'viewed') then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_offerable';
  end if;

  if v_request_status not in ('open', 'has_offers')
    or v_request_expires_at <= statement_timestamp()
  then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_open';
  end if;

  if exists (
    select 1
    from public.groomer_offers as existing_offer
    where existing_offer.request_id = p_request_id
      and existing_offer.groomer_id = v_user_id
      and existing_offer.status = 'pending'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'active_offer_exists';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 71071)
  );

  if not app_private.groomer_can_admit_service(
    v_user_id,
    p_proposed_start,
    p_proposed_end
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_unavailable';
  end if;

  insert into public.groomer_offers (
    request_id,
    match_id,
    customer_id,
    groomer_id,
    proposed_start,
    proposed_end,
    price_estimate,
    message,
    status,
    expires_at
  )
  values (
    p_request_id,
    v_match_id,
    v_customer_id,
    v_user_id,
    p_proposed_start,
    p_proposed_end,
    p_price_estimate,
    v_message,
    'pending',
    v_request_expires_at
  )
  returning id, status
  into v_offer_id, v_offer_status;

  update public.request_matches as request_match
  set
    status = 'offered',
    viewed_at = coalesce(request_match.viewed_at, statement_timestamp())
  where request_match.id = v_match_id;

  update public.grooming_requests as grooming_request
  set status = 'has_offers'
  where grooming_request.id = p_request_id
    and grooming_request.status = 'open'
  returning grooming_request.status
  into v_request_status;

  if v_request_status is null then
    v_request_status := 'has_offers';
  end if;

  return query
  select v_offer_id, v_offer_status, v_request_status;
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.guard_booking_admission()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_pet_id uuid;
begin
  if tg_op = 'UPDATE' then
    if (new.request_id, new.offer_id, new.customer_id, new.groomer_id,
        new.pet_id, new.scheduled_start, new.scheduled_end)
      is distinct from
       (old.request_id, old.offer_id, old.customer_id, old.groomer_id,
        old.pet_id, old.scheduled_start, old.scheduled_end) then
      raise exception using errcode = 'P0001', message = 'booking_allocation_immutable';
    end if;
    -- Cancellation/completion preserve the original allocation and receipt.
    if new.status <> 'confirmed' or old.status = 'confirmed' then
      return new;
    end if;
    raise exception using errcode = 'P0001', message = 'booking_not_reactivatable';
  end if;

  select request.pet_id into v_pet_id
  from public.grooming_requests as request
  where request.id = new.request_id and request.customer_id = new.customer_id;
  if v_pet_id is null or (new.pet_id is not null and new.pet_id <> v_pet_id) then
    raise exception using errcode = 'P0001', message = 'booking_pet_identity_required';
  end if;
  new.pet_id := v_pet_id;
  if new.status <> 'confirmed' then
    raise exception using errcode = 'P0001', message = 'booking_must_start_confirmed';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.groomer_id::text, 71071)
  );
  if not app_private.groomer_can_admit_service(
    new.groomer_id, new.scheduled_start, new.scheduled_end
  ) then
    raise exception using errcode = 'P0001', message = 'booking_conflict';
  end if;
  return new;
end;
$function$;
