-- Caller owns BEGIN/ROLLBACK and runs T-376_AGREEMENT_ASSERTIONS.sql first.
do $$
declare c uuid; g uuid; foreign_c uuid; r uuid; b public.bookings;
  notice uuid:=gen_random_uuid(); unread_notice uuid:=gen_random_uuid(); match_notice uuid:=gen_random_uuid(); matched public.request_matches;
  before_booking jsonb; read_time timestamptz;
begin
  select id into strict c from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict g from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict foreign_c from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-002';
  select * into strict b from public.bookings where customer_id=c and groomer_id=g and status='confirmed' order by id limit 1;
  before_booking:=to_jsonb(b);
  select id into strict r from public.grooming_requests where customer_id=c and pet_snapshot->>'name'='T376' and status='open' order by id limit 1;
  insert into public.request_matches(request_id,customer_id,groomer_id,status,eligibility_evaluation)
    values(r,c,g,'visible',null) on conflict(request_id,groomer_id) do update set status='visible',eligibility_evaluation=null;
  insert into public.customer_notifications(id,customer_id,kind,title,body,related_booking_id,related_request_id)
    values(notice,c,'booking_confirmed','T381 notification','T381 independent read',b.id,b.request_id);
  insert into public.groomer_notifications(id,groomer_id,kind,title,body,related_request_id)
    values(match_notice,g,'new_match','T381 match','T381 exact match',r);
  insert into public.customer_notifications(id,customer_id,kind,title,body,related_booking_id,related_request_id)
    values(unread_notice,c,'booking_confirmed','T381 unread','T381 independent acknowledgement',b.id,b.request_id);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  perform public.mark_customer_notification_read(notice);
  if exists(select 1 from public.customer_booking_handoff_acknowledgements where request_id=b.request_id) then
    raise exception 'T381 reading notification acknowledged booking'; end if;
  perform public.acknowledge_booking_handoff(b.request_id,b.id);
  if (select is_read from public.customer_notifications where id=unread_notice) then
    raise exception 'T381 acknowledgement read an independent notification'; end if;
  select acknowledged_at into strict read_time from public.customer_booking_handoff_acknowledgements where request_id=b.request_id;
  execute 'reset role';
  -- A second independently identified auth session reads the same authoritative record.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','session_id',gen_random_uuid(),'is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  perform public.acknowledge_booking_handoff(b.request_id,b.id);
  if not exists(select 1 from public.customer_booking_handoff_acknowledgements where request_id=b.request_id and acknowledged_at=read_time) then
    raise exception 'T381 acknowledgement replay changed record'; end if;
  execute 'reset role';
  if (select to_jsonb(x) from public.bookings x where id=b.id) is distinct from before_booking then
    raise exception 'T381 read or acknowledgement changed fulfillment'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',g,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  select * into strict matched from public.get_my_matched_request(g,r);
  if matched.eligibility_evaluation->>'state'<>'pending' then raise exception 'T381 pending refresh exposed stale eligibility'; end if;
  if exists(select 1 from public.get_my_matched_request(g,gen_random_uuid())) then raise exception 'T381 missing request exposed another match'; end if;
  perform public.mark_groomer_notification_read(match_notice);
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  perform public.cancel_grooming_request(r);
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',g,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  if exists(select 1 from public.get_my_matched_request(g,r)) then raise exception 'T381 cancelled notification target remained offerable'; end if;
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',foreign_c,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  begin
    perform public.get_my_matched_request(g,r);
    raise exception 'T381 foreign actor read match';
  exception when insufficient_privilege then null; end;
  begin
    perform public.mark_customer_notification_read(notice);
    raise exception 'T381 foreign actor marked notification';
  exception when raise_exception then if sqlerrm<>'notification_not_found' then raise; end if; end;
  begin
    perform public.acknowledge_booking_handoff(b.request_id,b.id);
    raise exception 'T381 foreign actor acknowledged booking';
  exception when raise_exception then if sqlerrm<>'booking_handoff_not_found' then raise; end if; end;
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',g,'role','authenticated','is_anonymous',true)::text,true);
  execute 'set local role authenticated';
  begin
    perform public.get_my_matched_request(g,r);
    raise exception 'T381 anonymous actor read match';
  exception when insufficient_privilege then null; end;
  execute 'reset role';
end $$;
