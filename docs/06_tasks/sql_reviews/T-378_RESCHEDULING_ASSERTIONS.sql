-- Caller owns BEGIN/ROLLBACK, the named isolated T-376 fixtures and the
-- existing pg_temp.fulfillment_fixture helper from the T-377 assertion file.
create function pg_temp.reschedule_act(actor uuid,booking uuid,revision uuid,operation uuid,action text,proposal uuid,starts timestamptz default null)
returns jsonb language plpgsql as $$
declare result jsonb;
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  result:=public.mutate_booking_reschedule(booking,revision,operation,action,proposal,starts);
  execute 'reset role';
  return result;
end $$;

do $$
declare b public.bookings%rowtype; proposal uuid:=gen_random_uuid(); operation uuid:=gen_random_uuid();
  foreign_actor uuid; result jsonb; original_start timestamptz;
begin
  select booking.* into strict b from public.bookings booking join public.grooming_requests request on request.id=booking.request_id
    where request.pet_snapshot->>'name'='T376' order by booking.scheduled_start limit 1;
  select id into strict foreign_actor from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-002';
  begin
    result:=pg_temp.reschedule_act(b.customer_id,b.id,b.fulfillment_revision,operation,'propose',proposal,b.scheduled_start+interval '2 hours');
    begin
      perform pg_temp.reschedule_act(b.customer_id,b.id,b.fulfillment_revision,operation,'propose',proposal,b.scheduled_start+interval '3 hours');
      raise exception 'T-378 operation accepted changed intent';
    exception when invalid_parameter_value then if sqlerrm<>'reschedule_operation_intent_changed' then raise; end if;
    end;
    perform set_config('request.jwt.claims',jsonb_build_object('sub',foreign_actor,'role','authenticated','is_anonymous',false)::text,true);
    execute 'set local role authenticated';
    if exists(select 1 from public.booking_reschedule_proposals where id=proposal)
      or public.get_booking_reschedule_operation(operation) is not null then
      raise exception 'T-378 foreign reader saw a proposal or receipt'; end if;
    begin
      perform public.get_booking_reschedule(b.id);
      raise exception 'T-378 foreign reader saw the booking';
    exception when raise_exception then if sqlerrm<>'booking_not_found' then raise; end if;
    end;
    execute 'reset role';
    perform set_config('request.jwt.claims',jsonb_build_object('sub',b.customer_id,'role','authenticated','is_anonymous',false)::text,true);
    execute 'set local role authenticated';
    begin
      update public.booking_reschedule_proposals set status='accepted' where id=proposal;
      raise exception 'T-378 participant bypassed proposal RPC';
    exception when insufficient_privilege then null;
    end;
    begin
      perform set_config('app.reschedule_proposal',proposal::text,true);
      update public.bookings set scheduled_start=scheduled_start+interval '1 hour' where id=b.id;
      raise exception 'T-378 forged GUC bypassed booking writer';
    exception when insufficient_privilege then null;
    end;
    execute 'reset role';
    raise exception using errcode='ZX001',message='restore access scenario';
  exception when sqlstate 'ZX001' then null;
  end;
  begin
    original_start:=b.scheduled_start;
    perform pg_temp.fulfillment_fixture(b.id,clock_timestamp()-statement_timestamp()+interval '2 seconds','scheduled');
    select * into strict b from public.bookings where id=b.id;
    result:=pg_temp.reschedule_act(b.customer_id,b.id,b.fulfillment_revision,gen_random_uuid(),'propose',proposal,original_start);
    if (result->'proposal'->>'expires_at')::timestamptz is distinct from b.scheduled_start then
      raise exception 'T-378 deadline did not use original service boundary'; end if;
    perform pg_sleep(greatest(0,extract(epoch from b.scheduled_start-clock_timestamp()))+0.1);
    begin
      perform pg_temp.reschedule_act(b.groomer_id,b.id,b.fulfillment_revision,gen_random_uuid(),'accept',proposal);
      raise exception 'T-378 accepted after original service boundary';
    exception when invalid_parameter_value then if sqlerrm<>'reschedule_deadline_passed' then raise; end if;
    end;
    if (select scheduled_start from public.bookings where id=b.id) is distinct from b.scheduled_start then
      raise exception 'T-378 expiry released original agreement'; end if;
    raise exception using errcode='ZX001',message='restore service boundary scenario';
  exception when sqlstate 'ZX001' then null;
  end;
end $$;

do $$
declare b public.bookings%rowtype; proposal uuid:=gen_random_uuid(); operation uuid:=gen_random_uuid(); result jsonb; accepted jsonb;
begin
  select booking.* into strict b from public.bookings booking join public.grooming_requests request on request.id=booking.request_id
    where request.pet_snapshot->>'name'='T376' order by booking.scheduled_start limit 1;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b.customer_id,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  result:=public.mutate_booking_reschedule(b.id,b.fulfillment_revision,operation,'propose',proposal,b.scheduled_start+interval '30 minutes');
  execute 'reset role';
  if (select scheduled_start from public.bookings where id=b.id) is distinct from b.scheduled_start then
    raise exception 'T-378 proposal changed the old reservation'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b.groomer_id,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  accepted:=public.mutate_booking_reschedule(b.id,b.fulfillment_revision,gen_random_uuid(),'accept',proposal,null);
  execute 'reset role';
  if (accepted->'booking'->>'scheduled_start')::timestamptz is distinct from b.scheduled_start+interval '30 minutes'
    or (accepted->'booking'->>'scheduled_end')::timestamptz is distinct from b.scheduled_end+interval '30 minutes'
    or accepted->'booking'->>'id'<>b.id::text
    or (select count(*) from public.bookings where request_id=b.request_id)<>1 then
    raise exception 'T-378 own-overlap reschedule did not preserve one booking'; end if;
  result:=pg_temp.reschedule_act(b.customer_id,b.id,b.fulfillment_revision,operation,'propose',proposal,b.scheduled_start+interval '30 minutes');
  if result->'proposal'->>'effective_status'<>'accepted' or result->'booking' is distinct from accepted->'booking'
    or result->>'replayed'<>'true' then raise exception 'T-378 replay lost original proposal or current booking'; end if;
end $$;

do $$
declare b public.bookings%rowtype; other public.bookings%rowtype; proposal uuid; operation uuid; result jsonb; competing uuid; kind text;
begin
  select booking.* into strict b from public.bookings booking join public.grooming_requests request on request.id=booking.request_id
    where request.pet_snapshot->>'name'='T376' order by booking.scheduled_start limit 1;
  select booking.* into strict other from public.bookings booking join public.grooming_requests request on request.id=booking.request_id
    where request.pet_snapshot->>'name'='T376' and booking.id<>b.id order by booking.scheduled_start limit 1;
  foreach kind in array array['reject','withdraw','expiry','capacity','slot_taken','cancelled'] loop
    begin
      proposal:=gen_random_uuid(); operation:=gen_random_uuid();
      if kind='capacity' then
        update public.groomer_booking_preferences set max_appointments_per_day=1 where groomer_id=b.groomer_id;
        begin
          perform pg_temp.reschedule_act(b.customer_id,b.id,b.fulfillment_revision,operation,'propose',proposal,other.scheduled_end+interval '1 hour');
          raise exception 'T-378 changed date ignored daily quota';
        exception when sqlstate 'PT409' then if sqlerrm<>'reschedule_daily_limit' then raise; end if;
        end;
        result:=pg_temp.reschedule_act(b.customer_id,b.id,b.fulfillment_revision,operation,'propose',proposal,b.scheduled_start+interval '15 minutes');
        perform pg_temp.reschedule_act(b.groomer_id,b.id,b.fulfillment_revision,gen_random_uuid(),'accept',proposal);
      else
        result:=pg_temp.reschedule_act(b.customer_id,b.id,b.fulfillment_revision,operation,'propose',proposal,b.scheduled_start+interval '3 hours');
        begin
          perform pg_temp.reschedule_act(b.customer_id,b.id,b.fulfillment_revision,gen_random_uuid(),'accept',proposal);
          raise exception 'T-378 proposer supplied both consents';
        exception when insufficient_privilege then if sqlerrm<>'reschedule_other_participant_required' then raise; end if;
        end;
        begin
          perform pg_temp.reschedule_act(b.groomer_id,b.id,b.fulfillment_revision,gen_random_uuid(),'propose',gen_random_uuid(),b.scheduled_start+interval '2 hours');
          raise exception 'T-378 two pending proposals accepted';
        exception when sqlstate 'PT409' then if sqlerrm<>'reschedule_proposal_pending' then raise; end if;
        end;
        if kind in ('reject','withdraw') then
          result:=pg_temp.reschedule_act(case kind when 'withdraw' then b.customer_id else b.groomer_id end,
            b.id,b.fulfillment_revision,gen_random_uuid(),kind,proposal);
          if result->'proposal'->>'effective_status' is distinct from (case kind when 'withdraw' then 'withdrawn' else 'rejected' end) then
            raise exception 'T-378 proposal outcome missing'; end if;
        elsif kind='expiry' then
          update public.booking_reschedule_proposals set created_at=clock_timestamp()-interval '2 hours',
            expires_at=clock_timestamp()-interval '1 second' where id=proposal;
          begin
            perform pg_temp.reschedule_act(b.groomer_id,b.id,b.fulfillment_revision,gen_random_uuid(),'accept',proposal);
            raise exception 'T-378 expired proposal accepted';
          exception when invalid_parameter_value then if sqlerrm<>'reschedule_deadline_passed' then raise; end if;
          end;
        elsif kind='slot_taken' then
          competing:=gen_random_uuid();
          perform pg_temp.reschedule_act(other.customer_id,other.id,other.fulfillment_revision,gen_random_uuid(),'propose',competing,b.scheduled_start+interval '3 hours');
          perform pg_temp.reschedule_act(other.groomer_id,other.id,other.fulfillment_revision,gen_random_uuid(),'accept',competing);
          begin
            perform pg_temp.reschedule_act(b.groomer_id,b.id,b.fulfillment_revision,gen_random_uuid(),'accept',proposal);
            raise exception 'T-378 acceptance ignored another booking taking the slot';
          exception when sqlstate 'PT409' then if sqlerrm<>'reschedule_resource_conflict' then raise; end if;
          end;
        else
          perform set_config('request.jwt.claims',jsonb_build_object('sub',b.customer_id,'role','authenticated','is_anonymous',false)::text,true);
          execute 'set local role authenticated';
          perform public.mutate_booking_fulfillment(b.id,b.fulfillment_revision,gen_random_uuid(),'cancel');
          execute 'reset role';
          begin
            perform pg_temp.reschedule_act(b.groomer_id,b.id,b.fulfillment_revision,gen_random_uuid(),'accept',proposal);
            raise exception 'T-378 proposal revived a cancelled booking';
          exception when sqlstate 'PT409' then if sqlerrm<>'booking_revision_changed' then raise; end if;
          end;
        end if;
        if (select scheduled_start from public.bookings where id=b.id) is distinct from b.scheduled_start then
          raise exception 'T-378 non-accepting action changed original time'; end if;
      end if;
      raise exception using errcode='ZX001',message='restore isolated scenario';
    exception when sqlstate 'ZX001' then null;
    end;
  end loop;
end $$;
