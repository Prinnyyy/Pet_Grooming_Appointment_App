-- Reuse the exact second grid; avoid constructing thousands of equivalent ranges.
-- Offset-changing windows retain the existing DST oracle without approximation.
create or replace function app_private.match_weekly_ranges_validated(
  p_start timestamptz,p_end timestamptz,p_zone text,p_starts time[],p_ends time[]
)
returns tstzmultirange language plpgsql stable set search_path = ''
as $$
declare lowest_offset interval; highest_offset interval;
begin
  if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end)
    or p_start>=p_end or p_end-p_start>interval '3 days'
    or cardinality(p_starts) is distinct from 7 or cardinality(p_ends) is distinct from 7 then
    return null;
  end if;
  select min(offset_value),max(offset_value) into lowest_offset,highest_offset
  from (
    select timezone(p_zone,t)-timezone('UTC',t) offset_value
    from generate_series(date_trunc('second',p_start),p_end,interval '1 second') t
  ) offsets;
  if lowest_offset=highest_offset then
    return (
      with days as (
        select day::date d,extract(isodow from day)::integer weekday
        from generate_series(timezone(p_zone,p_start)::date::timestamp,
          timezone(p_zone,p_end)::date::timestamp,interval '1 day') day
      ), bounds as (
        select greatest(p_start,timezone('UTC',d+p_starts[weekday]-lowest_offset)) a,
          least(p_end,timezone('UTC',d+p_ends[weekday]-lowest_offset)) b
        from days where p_starts[weekday] is not null and p_ends[weekday] is not null
      )
      select coalesce(range_agg(tstzrange(a,b,'[)')),'{}'::tstzmultirange) from bounds where a<b
    );
  end if;
  return (
    with wall as materialized (
      select t,timezone(p_zone,t) as local_time
      from generate_series(date_trunc('second',p_start),p_end,interval '1 second') t
      where t<p_end
    ), bounds as (
      select greatest(t,p_start,t+((local_time::date+p_starts[extract(isodow from local_time)::integer])-local_time)) a,
        least(t+interval '1 second',p_end,
          t+((local_time::date+p_ends[extract(isodow from local_time)::integer])-local_time)) b
      from wall
      where p_starts[extract(isodow from local_time)::integer] is not null
        and p_ends[extract(isodow from local_time)::integer] is not null
    )
    select coalesce(range_agg(case when a<b then tstzrange(a,b,'[)') end),'{}'::tstzmultirange)
      from bounds
  );
end $$;
revoke all on function app_private.match_weekly_ranges_validated(timestamptz,timestamptz,text,time[],time[])
  from public,anon,authenticated,service_role;
