alter table public.bookings
  add column fulfillment_revision uuid not null default gen_random_uuid(),
  add column fulfillment_phase text not null default 'scheduled',
  add column fulfillment_basis text not null default 'live',
  add column actual_started_at timestamptz,
  add column actual_ended_at timestamptz,
  add column pet_release_at timestamptz,
  add column resource_release_at timestamptz,
  add column reported_outcome text,
  add column reported_by uuid,
  add column reported_at timestamptz,
  add column report_previous_phase text,
  add column report_note text;

update public.bookings set fulfillment_basis='legacy',fulfillment_phase=case status
  when 'completed' then 'completed' when 'confirmed' then 'scheduled' else 'cancelled' end;

alter table public.bookings drop constraint bookings_status_check;
alter table public.bookings add constraint bookings_status_check check(status in
  ('confirmed','completed','cancelled_by_customer','cancelled_by_groomer','unfulfilled'));
alter table public.bookings drop constraint bookings_cancellation_check;
alter table public.bookings add constraint bookings_cancellation_check check(
  (status='cancelled_by_customer' and cancelled_at is not null and cancelled_by=customer_id)
  or (status='cancelled_by_groomer' and cancelled_at is not null and cancelled_by=groomer_id)
  or (status in ('confirmed','completed','unfulfilled') and cancelled_at is null and cancelled_by is null));
alter table public.bookings add constraint bookings_fulfillment_check check(
  fulfillment_basis in ('live','legacy','bilateral_retrospective')
  and ((status='confirmed' and fulfillment_phase in ('scheduled','in_service','outcome_reported'))
    or (status='completed' and fulfillment_phase='completed')
    or (status='unfulfilled' and fulfillment_phase in ('unfulfilled','outcome_reported'))
    or (status in ('cancelled_by_customer','cancelled_by_groomer') and fulfillment_phase='cancelled'))
  and (actual_ended_at is null or (actual_started_at is not null and actual_ended_at>=actual_started_at))
  and (actual_started_at is null or actual_started_at>=scheduled_start and actual_started_at<scheduled_end)
  and (reported_by is null or reported_by in (customer_id,groomer_id))
  and (fulfillment_phase<>'outcome_reported' or
    (reported_outcome is not null and reported_outcome in ('interruption','no_show','completion')
      and reported_by is not null and reported_at is not null
      and report_previous_phase is not null and report_previous_phase in ('scheduled','in_service','unfulfilled')
      and report_note is not null and char_length(btrim(report_note))>0))
  and (report_note is null or char_length(report_note)<=500));

create table public.booking_fulfillment_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  operation_id uuid not null,
  expected_revision uuid not null,
  result_revision uuid not null,
  action text not null,
  note text,
  recorded_at timestamptz not null default statement_timestamp(),
  receipt jsonb not null,
  unique(actor_id,operation_id)
);
create index booking_fulfillment_events_booking_time on public.booking_fulfillment_events(booking_id,recorded_at);
alter table public.booking_fulfillment_events enable row level security;
revoke all on public.booking_fulfillment_events from public,anon,authenticated,service_role;
grant select on public.booking_fulfillment_events to authenticated;
create policy booking_fulfillment_events_participant_read on public.booking_fulfillment_events
for select to authenticated using(exists(select 1 from public.bookings b join public.profiles p
  on p.id=(select auth.uid()) where b.id=booking_id
  and ((b.customer_id=p.id and p.role='customer') or (b.groomer_id=p.id and p.role='groomer'))));

create function app_private.guard_booking_fulfillment()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_op='INSERT' then
    new.fulfillment_revision:=gen_random_uuid();
    if new.status<>'confirmed' or new.fulfillment_phase<>'scheduled'
      or new.actual_started_at is not null or new.actual_ended_at is not null
      or new.pet_release_at is not null or new.resource_release_at is not null
      or new.fulfillment_basis<>'live' or new.reported_outcome is not null
      or new.reported_by is not null or new.reported_at is not null
      or new.report_previous_phase is not null or new.report_note is not null then
      raise exception using errcode='23514',message='invalid_initial_fulfillment';
    end if;
    return new;
  end if;
  if row(new.status,new.fulfillment_phase,new.fulfillment_basis,new.fulfillment_revision,
    new.actual_started_at,new.actual_ended_at,new.pet_release_at,new.resource_release_at,
    new.reported_outcome,new.reported_by,new.reported_at,new.report_previous_phase,new.report_note,
    new.completed_at,new.completed_by,new.cancelled_at,new.cancelled_by)
    is distinct from row(old.status,old.fulfillment_phase,old.fulfillment_basis,old.fulfillment_revision,
    old.actual_started_at,old.actual_ended_at,old.pet_release_at,old.resource_release_at,
    old.reported_outcome,old.reported_by,old.reported_at,old.report_previous_phase,old.report_note,
    old.completed_at,old.completed_by,old.cancelled_at,old.cancelled_by) then
    if current_setting('app.fulfillment_write',true) is distinct from '1' then
      raise exception using errcode='23514',message='versioned_fulfillment_operation_required';
    end if;
    new.fulfillment_revision:=gen_random_uuid();
  end if;
  return new;
end $$;
revoke all on function app_private.guard_booking_fulfillment() from public,anon,authenticated,service_role;
create trigger bookings_guard_fulfillment before insert or update on public.bookings
for each row execute function app_private.guard_booking_fulfillment();

create function app_private.get_booking_fulfillment_operation(p_operation_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); event public.booking_fulfillment_events%rowtype; b public.bookings%rowtype;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  select * into event from public.booking_fulfillment_events where actor_id=actor and operation_id=p_operation_id;
  if not found then return null; end if;
  select booking.* into b from public.bookings booking
    join public.profiles profile on profile.id=actor
    where booking.id=event.booking_id
    and ((booking.customer_id=actor and profile.role='customer')
      or (booking.groomer_id=actor and profile.role='groomer'));
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  return jsonb_build_object('receipt',event.receipt,'booking',to_jsonb(b),'replayed',true);
end $$;

create function app_private.mutate_booking_fulfillment(p_booking_id uuid,p_expected_revision uuid,
  p_operation_id uuid,p_action text,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype; event public.booking_fulfillment_events%rowtype;
  parent uuid; at_time timestamptz:=statement_timestamp(); note text:=nullif(btrim(p_note),'');
  receipt jsonb; event_id uuid:=gen_random_uuid(); conversation uuid; chat_text text;
  tail_minutes integer; old_write text:=current_setting('app.fulfillment_write',true);
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if p_booking_id is null or p_expected_revision is null or p_operation_id is null
    or p_action is null or char_length(coalesce(note,''))>500 then
    raise exception using errcode='22023',message='invalid_fulfillment_operation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||p_operation_id::text,71377));
  select * into event from public.booking_fulfillment_events where actor_id=actor and operation_id=p_operation_id;
  if found then
    if row(event.booking_id,event.expected_revision,event.action,event.note)
      is distinct from row(p_booking_id,p_expected_revision,p_action,note) then
      raise exception using errcode='22023',message='fulfillment_operation_intent_changed';
    end if;
    return app_private.get_booking_fulfillment_operation(p_operation_id);
  end if;
  select r.id into parent from public.grooming_requests r join public.bookings booking on booking.request_id=r.id
    where booking.id=p_booking_id and (booking.customer_id=actor or booking.groomer_id=actor) for update of r;
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  select * into strict b from public.bookings where id=p_booking_id for update;
  if not exists(select 1 from public.profiles where id=actor
    and ((actor=b.customer_id and role='customer') or (actor=b.groomer_id and role='groomer'))) then
    raise exception using errcode='42501',message='booking_participant_required';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(b.groomer_id::text,71071));
  -- Evaluate boundaries after lock waits, not at the request's earlier arrival time.
  at_time:=clock_timestamp();
  if b.fulfillment_revision is distinct from p_expected_revision then
    raise exception using errcode='PT409',message='booking_revision_changed';
  end if;
  if p_action in ('report_interruption','report_no_show','close_elapsed','report_completion','record_objection')
    and note is null then raise exception using errcode='22023',message='fulfillment_note_required'; end if;
  tail_minutes:=coalesce((b.applied_timing_buffers->>'cleanup_minutes')::integer,0)
    +coalesce((b.applied_timing_buffers->>'outbound_travel_minutes')::integer,0);
  case p_action
  when 'start' then
    if actor<>b.groomer_id or b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' then
      raise exception using errcode='P0001',message='service_not_startable'; end if;
    if at_time<b.scheduled_start or at_time>=b.scheduled_end then
      raise exception using errcode='22023',message='outside_service_start_window'; end if;
    b.fulfillment_phase:='in_service'; b.fulfillment_basis:='live'; b.actual_started_at:=at_time;
    chat_text:='Service has started.';
  when 'complete' then
    if actor<>b.groomer_id or b.status<>'confirmed' or b.fulfillment_phase<>'in_service'
      or b.actual_started_at is null then
      raise exception using errcode='P0001',message='service_not_completable'; end if;
    if at_time<b.actual_started_at+interval '1 minute' then
      raise exception using errcode='22023',message='completion_too_early'; end if;
    b.status:='completed'; b.fulfillment_phase:='completed'; b.actual_ended_at:=at_time;
    b.completed_at:=at_time; b.completed_by:=actor;
    b.pet_release_at:=greatest(b.scheduled_start,least(b.scheduled_end,at_time));
    b.resource_release_at:=greatest(coalesce(b.occupied_start,b.scheduled_start),
      least(coalesce(b.occupied_end,b.scheduled_end),at_time+make_interval(mins=>tail_minutes)));
    chat_text:='Service is completed. The customer can leave a review.';
  when 'cancel' then
    if b.status<>'confirmed' or b.fulfillment_phase<>'scheduled' or at_time>=b.scheduled_start then
      raise exception using errcode='P0001',message='use_service_outcome_report'; end if;
    b.status:=case when actor=b.customer_id then 'cancelled_by_customer' else 'cancelled_by_groomer' end;
    b.fulfillment_phase:='cancelled'; b.cancelled_at:=at_time; b.cancelled_by:=actor;
    chat_text:='This booking was cancelled before service. The original request remains closed.';
  when 'report_interruption','report_no_show' then
    if b.status<>'confirmed' or b.fulfillment_phase not in ('scheduled','in_service') or at_time<b.scheduled_start then
      raise exception using errcode='P0001',message='service_not_reportable'; end if;
    if p_action='report_no_show' and (b.actual_started_at is not null or at_time<b.scheduled_start+interval '15 minutes') then
      raise exception using errcode='22023',message='no_show_wait_required'; end if;
    b.report_previous_phase:=b.fulfillment_phase; b.fulfillment_phase:='outcome_reported';
    b.reported_outcome:=case p_action when 'report_no_show' then 'no_show' else 'interruption' end;
    b.reported_by:=actor; b.reported_at:=at_time; b.report_note:=note;
    chat_text:='A service issue was reported. Please confirm the service outcome. No fault has been assigned.';
  when 'confirm_stop' then
    if b.fulfillment_phase<>'outcome_reported' or b.reported_outcome not in ('interruption','no_show')
      or b.reported_by=actor then raise exception using errcode='P0001',message='other_participant_confirmation_required'; end if;
    b.status:='unfulfilled'; b.fulfillment_phase:='unfulfilled';
    if b.actual_started_at is not null then b.actual_ended_at:=at_time; end if;
    b.pet_release_at:=greatest(b.scheduled_start,least(b.scheduled_end,at_time));
    b.resource_release_at:=greatest(coalesce(b.occupied_start,b.scheduled_start),
      least(coalesce(b.occupied_end,b.scheduled_end),at_time+make_interval(mins=>tail_minutes)));
    chat_text:='Both participants confirmed that service ended without completion. No fault has been assigned.';
  when 'withdraw_report' then
    if b.fulfillment_phase<>'outcome_reported' or b.reported_by<>actor then
      raise exception using errcode='P0001',message='report_not_withdrawable'; end if;
    b.fulfillment_phase:=b.report_previous_phase; b.reported_outcome:=null; b.reported_by:=null;
    b.reported_at:=null; b.report_previous_phase:=null; b.report_note:=null;
    chat_text:='The service outcome report was withdrawn. Previous observations remain recorded.';
  when 'close_elapsed' then
    if b.status<>'confirmed' or at_time<b.scheduled_end then
      raise exception using errcode='P0001',message='elapsed_closure_not_available'; end if;
    b.status:='unfulfilled'; b.fulfillment_phase:='unfulfilled';
    b.reported_outcome:='unresolved'; b.reported_by:=actor; b.reported_at:=at_time; b.report_note:=note;
    b.pet_release_at:=b.scheduled_end;
    b.resource_release_at:=least(coalesce(b.occupied_end,b.scheduled_end),at_time+make_interval(mins=>tail_minutes));
    chat_text:='This elapsed booking was closed without confirmed completion. No fault has been assigned.';
  when 'report_completion' then
    if b.status not in ('confirmed','unfulfilled') or b.fulfillment_phase='outcome_reported' or at_time<b.scheduled_end then
      raise exception using errcode='P0001',message='retrospective_completion_not_available'; end if;
    b.report_previous_phase:=b.fulfillment_phase; b.fulfillment_phase:='outcome_reported';
    b.reported_outcome:='completion'; b.reported_by:=actor; b.reported_at:=at_time; b.report_note:=note;
    chat_text:='Service completion was reported retrospectively. The other participant must confirm it.';
  when 'confirm_completion' then
    if b.fulfillment_phase<>'outcome_reported' or b.reported_outcome<>'completion' or b.reported_by=actor then
      raise exception using errcode='P0001',message='other_participant_confirmation_required'; end if;
    b.status:='completed'; b.fulfillment_phase:='completed'; b.fulfillment_basis:='bilateral_retrospective';
    b.completed_at:=at_time; b.completed_by:=b.groomer_id;
    chat_text:='Both participants confirmed service completion. Unrecorded actual times remain unverified.';
  when 'record_objection' then
    if b.status='confirmed' or b.fulfillment_phase='outcome_reported' then
      raise exception using errcode='P0001',message='objection_requires_terminal_outcome'; end if;
    b.fulfillment_revision:=gen_random_uuid();
    chat_text:='An observation about the recorded service outcome was added. No automatic judgment has been made.';
  else raise exception using errcode='22023',message='invalid_fulfillment_action';
  end case;
  perform set_config('app.fulfillment_write','1',true);
  update public.bookings set status=b.status,fulfillment_phase=b.fulfillment_phase,fulfillment_basis=b.fulfillment_basis,
    fulfillment_revision=b.fulfillment_revision,actual_started_at=b.actual_started_at,actual_ended_at=b.actual_ended_at,
    pet_release_at=b.pet_release_at,resource_release_at=b.resource_release_at,reported_outcome=b.reported_outcome,
    reported_by=b.reported_by,reported_at=b.reported_at,report_previous_phase=b.report_previous_phase,report_note=b.report_note,
    cancelled_at=b.cancelled_at,cancelled_by=b.cancelled_by,completed_at=b.completed_at,completed_by=b.completed_by
    where id=b.id returning * into b;
  perform set_config('app.fulfillment_write',coalesce(old_write,''),true);
  receipt:=jsonb_build_object('id',event_id,'operation_id',p_operation_id,'booking_id',b.id,'action',p_action,
    'result_revision',b.fulfillment_revision,'recorded_at',at_time);
  insert into public.booking_fulfillment_events(id,booking_id,actor_id,operation_id,expected_revision,result_revision,action,note,receipt,recorded_at)
    values(event_id,b.id,actor,p_operation_id,p_expected_revision,b.fulfillment_revision,p_action,note,receipt,at_time);
  select id into conversation from public.conversations where customer_id=b.customer_id and groomer_id=b.groomer_id;
  if conversation is null then raise exception using errcode='P0001',message='conversation_not_found'; end if;
  insert into public.messages(conversation_id,sender_id,kind,booking_id,created_at)
    values(conversation,actor,'booking_card',b.id,at_time);
  insert into public.messages(conversation_id,sender_id,kind,body,created_at)
    values(conversation,actor,'text',chat_text,at_time+interval '1 microsecond');
  return jsonb_build_object('receipt',receipt,'booking',to_jsonb(b),'replayed',false);
end $$;

create function public.mutate_booking_fulfillment(p_booking_id uuid,p_expected_revision uuid,
  p_operation_id uuid,p_action text,p_note text default null)
returns jsonb language sql security invoker set search_path='' as $$
  select app_private.mutate_booking_fulfillment(p_booking_id,p_expected_revision,p_operation_id,p_action,p_note);
$$;
create function public.get_booking_fulfillment_operation(p_operation_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.get_booking_fulfillment_operation(p_operation_id);
$$;
revoke all on function app_private.mutate_booking_fulfillment(uuid,uuid,uuid,text,text),
  public.mutate_booking_fulfillment(uuid,uuid,uuid,text,text),app_private.get_booking_fulfillment_operation(uuid),
  public.get_booking_fulfillment_operation(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.mutate_booking_fulfillment(uuid,uuid,uuid,text,text),
  public.mutate_booking_fulfillment(uuid,uuid,uuid,text,text),app_private.get_booking_fulfillment_operation(uuid),
  public.get_booking_fulfillment_operation(uuid) to authenticated;
revoke execute on function app_private.complete_booking(uuid),app_private.cancel_booking(uuid) from public,anon,authenticated,service_role;
create or replace function public.complete_booking(p_booking_id uuid)
returns table(booking_id uuid,booking_status text,completed_timestamp timestamptz,completed_by uuid)
language plpgsql security invoker set search_path='' as $$
begin raise exception using errcode='22023',message='updated_fulfillment_client_required'; end $$;
create or replace function public.cancel_booking(p_booking_id uuid)
returns table(booking_id uuid,booking_status text,cancelled_timestamp timestamptz,cancelled_by uuid)
language plpgsql security invoker set search_path='' as $$
begin raise exception using errcode='22023',message='updated_fulfillment_client_required'; end $$;

create function app_private.booking_pet_end(p_start timestamptz,p_end timestamptz,p_release timestamptz)
returns timestamptz language sql immutable set search_path='' as $$
  select greatest(p_start,least(p_end,p_release));
$$;
create function app_private.booking_resource_end(p_service_start timestamptz,p_service_end timestamptz,
  p_occupied_start timestamptz,p_occupied_end timestamptz,p_release timestamptz)
returns timestamptz language sql immutable set search_path='' as $$
  select greatest(coalesce(p_occupied_start,p_service_start),least(coalesce(p_occupied_end,p_service_end),p_release));
$$;
revoke all on function app_private.booking_pet_end(timestamptz,timestamptz,timestamptz),
  app_private.booking_resource_end(timestamptz,timestamptz,timestamptz,timestamptz,timestamptz)
  from public,anon,authenticated,service_role;
alter table public.bookings add constraint bookings_effective_release_check check(
  (pet_release_at is null or pet_release_at between scheduled_start and scheduled_end)
  and (resource_release_at is null or resource_release_at between coalesce(occupied_start,scheduled_start)
    and coalesce(occupied_end,scheduled_end)));
alter table public.bookings drop constraint bookings_no_groomer_time_overlap;
alter table public.bookings drop constraint bookings_no_groomer_occupied_overlap;
alter table public.bookings drop constraint bookings_no_pet_time_overlap;
alter table public.bookings add constraint bookings_no_groomer_occupied_overlap exclude using gist
  (groomer_id with =,tstzrange(coalesce(occupied_start,scheduled_start),
    app_private.booking_resource_end(scheduled_start,scheduled_end,occupied_start,occupied_end,resource_release_at),'[)') with &&)
  where(status in ('confirmed','completed','unfulfilled'));
alter table public.bookings add constraint bookings_no_pet_time_overlap exclude using gist
  (pet_id with =,tstzrange(scheduled_start,app_private.booking_pet_end(scheduled_start,scheduled_end,pet_release_at),'[)') with &&)
  where(status in ('confirmed','completed','unfulfilled'));
drop trigger bookings_refresh_matches on public.bookings;
create trigger bookings_refresh_matches after insert or delete or update of status,scheduled_start,scheduled_end,
  occupied_start,occupied_end,pet_release_at,resource_release_at on public.bookings
for each row execute function app_private.enqueue_booking_match_refresh();


-- Existing resource consumers use the same effective release boundaries.
CREATE OR REPLACE FUNCTION app_private.evaluate_match_eligibility_with_zones(p_request uuid, p_groomer uuid, p_now timestamp with time zone, p_valid_zones text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype;
  prefs public.groomer_booking_preferences%rowtype;
  zone text; service_zone text; valid_zones text[]; zones integer; windows integer;
  starts time[]; ends time[]; before_minutes integer := 0; after_minutes integer := 0;
  buffers_known boolean; earliest timestamptz; day date; day_end timestamptz;
  window_start timestamptz; window_end timestamptz; cursor_start timestamptz;
  available tstzmultirange; blocked tstzmultirange; allocation record; service record;
  pet_busy_until timestamptz; size_state text; duration integer; assessment jsonb;
begin
  assessment:=app_private.evaluate_match_constraints(p_request,p_groomer,p_now);
  if assessment->>'state'='excluded' then return assessment; end if;
  assessment:=null;
  select * into strict r from public.grooming_requests where id=p_request;
  select * into strict g from public.groomer_profiles where user_id=p_groomer;
  select min(timezone),count(distinct timezone),count(*),
    array_agg(case when is_enabled then start_time end order by weekday),
    array_agg(case when is_enabled then end_time end order by weekday)
    into zone,zones,windows,starts,ends from public.groomer_availability_windows where groomer_id=p_groomer;
  if zones<>1 or windows<>7 then
    return jsonb_build_object('state','excluded','reason','schedule_confirmation_required');
  end if;
  if r.location_mode='groomer_comes_to_customer' then service_zone:=r.preference_time_zone_identifier;
  else
    select time_zone_identifier into service_zone from app_private.address_locations
      where id=g.address_location_id and owner_id=p_groomer;
  end if;
  valid_zones:=p_valid_zones;
  if valid_zones is null then
    select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names where name in (zone,service_zone);
  end if;
  if not coalesce(zone=any(valid_zones),false) then
    return jsonb_build_object('state','excluded','reason','schedule_confirmation_required');
  end if;
  if not coalesce(service_zone=any(valid_zones),false) then
    return jsonb_build_object('state','excluded','reason','service_timezone_confirmation_required');
  end if;
  select * into prefs from public.groomer_booking_preferences where groomer_id=p_groomer;
  if not found then
    -- Optimistic notice only proves impossibility; missing preferences cannot
    -- produce estimated_fit because their buffers remain unconfirmed.
    prefs.minimum_advance_notice_days:=0;
  end if;
  buffers_known:=coalesce(app_private.valid_timing_buffers(prefs.timing_buffers),false);
  if buffers_known then
    before_minutes:=(prefs.timing_buffers->>'preparation_minutes')::integer;
    after_minutes:=(prefs.timing_buffers->>'cleanup_minutes')::integer;
    if r.location_mode='groomer_comes_to_customer' then
      before_minutes:=before_minutes+(prefs.timing_buffers->>'inbound_travel_minutes')::integer;
      after_minutes:=after_minutes+(prefs.timing_buffers->>'outbound_travel_minutes')::integer;
    end if;
  end if;
  earliest:=greatest(r.preferred_start,
    app_private.service_timing_earliest_start_validated(p_now,prefs.minimum_advance_notice_days,zone));
  select coalesce(range_agg(slot),'{}'::tstzmultirange) into blocked from (
    select tstzrange(coalesce(b.occupied_start,b.scheduled_start),app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)') slot
      from public.bookings b where b.groomer_id=p_groomer and b.status in ('confirmed','completed','unfulfilled')
    union all
    select tstzrange(timezone(zone,t.start_date::timestamp),timezone(zone,(t.end_date+1)::timestamp),'[)')
      from public.groomer_time_off_windows t where t.groomer_id=p_groomer
  ) occupied;
  day:=timezone(service_zone,earliest)::date;
  while timezone(service_zone,day::timestamp)<r.preferred_end loop
    day_end:=timezone(service_zone,(day+1)::timestamp);
    window_start:=greatest(earliest,timezone(service_zone,day::timestamp));
    window_end:=least(r.preferred_end,day_end);
    if window_start<window_end and not blocked @> tstzrange(window_start,window_end,'[)') then
      available:=app_private.match_weekly_ranges_validated(window_start-make_interval(mins=>before_minutes),
        window_end+make_interval(mins=>after_minutes),zone,starts,ends);
      if available is null then
        return jsonb_build_object('state','assessment_required','reason','schedule_evaluation_required');
      end if;
      for service in select * from public.groomer_services s where s.groomer_id=p_groomer
        and s.is_active and s.service_type=r.service_type order by s.duration_minutes,s.id loop
        size_state:=app_private.match_service_size(r.pet_snapshot->>'size',service.accepted_pet_sizes);
        if size_state='excluded' then continue; end if;
        -- Unknown duration/buffers use optimistic lower bounds only to prove impossibility.
        duration:=case when r.service_type<>'custom_request' and service.duration_minutes between 15 and 720
          then service.duration_minutes else 15 end;
        cursor_start:=window_start;
        loop
          select * into allocation from app_private.match_service_interval(tstzrange(window_start,window_end,'[)'),
            available,blocked,duration,before_minutes,after_minutes,cursor_start);
          exit when not found;
          if (select count(*) from public.bookings b where b.groomer_id=p_groomer
              and b.status in ('confirmed','completed','unfulfilled')
              and timezone(zone,b.scheduled_start)::date=timezone(zone,allocation.service_start)::date)
              >=prefs.max_appointments_per_day then
            cursor_start:=timezone(zone,(timezone(zone,allocation.service_start)::date+1)::timestamp);
            continue;
          end if;
          select max(app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at)) into pet_busy_until from public.bookings b
            where b.pet_id=r.pet_id and b.status in ('confirmed','completed','unfulfilled')
              and b.scheduled_start<allocation.service_end and app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at)>allocation.service_start;
          if pet_busy_until is not null then cursor_start:=pet_busy_until; continue; end if;
          if size_state='eligible' and buffers_known and r.service_type<>'custom_request'
            and service.duration_minutes between 15 and 720 then
            return jsonb_build_object('state','estimated_fit','reason','continuous_opening',
              'service_id',service.id,'service_start',allocation.service_start,'service_end',allocation.service_end,
              'occupied_start',allocation.occupied_start,'occupied_end',allocation.occupied_end);
          end if;
          assessment:=jsonb_build_object('state','assessment_required','reason','service_details_unconfirmed');
          exit;
        end loop;
      end loop;
    end if;
    day:=day+1;
  end loop;
  return coalesce(assessment,jsonb_build_object('state','excluded','reason','no_continuous_opening'));
end $function$;

CREATE OR REPLACE FUNCTION app_private.evaluate_quote(p_offer_id uuid, p_now timestamp with time zone DEFAULT statement_timestamp())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.groomer_offers%rowtype; r public.grooming_requests%rowtype;
  reason text; constraints jsonb; earliest timestamptz; notice integer; zone text;
  zone_count integer; window_count integer;
begin
  select * into o from public.groomer_offers where id=p_offer_id;
  if not found then return jsonb_build_object('terms_valid',false,'selectable',false,'reason','not_found'); end if;
  select * into strict r from public.grooming_requests where id=o.request_id;
  if o.terms_invalid_reason is not null then reason:=o.terms_invalid_reason;
  elsif o.status='withdrawn_by_groomer' then reason:='withdrawn';
  elsif o.status='expired' or least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')<=p_now then reason:='expired';
  elsif o.status<>'pending' or r.status not in ('open','has_offers') then reason:='superseded';
  elsif o.agreement_snapshot is null then reason:='legacy_unverified';
  elsif o.agreement_snapshot->>'request_revision' is distinct from r.terms_revision::text then reason:='superseded';
  elsif o.agreement_snapshot->>'groomer_eligibility_revision' is distinct from
    (select eligibility_revision::text from public.groomer_profiles where user_id=o.groomer_id)
    or o.agreement_snapshot->>'service_eligibility_revision' is distinct from
    (select eligibility_revision::text from public.groomer_services where groomer_id=o.groomer_id and service_type=r.service_type)
    or (o.agreement_snapshot->'address'->>'source_updated_at')::timestamptz is distinct from
    (select updated_at from app_private.address_locations where id=(o.agreement_snapshot->'address'->>'source_location_id')::uuid)
    then reason:='eligibility_revoked';
  else
    constraints:=app_private.evaluate_match_constraints(r.id,o.groomer_id,p_now);
    if constraints->>'state'='excluded' then reason:='eligibility_revoked'; end if;
  end if;
  if reason is not null then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason',reason);
  end if;
  select coalesce((select minimum_advance_notice_days from public.groomer_booking_preferences
    where groomer_id=o.groomer_id),0) into notice;
  select min(timezone),count(distinct timezone),count(*) into zone,zone_count,window_count
    from public.groomer_availability_windows where groomer_id=o.groomer_id;
  if zone_count<>1 or window_count<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=zone
  ) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  earliest:=app_private.service_timing_earliest_start(p_now,notice,zone);
  if o.proposed_start<earliest then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason','expired');
  end if;
  if not app_private.groomer_can_admit_service(o.groomer_id,o.proposed_start,o.proposed_end,p_now)
    or exists(select 1 from public.bookings b where b.pet_id=r.pet_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(b.scheduled_start,app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at),'[)') && tstzrange(o.proposed_start,o.proposed_end,'[)'))
    or exists(select 1 from public.bookings b where b.groomer_id=o.groomer_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(coalesce(b.occupied_start,b.scheduled_start),app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)')
        && tstzrange(o.occupied_start,o.occupied_end,'[)'))
    or app_private.occupied_time_off_conflict(o.groomer_id,o.occupied_start,o.occupied_end)
    or not app_private.occupied_weekly_hours_covered(o.groomer_id,o.occupied_start,o.occupied_end) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  return jsonb_build_object('terms_valid',true,'selectable',true,'reason','available');
end $function$;

CREATE OR REPLACE FUNCTION app_private.groomer_can_admit_service(p_groomer_id uuid, p_start timestamp with time zone, p_end timestamp with time zone, p_now timestamp with time zone DEFAULT statement_timestamp())
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
      and b.status in ('confirmed','completed','unfulfilled') and coalesce(b.occupied_start,b.scheduled_start)<p_end
      and p_start<app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at))
    and (select count(*) from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and pg_catalog.timezone(v_zone,b.scheduled_start)::date=pg_catalog.timezone(v_zone,p_start)::date)<v_limit;
end $function$;

CREATE OR REPLACE FUNCTION app_private.groomer_has_capacity_on_request_day(p_groomer_id uuid, p_requested_start timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  with matching_window as (
    select
      availability_window.timezone,
      timezone(availability_window.timezone, p_requested_start)::date as local_request_date
    from public.groomer_availability_windows as availability_window
    join pg_catalog.pg_timezone_names as timezone_name
      on timezone_name.name = availability_window.timezone
    where p_groomer_id is not null
      and p_requested_start is not null
      and p_requested_start > statement_timestamp()
      and availability_window.groomer_id = p_groomer_id
      and availability_window.is_enabled
      and availability_window.weekday =
        extract(isodow from timezone(availability_window.timezone, p_requested_start))::smallint
  ),
  booking_preferences as (
    select
      coalesce(preferences.max_appointments_per_day, 4) as max_appointments_per_day,
      coalesce(preferences.minimum_advance_notice_days, 0) as minimum_advance_notice_days
    from public.groomer_profiles as groomer_profile
    left join public.groomer_booking_preferences as preferences
      on preferences.groomer_id = groomer_profile.user_id
    where groomer_profile.user_id = p_groomer_id
  )
  select coalesce(
    (
      select true
      from matching_window
      cross join booking_preferences
      where matching_window.local_request_date >=
        (
          timezone(matching_window.timezone, statement_timestamp())::date
          + booking_preferences.minimum_advance_notice_days
        )
        and not exists (
          select 1
          from public.groomer_time_off_windows as time_off
          where time_off.groomer_id = p_groomer_id
            and matching_window.local_request_date between time_off.start_date and time_off.end_date
        )
        and (
          select count(*)::integer
          from public.bookings as daily_booking
          where daily_booking.groomer_id = p_groomer_id
            and daily_booking.status in ('confirmed','completed','unfulfilled')
            and timezone(matching_window.timezone, daily_booking.scheduled_start)::date =
              matching_window.local_request_date
        ) < booking_preferences.max_appointments_per_day
      limit 1
    ),
    false
  );
$function$;

CREATE OR REPLACE FUNCTION app_private.groomer_is_available_for_range(p_groomer_id uuid, p_scheduled_start timestamp with time zone, p_scheduled_end timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  with matching_window as (
    select
      availability_window.timezone,
      timezone(availability_window.timezone, p_scheduled_start) as local_start,
      timezone(availability_window.timezone, p_scheduled_end) as local_end,
      availability_window.start_time,
      availability_window.end_time
    from public.groomer_availability_windows as availability_window
    join pg_catalog.pg_timezone_names as timezone_name
      on timezone_name.name = availability_window.timezone
    where p_groomer_id is not null
      and p_scheduled_start is not null
      and p_scheduled_end is not null
      and p_scheduled_start > statement_timestamp()
      and p_scheduled_end > p_scheduled_start
      and availability_window.groomer_id = p_groomer_id
      and availability_window.is_enabled
      and availability_window.weekday =
        extract(isodow from timezone(availability_window.timezone, p_scheduled_start))::smallint
  ),
  feasible_window as (
    select
      matching_window.timezone,
      matching_window.local_start::date as local_date
    from matching_window
    where matching_window.local_start::date = matching_window.local_end::date
      and matching_window.local_start::time >= matching_window.start_time
      and matching_window.local_end::time <= matching_window.end_time
  ),
  booking_preferences as (
    select
      coalesce(preferences.max_appointments_per_day, 4) as max_appointments_per_day,
      coalesce(preferences.minimum_advance_notice_days, 0) as minimum_advance_notice_days
    from public.groomer_profiles as groomer_profile
    left join public.groomer_booking_preferences as preferences
      on preferences.groomer_id = groomer_profile.user_id
    where groomer_profile.user_id = p_groomer_id
  )
  select coalesce(
    (
      select true
      from feasible_window
      cross join booking_preferences
      where feasible_window.local_date >=
        (
          timezone(feasible_window.timezone, statement_timestamp())::date
          + booking_preferences.minimum_advance_notice_days
        )
        and not exists (
          select 1
          from public.groomer_time_off_windows as time_off
          where time_off.groomer_id = p_groomer_id
            and feasible_window.local_date between time_off.start_date and time_off.end_date
        )
        and not exists (
          select 1
          from public.bookings as existing_booking
          where existing_booking.groomer_id = p_groomer_id
            and existing_booking.status in ('confirmed','completed','unfulfilled')
            and coalesce(existing_booking.occupied_start,existing_booking.scheduled_start) < p_scheduled_end
            and p_scheduled_start < app_private.booking_resource_end(existing_booking.scheduled_start,existing_booking.scheduled_end,existing_booking.occupied_start,existing_booking.occupied_end,existing_booking.resource_release_at)
        )
        and (
          select count(*)::integer
          from public.bookings as daily_booking
          where daily_booking.groomer_id = p_groomer_id
            and daily_booking.status in ('confirmed','completed','unfulfilled')
            and timezone(feasible_window.timezone, daily_booking.scheduled_start)::date =
              feasible_window.local_date
        ) < booking_preferences.max_appointments_per_day
      limit 1
    ),
    false
  );
$function$;

CREATE OR REPLACE FUNCTION app_private.snapshot_offer_timing()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      and b.status in ('confirmed','completed','unfulfilled')
      and coalesce(b.occupied_start,b.scheduled_start)<new.occupied_end
      and new.occupied_start<app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at)) then
    raise exception using errcode='P0001',message='groomer_unavailable';
  end if;
  if app_private.occupied_time_off_conflict(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_time_off_conflict';
  end if;
  if not app_private.occupied_weekly_hours_covered(new.groomer_id,new.occupied_start,new.occupied_end) then
    raise exception using errcode='22023',message='occupied_outside_weekly_hours';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION app_private.validate_booked_coverage(p_groomer_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_zone text; v_zone_count integer; v_window_count integer; v_starts time[]; v_ends time[];
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_groomer_id::text,71071));
  if not exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at)>statement_timestamp()) then return; end if;
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
      and b.status in ('confirmed','completed','unfulfilled')
      and app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at)>statement_timestamp()
      and exists(select 1 from public.groomer_time_off_windows t where t.groomer_id=p_groomer_id
        and tstzrange(pg_catalog.timezone(v_zone,t.start_date::timestamp),
          pg_catalog.timezone(v_zone,(t.end_date+1)::timestamp),'[)')
          && tstzrange(coalesce(b.occupied_start,b.scheduled_start),
            app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)'))) then
    raise exception using errcode='22023',message='time_off_conflicts_with_booking_occupancy';
  end if;
  if exists(select 1 from public.bookings b where b.groomer_id=p_groomer_id
      and b.status in ('confirmed','completed','unfulfilled')
      and app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at)>statement_timestamp()
      and not app_private.weekly_hours_cover_interval(
        coalesce(b.occupied_start,b.scheduled_start),app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),
        v_zone,v_starts,v_ends)) then
    raise exception using errcode='22023',message='weekly_hours_conflict_with_booking_occupancy';
  end if;
end $function$;

notify pgrst, 'reload schema';
