-- T-390 / MR-01. Keep legacy acceptance unknown until its owner confirms it.
alter table public.pets add column coat_type_source text not null default 'legacy_unverified'
  check (coat_type_source in ('explicit','legacy_unverified','unknown'));
alter table public.pets add column matting_confirmed boolean;
-- Remove the old slider's persistence limits and typmod rounding before validating facts.
alter table public.pets drop constraint pets_weight_lbs_range_check;
drop trigger pets_derive_size_from_weight on public.pets;
alter table public.pets alter column weight_lbs type numeric;
create trigger pets_derive_size_from_weight before insert or update of weight_lbs, size on public.pets
for each row execute function app_private.set_pet_size_from_weight();
alter table public.pets add constraint pets_weight_lbs_range_check
  check (weight_lbs is null or (weight_lbs>0 and weight_lbs::text not in ('NaN','Infinity','-Infinity')));
update public.pets set coat_type_source='unknown' where coat_type is null;
-- Pure arithmetic only; the invoker provenance trigger must retain the caller role.
grant execute on function app_private.pet_size_code_for_weight_lbs(numeric) to authenticated;

create function app_private.guard_pet_match_facts()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.weight_lbs is not null and (new.weight_lbs::text in ('NaN','Infinity','-Infinity')
    or new.weight_lbs<=0) then
    raise exception using errcode='22023',message='invalid_pet_weight';
  end if;
  if new.weight_lbs is not null and new.size is not null
    and new.size is distinct from app_private.pet_size_code_for_weight_lbs(new.weight_lbs) then
    raise exception using errcode='22023',message='pet_size_weight_conflict';
  end if;
  -- Legacy REST writers cannot assert provenance; only the owner-executed RPC can.
  if current_user is distinct from (select pg_catalog.pg_get_userbyid(relowner)
      from pg_catalog.pg_class where oid=tg_relid) then
    if tg_op='INSERT' then
      new.coat_type_source:=case when new.coat_type is null then 'unknown' else 'legacy_unverified' end;
    elsif row(new.coat_type,new.species,new.breed) is distinct from row(old.coat_type,old.species,old.breed) then
      new.coat_type_source:=case when new.coat_type is null then 'unknown' else 'legacy_unverified' end;
    else new.coat_type_source:=old.coat_type_source;
    end if;
  end if;
  if new.coat_type is null then new.coat_type_source:='unknown'; end if;
  return new;
end $$;
revoke all on function app_private.guard_pet_match_facts() from public,anon,authenticated,service_role;
create trigger pets_aaa_match_facts before insert or update on public.pets
for each row execute function app_private.guard_pet_match_facts();

create function app_private.save_my_pet_v2(p_pet_id uuid,p_facts jsonb,p_coat_confirmed boolean default false)
returns setof public.pets language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); input public.pets%rowtype; previous public.pets%rowtype; source text;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if not exists(select 1 from public.profiles where id=actor and role='customer') then
    raise exception using errcode='42501',message='customer_profile_required';
  end if;
  if p_facts is null or jsonb_typeof(p_facts)<>'object' then
    raise exception using errcode='22023',message='invalid_pet_facts';
  end if;
  if exists(select 1 from jsonb_object_keys(p_facts) key where key<>all(array[
    'name','species','breed','coat_type','size','weight_lbs','birthday','temperament',
    'medical_notes','grooming_notes','matting_confirmed'])) then
    raise exception using errcode='22023',message='invalid_pet_facts';
  end if;
  select * into input from jsonb_populate_record(null::public.pets,p_facts);
  if input.species is null or lower(input.species) not in ('dog','cat') then
    raise exception using errcode='22023',message='invalid_pet_species';
  end if;
  if p_pet_id is not null then
    select * into previous from public.pets where id=p_pet_id and customer_id=actor
      and is_active and deleted_at is null for update;
    if not found then raise exception using errcode='P0001',message='pet_not_found'; end if;
  end if;
  source:=case when input.coat_type is null then 'unknown'
    when p_coat_confirmed then 'explicit'
    when p_pet_id is not null and row(input.coat_type,input.species,input.breed)
      is not distinct from row(previous.coat_type,previous.species,previous.breed) then previous.coat_type_source
    else 'legacy_unverified' end;
  if p_pet_id is null then
    return query insert into public.pets(customer_id,name,species,breed,coat_type,size,weight_lbs,birthday,
      temperament,medical_notes,grooming_notes,coat_type_source,matting_confirmed)
    values(actor,input.name,input.species,input.breed,input.coat_type,input.size,input.weight_lbs,input.birthday,
      input.temperament,input.medical_notes,input.grooming_notes,source,input.matting_confirmed) returning *;
  else
    return query update public.pets set name=input.name,species=input.species,breed=input.breed,
      coat_type=input.coat_type,size=input.size,weight_lbs=input.weight_lbs,birthday=input.birthday,
      temperament=input.temperament,medical_notes=input.medical_notes,grooming_notes=input.grooming_notes,
      coat_type_source=source,matting_confirmed=input.matting_confirmed
      where id=p_pet_id and customer_id=actor returning *;
  end if;
end $$;
create function public.save_my_pet_v2(p_pet_id uuid,p_facts jsonb,p_coat_confirmed boolean default false)
returns setof public.pets language sql security invoker set search_path = '' as $$
  select * from app_private.save_my_pet_v2(p_pet_id,p_facts,p_coat_confirmed);
$$;
revoke all on function app_private.save_my_pet_v2(uuid,jsonb,boolean),public.save_my_pet_v2(uuid,jsonb,boolean)
  from public,anon,authenticated,service_role;
grant execute on function app_private.save_my_pet_v2(uuid,jsonb,boolean),public.save_my_pet_v2(uuid,jsonb,boolean)
  to authenticated;

create or replace function app_private.create_grooming_request_v2(
  p_pet_id uuid,
  p_service_type text,
  p_service_notes text,
  p_preferred_start timestamptz,
  p_preferred_end timestamptz,
  p_location_mode text,
  p_street_address text,
  p_city text,
  p_state text,
  p_zip_code text,
  p_address_line_2 text,
  p_provider text,
  p_place_id text,
  p_country_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_resolution_source text,
  p_user_confirmed_at timestamptz,
  p_travel_radius_miles integer
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
  v_service_type text := lower(btrim(p_service_type));
  v_service_notes text := nullif(btrim(p_service_notes), '');
  v_location_mode text := lower(btrim(p_location_mode));
  v_street_address text := btrim(p_street_address);
  v_city text := btrim(p_city);
  v_state text := upper(btrim(p_state));
  v_zip_code text := btrim(p_zip_code);
  v_address_line_2 text := nullif(btrim(p_address_line_2), '');
  v_travel_radius_miles integer := p_travel_radius_miles;
  v_open_request_count integer;
  v_request_id uuid;
  v_location_id uuid;
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

  if v_service_type not in (
    'full_groom',
    'bath_and_brush',
    'haircut_only',
    'nail_trim',
    'de_shedding',
    'custom_request'
  ) then
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

  if v_location_mode not in (
    'groomer_comes_to_customer',
    'customer_comes_to_groomer'
  ) then
    raise exception using
      errcode = '22023',
      message = 'invalid_location_mode';
  end if;

  if v_street_address is null
    or char_length(v_street_address) not between 1 and 160
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_street_address';
  end if;

  if v_city is null
    or char_length(v_city) not between 1 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_city';
  end if;

  if v_state is null
    or v_state !~ '^[A-Z]{2}$'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_state';
  end if;

  if v_zip_code is null
    or v_zip_code !~ '^[0-9]{5}(-[0-9]{4})?$'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_zip_code';
  end if;

  if v_address_line_2 is not null
    and char_length(v_address_line_2) > 60
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_address_line_2';
  end if;

  if v_location_mode = 'groomer_comes_to_customer' then
    v_travel_radius_miles := null;
  elsif v_travel_radius_miles is null
    or v_travel_radius_miles not between 5 and 100
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_travel_radius';
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
    'coat_type', v_pet.coat_type,
    'coat_type_source', v_pet.coat_type_source,
    'matting_confirmed', v_pet.matting_confirmed,
    'facts_version', 2,
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
  from (
    select photo.*
    from public.pet_photos as photo
    where photo.customer_id = v_user_id
      and photo.pet_id = p_pet_id
    order by photo.is_primary desc, photo.sort_order, photo.created_at
    limit 20
  ) as photo;

  v_location_id := app_private.save_address_location_v2(
    v_user_id,
    null,
    p_provider,
    p_place_id,
    p_country_code,
    p_latitude,
    p_longitude,
    p_resolution_source,
    p_user_confirmed_at
  );

  insert into public.grooming_requests (
    customer_id,
    pet_id,
    pet_snapshot,
    photo_snapshot,
    service_type,
    service_notes,
    preferred_start,
    preferred_end,
    location_mode,
    street_address,
    city,
    state,
    zip_code,
    address_line_2,
    address_location_id,
    travel_radius_miles,
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
    v_location_mode,
    v_street_address,
    v_city,
    v_state,
    v_zip_code,
    v_address_line_2,
    v_location_id,
    v_travel_radius_miles,
    'open',
    statement_timestamp() + interval '48 hours'
  )
  returning id into v_request_id;

  v_match_count := app_private.create_request_matches_for_request(
    v_request_id,
    null
  );

  return query
  select v_request_id, v_match_count;
end;
$$;

alter table public.groomer_services add column accepted_species text[];
alter table public.groomer_services add constraint accepted_species_values
  check (accepted_species is null or
    (array_position(accepted_species, null) is null and
     accepted_species <@ array['dog','cat']::text[]));

create function app_private.guard_service_species()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.accepted_species is not null then
    if array_ndims(new.accepted_species) > 1
      or array_position(new.accepted_species, null) is not null
      or not new.accepted_species <@ array['dog','cat']::text[]
      or cardinality(new.accepted_species) <> (
        select count(distinct species) from unnest(new.accepted_species) species
      ) then
      raise exception using errcode='22023',message='invalid_accepted_species';
    end if;
    new.accepted_species := array(select species from unnest(new.accepted_species) species order by species);
  end if;
  if new.is_active and coalesce(cardinality(new.accepted_species),0)=0 then
    if tg_op='INSERT' then
      raise exception using errcode='22023',message='service_species_confirmation_required';
    elsif not old.is_active or new.accepted_species is distinct from old.accepted_species
      or new.service_type is distinct from old.service_type then
      raise exception using errcode='22023',message='service_species_confirmation_required';
    end if;
  end if;
  -- Runs after the existing revision trigger so its other revocation rules stay intact.
  if tg_op='UPDATE' and new.accepted_species is distinct from old.accepted_species then
    new.eligibility_revision := gen_random_uuid();
  end if;
  return new;
end $$;
revoke all on function app_private.guard_service_species() from public,anon,authenticated,service_role;
create trigger groomer_services_species before insert or update on public.groomer_services
for each row execute function app_private.guard_service_species();

create function app_private.match_request_size(p_snapshot jsonb)
returns text language plpgsql immutable set search_path = '' as $$
declare raw_size text:=nullif(btrim(p_snapshot->>'size'),''); normalized_size text;
  raw_weight text:=p_snapshot->>'weight_lbs'; weight numeric; weight_size text;
begin
  select size into normalized_size from unnest(array['XS','S','M','L','XL','XXL','Giant']) size
    where lower(size)=lower(raw_size);
  if raw_size is not null and normalized_size is null then return null; end if;
  if raw_weight is null then return normalized_size; end if;
  if raw_weight !~ '^[+]?[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$' then return null; end if;
  weight:=raw_weight::numeric;
  if weight<=0 or weight::text in ('NaN','Infinity','-Infinity') then return null; end if;
  weight_size:=app_private.pet_size_code_for_weight_lbs(weight);
  if normalized_size is not null and weight_size is distinct from normalized_size then return null; end if;
  return weight_size;
exception when invalid_text_representation or numeric_value_out_of_range then return null;
end $$;
revoke all on function app_private.match_request_size(jsonb) from public,anon,authenticated,service_role;

create function app_private.match_required_confirmations(p_snapshot jsonb,p_service_type text,
  p_species text[],p_sizes text[])
returns text[] language plpgsql immutable set search_path = '' as $$
declare required text[]:='{}';
begin
  if p_species is null then required:=array_append(required,'service_species_configuration'); end if;
  if app_private.match_service_size(app_private.match_request_size(p_snapshot),p_sizes)<>'eligible' then
    required:=array_append(required,'pet_size');
  end if;
  if p_service_type='custom_request' then required:=array_append(required,'custom_service'); end if;
  if p_service_type in ('full_groom','bath_and_brush','haircut_only','de_shedding') then
    if p_snapshot->>'coat_type_source' is distinct from 'explicit'
      or p_snapshot->>'coat_type' is null then required:=array_append(required,'pet_coat'); end if;
    if jsonb_typeof(p_snapshot->'matting_confirmed') is distinct from 'boolean' then
      required:=array_append(required,'pet_matting');
    end if;
  end if;
  return required;
end $$;
revoke all on function app_private.match_required_confirmations(jsonb,text,text[],text[])
  from public,anon,authenticated,service_role;

create or replace function app_private.evaluate_match_constraints(p_request uuid,p_groomer uuid,p_now timestamptz)
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype; species text;
begin
  if p_now is null or not isfinite(p_now) then
    return jsonb_build_object('state','excluded','reason','invalid_clock');
  end if;
  select * into r from public.grooming_requests where id=p_request;
  if not found or r.status not in ('open','has_offers') or r.expires_at<=p_now
    or r.preferred_start is null or r.preferred_end is null
    or not isfinite(r.preferred_start) or not isfinite(r.preferred_end)
    or r.preferred_start>=r.preferred_end
    or not exists(select 1 from public.profiles where id=r.customer_id and role='customer')
    or not exists(select 1 from public.pets where id=r.pet_id and customer_id=r.customer_id
      and is_active and deleted_at is null) then
    return jsonb_build_object('state','excluded','reason','request_unavailable');
  end if;
  species:=lower(btrim(r.pet_snapshot->>'species'));
  if species is null or species not in ('dog','cat') then
    return jsonb_build_object('state','excluded','reason','request_species_confirmation_required');
  end if;
  select * into g from public.groomer_profiles where user_id=p_groomer;
  if not found or not g.is_active
    or not exists(select 1 from public.profiles where id=p_groomer and role='groomer')
    or not coalesce(g.service_location_modes @> array[r.location_mode]::text[],
      g.service_location_mode=r.location_mode,false) then
    return jsonb_build_object('state','excluded','reason','groomer_unavailable');
  end if;
  if not exists(select 1 from app_private.address_locations a
    join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=p_groomer
    cross join lateral app_private.evaluate_request_location_fit(a.location,b.location,r.location_mode,
      r.travel_radius_miles,g.service_radius_miles,r.state,r.city,g.base_state,g.base_city) fit
    where a.id=r.address_location_id and a.owner_id=r.customer_id and fit.is_eligible) then
    return jsonb_build_object('state','excluded','reason','location_excluded');
  end if;
  if not exists(select 1 from public.groomer_services s where s.groomer_id=p_groomer
    and s.is_active and s.service_type=r.service_type) then
    return jsonb_build_object('state','excluded','reason','service_unavailable');
  end if;
  if not exists(select 1 from public.groomer_services s where s.groomer_id=p_groomer
    and s.is_active and s.service_type=r.service_type
    and (s.accepted_species is null or species=any(s.accepted_species))) then
    return jsonb_build_object('state','excluded','reason','pet_species_excluded');
  end if;
  if not exists(select 1 from public.groomer_services s where s.groomer_id=p_groomer
    and s.is_active and s.service_type=r.service_type
    and (s.accepted_species is null or species=any(s.accepted_species))
    and app_private.match_service_size(app_private.match_request_size(r.pet_snapshot),s.accepted_pet_sizes)<>'excluded') then
    return jsonb_build_object('state','excluded','reason','pet_size_excluded');
  end if;
  return jsonb_build_object('state','eligible','reason','explicit_constraints_met');
end $$;
revoke all on function app_private.evaluate_match_constraints(uuid,uuid,timestamptz)
  from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION app_private.evaluate_match_eligibility_with_zones(p_request uuid, p_groomer uuid, p_now timestamp with time zone, p_valid_zones text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  r public.grooming_requests%rowtype; g public.groomer_profiles%rowtype;
  prefs public.groomer_booking_preferences%rowtype;
  zone text; service_zone text; valid_zones text[]; zones integer; windows integer;
  starts time[]; ends time[]; before_minutes integer := 0; after_minutes integer := 0;
  buffers_known boolean; earliest timestamptz; day date; day_end timestamptz;
  window_start timestamptz; window_end timestamptz; cursor_start timestamptz;
  available tstzmultirange; blocked tstzmultirange; allocation record; service record;
  pet_busy_until timestamptz; size_state text; duration integer; assessment jsonb;
begin
  assessment:=app_private.evaluate_match_constraints(p_request,p_groomer,p_now);
  if assessment->>'state'='excluded' then return assessment; end if;
  assessment:=null;
  select * into strict r from public.grooming_requests where id=p_request;
  select * into strict g from public.groomer_profiles where user_id=p_groomer;
  select min(timezone),count(distinct timezone),count(*),
    array_agg(case when is_enabled then start_time end order by weekday),
    array_agg(case when is_enabled then end_time end order by weekday)
    into zone,zones,windows,starts,ends from public.groomer_availability_windows where groomer_id=p_groomer;
  if zones<>1 or windows<>7 then
    return jsonb_build_object('state','excluded','reason','schedule_confirmation_required');
  end if;
  if r.location_mode='groomer_comes_to_customer' then service_zone:=r.preference_time_zone_identifier;
  else
    select time_zone_identifier into service_zone from app_private.address_locations
      where id=g.address_location_id and owner_id=p_groomer;
  end if;
  valid_zones:=p_valid_zones;
  if valid_zones is null then
    select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names where name in (zone,service_zone);
  end if;
  if not coalesce(zone=any(valid_zones),false) then
    return jsonb_build_object('state','excluded','reason','schedule_confirmation_required');
  end if;
  if not coalesce(service_zone=any(valid_zones),false) then
    return jsonb_build_object('state','excluded','reason','service_timezone_confirmation_required');
  end if;
  select * into prefs from public.groomer_booking_preferences where groomer_id=p_groomer;
  if not found then
    -- Optimistic notice only proves impossibility; missing preferences cannot
    -- produce estimated_fit because their buffers remain unconfirmed.
    prefs.minimum_advance_notice_days:=0;
  end if;
  buffers_known:=coalesce(app_private.valid_timing_buffers(prefs.timing_buffers),false);
  if buffers_known then
    before_minutes:=(prefs.timing_buffers->>'preparation_minutes')::integer;
    after_minutes:=(prefs.timing_buffers->>'cleanup_minutes')::integer;
    if r.location_mode='groomer_comes_to_customer' then
      before_minutes:=before_minutes+(prefs.timing_buffers->>'inbound_travel_minutes')::integer;
      after_minutes:=after_minutes+(prefs.timing_buffers->>'outbound_travel_minutes')::integer;
    end if;
  end if;
  earliest:=greatest(r.preferred_start,
    app_private.service_timing_earliest_start_validated(p_now,prefs.minimum_advance_notice_days,zone));
  select coalesce(range_agg(slot),'{}'::tstzmultirange) into blocked from (
    select tstzrange(coalesce(b.occupied_start,b.scheduled_start),app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)') slot
      from public.bookings b where b.groomer_id=p_groomer and b.status in ('confirmed','completed','unfulfilled')
    union all
    select tstzrange(timezone(zone,t.start_date::timestamp),timezone(zone,(t.end_date+1)::timestamp),'[)')
      from public.groomer_time_off_windows t where t.groomer_id=p_groomer
  ) occupied;
  day:=timezone(service_zone,earliest)::date;
  while timezone(service_zone,day::timestamp)<r.preferred_end loop
    day_end:=timezone(service_zone,(day+1)::timestamp);
    window_start:=greatest(earliest,timezone(service_zone,day::timestamp));
    window_end:=least(r.preferred_end,day_end);
    if window_start<window_end and not blocked @> tstzrange(window_start,window_end,'[)') then
      available:=app_private.match_weekly_ranges_validated(window_start-make_interval(mins=>before_minutes),
        window_end+make_interval(mins=>after_minutes),zone,starts,ends);
      if available is null then
        return jsonb_build_object('state','assessment_required','reason','schedule_evaluation_required');
      end if;
      for service in select * from public.groomer_services s where s.groomer_id=p_groomer
        and s.is_active and s.service_type=r.service_type order by s.duration_minutes,s.id loop
        size_state:=app_private.match_service_size(app_private.match_request_size(r.pet_snapshot),service.accepted_pet_sizes);
        if service.accepted_species is not null
          and not lower(btrim(r.pet_snapshot->>'species'))=any(service.accepted_species) then continue; end if;
        if size_state='excluded' then continue; end if;
        -- Unknown duration/buffers use optimistic lower bounds only to prove impossibility.
        duration:=case when r.service_type<>'custom_request' and service.duration_minutes between 15 and 720
          then service.duration_minutes else 15 end;
        cursor_start:=window_start;
        loop
          select * into allocation from app_private.match_service_interval(tstzrange(window_start,window_end,'[)'),
            available,blocked,duration,before_minutes,after_minutes,cursor_start);
          exit when not found;
          if (select count(*) from public.bookings b where b.groomer_id=p_groomer
              and b.status in ('confirmed','completed','unfulfilled')
              and timezone(zone,b.scheduled_start)::date=timezone(zone,allocation.service_start)::date)
              >=prefs.max_appointments_per_day then
            cursor_start:=timezone(zone,(timezone(zone,allocation.service_start)::date+1)::timestamp);
            continue;
          end if;
          select max(app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at)) into pet_busy_until from public.bookings b
            where b.pet_id=r.pet_id and b.status in ('confirmed','completed','unfulfilled')
              and b.scheduled_start<allocation.service_end and app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at)>allocation.service_start;
          if pet_busy_until is not null then cursor_start:=pet_busy_until; continue; end if;
          if size_state='eligible' and service.accepted_species is not null
            and cardinality(app_private.match_required_confirmations(r.pet_snapshot,r.service_type,
              service.accepted_species,service.accepted_pet_sizes))=0
            and buffers_known and r.service_type<>'custom_request'
            and service.duration_minutes between 15 and 720 then
            return jsonb_build_object('state','estimated_fit','reason','continuous_opening',
              'service_id',service.id,'service_start',allocation.service_start,'service_end',allocation.service_end,
              'occupied_start',allocation.occupied_start,'occupied_end',allocation.occupied_end);
          end if;
          assessment:=jsonb_build_object('state','assessment_required','reason','service_details_unconfirmed',
            'required_confirmations',to_jsonb(app_private.match_required_confirmations(r.pet_snapshot,
              r.service_type,service.accepted_species,service.accepted_pet_sizes)));
          exit;
        end loop;
      end loop;
    end if;
    day:=day+1;
  end loop;
  return coalesce(assessment,jsonb_build_object('state','excluded','reason','no_continuous_opening'));
end $function$;

alter table public.groomer_offers add column assessment_confirmations text[] not null default '{}';

create function app_private.validate_offer_match_facts(p_request uuid,p_groomer uuid,p_confirmations text[])
returns void language plpgsql set search_path = '' as $$
declare r public.grooming_requests%rowtype; s public.groomer_services%rowtype;
  required text[] := '{}'; supplied text[];
begin
  -- The request/admission writers and service-change triggers share this lock.
  -- Do not add source row locks after it: configuration UPDATE already owns its row.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_groomer::text,71071));
  select * into strict r from public.grooming_requests where id=p_request;
  if app_private.evaluate_match_constraints(p_request,p_groomer,statement_timestamp())->>'state' is distinct from 'eligible' then
    raise exception using errcode='22023',message='match_constraints_changed';
  end if;
  select * into strict s from public.groomer_services
    where groomer_id=p_groomer and service_type=r.service_type and is_active;
  if s.accepted_species is null then
    raise exception using errcode='22023',message='service_species_confirmation_required';
  end if;
  required:=app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes);
  if p_confirmations is null or array_ndims(p_confirmations)>1 then
    raise exception using errcode='22023',message='assessment_confirmation_required';
  end if;
  select array_agg(key order by key) into supplied from unnest(p_confirmations) key;
  if array_position(p_confirmations,null) is not null
    or cardinality(p_confirmations)<>(select count(distinct key) from unnest(p_confirmations) key)
    or coalesce(supplied,'{}') is distinct from array(select key from unnest(required) key order by key) then
    raise exception using errcode='22023',message='assessment_confirmation_required';
  end if;
end $$;
revoke all on function app_private.validate_offer_match_facts(uuid,uuid,text[])
  from public,anon,authenticated,service_role;

create function app_private.guard_offer_match_facts()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='UPDATE' then
    if new.assessment_confirmations is distinct from old.assessment_confirmations then
      raise exception using errcode='23514',message='quote_terms_are_immutable';
    end if;
  else
    perform app_private.validate_offer_match_facts(new.request_id,new.groomer_id,new.assessment_confirmations);
  end if;
  return new;
end $$;
revoke all on function app_private.guard_offer_match_facts() from public,anon,authenticated,service_role;
create trigger groomer_offers_z_match_facts before insert or update on public.groomer_offers
for each row execute function app_private.guard_offer_match_facts();

create function app_private.snapshot_offer_assessment()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.agreement_snapshot:=new.agreement_snapshot||jsonb_build_object(
    'assessment_confirmations',to_jsonb(new.assessment_confirmations));
  return new;
end $$;
revoke all on function app_private.snapshot_offer_assessment() from public,anon,authenticated,service_role;
create trigger groomer_offers_zzz_assessment before insert on public.groomer_offers
for each row execute function app_private.snapshot_offer_assessment();

create function app_private.guard_booking_match_facts()
returns trigger language plpgsql security definer set search_path = '' as $$
declare confirmations text[];
begin
  select assessment_confirmations into strict confirmations from public.groomer_offers
    where id=new.offer_id and request_id=new.request_id
      and groomer_id=new.groomer_id and customer_id=new.customer_id;
  perform app_private.validate_offer_match_facts(new.request_id,new.groomer_id,confirmations);
  return new;
end $$;
revoke all on function app_private.guard_booking_match_facts() from public,anon,authenticated,service_role;
create trigger bookings_aab_match_facts before insert on public.bookings
for each row execute function app_private.guard_booking_match_facts();

CREATE FUNCTION app_private.create_groomer_offer(p_request_id uuid, p_proposed_start timestamp with time zone, p_proposed_end timestamp with time zone, p_price_estimate numeric, p_message text, p_assessment_confirmations text[])
 RETURNS TABLE(offer_id uuid, offer_status text, request_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_message text := nullif(
    regexp_replace(coalesce(p_message, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g'),
    ''
  );
  v_match_id uuid;
  v_match_status text;
  v_customer_id uuid;
  v_request_status text;
  v_request_expires_at timestamptz;
  v_offer_id uuid;
  v_offer_status text;
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

  if p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_request';
  end if;

  if p_proposed_start is null
    or p_proposed_end is null
    or p_proposed_start <= statement_timestamp()
    or p_proposed_end <= p_proposed_start
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_proposed_range';
  end if;

  if p_price_estimate is null
    or p_price_estimate < 0
    or p_price_estimate > 100000
    or p_price_estimate <> round(p_price_estimate, 2)
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_price_estimate';
  end if;

  if v_message is not null
    and char_length(v_message) > 2000
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_message';
  end if;

  perform 1 from public.grooming_requests as parent_request
  where parent_request.id = p_request_id and exists (
      select 1 from public.request_matches m
      where m.request_id=parent_request.id and m.groomer_id=v_user_id
    )
  for update of parent_request;
  if not found then
    raise exception using errcode='P0001', message='match_not_found';
  end if;

  select
    request_match.id,
    request_match.status,
    request_match.customer_id,
    grooming_request.status,
    grooming_request.expires_at
  into
    v_match_id,
    v_match_status,
    v_customer_id,
    v_request_status,
    v_request_expires_at
  from public.request_matches as request_match
  join public.grooming_requests as grooming_request
    on grooming_request.id = request_match.request_id
   and grooming_request.customer_id = request_match.customer_id
  where request_match.request_id = p_request_id
    and request_match.groomer_id = v_user_id
  for update of request_match, grooming_request;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_found';
  end if;

  if v_match_status not in ('visible', 'viewed') then
    raise exception using
      errcode = 'P0001',
      message = 'match_not_offerable';
  end if;

  if v_request_status not in ('open', 'has_offers')
    or v_request_expires_at <= statement_timestamp()
  then
    raise exception using
      errcode = 'P0001',
      message = 'request_not_open';
  end if;

  if exists (
    select 1
    from public.groomer_offers as existing_offer
    where existing_offer.request_id = p_request_id
      and existing_offer.groomer_id = v_user_id
      and existing_offer.status = 'pending'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'active_offer_exists';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 71071)
  );

  if not app_private.groomer_can_admit_service(
    v_user_id,
    p_proposed_start,
    p_proposed_end
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'groomer_unavailable';
  end if;

  insert into public.groomer_offers (
    request_id,
    match_id,
    customer_id,
    groomer_id,
    proposed_start,
    proposed_end,
    price_estimate,
    message,
    status,
    expires_at,
    assessment_confirmations
  )
  values (
    p_request_id,
    v_match_id,
    v_customer_id,
    v_user_id,
    p_proposed_start,
    p_proposed_end,
    p_price_estimate,
    v_message,
    'pending',
    v_request_expires_at,
    p_assessment_confirmations
  )
  returning id, status
  into v_offer_id, v_offer_status;

  update public.request_matches as request_match
  set
    status = 'offered',
    viewed_at = coalesce(request_match.viewed_at, statement_timestamp())
  where request_match.id = v_match_id;

  update public.grooming_requests as grooming_request
  set status = 'has_offers'
  where grooming_request.id = p_request_id
    and grooming_request.status = 'open'
  returning grooming_request.status
  into v_request_status;

  if v_request_status is null then
    v_request_status := 'has_offers';
  end if;

  return query
  select v_offer_id, v_offer_status, v_request_status;
end;
$function$;

revoke all on function app_private.create_groomer_offer(uuid,timestamptz,timestamptz,numeric,text,text[])
  from public,anon,authenticated,service_role;
create or replace function app_private.create_groomer_offer(p_request_id uuid,p_proposed_start timestamptz,
  p_proposed_end timestamptz,p_price_estimate numeric,p_message text default null)
returns table(offer_id uuid,offer_status text,request_status text)
language sql security definer set search_path = '' as $$
  select * from app_private.create_groomer_offer(p_request_id,p_proposed_start,p_proposed_end,p_price_estimate,p_message,'{}'::text[]);
$$;
revoke all on function app_private.create_groomer_offer(uuid,timestamptz,timestamptz,numeric,text)
  from public,anon,authenticated,service_role;

create function app_private.create_groomer_offer_v3(p_request_id uuid,p_expected_request_revision uuid,
  p_proposed_start timestamptz,p_proposed_end timestamptz,p_price_estimate numeric,p_message text default null,
  p_assessment_confirmations text[] default '{}')
returns table(offer_id uuid,offer_status text,request_status text)
language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); revision uuid;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  select r.terms_revision into revision from public.grooming_requests r where r.id=p_request_id
    and exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=actor)
    for update;
  if not found then raise exception using errcode='P0001',message='match_not_found'; end if;
  if p_expected_request_revision is distinct from revision then
    raise exception using errcode='22023',message='request_revision_changed';
  end if;
  return query select * from app_private.create_groomer_offer(p_request_id,p_proposed_start,
    p_proposed_end,p_price_estimate,p_message,p_assessment_confirmations);
end $$;
create function public.create_groomer_offer_v3(p_request_id uuid,p_expected_request_revision uuid,
  p_proposed_start timestamptz,p_proposed_end timestamptz,p_price_estimate numeric,p_message text default null,
  p_assessment_confirmations text[] default '{}')
returns table(offer_id uuid,offer_status text,request_status text)
language sql security invoker set search_path = '' as $$
  select * from app_private.create_groomer_offer_v3(p_request_id,p_expected_request_revision,
    p_proposed_start,p_proposed_end,p_price_estimate,p_message,p_assessment_confirmations);
$$;
revoke all on function app_private.create_groomer_offer_v3(uuid,uuid,timestamptz,timestamptz,numeric,text,text[]),
  public.create_groomer_offer_v3(uuid,uuid,timestamptz,timestamptz,numeric,text,text[]) from public,anon,authenticated,service_role;
grant execute on function app_private.create_groomer_offer_v3(uuid,uuid,timestamptz,timestamptz,numeric,text,text[]),
  public.create_groomer_offer_v3(uuid,uuid,timestamptz,timestamptz,numeric,text,text[]) to authenticated;

CREATE OR REPLACE FUNCTION app_private.evaluate_quote(p_offer_id uuid, p_now timestamp with time zone DEFAULT statement_timestamp())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.groomer_offers%rowtype; r public.grooming_requests%rowtype;
  reason text; constraints jsonb; earliest timestamptz; notice integer; zone text;
  zone_count integer; window_count integer; required text[];
begin
  select * into o from public.groomer_offers where id=p_offer_id;
  if not found then return jsonb_build_object('terms_valid',false,'selectable',false,'reason','not_found'); end if;
  select * into strict r from public.grooming_requests where id=o.request_id;
  if o.terms_invalid_reason is not null then reason:=o.terms_invalid_reason;
  elsif o.status='withdrawn_by_groomer' then reason:='withdrawn';
  elsif o.status='expired' or least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes')<=p_now then reason:='expired';
  elsif o.status<>'pending' or r.status not in ('open','has_offers') then reason:='superseded';
  elsif o.agreement_snapshot is null then reason:='legacy_unverified';
  elsif o.agreement_snapshot->>'request_revision' is distinct from r.terms_revision::text then reason:='superseded';
  elsif o.agreement_snapshot->>'groomer_eligibility_revision' is distinct from
    (select eligibility_revision::text from public.groomer_profiles where user_id=o.groomer_id)
    or o.agreement_snapshot->>'service_eligibility_revision' is distinct from
    (select eligibility_revision::text from public.groomer_services where groomer_id=o.groomer_id and service_type=r.service_type)
    or (o.agreement_snapshot->'address'->>'source_updated_at')::timestamptz is distinct from
    (select updated_at from app_private.address_locations where id=(o.agreement_snapshot->'address'->>'source_location_id')::uuid)
    then reason:='eligibility_revoked';
  else
    constraints:=app_private.evaluate_match_constraints(r.id,o.groomer_id,p_now);
    if constraints->>'state'='excluded' then reason:='eligibility_revoked'; end if;
  end if;
  if reason is null then
    select app_private.match_required_confirmations(r.pet_snapshot,r.service_type,s.accepted_species,s.accepted_pet_sizes)
      into required from public.groomer_services s where s.groomer_id=o.groomer_id and s.service_type=r.service_type and s.is_active;
    if required is null or 'service_species_configuration'=any(required)
      or not (o.assessment_confirmations @> required and o.assessment_confirmations <@ required) then
      reason:='assessment_confirmation_required';
    end if;
  end if;
  if reason is not null then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason',reason);
  end if;
  select coalesce((select minimum_advance_notice_days from public.groomer_booking_preferences
    where groomer_id=o.groomer_id),0) into notice;
  select min(timezone),count(distinct timezone),count(*) into zone,zone_count,window_count
    from public.groomer_availability_windows where groomer_id=o.groomer_id;
  if zone_count<>1 or window_count<>7 or not exists(
    select 1 from pg_catalog.pg_timezone_names where name=zone
  ) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  earliest:=app_private.service_timing_earliest_start(p_now,notice,zone);
  if o.proposed_start<earliest then
    return jsonb_build_object('terms_valid',false,'selectable',false,'reason','expired');
  end if;
  if not app_private.groomer_can_admit_service(o.groomer_id,o.proposed_start,o.proposed_end,p_now)
    or exists(select 1 from public.bookings b where b.pet_id=r.pet_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(b.scheduled_start,app_private.booking_pet_end(b.scheduled_start,b.scheduled_end,b.pet_release_at),'[)') && tstzrange(o.proposed_start,o.proposed_end,'[)'))
    or exists(select 1 from public.bookings b where b.groomer_id=o.groomer_id and b.status in ('confirmed','completed','unfulfilled')
      and tstzrange(coalesce(b.occupied_start,b.scheduled_start),app_private.booking_resource_end(b.scheduled_start,b.scheduled_end,b.occupied_start,b.occupied_end,b.resource_release_at),'[)')
        && tstzrange(o.occupied_start,o.occupied_end,'[)'))
    or app_private.occupied_time_off_conflict(o.groomer_id,o.occupied_start,o.occupied_end)
    or not app_private.occupied_weekly_hours_covered(o.groomer_id,o.occupied_start,o.occupied_end) then
    return jsonb_build_object('terms_valid',true,'selectable',false,'reason','capacity_unavailable');
  end if;
  return jsonb_build_object('terms_valid',true,'selectable',true,'reason','available');
end $function$;
