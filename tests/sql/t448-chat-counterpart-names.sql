begin read only;
do $test$
declare c record; actual text; expected text; unknown_id uuid := gen_random_uuid();
begin
  if has_function_privilege('anon', 'public.get_chat_counterpart_names(uuid[])', 'execute') then
    raise exception 'anonymous execution must be revoked';
  end if;
  select cv.* into c from public.conversations cv
    join public.profiles customer on customer.id=cv.customer_id
    join public.profiles groomer on groomer.id=cv.groomer_id limit 1;
  if not found then raise exception 'participant fixture required'; end if;

  perform set_config('request.jwt.claims', jsonb_build_object('sub',c.customer_id,'role','authenticated','is_anonymous',false)::text,true);
  set local role authenticated;
  select display_name into actual from public.get_chat_counterpart_names(array[c.id]);
  reset role;
  select nullif(btrim(display_name),'') into expected from public.profiles where id=c.groomer_id;
  if actual is distinct from expected then raise exception 'customer must see groomer name'; end if;

  perform set_config('request.jwt.claims', jsonb_build_object('sub',c.groomer_id,'role','authenticated','is_anonymous',false)::text,true);
  set local role authenticated;
  select display_name into actual from public.get_chat_counterpart_names(array[c.id]);
  reset role;
  select nullif(btrim(display_name),'') into expected from public.profiles where id=c.customer_id;
  if actual is distinct from expected then raise exception 'groomer must see customer name'; end if;

  set local role authenticated;
  begin
    perform public.get_chat_counterpart_names(array[c.id, unknown_id]);
    raise exception 'mixed inaccessible scope must fail atomically';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_chat_counterpart_names(array[null::uuid]);
    raise exception 'null element must fail';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.get_chat_counterpart_names(array_fill(c.id, array[101]));
    raise exception 'oversized scope must fail';
  exception when invalid_parameter_value then null; end;
  reset role;

  perform set_config('request.jwt.claims', jsonb_build_object('sub',unknown_id,'role','authenticated','is_anonymous',false)::text,true);
  set local role authenticated;
  begin
    perform public.get_chat_counterpart_names(array[c.id]);
    raise exception 'outsider must not see a name';
  exception when insufficient_privilege then null; end;
  reset role;

  perform set_config('request.jwt.claims', jsonb_build_object('sub',c.customer_id,'role','authenticated','is_anonymous',true)::text,true);
  set local role authenticated;
  begin
    perform public.get_chat_counterpart_names(array[c.id]);
    raise exception 'anonymous identity must fail';
  exception when insufficient_privilege then null; end;
  reset role;
end;
$test$;
select 'T448 participant names and negative authorization checks passed; no data written' as result;
rollback;
