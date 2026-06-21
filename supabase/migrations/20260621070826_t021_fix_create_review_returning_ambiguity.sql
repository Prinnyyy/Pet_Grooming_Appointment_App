-- T-021 corrective migration.
-- Fixes PostgreSQL 42702 in create_review caused by unqualified
-- RETURNING created_at conflicting with the function OUT column created_at.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

create or replace function public.create_review(
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
