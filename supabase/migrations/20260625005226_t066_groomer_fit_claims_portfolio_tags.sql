-- T-066 groomer pet-fit claims and portfolio tags.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

grant execute on function app_private.pet_fit_normalized_text(text)
to authenticated;
grant execute on function app_private.pet_fit_valid_trait_pair(text, text)
to authenticated;

alter table public.groomer_portfolio_photos
  add constraint groomer_portfolio_photos_id_groomer_id_key unique (
    id,
    groomer_id
  );

create table public.groomer_fit_claims (
  id uuid primary key default gen_random_uuid(),
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  trait_type text not null,
  trait_value text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groomer_fit_claims_trait_check check (
    app_private.pet_fit_valid_trait_pair(trait_type, trait_value)
    and (
      (
        trait_type = 'breed_group'
        and trait_value in ('poodle', 'terrier')
      )
      or (
        trait_type = 'size_band'
        and trait_value in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
      )
      or (
        trait_type = 'care_flag'
        and trait_value in ('anxious', 'senior')
      )
      or (
        trait_type = 'service_fit'
        and trait_value in (
          'curly_coat',
          'terrier_coat',
          'gentle_handling',
          'senior_care'
        )
      )
    )
  ),
  constraint groomer_fit_claims_groomer_trait_key unique (
    groomer_id,
    trait_type,
    trait_value
  )
);

comment on table public.groomer_fit_claims is
  'Groomer-owned low-confidence pet-fit claims. Claims are not evidence-backed expertise and do not change matching until a later task consumes them.';
comment on column public.groomer_fit_claims.trait_type is
  'Canonical T-065 trait type: breed_group, size_band, care_flag, or service_fit.';
comment on column public.groomer_fit_claims.trait_value is
  'Canonical T-065 trait value for the selected trait_type.';
comment on column public.groomer_fit_claims.is_active is
  'Owner-managed visibility flag. Only active claims for active groomers are readable by other authenticated users.';

create table public.groomer_portfolio_fit_tags (
  id uuid primary key default gen_random_uuid(),
  portfolio_photo_id uuid not null,
  groomer_id uuid not null,
  trait_type text not null,
  trait_value text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groomer_portfolio_fit_tags_photo_fkey foreign key (
    portfolio_photo_id,
    groomer_id
  ) references public.groomer_portfolio_photos (
    id,
    groomer_id
  ) on delete cascade,
  constraint groomer_portfolio_fit_tags_trait_check check (
    app_private.pet_fit_valid_trait_pair(trait_type, trait_value)
    and (
      (
        trait_type = 'breed_group'
        and trait_value in ('poodle', 'terrier')
      )
      or (
        trait_type = 'size_band'
        and trait_value in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
      )
      or (
        trait_type = 'care_flag'
        and trait_value in ('anxious', 'senior')
      )
      or (
        trait_type = 'service_fit'
        and trait_value in (
          'curly_coat',
          'terrier_coat',
          'gentle_handling',
          'senior_care'
        )
      )
    )
  ),
  constraint groomer_portfolio_fit_tags_photo_trait_key unique (
    portfolio_photo_id,
    trait_type,
    trait_value
  )
);

comment on table public.groomer_portfolio_fit_tags is
  'Optional groomer-owned pet-fit tags attached to portfolio photos as lightweight visual evidence for later matching work.';
comment on column public.groomer_portfolio_fit_tags.portfolio_photo_id is
  'Existing groomer portfolio photo metadata row. Deleting the photo deletes its fit tags.';
comment on column public.groomer_portfolio_fit_tags.trait_type is
  'Canonical T-065 trait type: breed_group, size_band, care_flag, or service_fit.';
comment on column public.groomer_portfolio_fit_tags.trait_value is
  'Canonical T-065 trait value for the selected trait_type.';

create index groomer_fit_claims_active_trait_idx
on public.groomer_fit_claims (trait_type, trait_value, groomer_id)
where is_active;

create index groomer_portfolio_fit_tags_groomer_trait_idx
on public.groomer_portfolio_fit_tags (groomer_id, trait_type, trait_value);

create trigger groomer_fit_claims_set_updated_at
before update on public.groomer_fit_claims
for each row execute function app_private.set_updated_at();

create trigger groomer_portfolio_fit_tags_set_updated_at
before update on public.groomer_portfolio_fit_tags
for each row execute function app_private.set_updated_at();

alter table public.groomer_fit_claims enable row level security;
alter table public.groomer_portfolio_fit_tags enable row level security;

revoke all on table public.groomer_fit_claims
from public, anon, authenticated;
revoke all on table public.groomer_portfolio_fit_tags
from public, anon, authenticated;

grant select on table public.groomer_fit_claims to authenticated;
grant insert (
  groomer_id,
  trait_type,
  trait_value,
  is_active
) on table public.groomer_fit_claims to authenticated;
grant update (
  trait_type,
  trait_value,
  is_active
) on table public.groomer_fit_claims to authenticated;
grant delete on table public.groomer_fit_claims to authenticated;

grant select on table public.groomer_portfolio_fit_tags to authenticated;
grant insert (
  portfolio_photo_id,
  groomer_id,
  trait_type,
  trait_value
) on table public.groomer_portfolio_fit_tags to authenticated;
grant update (
  trait_type,
  trait_value
) on table public.groomer_portfolio_fit_tags to authenticated;
grant delete on table public.groomer_portfolio_fit_tags to authenticated;

grant select, insert, update, delete
on table public.groomer_fit_claims, public.groomer_portfolio_fit_tags
to service_role;

create policy groomer_fit_claims_select_own
on public.groomer_fit_claims
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
);

create policy groomer_fit_claims_select_active_groomer
on public.groomer_fit_claims
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and is_active
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = groomer_fit_claims.groomer_id
      and is_active
  )
);

create policy groomer_fit_claims_insert_own
on public.groomer_fit_claims
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

create policy groomer_fit_claims_update_own
on public.groomer_fit_claims
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

create policy groomer_fit_claims_delete_own
on public.groomer_fit_claims
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

create policy groomer_portfolio_fit_tags_select_own
on public.groomer_portfolio_fit_tags
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
);

create policy groomer_portfolio_fit_tags_select_active_groomer
on public.groomer_portfolio_fit_tags
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = groomer_portfolio_fit_tags.groomer_id
      and is_active
  )
);

create policy groomer_portfolio_fit_tags_insert_own
on public.groomer_portfolio_fit_tags
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
  and exists (
    select 1
    from public.groomer_portfolio_photos
    where id = groomer_portfolio_fit_tags.portfolio_photo_id
      and groomer_id = (select auth.uid())
  )
);

create policy groomer_portfolio_fit_tags_update_own
on public.groomer_portfolio_fit_tags
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
  and exists (
    select 1
    from public.groomer_portfolio_photos
    where id = groomer_portfolio_fit_tags.portfolio_photo_id
      and groomer_id = (select auth.uid())
  )
);

create policy groomer_portfolio_fit_tags_delete_own
on public.groomer_portfolio_fit_tags
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
