-- Pure timing vectors. The runner wraps definitions and assertions in one rollback transaction.
set local timezone = 'Pacific/Auckland';
do $$
declare
  v record;
begin
  select * into strict v from app_private.service_timing_allocation(
    '2026-09-07T18:00:00Z',60,15,10,30,20,'groomer_comes_to_customer');
  if v.service_end <> '2026-09-07T19:00:00Z'::timestamptz
    or v.occupied_start <> '2026-09-07T17:15:00Z'::timestamptz
    or v.occupied_end <> '2026-09-07T19:30:00Z'::timestamptz then
    raise exception 'mobile_allocation_mismatch';
  end if;
  select * into strict v from app_private.service_timing_allocation(
    '2026-09-07T18:00:00Z',60,15,10,30,20,'customer_comes_to_groomer');
  if v.occupied_start <> '2026-09-07T17:45:00Z'::timestamptz
    or v.occupied_end <> '2026-09-07T19:10:00Z'::timestamptz then
    raise exception 'customer_travel_reserved_groomer_time';
  end if;
  select * into strict v from app_private.service_timing_allocation(
    '2026-03-08T09:30:00Z',60,0,0,0,0,'groomer_comes_to_customer');
  if v.service_end <> '2026-03-08T10:30:00Z'::timestamptz then
    raise exception 'duration_is_not_elapsed_time';
  end if;
  if app_private.service_timing_earliest_start('2026-03-08T07:30:00Z',1,'America/Los_Angeles')
      <> '2026-03-08T08:00:00Z'::timestamptz
    or app_private.service_timing_earliest_start('2026-03-08T07:30:00Z',2,'America/Los_Angeles')
      <> '2026-03-09T07:00:00Z'::timestamptz
    or app_private.service_timing_earliest_start('2026-09-07T17:00:00Z',0,'America/Los_Angeles')
      <> '2026-09-07T17:05:00Z'::timestamptz then
    raise exception 'calendar_notice_mismatch';
  end if;
  select * into strict v from app_private.remaining_service_window(
    '2026-09-07T13:00:00Z','2026-09-07T18:59:00Z','2026-09-07T17:00:00Z');
  if v.window_start <> '2026-09-07T17:05:00Z'::timestamptz
    or v.window_end <> '2026-09-07T18:59:00Z'::timestamptz then
    raise exception 'remaining_window_mismatch';
  end if;
  if exists(select 1 from app_private.remaining_service_window(
    '2026-09-07T13:00:00Z','2026-09-07T17:05:00Z','2026-09-07T17:00:00Z')) then
    raise exception 'empty_remaining_window_accepted';
  end if;
  begin
    perform app_private.service_timing_allocation('2026-09-07T18:00:00Z',14,0,0,0,0,'groomer_comes_to_customer');
    raise exception 'invalid_duration_accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform app_private.service_timing_allocation('2026-09-07T18:00:00Z',60,121,0,0,0,'groomer_comes_to_customer');
    raise exception 'invalid_buffer_accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform app_private.service_timing_earliest_start('2026-09-07T18:00:00Z',0,'Not/A_Zone');
    raise exception 'invalid_zone_accepted';
  exception when sqlstate '22023' then null;
  end;
  if has_function_privilege('authenticated',
    'app_private.service_timing_allocation(timestamptz,integer,integer,integer,integer,integer,text)','execute')
    or has_function_privilege('anon',
    'app_private.service_timing_earliest_start(timestamptz,integer,text)','execute') then
    raise exception 'private_helper_exposed';
  end if;
end $$;
select 'T-374 timing core vectors passed' as result;
