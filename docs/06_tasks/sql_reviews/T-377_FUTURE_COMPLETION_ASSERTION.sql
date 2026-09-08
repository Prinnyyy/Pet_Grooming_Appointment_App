-- Caller first creates rollback-only T-376 named fixtures, then rolls back everything.
do $$
declare g uuid; target uuid;
begin
  select id into strict g from auth.users where raw_app_meta_data->>'beckon_seed_id'='BTG-001';
  select b.id into strict target from public.bookings b join public.grooming_requests r on r.id=b.request_id
    where b.groomer_id=g and b.status='confirmed' and b.scheduled_start>statement_timestamp()
      and r.pet_snapshot->>'name'='T376' order by b.scheduled_start limit 1;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',g,'role','authenticated','is_anonymous',false)::text,true);
  execute 'set local role authenticated';
  begin
    perform public.complete_booking(target);
    raise exception 'T-377 future booking completed without service evidence';
  exception when invalid_parameter_value then
    if sqlerrm<>'updated_fulfillment_client_required' then raise; end if;
  end;
  execute 'reset role';
end $$;
