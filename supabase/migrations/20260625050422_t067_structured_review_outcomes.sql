-- T-067 structured review outcomes for pet-fit evidence.
-- Authorized target: lqmasbuqzvcvtawonjlb only.

create table public.review_pet_fit_outcomes (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null
    references public.reviews (id) on delete cascade,
  booking_id uuid not null
    references public.bookings (id) on delete cascade,
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  trait_type text not null,
  trait_value text not null,
  outcome text not null,
  created_at timestamptz not null default now(),
  constraint review_pet_fit_outcomes_trait_check check (
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
  ),
  constraint review_pet_fit_outcomes_outcome_check check (
    outcome in ('positive', 'negative')
  ),
  constraint review_pet_fit_outcomes_review_trait_key unique (
    review_id,
    trait_type,
    trait_value
  )
);

comment on table public.review_pet_fit_outcomes is
  'Structured customer review outcomes for pet-fit evidence. Rows are created only through create_review and are consumed by later evidence summary work.';
comment on column public.review_pet_fit_outcomes.review_id is
  'Review that captured this structured pet-fit outcome.';
comment on column public.review_pet_fit_outcomes.booking_id is
  'Completed booking reviewed by the customer. Denormalized for participant RLS and later evidence aggregation.';
comment on column public.review_pet_fit_outcomes.trait_type is
  'Canonical T-065 trait type: breed_group, size_band, care_flag, or service_fit.';
comment on column public.review_pet_fit_outcomes.trait_value is
  'Canonical T-065 trait value for the selected trait_type.';
comment on column public.review_pet_fit_outcomes.outcome is
  'Customer-confirmed outcome for the trait: positive or negative.';

create index review_pet_fit_outcomes_booking_idx
on public.review_pet_fit_outcomes (booking_id);

create index review_pet_fit_outcomes_customer_created_idx
on public.review_pet_fit_outcomes (customer_id, created_at desc);

create index review_pet_fit_outcomes_groomer_trait_idx
on public.review_pet_fit_outcomes (
  groomer_id,
  trait_type,
  trait_value,
  outcome
);

alter table public.review_pet_fit_outcomes enable row level security;

revoke all on table public.review_pet_fit_outcomes
from public, anon, authenticated;

grant select on table public.review_pet_fit_outcomes to authenticated;

grant select, insert, update, delete
on table public.review_pet_fit_outcomes
to service_role;

create policy review_pet_fit_outcomes_select_booking_participants
on public.review_pet_fit_outcomes
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and (
    (
      customer_id = (select auth.uid())
      and exists (
        select 1
        from public.customer_profiles
        where user_id = (select auth.uid())
      )
    )
    or (
      groomer_id = (select auth.uid())
      and exists (
        select 1
        from public.groomer_profiles
        where user_id = (select auth.uid())
      )
    )
  )
);

drop function public.create_review(uuid, integer, text);

create function public.create_review(
  p_booking_id uuid,
  p_rating integer,
  p_content text default null,
  p_pet_fit_outcomes jsonb default '[]'::jsonb
)
returns table (
  review_id uuid,
  booking_id uuid,
  customer_id uuid,
  groomer_id uuid,
  rating integer,
  content text,
  created_at timestamptz,
  groomer_rating_avg numeric,
  groomer_rating_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_booking_id uuid;
  v_customer_id uuid;
  v_groomer_id uuid;
  v_booking_status text;
  v_content text := nullif(
    regexp_replace(
      coalesce(p_content, ''),
      '^[[:space:]]+|[[:space:]]+$',
      '',
      'g'
    ),
    ''
  );
  v_review_id uuid;
  v_created_at timestamptz;
  v_old_rating_avg numeric(3, 2);
  v_old_rating_count integer;
  v_new_rating_avg numeric(3, 2);
  v_new_rating_count integer;
  v_pet_fit_outcomes jsonb := coalesce(p_pet_fit_outcomes, '[]'::jsonb);
  v_outcome_item jsonb;
  v_trait_type text;
  v_trait_value text;
  v_outcome text;
  v_seen_outcome_keys text[] := array[]::text[];
  v_seen_outcome_key text;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_booking_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_booking';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception using
      errcode = '22023',
      message = 'invalid_rating';
  end if;

  if v_content is not null and char_length(v_content) > 2000 then
    raise exception using
      errcode = '22023',
      message = 'invalid_review_content';
  end if;

  if jsonb_typeof(v_pet_fit_outcomes) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'invalid_review_outcomes';
  end if;

  if jsonb_array_length(v_pet_fit_outcomes) > 20 then
    raise exception using
      errcode = '22023',
      message = 'too_many_review_outcomes';
  end if;

  perform 1
  from public.customer_profiles as customer_profile
  join public.profiles as profile
    on profile.id = customer_profile.user_id
  where customer_profile.user_id = v_user_id
    and profile.role = 'customer'::public.user_role;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'customer_profile_required';
  end if;

  select
    booking.id,
    booking.customer_id,
    booking.groomer_id,
    booking.status
  into
    v_booking_id,
    v_customer_id,
    v_groomer_id,
    v_booking_status
  from public.bookings as booking
  where booking.id = p_booking_id
    and booking.customer_id = v_user_id
  for update of booking;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_found';
  end if;

  if v_booking_status <> 'completed' then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_completed';
  end if;

  select
    groomer_profile.rating_avg,
    groomer_profile.rating_count
  into
    v_old_rating_avg,
    v_old_rating_count
  from public.groomer_profiles as groomer_profile
  where groomer_profile.user_id = v_groomer_id
  for update of groomer_profile;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_profile_required';
  end if;

  begin
    insert into public.reviews as review (
      booking_id,
      customer_id,
      groomer_id,
      rating,
      content
    )
    values (
      v_booking_id,
      v_customer_id,
      v_groomer_id,
      p_rating,
      v_content
    )
    returning
      review.id,
      review.created_at
    into
      v_review_id,
      v_created_at;
  exception
    when unique_violation then
      raise exception using
        errcode = 'P0001',
        message = 'review_already_exists';
  end;

  for v_outcome_item in
    select value
    from jsonb_array_elements(v_pet_fit_outcomes)
  loop
    if jsonb_typeof(v_outcome_item) <> 'object' then
      raise exception using
        errcode = '22023',
        message = 'invalid_review_outcomes';
    end if;

    v_trait_type := v_outcome_item ->> 'trait_type';
    v_trait_value := v_outcome_item ->> 'trait_value';
    v_outcome := v_outcome_item ->> 'outcome';

    if not coalesce((
      (
        v_trait_type = 'breed_group'
        and v_trait_value in ('poodle', 'terrier')
      )
      or (
        v_trait_type = 'size_band'
        and v_trait_value in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
      )
      or (
        v_trait_type = 'care_flag'
        and v_trait_value in ('anxious', 'senior')
      )
      or (
        v_trait_type = 'service_fit'
        and v_trait_value in (
          'curly_coat',
          'terrier_coat',
          'gentle_handling',
          'senior_care'
        )
      )
    ), false) then
      raise exception using
        errcode = '22023',
        message = 'invalid_review_outcome_trait';
    end if;

    if v_outcome is null or v_outcome not in ('positive', 'negative') then
      raise exception using
        errcode = '22023',
        message = 'invalid_review_outcome_value';
    end if;

    v_seen_outcome_key := v_trait_type || ':' || v_trait_value;

    if v_seen_outcome_key = any(v_seen_outcome_keys) then
      raise exception using
        errcode = '22023',
        message = 'duplicate_review_outcome';
    end if;

    v_seen_outcome_keys := array_append(
      v_seen_outcome_keys,
      v_seen_outcome_key
    );

    insert into public.review_pet_fit_outcomes (
      review_id,
      booking_id,
      customer_id,
      groomer_id,
      trait_type,
      trait_value,
      outcome
    )
    values (
      v_review_id,
      v_booking_id,
      v_customer_id,
      v_groomer_id,
      v_trait_type,
      v_trait_value,
      v_outcome
    );
  end loop;

  v_new_rating_count := v_old_rating_count + 1;
  v_new_rating_avg := round(
    ((v_old_rating_avg * v_old_rating_count) + p_rating)::numeric
    / v_new_rating_count,
    2
  );

  update public.groomer_profiles as groomer_profile
  set
    rating_avg = v_new_rating_avg,
    rating_count = v_new_rating_count
  where groomer_profile.user_id = v_groomer_id
  returning
    groomer_profile.rating_avg,
    groomer_profile.rating_count
  into
    v_new_rating_avg,
    v_new_rating_count;

  return query
  select
    v_review_id,
    v_booking_id,
    v_customer_id,
    v_groomer_id,
    p_rating,
    v_content,
    v_created_at,
    v_new_rating_avg,
    v_new_rating_count;
end;
$$;

comment on function public.create_review(uuid, integer, text, jsonb) is
  'Creates the single customer review for a completed booking, optionally records structured pet-fit outcomes, and updates the groomer rating summary.';

revoke all on function public.create_review(uuid, integer, text, jsonb)
from public, anon, authenticated;

grant execute on function public.create_review(uuid, integer, text, jsonb)
to authenticated, service_role;
