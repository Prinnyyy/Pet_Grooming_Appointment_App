-- T-060 groomer availability booking preferences and time off.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create table public.groomer_booking_preferences (
  groomer_id uuid primary key
    references public.groomer_profiles (user_id) on delete cascade,
  max_appointments_per_day smallint not null default 4,
  minimum_advance_notice_days smallint not null default 0,
  auto_accept_bookings boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groomer_booking_preferences_max_daily_check check (
    max_appointments_per_day between 1 and 12
  ),
  constraint groomer_booking_preferences_notice_check check (
    minimum_advance_notice_days between 0 and 2
  )
);

comment on table public.groomer_booking_preferences is
  'Groomer-owned availability booking preferences. T-060 stores the editable Availability screen booking preference controls.';
comment on column public.groomer_booking_preferences.minimum_advance_notice_days is
  '0 means same-day requests are allowed; 1 and 2 match the current groomer Availability UI options.';

create trigger groomer_booking_preferences_set_updated_at
before update on public.groomer_booking_preferences
for each row execute function app_private.set_updated_at();

alter table public.groomer_booking_preferences enable row level security;

revoke all on table public.groomer_booking_preferences
from public, anon, authenticated;

grant select, insert, update, delete
on table public.groomer_booking_preferences
to authenticated;

grant select, insert, update, delete
on table public.groomer_booking_preferences
to service_role;

create policy groomer_booking_preferences_select_own
on public.groomer_booking_preferences
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

create policy groomer_booking_preferences_insert_own
on public.groomer_booking_preferences
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

create policy groomer_booking_preferences_update_own
on public.groomer_booking_preferences
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

create policy groomer_booking_preferences_delete_own
on public.groomer_booking_preferences
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

create table public.groomer_time_off_windows (
  id uuid primary key default gen_random_uuid(),
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  title text not null,
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groomer_time_off_title_check check (
    title = btrim(title)
    and char_length(title) between 1 and 80
  ),
  constraint groomer_time_off_date_window_check check (
    start_date <= end_date
  )
);

comment on table public.groomer_time_off_windows is
  'Groomer-owned unavailable date windows. T-060 stores Availability screen time off rows; booking conflict integration is deferred.';

create index groomer_time_off_groomer_start_idx
on public.groomer_time_off_windows (groomer_id, start_date, end_date);

create trigger groomer_time_off_set_updated_at
before update on public.groomer_time_off_windows
for each row execute function app_private.set_updated_at();

alter table public.groomer_time_off_windows enable row level security;

revoke all on table public.groomer_time_off_windows
from public, anon, authenticated;

grant select, insert, update, delete
on table public.groomer_time_off_windows
to authenticated;

grant select, insert, update, delete
on table public.groomer_time_off_windows
to service_role;

create policy groomer_time_off_select_own
on public.groomer_time_off_windows
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

create policy groomer_time_off_insert_own
on public.groomer_time_off_windows
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

create policy groomer_time_off_update_own
on public.groomer_time_off_windows
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

create policy groomer_time_off_delete_own
on public.groomer_time_off_windows
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
