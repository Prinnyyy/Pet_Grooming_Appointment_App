-- Caller owns BEGIN/ROLLBACK and the T-376 isolated fixtures. Never run outside rollback.
-- Historical fixture setup alone bypasses triggers in this session; every tested action
-- runs with normal triggers and an actual authenticated role.
create function pg_temp.fulfillment_fixture(target uuid, start_offset interval, phase text)
returns void language plpgsql as $$
declare b public.bookings%rowtype; shift interval; buffers jsonb; tail interval;
begin
  select booking.* into strict b from public.bookings booking join public.grooming_requests r on r.id=booking.request_id
    where booking.id=target and r.pet_snapshot->>'name'='T376';
  shift:=statement_timestamp()+start_offset-b.scheduled_start;
  buffers:=jsonb_build_object('preparation_minutes',0,'cleanup_minutes',10,'inbound_travel_minutes',0,
    'outbound_travel_minutes',case when b.agreement_snapshot->>'location_mode'='groomer_comes_to_customer' then 20 else 0 end);
  tail:=make_interval(mins=>10+(buffers->>'outbound_travel_minutes')::integer);
  alter table public.grooming_requests disable trigger grooming_requests_guard_agreement_terms;
  alter table public.grooming_requests disable trigger grooming_requests_guard_timing_intent;
  alter table public.groomer_offers disable trigger groomer_offers_guard_timing_consent;
  alter table public.groomer_offers disable trigger groomer_offers_snapshot_timing;
  alter table public.groomer_offers disable trigger groomer_offers_zz_agreement;
  alter table public.bookings disable trigger bookings_guard_admission;
  alter table public.bookings disable trigger bookings_snapshot_timing;
  alter table public.bookings disable trigger bookings_aaa_agreement;
  perform set_config('app.fulfillment_write','1',true);
  update public.grooming_requests set preferred_start=preferred_start+shift,preferred_end=preferred_end+shift where id=b.request_id;
  update public.groomer_offers set proposed_start=proposed_start+shift,proposed_end=proposed_end+shift,
    occupied_start=proposed_start+shift,occupied_end=proposed_end+shift+tail,applied_timing_buffers=buffers,
    agreement_snapshot=agreement_snapshot||jsonb_build_object('scheduled_start',proposed_start+shift,'scheduled_end',proposed_end+shift)
    where id=b.offer_id;
  update public.bookings set scheduled_start=scheduled_start+shift,scheduled_end=scheduled_end+shift,
    occupied_start=scheduled_start+shift,occupied_end=scheduled_end+shift+tail,
    applied_timing_buffers=buffers,fulfillment_phase=phase,
    actual_started_at=case when phase='in_service' then scheduled_start+shift end,
    agreement_snapshot=(select agreement_snapshot from public.groomer_offers where id=b.offer_id)
    where id=target;
  perform set_config('app.fulfillment_write','',true);
  alter table public.grooming_requests enable trigger grooming_requests_guard_agreement_terms;
  alter table public.grooming_requests enable trigger grooming_requests_guard_timing_intent;
  alter table public.groomer_offers enable trigger groomer_offers_guard_timing_consent;
  alter table public.groomer_offers enable trigger groomer_offers_snapshot_timing;
  alter table public.groomer_offers enable trigger groomer_offers_zz_agreement;
  alter table public.bookings enable trigger bookings_guard_admission;
  alter table public.bookings enable trigger bookings_snapshot_timing;
  alter table public.bookings enable trigger bookings_aaa_agreement;
  if exists(select 1 from pg_trigger where tgrelid in ('public.bookings'::regclass,
    'public.groomer_offers'::regclass,'public.grooming_requests'::regclass) and tgenabled='D') then
    raise exception 'T-377 fixture left a business guard disabled';
  end if;
end $$;

create function pg_temp.fulfillment_act(actor uuid,target uuid,revision uuid,operation uuid,action text,note text default null)
returns jsonb language plpgsql as $$
declare result jsonb;
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  result:=public.mutate_booking_fulfillment(target,revision,operation,action,note);
  execute 'reset role';
  return result;
end $$;

do $$
declare b public.bookings%rowtype; c uuid; g uuid; target uuid; revision uuid; operation uuid; result jsonb; replay jsonb;
  original_agreement jsonb; kind text;
begin
  select id into strict g from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select booking.* into strict b from public.bookings booking join public.grooming_requests r on r.id=booking.request_id
    where booking.groomer_id=g and r.pet_snapshot->>'name'='T376' order by booking.scheduled_start limit 1;
  c:=b.customer_id; target:=b.id; revision:=b.fulfillment_revision;
  begin
    perform pg_temp.fulfillment_act(g,target,revision,gen_random_uuid(),'start');
    raise exception 'T-377 future Start succeeded';
  exception when invalid_parameter_value then if sqlerrm<>'outside_service_start_window' then raise; end if;
  end;
  begin
    perform pg_temp.fulfillment_act(g,target,revision,gen_random_uuid(),'complete');
    raise exception 'T-377 future Complete succeeded';
  exception when raise_exception then if sqlerrm<>'service_not_completable' then raise; end if;
  end;
  begin
    operation:=gen_random_uuid();
    result:=pg_temp.fulfillment_act(c,target,revision,operation,'cancel');
    replay:=pg_temp.fulfillment_act(c,target,revision,operation,'cancel');
    if result->'receipt' is distinct from replay->'receipt' or replay->>'replayed'<>'true'
      or result->'booking'->>'status'<>'cancelled_by_customer'
      or (select count(*) from public.booking_fulfillment_events where booking_id=target)<>1 then
      raise exception 'T-377 cancellation replay duplicated or changed receipt'; end if;
    begin
      perform pg_temp.fulfillment_act(c,target,revision,operation,'cancel','changed intent');
      raise exception 'T-377 operation identity accepted new intent';
    exception when invalid_parameter_value then if sqlerrm<>'fulfillment_operation_intent_changed' then raise; end if;
    end;
    begin
      perform pg_temp.fulfillment_act(g,target,revision,gen_random_uuid(),'cancel');
      raise exception 'T-377 stale terminal revision accepted';
    exception when sqlstate 'PT409' then null;
    end;
    raise exception using errcode='ZX001',message='restore cancellation';
  exception when sqlstate 'ZX001' then null;
  end;
  begin
    perform pg_temp.fulfillment_fixture(target,interval '-2 minutes','scheduled');
    select fulfillment_revision into revision from public.bookings where id=target;
    result:=pg_temp.fulfillment_act(g,target,revision,gen_random_uuid(),'start');
    if result->'booking'->>'actual_started_at' is null then raise exception 'T-377 Start missing evidence'; end if;
    begin
      perform pg_temp.fulfillment_act(g,target,(result->'booking'->>'fulfillment_revision')::uuid,gen_random_uuid(),'complete');
      raise exception 'T-377 instant completion bypassed start rule';
    exception when invalid_parameter_value then if sqlerrm<>'completion_too_early' then raise; end if;
    end;
    raise exception using errcode='ZX001',message='restore start';
  exception when sqlstate 'ZX001' then null;
  end;
  foreach kind in array array['complete','report_interruption','report_no_show','close_elapsed','report_completion'] loop
    begin
      perform pg_temp.fulfillment_fixture(target,
        case when kind in ('close_elapsed','report_completion') then interval '-2 hours'
          when kind='report_no_show' then interval '-16 minutes' else interval '-2 minutes' end,
        case when kind in ('complete','report_interruption') then 'in_service' else 'scheduled' end);
      select fulfillment_revision,agreement_snapshot into revision,original_agreement from public.bookings where id=target;
      result:=pg_temp.fulfillment_act(case when kind='complete' then g else c end,target,revision,
        gen_random_uuid(),kind,'T-377 observed service outcome');
      if kind in ('report_interruption','report_no_show','report_completion') then
        if result->'booking'->>'resource_release_at' is not null then raise exception 'T-377 unilateral report released resource'; end if;
        begin
          replay:=pg_temp.fulfillment_act(c,target,(result->'booking'->>'fulfillment_revision')::uuid,
            gen_random_uuid(),'withdraw_report');
          if replay->'booking'->>'fulfillment_phase' is distinct from result->'booking'->>'report_previous_phase'
            or replay->'booking'->>'reported_by' is not null
            or (select count(*) from public.booking_fulfillment_events where booking_id=target)<>2 then
            raise exception 'T-377 withdrawal lost prior phase or audit'; end if;
          raise exception using errcode='ZX003',message='restore report';
        exception when sqlstate 'ZX003' then null;
        end;
        begin
          perform pg_temp.fulfillment_act(c,target,(result->'booking'->>'fulfillment_revision')::uuid,gen_random_uuid(),
            case when kind='report_completion' then 'confirm_completion' else 'confirm_stop' end);
          raise exception 'T-377 reporter supplied both consents';
        exception when raise_exception then if sqlerrm<>'other_participant_confirmation_required' then raise; end if;
        end;
        result:=pg_temp.fulfillment_act(g,target,(result->'booking'->>'fulfillment_revision')::uuid,gen_random_uuid(),
          case when kind='report_completion' then 'confirm_completion' else 'confirm_stop' end);
      end if;
      select * into b from public.bookings where id=target;
      if b.agreement_snapshot is distinct from original_agreement then raise exception 'T-377 fulfillment changed agreed terms'; end if;
      if kind in ('complete','report_completion') then
        if b.status<>'completed' then raise exception 'T-377 completion outcome missing'; end if;
        if kind='report_completion' and (b.actual_started_at is not null or b.actual_ended_at is not null
          or b.fulfillment_basis<>'bilateral_retrospective') then raise exception 'T-377 fabricated retrospective actual times'; end if;
      elsif b.status<>'unfulfilled' then raise exception 'T-377 service exception did not close';
      end if;
      if kind in ('complete','report_interruption','report_no_show') then
        if b.pet_release_at is distinct from (result->'receipt'->>'recorded_at')::timestamptz then raise exception 'T-377 pet release boundary incorrect'; end if;
        if b.resource_release_at is distinct from least(coalesce(b.occupied_end,b.scheduled_end),(result->'receipt'->>'recorded_at')::timestamptz
          +make_interval(mins=>coalesce((b.applied_timing_buffers->>'cleanup_minutes')::integer,0)
            +coalesce((b.applied_timing_buffers->>'outbound_travel_minutes')::integer,0))) then
          raise exception 'T-377 release omitted cleanup/travel'; end if;
        if b.resource_release_at<=statement_timestamp() then raise exception 'T-377 nonzero buffer fixture required'; end if;
        if app_private.groomer_can_admit_service(g,b.resource_release_at-interval '1 second',
          b.resource_release_at+interval '1 minute') then raise exception 'T-377 buffered resource admitted overlap'; end if;
        if not app_private.groomer_can_admit_service(g,b.resource_release_at,b.resource_release_at+interval '1 minute') then
          raise exception 'T-377 effective release failed to free adjacent groomer interval'; end if;
        if app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at)<>(result->'receipt'->>'recorded_at')::timestamptz then
          raise exception 'T-377 pet helper retained released allocation'; end if;
        begin
          update public.groomer_booking_preferences set max_appointments_per_day=1 where groomer_id=g;
          if app_private.groomer_can_admit_service(g,b.resource_release_at,b.resource_release_at+interval '1 minute')
            or app_private.groomer_has_capacity_on_request_day(g,b.resource_release_at) then
            raise exception 'T-377 early release incorrectly reset daily quota'; end if;
          raise exception using errcode='ZX002',message='restore quota';
        exception when sqlstate 'ZX002' then null;
        end;
      end if;
      perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
      execute 'set local role authenticated';
      if b.status='completed' then
        perform public.create_review(target,5,'T-377 service review','[]');
        begin
          perform public.create_review(target,5,'duplicate','[]');
          raise exception 'T-377 duplicate review accepted';
        exception when raise_exception then if sqlerrm<>'review_already_exists' then raise; end if;
        end;
      else
        begin
          perform public.create_review(target,5,'T-377 service review','[]');
          raise exception 'T-377 allegation enabled completed-service review';
        exception when raise_exception then if sqlerrm<>'booking_not_completed' then raise; end if;
        end;
      end if;
      begin
        delete from public.booking_fulfillment_events where booking_id=target;
        raise exception 'T-377 participant deleted immutable evidence';
      exception when insufficient_privilege then null;
      end;
      execute 'reset role';
      replay:=pg_temp.fulfillment_act(c,target,b.fulfillment_revision,gen_random_uuid(),
        'record_objection','T-377 participant observation');
      if replay->'booking'->>'status' is distinct from b.status
        or replay->'booking'->>'fulfillment_phase' is distinct from b.fulfillment_phase then
        raise exception 'T-377 objection silently reversed outcome'; end if;
      if kind='close_elapsed' then
        replay:=pg_temp.fulfillment_act(c,target,(replay->'booking'->>'fulfillment_revision')::uuid,
          gen_random_uuid(),'report_completion','T-377 correction confirmed by both');
        replay:=pg_temp.fulfillment_act(g,target,(replay->'booking'->>'fulfillment_revision')::uuid,
          gen_random_uuid(),'confirm_completion');
        if replay->'booking'->>'status'<>'completed'
          or replay->'booking'->>'fulfillment_basis'<>'bilateral_retrospective'
          or replay->'booking'->>'actual_started_at' is not null then
          raise exception 'T-377 bilateral unfulfilled correction failed'; end if;
      end if;
      raise exception using errcode='ZX001',message='restore outcome';
    exception when sqlstate 'ZX001' then null;
    end;
  end loop;
  begin
    perform pg_temp.fulfillment_act(gen_random_uuid(),target,revision,gen_random_uuid(),'cancel');
    raise exception 'T-377 unrelated actor mutated booking';
  exception when raise_exception then if sqlerrm<>'booking_not_found' then raise; end if;
  end;
end $$;
