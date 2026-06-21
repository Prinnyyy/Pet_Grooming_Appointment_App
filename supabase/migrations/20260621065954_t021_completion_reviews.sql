-- T-021 reviewed SQL draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

alter table public.bookings
  add column completed_at timestamptz,
  add column completed_by uuid,
  add constraint bookings_completion_check check (
    (
      status = 'completed'
      and completed_at is not null
      and completed_by = groomer_id
    )
    or (
      status <> 'completed'
      and completed_at is null
      and completed_by is null
    )
  );

comment on column public.bookings.completed_at is
  'Timestamp set when the booked groomer marks the service completed.';
comment on column public.bookings.completed_by is
  'Groomer participant that completed the booking. Must match bookings.groomer_id.';

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique
    references public.bookings (id) on delete cascade,
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  rating integer not null,
  content text,
  created_at timestamptz not null default now(),
  constraint reviews_rating_check check (
    rating between 1 and 5
  ),
  constraint reviews_content_check check (
    content is null
    or (
      content = regexp_replace(content, '^[[:space:]]+|[[:space:]]+$', '', 'g')
      and char_length(content) between 1 and 2000
    )
  )
);

comment on table public.reviews is
  'One customer-authored review for a completed booking.';
comment on column public.reviews.booking_id is
  'Completed booking being reviewed. A booking can receive at most one review.';
comment on column public.reviews.rating is
  'Customer rating from 1 through 5.';
comment on column public.reviews.content is
  'Optional trimmed review text. Moderation and disputes are outside T-021.';

create index reviews_customer_created_idx
on public.reviews (customer_id, created_at desc);

create index reviews_groomer_created_idx
on public.reviews (groomer_id, created_at desc);

alter table public.reviews enable row level security;

revoke all on table public.reviews from public, anon, authenticated;

grant select on table public.reviews to authenticated;

grant select, insert, update, delete
on table public.reviews
to service_role;

create policy reviews_select_booking_participants
on public.reviews
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

create function public.complete_booking(
  p_booking_id uuid
)
returns table (
  booking_id uuid,
  booking_status text,
  completed_timestamp timestamptz,
  completed_by uuid
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
  v_groomer_id uuid;
  v_booking_status text;
  v_completed_at timestamptz;
  v_completed_by uuid;
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

  perform 1
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile
    on profile.id = groomer_profile.user_id
  where groomer_profile.user_id = v_user_id
    and profile.role = 'groomer'::public.user_role;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_profile_required';
  end if;

  select
    booking.id,
    booking.groomer_id,
    booking.status,
    booking.completed_at,
    booking.completed_by
  into
    v_booking_id,
    v_groomer_id,
    v_booking_status,
    v_completed_at,
    v_completed_by
  from public.bookings as booking
  where booking.id = p_booking_id
    and booking.groomer_id = v_user_id
  for update of booking;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_found';
  end if;

  if v_booking_status = 'completed' then
    return query
    select v_booking_id, v_booking_status, v_completed_at, v_completed_by;
    return;
  end if;

  if v_booking_status <> 'confirmed' then
    raise exception using
      errcode = 'P0001',
      message = 'booking_not_completable';
  end if;

  update public.bookings as booking
  set
    status = 'completed',
    completed_at = statement_timestamp(),
    completed_by = v_user_id
  where booking.id = v_booking_id
  returning
    booking.status,
    booking.completed_at,
    booking.completed_by
  into
    v_booking_status,
    v_completed_at,
    v_completed_by;

  return query
  select v_booking_id, v_booking_status, v_completed_at, v_completed_by;
end;
$$;

comment on function public.complete_booking(uuid) is
  'Marks a confirmed booking completed as the booked groomer participant.';

revoke all on function public.complete_booking(uuid)
from public, anon, authenticated;

grant execute on function public.complete_booking(uuid)
to authenticated, service_role;

create function public.create_review(
  p_booking_id uuid,
  p_rating integer,
  p_content text default null
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
    insert into public.reviews (
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
      id,
      created_at
    into
      v_review_id,
      v_created_at;
  exception
    when unique_violation then
      raise exception using
        errcode = 'P0001',
        message = 'review_already_exists';
  end;

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

comment on function public.create_review(uuid, integer, text) is
  'Creates the single customer review for a completed booking and updates the groomer rating summary.';

revoke all on function public.create_review(uuid, integer, text)
from public, anon, authenticated;

grant execute on function public.create_review(uuid, integer, text)
to authenticated, service_role;
