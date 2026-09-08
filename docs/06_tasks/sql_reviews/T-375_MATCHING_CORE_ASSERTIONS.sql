-- Pure interval/eligibility vectors; caller owns BEGIN/ROLLBACK.
do $$
declare
  w tstzrange := tstzrange('2026-09-09 09:00Z','2026-09-09 12:00Z','[)');
  free tstzmultirange := tstzmultirange(w);
  occupied tstzmultirange;
  result record;
begin
  if app_private.match_service_size('M',array['S']) <> 'excluded'
    or app_private.match_service_size('M',array['M','L']) <> 'eligible'
    or app_private.match_service_size('M',array[]::text[]) <> 'assessment_required'
    or app_private.match_service_size(null,array['M']) <> 'assessment_required'
    or app_private.match_service_size('unknown',array['M']) <> 'assessment_required'
    or app_private.match_service_size('Giant',array['Giant']) <> 'eligible' then
    raise exception 'accepted-size eligibility does not match declared semantics';
  end if;

  -- A single booking can fill a day even below its appointment count limit.
  select * into result from app_private.match_service_interval(w,free,free,60,0,0,lower(w));
  if found then raise exception 'fully occupied preference matched'; end if;

  occupied := tstzmultirange(tstzrange('2026-09-09 09:40Z','2026-09-09 10:00Z','[)'),
    tstzrange('2026-09-09 10:40Z','2026-09-09 11:00Z','[)'),
    tstzrange('2026-09-09 11:40Z','2026-09-09 12:00Z','[)'));
  select * into result from app_private.match_service_interval(w,free,occupied,60,0,0,lower(w));
  if found then raise exception 'fragmented gaps were added into a continuous hour'; end if;

  occupied := tstzmultirange(tstzrange('2026-09-09 09:00Z','2026-09-09 10:00Z','[)'));
  select * into result from app_private.match_service_interval(w,free,occupied,60,0,0,lower(w));
  if not found or result.service_start <> '2026-09-09 10:00Z'::timestamptz
    or result.service_end <> '2026-09-09 11:00Z'::timestamptz then
    raise exception 'short service inside broad preference not found';
  end if;

  select * into result from app_private.match_service_interval(w,free,occupied,60,15,10,lower(w));
  if not found or result.service_start <> '2026-09-09 10:15Z'::timestamptz
    or result.occupied_start <> '2026-09-09 10:00Z'::timestamptz
    or result.occupied_end <> '2026-09-09 11:25Z'::timestamptz then
    raise exception 'buffers not included in feasible interval';
  end if;

  select * into result from app_private.match_service_interval(w,free,'{}',60,0,0,'2026-09-09 11:00Z');
  if not found or result.service_end <> upper(w) then raise exception 'touching exclusive end rejected'; end if;
  select * into result from app_private.match_service_interval(w,free,'{}',60,0,0,'2026-09-09 11:00:00.001Z');
  if found then raise exception 'outside preference end accepted'; end if;
  select * into result from app_private.match_service_interval(w,free,'{}',null,0,0,lower(w));
  if found then raise exception 'unknown duration became exact fit'; end if;
end $$;

do $$
declare
  starts time[] := array_fill('01:15'::time,array[7]);
  ends time[] := array_fill('01:45'::time,array[7]);
  available tstzmultirange;
  expected tstzmultirange;
begin
  available := app_private.match_weekly_ranges('2026-11-01 05:00Z','2026-11-01 07:00Z',
    'America/New_York',starts,ends);
  expected := tstzmultirange(tstzrange('2026-11-01 05:15Z','2026-11-01 05:45Z','[)'),
    tstzrange('2026-11-01 06:15Z','2026-11-01 06:45Z','[)'));
  if available is distinct from expected then raise exception 'fall repeat includes a closed real-time gap'; end if;
  available := app_private.match_weekly_ranges('2027-03-14 06:00Z','2027-03-14 08:00Z',
    'America/New_York',array_fill('02:30'::time,array[7]),array_fill('03:30'::time,array[7]));
  expected := tstzmultirange(tstzrange('2027-03-14 07:00Z','2027-03-14 07:30Z','[)'));
  if available is distinct from expected then raise exception 'spring gap shifts opening incorrectly'; end if;
  available := app_private.match_weekly_ranges('2026-09-09 09:00:00.25Z','2026-09-09 09:00:02.75Z',
    'UTC',array_fill('09:00:00.5'::time,array[7]),array_fill('09:00:02.5'::time,array[7]));
  expected := tstzmultirange(tstzrange('2026-09-09 09:00:00.5Z','2026-09-09 09:00:02.5Z','[)'));
  if available is distinct from expected then raise exception 'fractional schedule boundaries changed'; end if;
end $$;
