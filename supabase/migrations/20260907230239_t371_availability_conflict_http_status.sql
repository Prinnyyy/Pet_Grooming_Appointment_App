-- An expired client revision is a permanent business conflict, not a
-- serialization failure that PostgREST/Hasql should retry automatically.
begin;
create or replace function public.save_groomer_availability(
  p_expected_revision text, p_windows jsonb, p_preferences jsonb, p_time_off jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_message text;
begin
  return app_private.save_groomer_availability(
    p_expected_revision, p_windows, p_preferences, p_time_off);
exception when serialization_failure then
  get stacked diagnostics v_message = message_text;
  if v_message = 'availability_revision_conflict' then
    raise exception using errcode = 'PT409', message = v_message;
  end if;
  raise;
end;
$$;
notify pgrst, 'reload schema';
commit;
