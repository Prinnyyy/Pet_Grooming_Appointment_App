-- T-004 reviewed draft. Not yet applied.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create type public.user_role as enum ('customer', 'groomer');

comment on type public.user_role is
  'Immutable marketplace role selected during onboarding.';

create schema app_private;

revoke all on schema app_private from public, anon, authenticated;

create function app_private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = statement_timestamp();
  return new;
end;
$$;

revoke all on function app_private.set_updated_at()
from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null,
  display_name text not null,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_check check (
    display_name = btrim(display_name)
    and char_length(display_name) between 1 and 80
  ),
  constraint profiles_avatar_path_check check (
    avatar_path is null
    or (
      char_length(avatar_path) <= 512
      and split_part(avatar_path, '/', 1) = id::text
      and split_part(avatar_path, '/', 2) <> ''
      and array_length(string_to_array(avatar_path, '/'), 1) = 2
      and lower(avatar_path) ~ '\\.(jpe?g|png|heic|heif)$'
    )
  )
);

comment on table public.profiles is
  'Auth identity mapping and shared profile fields. Role is client-immutable after insert.';

create table public.customer_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.customer_profiles is
  'Customer role marker and extension point for later customer-specific fields.';

create table public.groomer_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.groomer_profiles is
  'Groomer role marker; detailed marketplace fields are owned by T-010.';

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function app_private.set_updated_at();

create trigger customer_profiles_set_updated_at
before update on public.customer_profiles
for each row execute function app_private.set_updated_at();

create trigger groomer_profiles_set_updated_at
before update on public.groomer_profiles
for each row execute function app_private.set_updated_at();

alter table public.profiles enable row level security;
alter table public.customer_profiles enable row level security;
alter table public.groomer_profiles enable row level security;

revoke all on type public.user_role from public, anon, authenticated;
grant usage on type public.user_role to authenticated, service_role;

revoke all on table public.profiles from public, anon, authenticated;
revoke all on table public.customer_profiles from public, anon, authenticated;
revoke all on table public.groomer_profiles from public, anon, authenticated;

grant select on table public.profiles to authenticated;
grant insert (id, role, display_name, avatar_path)
  on table public.profiles to authenticated;
grant update (display_name, avatar_path)
  on table public.profiles to authenticated;

grant select on table public.customer_profiles to authenticated;
grant insert (user_id) on table public.customer_profiles to authenticated;

grant select on table public.groomer_profiles to authenticated;
grant insert (user_id) on table public.groomer_profiles to authenticated;

grant select, insert, update, delete
  on table public.profiles, public.customer_profiles, public.groomer_profiles
  to service_role;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and id = (select auth.uid())
);

create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and id = (select auth.uid())
);

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and id = (select auth.uid())
)
with check (
  (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and id = (select auth.uid())
);

create policy customer_profiles_select_own
on public.customer_profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and user_id = (select auth.uid())
);

create policy customer_profiles_insert_own_role
on public.customer_profiles
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and user_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'customer'::public.user_role
  )
);

create policy groomer_profiles_select_own
on public.groomer_profiles
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and user_id = (select auth.uid())
);

create policy groomer_profiles_insert_own_role
on public.groomer_profiles
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and user_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'groomer'::public.user_role
  )
);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'avatars',
  'avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']::text[]
);

create policy avatars_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy avatars_insert_own_folder
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'heic', 'heif')
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
  )
);

create policy avatars_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'heic', 'heif')
);

create policy avatars_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (select auth.uid()) is not null
  and not coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false)
  and owner_id = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
