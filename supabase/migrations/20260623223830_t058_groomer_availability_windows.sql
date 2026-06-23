-- T-058 groomer account/profile/availability rework.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create table public.groomer_availability_windows (
  id uuid primary key default gen_random_uuid(),
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  weekday smallint not null,
  start_time time not null,
  end_time time not null,
  is_enabled boolean not null default true,
  timezone text not null default 'America/Los_Angeles',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groomer_availability_weekday_check check (
    weekday between 1 and 7
  ),
  constraint groomer_availability_time_window_check check (
    start_time < end_time
  ),
  constraint groomer_availability_timezone_check check (
    timezone = btrim(timezone)
    and char_length(timezone) between 1 and 80
  ),
  constraint groomer_availability_groomer_weekday_key unique (
    groomer_id,
    weekday
  )
);

comment on table public.groomer_availability_windows is
  'Groomer-owned weekly availability windows. T-058 stores one window per weekday for profile availability editing.';
comment on column public.groomer_availability_windows.weekday is
  'ISO weekday number: Monday=1 through Sunday=7.';
comment on column public.groomer_availability_windows.is_enabled is
  'Disabled rows preserve a groomer-chosen time range without making the day available.';

create index groomer_availability_groomer_enabled_weekday_idx
on public.groomer_availability_windows (groomer_id, is_enabled, weekday);

create trigger groomer_availability_set_updated_at
before update on public.groomer_availability_windows
for each row execute function app_private.set_updated_at();

alter table public.groomer_availability_windows enable row level security;

revoke all on table public.groomer_availability_windows
from public, anon, authenticated;

grant select, insert, update, delete
on table public.groomer_availability_windows
to authenticated;

grant select, insert, update, delete
on table public.groomer_availability_windows
to service_role;

create policy groomer_availability_select_own
on public.groomer_availability_windows
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

create policy groomer_availability_insert_own
on public.groomer_availability_windows
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

create policy groomer_availability_update_own
on public.groomer_availability_windows
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
)
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

create policy groomer_availability_delete_own
on public.groomer_availability_windows
for delete
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);
