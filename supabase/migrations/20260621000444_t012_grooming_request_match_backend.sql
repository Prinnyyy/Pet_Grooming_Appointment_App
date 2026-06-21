-- T-012 reviewed draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

create table public.grooming_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  pet_id uuid,
  pet_snapshot jsonb not null,
  photo_snapshot jsonb not null default '[]'::jsonb,
  service_type text not null,
  service_notes text,
  preferred_start timestamptz not null,
  preferred_end timestamptz not null,
  city text not null,
  state text not null,
  zip_code text not null,
  status text not null default 'open',
  expires_at timestamptz not null default (statement_timestamp() + interval '48 hours'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint grooming_requests_owner_key unique (id, customer_id),
  constraint grooming_requests_pet_owner_fkey
    foreign key (pet_id, customer_id)
    references public.pets (id, customer_id)
    on delete cascade,
  constraint grooming_requests_pet_snapshot_check check (
    jsonb_typeof(pet_snapshot) = 'object'
    and pg_column_size(pet_snapshot) <= 65536
  ),
  constraint grooming_requests_photo_snapshot_check check (
    jsonb_typeof(photo_snapshot) = 'array'
    and jsonb_array_length(photo_snapshot) <= 20
    and pg_column_size(photo_snapshot) <= 131072
  ),
  constraint grooming_requests_service_type_check check (
    service_type = btrim(service_type)
    and char_length(service_type) between 1 and 80
  ),
  constraint grooming_requests_service_notes_check check (
    service_notes is null
    or (
      service_notes = btrim(service_notes)
      and char_length(service_notes) between 1 and 2000
    )
  ),
  constraint grooming_requests_preferred_range_check check (
    preferred_end > preferred_start
  ),
  constraint grooming_requests_city_check check (
    city = btrim(city)
    and char_length(city) between 1 and 100
  ),
  constraint grooming_requests_state_check check (
    state = btrim(state)
    and char_length(state) between 2 and 80
  ),
  constraint grooming_requests_zip_code_check check (
    zip_code = btrim(zip_code)
    and char_length(zip_code) between 3 and 20
  ),
  constraint grooming_requests_status_check check (
    status in (
      'open',
      'has_offers',
      'booked',
      'cancelled',
      'expired'
    )
  ),
  constraint grooming_requests_expires_at_check check (
    expires_at > created_at
  )
);

comment on table public.grooming_requests is
  'Customer-owned grooming request with frozen pet/photo snapshots and backend-controlled status transitions.';
comment on column public.grooming_requests.pet_snapshot is
  'Frozen pet data captured when the request is created.';
comment on column public.grooming_requests.photo_snapshot is
  'Frozen pet-photo metadata captured when the request is created.';

create table public.request_matches (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  groomer_id uuid not null
    references public.groomer_profiles (user_id) on delete cascade,
  customer_id uuid not null
    references public.customer_profiles (user_id) on delete cascade,
  match_score numeric(5, 2),
  match_reason text,
  dismiss_reason text,
  status text not null default 'visible',
  viewed_at timestamptz,
  dismissed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint request_matches_request_customer_fkey
    foreign key (request_id, customer_id)
    references public.grooming_requests (id, customer_id)
    on delete cascade,
  constraint request_matches_request_groomer_key unique (request_id, groomer_id),
  constraint request_matches_score_check check (
    match_score is null
    or match_score between 0 and 100
  ),
  constraint request_matches_reason_check check (
    match_reason is null
    or (
      match_reason = btrim(match_reason)
      and char_length(match_reason) between 1 and 500
    )
  ),
  constraint request_matches_dismiss_reason_check check (
    dismiss_reason is null
    or (
      dismiss_reason = btrim(dismiss_reason)
      and char_length(dismiss_reason) between 1 and 500
    )
  ),
  constraint request_matches_status_check check (
    status in (
      'visible',
      'viewed',
      'dismissed',
      'offered',
      'hidden',
      'expired'
    )
  ),
  constraint request_matches_dismissed_at_check check (
    (status = 'dismissed' and dismissed_at is not null)
    or (status <> 'dismissed' and dismissed_at is null)
  )
);

comment on table public.request_matches is
  'Backend-controlled assignment of an eligible grooming request to one groomer.';
comment on column public.request_matches.match_reason is
  'Backend-generated matching reason shown to the groomer when useful.';
comment on column public.request_matches.dismiss_reason is
  'Optional groomer-provided private dismissal reason.';

create index grooming_requests_customer_status_created_idx
on public.grooming_requests (customer_id, status, created_at desc);

create index grooming_requests_open_expiry_idx
on public.grooming_requests (status, expires_at, created_at desc)
where status in ('open', 'has_offers');

create index grooming_requests_pet_idx
on public.grooming_requests (pet_id)
where pet_id is not null;

create index request_matches_groomer_status_created_idx
on public.request_matches (groomer_id, status, created_at desc);

create index request_matches_request_status_idx
on public.request_matches (request_id, status);

create index request_matches_customer_idx
on public.request_matches (customer_id);

create trigger grooming_requests_set_updated_at
before update on public.grooming_requests
for each row execute function app_private.set_updated_at();

create trigger request_matches_set_updated_at
before update on public.request_matches
for each row execute function app_private.set_updated_at();

alter table public.grooming_requests enable row level security;
alter table public.request_matches enable row level security;

revoke all on table public.grooming_requests from public, anon, authenticated;
revoke all on table public.request_matches from public, anon, authenticated;

grant select on table public.grooming_requests to authenticated;
grant select on table public.request_matches to authenticated;

grant select, insert, update, delete
on table public.grooming_requests, public.request_matches
to service_role;

create policy grooming_requests_select_customer_or_matched_groomer
on public.grooming_requests
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
      status in ('open', 'has_offers')
      and expires_at > statement_timestamp()
      and exists (
        select 1
        from public.request_matches as request_match
        where request_match.request_id = grooming_requests.id
          and request_match.groomer_id = (select auth.uid())
          and request_match.status in ('visible', 'viewed', 'offered')
      )
      and exists (
        select 1
        from public.groomer_profiles
        where user_id = (select auth.uid())
      )
    )
  )
);

create policy request_matches_select_groomer_own
on public.request_matches
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and groomer_id = (select auth.uid())
  and exists (
    select 1
    from public.groomer_profiles
    where user_id = (select auth.uid())
  )
);

create function public.create_grooming_request(
  p_pet_id uuid,
  p_service_type text,
  p_service_notes text,
  p_preferred_start timestamptz,
  p_preferred_end timestamptz,
  p_city text,
  p_state text,
  p_zip_code text
)
returns table (
  request_id uuid,
  match_count integer
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
  v_service_type text := btrim(p_service_type);
  v_service_notes text := nullif(btrim(p_service_notes), '');
  v_city text := btrim(p_city);
  v_state text := btrim(p_state);
  v_zip_code text := btrim(p_zip_code);
  v_open_request_count integer;
  v_request_id uuid;
  v_match_count integer := 0;
  v_pet public.pets%rowtype;
  v_pet_snapshot jsonb;
  v_photo_snapshot jsonb;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  perform 1
  from public.customer_profiles as customer_profile
  join public.profiles as profile
    on profile.id = customer_profile.user_id
  where customer_profile.user_id = v_user_id
    and profile.role = 'customer'::public.user_role
  for update of customer_profile;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'customer_profile_required';
  end if;

  if p_pet_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_pet';
  end if;

  if v_service_type is null
    or char_length(v_service_type) not between 1 and 80
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_service_type';
  end if;

  if v_service_notes is not null
    and char_length(v_service_notes) > 2000
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_service_notes';
  end if;

  if p_preferred_start is null
    or p_preferred_end is null
    or p_preferred_start <= statement_timestamp()
    or p_preferred_end <= p_preferred_start
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_preferred_range';
  end if;

  if v_city is null
    or char_length(v_city) not between 1 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_city';
  end if;

  if v_state is null
    or char_length(v_state) not between 2 and 80
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_state';
  end if;

  if v_zip_code is null
    or char_length(v_zip_code) not between 3 and 20
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_zip_code';
  end if;

  select count(*)::integer
  into v_open_request_count
  from public.grooming_requests as request
  where request.customer_id = v_user_id
    and request.status in ('open', 'has_offers')
    and request.expires_at > statement_timestamp();

  if v_open_request_count >= 3 then
    raise exception using
      errcode = 'P0001',
      message = 'open_request_limit_exceeded';
  end if;

  select pet.*
  into v_pet
  from public.pets as pet
  where pet.id = p_pet_id
    and pet.customer_id = v_user_id
    and pet.is_active
    and pet.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'pet_not_found';
  end if;

  v_pet_snapshot := jsonb_build_object(
    'id', v_pet.id,
    'name', v_pet.name,
    'species', v_pet.species,
    'breed', v_pet.breed,
    'size', v_pet.size,
    'weight_lbs', v_pet.weight_lbs,
    'birthday', v_pet.birthday,
    'temperament', v_pet.temperament,
    'medical_notes', v_pet.medical_notes,
    'grooming_notes', v_pet.grooming_notes,
    'snapshot_at', statement_timestamp()
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', photo.id,
        'storage_bucket', photo.storage_bucket,
        'storage_path', photo.storage_path,
        'caption', photo.caption,
        'sort_order', photo.sort_order,
        'is_primary', photo.is_primary,
        'created_at', photo.created_at
      )
      order by photo.is_primary desc, photo.sort_order, photo.created_at
    ),
    '[]'::jsonb
  )
  into v_photo_snapshot
  from public.pet_photos as photo
  where photo.customer_id = v_user_id
    and photo.pet_id = p_pet_id;

  insert into public.grooming_requests (
    customer_id,
    pet_id,
    pet_snapshot,
    photo_snapshot,
    service_type,
    service_notes,
    preferred_start,
    preferred_end,
    city,
    state,
    zip_code,
    status,
    expires_at
  )
  values (
    v_user_id,
    p_pet_id,
    v_pet_snapshot,
    v_photo_snapshot,
    v_service_type,
    v_service_notes,
    p_preferred_start,
    p_preferred_end,
    v_city,
    v_state,
    v_zip_code,
    'open',
    statement_timestamp() + interval '48 hours'
  )
  returning id into v_request_id;

  insert into public.request_matches (
    request_id,
    groomer_id,
    customer_id,
    match_score,
    match_reason,
    status
  )
  select
    v_request_id,
    groomer_profile.user_id,
    v_user_id,
    case
      when lower(groomer_profile.base_state) = lower(v_state)
        and lower(groomer_profile.base_city) = lower(v_city)
      then 100
      when lower(groomer_profile.base_state) = lower(v_state)
      then 60
      else 40
    end,
    case
      when lower(groomer_profile.base_state) = lower(v_state)
        and lower(groomer_profile.base_city) = lower(v_city)
      then 'same_city_and_state'
      when lower(groomer_profile.base_state) = lower(v_state)
      then 'same_state'
      else 'same_city'
    end,
    'visible'
  from public.groomer_profiles as groomer_profile
  join public.profiles as profile
    on profile.id = groomer_profile.user_id
  where profile.role = 'groomer'::public.user_role
    and groomer_profile.is_active
    and (
      lower(groomer_profile.base_state) = lower(v_state)
      or lower(groomer_profile.base_city) = lower(v_city)
    )
    and exists (
      select 1
      from public.groomer_services as groomer_service
      where groomer_service.groomer_id = groomer_profile.user_id
        and groomer_service.is_active
    )
  on conflict (request_id, groomer_id) do nothing;

  get diagnostics v_match_count = row_count;

  return query
  select v_request_id, v_match_count;
end;
$$;

comment on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text
) is
  'Creates a customer grooming request, freezes pet/photo snapshots, and creates eligible groomer matches atomically.';

revoke all on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text
) from public, anon, authenticated;

grant execute on function public.create_grooming_request(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text
) to authenticated, service_role;

create function public.dismiss_request_match(
  p_match_id uuid,
  p_reason text default null
)
returns table (
  match_id uuid,
  status text,
  dismissed_at timestamptz
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
  v_dismiss_reason text := nullif(btrim(p_reason), '');
  v_match_id uuid;
  v_match_status text;
  v_match_dismissed_at timestamptz;
  v_request_status text;
  v_request_expires_at timestamptz;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
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

  if p_match_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_match';
  end if;

  if v_dismiss_reason is not null
    and char_length(v_dismiss_reason) > 500
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_dismiss_reason';
  end if;

  select
    request_match.id,
    request_match.status,
    request_match.dismissed_at,
    request.status,
    request.expires_at
  into
    v_match_id,
    v_match_status,
    v_match_dismissed_at,
    v_request_status,
    v_request_expires_at
  from public.request_matches as request_match
  join public.grooming_requests as request
    on request.id = request_match.request_id
  where request_match.id = p_match_id
    and request_match.groomer_id = v_user_id
  for update of request_match;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_found';
  end if;

  if v_match_status = 'dismissed' then
    return query
    select v_match_id, v_match_status, v_match_dismissed_at;
    return;
  end if;

  if v_match_status not in ('visible', 'viewed') then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_dismissible';
  end if;

  if v_request_status not in ('open', 'has_offers')
    or v_request_expires_at <= statement_timestamp()
  then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_open';
  end if;

  return query
  update public.request_matches as request_match
  set
    status = 'dismissed',
    viewed_at = coalesce(request_match.viewed_at, statement_timestamp()),
    dismissed_at = statement_timestamp(),
    dismiss_reason = v_dismiss_reason
  where request_match.id = v_match_id
  returning
    request_match.id,
    request_match.status,
    request_match.dismissed_at;
end;
$$;

comment on function public.dismiss_request_match(uuid, text) is
  'Privately dismisses the calling groomer''s own visible or viewed request match.';

revoke all on function public.dismiss_request_match(uuid, text)
from public, anon, authenticated;

grant execute on function public.dismiss_request_match(uuid, text)
to authenticated, service_role;
