-- Caller owns BEGIN/ROLLBACK and runs T-376_AGREEMENT_ASSERTIONS.sql first.
do $$
declare c uuid; g uuid; foreign_c uuid; b public.bookings; snapshot jsonb;
begin
  select id into strict c from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-001';
  select id into strict g from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select id into strict foreign_c from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTC-002';
  select * into strict b from public.bookings where customer_id=c and groomer_id=g and status='confirmed' order by id limit 1;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  snapshot:=public.get_my_reminder_snapshot(c,'customer');
  if snapshot->>'complete'<>'true' or snapshot->>'participant_id'<>c::text
    or (snapshot->>'horizon_end')::timestamptz-(snapshot->>'as_of')::timestamptz<>interval '30 days'
    or not exists(select 1 from jsonb_array_elements(snapshot->'bookings') x where x->>'id'=b.id::text) then
    raise exception 'T382 missing owned complete future booking'; end if;
  if exists(select 1 from jsonb_array_elements(snapshot->'bookings') x where x ? 'agreement_snapshot' or x ? 'street_address') then
    raise exception 'T382 snapshot contains unnecessary private payload'; end if;
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',g,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  snapshot:=public.get_my_reminder_snapshot(g,'groomer');
  if not exists(select 1 from jsonb_array_elements(snapshot->'bookings') x where x->>'id'=b.id::text) then
    raise exception 'T382 groomer snapshot missed booking'; end if;
  perform public.mutate_booking_fulfillment(b.id,b.fulfillment_revision,gen_random_uuid(),'cancel',null);
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  snapshot:=public.get_my_reminder_snapshot(c,'customer');
  if exists(select 1 from jsonb_array_elements(snapshot->'bookings') x where x->>'id'=b.id::text) then
    raise exception 'T382 other-party cancellation remained eligible'; end if;
  begin
    perform public.get_my_reminder_snapshot(foreign_c,'customer');
    raise exception 'T382 foreign participant accepted';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_my_reminder_snapshot(c,'groomer');
    raise exception 'T382 spoofed role accepted';
  exception when insufficient_privilege then null; end;
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',true)::text,true);
  execute 'set local role authenticated';
  begin
    perform public.get_my_reminder_snapshot(c,'customer');
    raise exception 'T382 anonymous participant accepted';
  exception when insufficient_privilege then null; end;
  execute 'reset role';
end $$;
