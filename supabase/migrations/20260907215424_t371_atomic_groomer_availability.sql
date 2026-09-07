-- One owned snapshot and one write boundary; old clients must not fall back to
-- DELETE/INSERT saves. Deploy only with the compatible client and validation.
begin;
create function app_private.get_groomer_availability()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_payload jsonb;
begin
  if v_user_id is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean, false)
    or not exists (select 1 from public.profiles p join public.groomer_profiles g on g.user_id = p.id
      where p.id = v_user_id and p.role = 'groomer'::public.user_role) then
    raise exception using errcode = '42501', message = 'groomer_profile_required';
  end if;

  select jsonb_build_object(
    'windows', coalesce((select jsonb_agg(to_jsonb(w) order by w.weekday)
      from public.groomer_availability_windows w where w.groomer_id = v_user_id), '[]'::jsonb),
    'preferences', coalesce((select to_jsonb(p) from public.groomer_booking_preferences p
      where p.groomer_id = v_user_id), jsonb_build_object('groomer_id', v_user_id,
        'max_appointments_per_day', 4, 'minimum_advance_notice_days', 0, 'auto_accept_bookings', false)),
    'time_off', coalesce((select jsonb_agg(to_jsonb(t) order by t.start_date, t.id)
      from public.groomer_time_off_windows t where t.groomer_id = v_user_id), '[]'::jsonb)
  ) into v_payload;
  -- Includes row identities and timestamps, not just the displayed hours.
  return v_payload || jsonb_build_object('revision', md5(v_payload::text));
end;
$$;

create or replace function app_private.backfill_matches_after_groomer_availability_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_groomer_id uuid;
begin
  if tg_op = 'DELETE' then v_groomer_id := old.groomer_id;
  else v_groomer_id := new.groomer_id; end if;
  if current_setting('app.availability_batch', true) is distinct from '1' then
    perform app_private.backfill_request_matches_for_groomer(v_groomer_id, 250);
  end if;
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;

create function app_private.save_groomer_availability(
  p_expected_revision text, p_windows jsonb, p_preferences jsonb, p_time_off jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_snapshot jsonb;
  v_previous_batch text := current_setting('app.availability_batch', true);
begin
  if v_user_id is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean, false) then
    raise exception using errcode = '42501', message = 'authenticated_user_required';
  end if;
  -- Acceptance uses this same key. Backfill uses SKIP LOCKED for request rows,
  -- so this save must not wait for request locks while holding the groomer lock.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user_id::text, 71071));
  v_snapshot := app_private.get_groomer_availability();
  if p_expected_revision is null or p_expected_revision <> v_snapshot->>'revision' then
    raise exception using errcode = '40001', message = 'availability_revision_conflict';
  end if;
  if jsonb_typeof(p_windows) is distinct from 'array'
    or jsonb_typeof(p_preferences) is distinct from 'object'
    or jsonb_typeof(p_time_off) is distinct from 'array' then
    raise exception using errcode = '22023', message = 'invalid_availability_payload';
  end if;
  if jsonb_array_length(p_windows) <> 7
    or (select count(distinct w.weekday) from jsonb_to_recordset(p_windows) as w(weekday integer)) <> 7
    or exists (select 1 from jsonb_to_recordset(p_windows) as w(timezone text)
      where not exists (select 1 from pg_catalog.pg_timezone_names n where n.name = w.timezone)) then
    raise exception using errcode = '22023', message = 'invalid_availability_windows';
  end if;

  perform set_config('app.availability_batch', '1', true);
  delete from public.groomer_availability_windows where groomer_id = v_user_id;
  insert into public.groomer_availability_windows
    (groomer_id, weekday, start_time, end_time, is_enabled, timezone)
    select v_user_id, w.weekday, w.start_time, w.end_time, w.is_enabled, w.timezone
    from jsonb_to_recordset(p_windows) as w(weekday smallint, start_time time, end_time time,
      is_enabled boolean, timezone text);

  insert into public.groomer_booking_preferences
    (groomer_id, max_appointments_per_day, minimum_advance_notice_days, auto_accept_bookings)
    values (v_user_id, (p_preferences->>'max_appointments_per_day')::smallint,
      (p_preferences->>'minimum_advance_notice_days')::smallint,
      (p_preferences->>'auto_accept_bookings')::boolean)
    on conflict (groomer_id) do update set
      max_appointments_per_day = excluded.max_appointments_per_day,
      minimum_advance_notice_days = excluded.minimum_advance_notice_days,
      auto_accept_bookings = excluded.auto_accept_bookings;

  delete from public.groomer_time_off_windows where groomer_id = v_user_id;
  insert into public.groomer_time_off_windows (id, groomer_id, title, start_date, end_date)
    select t.id, v_user_id, t.title, t.start_date, t.end_date
    from jsonb_to_recordset(p_time_off) as t(id uuid, title text, start_date date, end_date date);
  perform set_config('app.availability_batch', coalesce(v_previous_batch, ''), true);
  perform app_private.backfill_request_matches_for_groomer(v_user_id, 250);
  return app_private.get_groomer_availability();
end;
$$;

create function public.get_groomer_availability()
returns jsonb language sql security invoker set search_path = ''
as $$ select app_private.get_groomer_availability(); $$;

create function public.save_groomer_availability(
  p_expected_revision text, p_windows jsonb, p_preferences jsonb, p_time_off jsonb
)
returns jsonb language sql security invoker set search_path = ''
as $$ select app_private.save_groomer_availability(p_expected_revision, p_windows, p_preferences, p_time_off); $$;

revoke all on function app_private.get_groomer_availability() from public, anon, authenticated;
revoke all on function app_private.save_groomer_availability(text, jsonb, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.get_groomer_availability() from public, anon, authenticated;
revoke all on function public.save_groomer_availability(text, jsonb, jsonb, jsonb) from public, anon, authenticated;
grant execute on function app_private.get_groomer_availability() to authenticated;
grant execute on function app_private.save_groomer_availability(text, jsonb, jsonb, jsonb) to authenticated;
grant execute on function public.get_groomer_availability() to authenticated;
grant execute on function public.save_groomer_availability(text, jsonb, jsonb, jsonb) to authenticated;

revoke insert, update, delete on table
  public.groomer_availability_windows,
  public.groomer_booking_preferences,
  public.groomer_time_off_windows
from public, anon, authenticated;

commit;
