-- T-390 / MR-02. Original reviews remain authoritative; contexts are immutable.
create table app_private.booking_review_contexts (
  booking_id uuid primary key references public.bookings(id) on delete cascade,
  context_revision uuid not null default gen_random_uuid(),
  evidence_context_version integer not null default 2 check (evidence_context_version=2),
  service_at timestamptz,
  service_time_zone_identifier text,
  species text,
  service_type text,
  allowed_keys jsonb not null check (jsonb_typeof(allowed_keys)='array'),
  source_state text not null,
  captured_at timestamptz not null default statement_timestamp()
);
revoke all on app_private.booking_review_contexts from public,anon,authenticated,service_role;
alter table app_private.booking_review_contexts enable row level security;

create function app_private.review_allowed_keys(p_snapshot jsonb,p_service text,p_service_at timestamptz,p_zone text)
returns jsonb language plpgsql stable set search_path = '' as $$
declare keys jsonb:='[]'; size text; coat text; birthday date; service_day date; temperament text;
begin
  if p_service_at is null or not isfinite(p_service_at)
    or lower(p_snapshot->>'species') not in ('dog','cat') or p_snapshot->>'species' is null
    or p_service is null or p_service not in ('full_groom','bath_and_brush','haircut_only','nail_trim','de_shedding') then
    return keys;
  end if;
  keys:=keys||jsonb_build_array(jsonb_build_object('dimension','service','value',p_service));
  size:=app_private.match_request_size(p_snapshot);
  if size is not null then keys:=keys||jsonb_build_array(jsonb_build_object('dimension','size','value',size)); end if;
  coat:=p_snapshot->>'coat_type';
  if p_service<>'nail_trim' and p_snapshot->>'coat_type_source'='explicit'
    and coat in ('curly_wavy','wire','double_coat','drop_coat','long_silky','short_smooth','hairless_low_coat') then
    keys:=keys||jsonb_build_array(jsonb_build_object('dimension','coat','value',coat));
  end if;
  temperament:=lower(p_snapshot->>'temperament');
  if temperament in ('anxious','reactive') then
    keys:=keys||jsonb_build_array(jsonb_build_object('dimension','care','value',temperament));
  end if;
  if p_service<>'nail_trim' and p_snapshot->'matting_confirmed'='true'::jsonb then
    keys:=keys||jsonb_build_array(jsonb_build_object('dimension','care','value','matted'));
  end if;
  if exists(select 1 from pg_catalog.pg_timezone_names where name=p_zone)
    and p_snapshot->>'birthday' ~ '^\d{4}-\d{2}-\d{2}$' then
    begin
      birthday:=(p_snapshot->>'birthday')::date;
      service_day:=(p_service_at at time zone p_zone)::date;
      if birthday<=service_day then
        if service_day < (birthday+interval '18 months')::date then
          keys:=keys||jsonb_build_array(jsonb_build_object('dimension','care','value','puppy'));
        elsif service_day >= (birthday+interval '10 years')::date then
          keys:=keys||jsonb_build_array(jsonb_build_object('dimension','care','value','senior'));
        end if;
      end if;
    exception when invalid_datetime_format or datetime_field_overflow then null;
    end;
  end if;
  return keys;
end $$;
revoke all on function app_private.review_allowed_keys(jsonb,text,timestamptz,text)
  from public,anon,authenticated,service_role;

create function app_private.freeze_booking_review_context(p_booking uuid)
returns void language plpgsql set search_path = '' as $$
declare b public.bookings%rowtype; snapshot jsonb; service text; service_at timestamptz; source text;
begin
  select * into b from public.bookings where id=p_booking and status='completed';
  if not found then return; end if;
  if exists(select 1 from public.account_deletion_requests where user_id in (b.customer_id,b.groomer_id) and anonymized_at is not null) then
    insert into app_private.booking_review_contexts(booking_id,allowed_keys,source_state)
      values(b.id,'[]','privacy_withheld') on conflict(booking_id) do nothing;
    return;
  end if;
  if exists(select 1 from app_private.booking_review_contexts where booking_id=p_booking) then return; end if;
  if b.agreement_snapshot is not null then
    snapshot:=b.agreement_snapshot->'pet_snapshot'; service:=b.agreement_snapshot->>'service_type';
    source:='booking_agreement';
  else
    select pet_snapshot,service_type into snapshot,service from public.grooming_requests where id=b.request_id;
    source:='legacy_request_snapshot';
  end if;
  -- scheduled_start incorporates accepted rescheduling, never late completion/review time.
  service_at:=case when isfinite(b.scheduled_start) then b.scheduled_start end;
  insert into app_private.booking_review_contexts(booking_id,service_at,service_time_zone_identifier,
    species,service_type,allowed_keys,source_state)
  values(b.id,service_at,b.service_time_zone_identifier,lower(snapshot->>'species'),service,
    app_private.review_allowed_keys(snapshot,service,service_at,b.service_time_zone_identifier),source)
  on conflict (booking_id) do nothing;
end $$;
revoke all on function app_private.freeze_booking_review_context(uuid) from public,anon,authenticated,service_role;

create function app_private.capture_completed_review_context()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status='completed' then perform app_private.freeze_booking_review_context(new.id); end if;
  return new;
end $$;
revoke all on function app_private.capture_completed_review_context() from public,anon,authenticated,service_role;
create trigger bookings_capture_review_context after insert or update of status on public.bookings
for each row execute function app_private.capture_completed_review_context();

create function app_private.get_booking_review_context(p_booking_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype; result jsonb;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  select * into b from public.bookings where id=p_booking_id and customer_id=actor;
  if not exists(select 1 from public.profiles where id=actor and role='customer')
    or exists(select 1 from public.account_deletion_requests where user_id=actor and anonymized_at is not null) then
    raise exception using errcode='42501',message='customer_profile_required';
  end if;
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  if b.status<>'completed' then raise exception using errcode='P0001',message='booking_not_completed'; end if;
  if exists(select 1 from public.reviews where booking_id=b.id) then
    raise exception using errcode='P0001',message='review_already_exists';
  end if;
  perform app_private.freeze_booking_review_context(b.id);
  select jsonb_build_object('booking_id',booking_id,'context_revision',context_revision,
    'evidence_context_version',evidence_context_version,'service_at',service_at,'allowed_keys',allowed_keys)
    into result from app_private.booking_review_contexts where booking_id=b.id;
  return result;
end $$;
create function public.get_booking_review_context(p_booking_id uuid)
returns jsonb language sql security invoker set search_path = '' as $$
  select app_private.get_booking_review_context(p_booking_id);
$$;
revoke all on function app_private.get_booking_review_context(uuid),public.get_booking_review_context(uuid)
  from public,anon,authenticated,service_role;
grant execute on function app_private.get_booking_review_context(uuid),public.get_booking_review_context(uuid) to authenticated;

alter table public.groomer_profiles add column rating_sum bigint not null default 0 check (rating_sum>=0);
update public.groomer_profiles p set rating_sum=a.total,rating_count=a.n,
  rating_avg=case when a.n=0 then 0 else round(a.total::numeric/a.n,2) end
from (select g.user_id,coalesce(sum(r.rating),0)::bigint total,count(r.id)::integer n
  from public.groomer_profiles g left join public.reviews r on r.groomer_id=g.user_id group by g.user_id) a
where p.user_id=a.user_id;

create function app_private.guard_review_identity()
returns trigger language plpgsql set search_path = '' as $$
begin
  if row(new.booking_id,new.customer_id,new.groomer_id) is distinct from row(old.booking_id,old.customer_id,old.groomer_id) then
    raise exception using errcode='23514',message='review_identity_is_immutable';
  end if;
  return new;
end $$;
revoke all on function app_private.guard_review_identity() from public,anon,authenticated,service_role;
create trigger reviews_guard_identity before update on public.reviews for each row execute function app_private.guard_review_identity();

create function app_private.update_exact_review_rating()
returns trigger language plpgsql security definer set search_path = '' as $$
declare groomer uuid; sum_delta bigint; count_delta integer;
begin
  if tg_op='INSERT' then groomer:=new.groomer_id; sum_delta:=new.rating; count_delta:=1;
  elsif tg_op='DELETE' then groomer:=old.groomer_id; sum_delta:=-old.rating; count_delta:=-1;
  else groomer:=new.groomer_id; sum_delta:=new.rating-old.rating; count_delta:=0;
  end if;
  update public.groomer_profiles set rating_sum=rating_sum+sum_delta,rating_count=rating_count+count_delta,
    rating_avg=case when rating_count+count_delta=0 then 0
      else round((rating_sum+sum_delta)::numeric/(rating_count+count_delta),2) end
    where user_id=groomer;
  -- A deleted parent is not recreated during a cascade.
  return null;
end $$;
revoke all on function app_private.update_exact_review_rating() from public,anon,authenticated,service_role;
create trigger reviews_exact_rating after insert or update or delete on public.reviews
for each row execute function app_private.update_exact_review_rating();

create function app_private.canonical_review_key(p_type text,p_value text,p_service text)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare dimension text:=p_type; value text:=p_value;
begin
  case p_type
    when 'coat_type' then dimension:='coat';
    when 'size_band' then dimension:='size';
    when 'care_flag' then dimension:='care';
    when 'service_fit' then
      case p_value
        when 'gentle_handling' then dimension:='care'; value:='anxious';
        when 'reactive_low_tolerance' then dimension:='care'; value:='reactive';
        when 'puppy_first_groom' then dimension:='care'; value:='puppy';
        when 'senior_care' then dimension:='care'; value:='senior';
        when 'matted_coat_handling' then dimension:='care'; value:='matted';
        when 'curly_coat' then dimension:='coat'; value:='curly_wavy';
        when 'terrier_coat' then dimension:='coat'; value:='wire';
        when 'nail_paw_care' then
          if p_service<>'nail_trim' then return null; end if;
          dimension:='service'; value:=p_service;
        when 'de_shedding_treatment' then
          if p_service<>'de_shedding' then return null; end if;
          dimension:='service'; value:=p_service;
        when 'full_haircut_styling' then
          if p_service not in ('full_groom','haircut_only') then return null; end if;
          dimension:='service'; value:=p_service;
        else return null;
      end case;
    when 'service' then null;
    when 'coat' then null;
    when 'size' then null;
    when 'care' then null;
    else return null;
  end case;
  return jsonb_build_object('dimension',dimension,'value',value);
end $$;
revoke all on function app_private.canonical_review_key(text,text,text) from public,anon,authenticated,service_role;

alter table public.review_pet_fit_outcomes drop constraint review_pet_fit_outcomes_trait_check;
alter table public.review_pet_fit_outcomes add constraint review_pet_fit_outcomes_trait_check check (
  app_private.pet_fit_valid_trait_pair(trait_type,trait_value)
  or (trait_type='service' and trait_value in ('full_groom','bath_and_brush','haircut_only','nail_trim','de_shedding'))
  or (trait_type='coat' and trait_value in ('curly_wavy','wire','double_coat','drop_coat','long_silky','short_smooth','hairless_low_coat'))
  or (trait_type='size' and trait_value in ('XS','S','M','L','XL','XXL','Giant'))
  or (trait_type='care' and trait_value in ('anxious','reactive','puppy','senior','matted'))
);
alter table public.reviews add column evidence_context_revision uuid;
alter table public.reviews add column evidence_context_version integer;

create function app_private.write_verified_review(p_booking uuid,p_revision uuid,p_rating integer,p_content text,
  p_outcomes jsonb,p_legacy boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); b public.bookings%rowtype; c app_private.booking_review_contexts%rowtype;
  r public.reviews%rowtype; body text:=nullif(btrim(p_content),''); item jsonb; key jsonb; seen jsonb:='[]';
  normalized jsonb:='[]'; avg numeric; n integer; total bigint;
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
    raise exception using errcode='28000',message='authenticated_user_required';
  end if;
  if not exists(select 1 from public.profiles where id=actor and role='customer')
    or exists(select 1 from public.account_deletion_requests where user_id=actor and anonymized_at is not null) then
    raise exception using errcode='42501',message='customer_profile_required';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception using errcode='22023',message='invalid_rating';
  end if;
  if char_length(body)>2000 then raise exception using errcode='22023',message='invalid_review_content'; end if;
  if p_outcomes is null or jsonb_typeof(p_outcomes)<>'array' then
    raise exception using errcode='22023',message='invalid_review_outcomes';
  end if;
  select * into b from public.bookings where id=p_booking and customer_id=actor for update;
  if not found then raise exception using errcode='P0001',message='booking_not_found'; end if;
  if b.status<>'completed' then raise exception using errcode='P0001',message='booking_not_completed'; end if;
  perform app_private.freeze_booking_review_context(b.id);
  select * into strict c from app_private.booking_review_contexts where booking_id=b.id;
  if not p_legacy and p_revision is distinct from c.context_revision then
    raise exception using errcode='22023',message='review_context_changed';
  end if;
  if jsonb_array_length(p_outcomes)>least(20,jsonb_array_length(c.allowed_keys)) then
    raise exception using errcode='22023',message='invalid_pet_fit_context';
  end if;
  for item in select value from jsonb_array_elements(p_outcomes) loop
    if jsonb_typeof(item)<>'object' or item->>'outcome' is null or item->>'outcome' not in ('positive','negative') then
      raise exception using errcode='22023',message='invalid_review_outcome_value';
    end if;
    if p_legacy then key:=app_private.canonical_review_key(item->>'trait_type',item->>'trait_value',c.service_type);
    else key:=jsonb_build_object('dimension',item->>'trait_type','value',item->>'trait_value'); end if;
    if key is null or not c.allowed_keys @> jsonb_build_array(key) then
      raise exception using errcode='22023',message='invalid_pet_fit_context';
    end if;
    if seen @> jsonb_build_array(key) then
      raise exception using errcode='22023',message='duplicate_review_outcome';
    end if;
    seen:=seen||jsonb_build_array(key);
    normalized:=normalized||jsonb_build_array(key||jsonb_build_object('outcome',item->>'outcome'));
  end loop;
  begin
    insert into public.reviews(booking_id,customer_id,groomer_id,rating,content,evidence_context_revision,evidence_context_version)
      values(b.id,actor,b.groomer_id,p_rating,body,c.context_revision,c.evidence_context_version) returning * into r;
  exception when unique_violation then raise exception using errcode='P0001',message='review_already_exists'; end;
  -- Rating/FK writes may wait behind anonymization. Recheck after those locks, before outcomes.
  if exists(select 1 from public.account_deletion_requests where user_id=actor and anonymized_at is not null) then
    raise exception using errcode='42501',message='customer_profile_required';
  end if;
  if (select context_revision from app_private.booking_review_contexts where booking_id=b.id) is distinct from c.context_revision then
    raise exception using errcode='22023',message='review_context_changed';
  end if;
  insert into public.review_pet_fit_outcomes(review_id,booking_id,customer_id,groomer_id,trait_type,trait_value,outcome)
    select r.id,b.id,actor,b.groomer_id,value->>'dimension',value->>'value',value->>'outcome'
    from jsonb_array_elements(normalized);
  select rating_avg,rating_count,rating_sum into avg,n,total from public.groomer_profiles where user_id=b.groomer_id;
  return jsonb_build_object('review_id',r.id,'booking_id',r.booking_id,'customer_id',r.customer_id,
    'groomer_id',r.groomer_id,'rating',r.rating,'content',r.content,'created_at',r.created_at,
    'groomer_rating_avg',avg,'groomer_rating_count',n,'groomer_rating_sum',total,
    'context_revision',c.context_revision);
end $$;
revoke all on function app_private.write_verified_review(uuid,uuid,integer,text,jsonb,boolean)
  from public,anon,authenticated,service_role;

create function app_private.create_review_v2(p_booking_id uuid,p_expected_context_revision uuid,p_rating integer,
  p_content text,p_pet_fit_outcomes jsonb)
returns jsonb language sql security definer set search_path = '' as $$
  select app_private.write_verified_review(p_booking_id,p_expected_context_revision,p_rating,p_content,p_pet_fit_outcomes,false);
$$;
create function public.create_review_v2(p_booking_id uuid,p_expected_context_revision uuid,p_rating integer,
  p_content text,p_pet_fit_outcomes jsonb)
returns jsonb language sql security invoker set search_path = '' as $$
  select app_private.create_review_v2(p_booking_id,p_expected_context_revision,p_rating,p_content,p_pet_fit_outcomes);
$$;
revoke all on function app_private.create_review_v2(uuid,uuid,integer,text,jsonb),public.create_review_v2(uuid,uuid,integer,text,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function app_private.create_review_v2(uuid,uuid,integer,text,jsonb),public.create_review_v2(uuid,uuid,integer,text,jsonb) to authenticated;

create or replace function app_private.create_review(p_booking_id uuid,p_rating integer,p_content text default null,
  p_pet_fit_outcomes jsonb default '[]')
returns table(review_id uuid,booking_id uuid,customer_id uuid,groomer_id uuid,rating integer,content text,
  created_at timestamptz,groomer_rating_avg numeric,groomer_rating_count integer)
language sql security definer set search_path = '' as $$
  select result.* from jsonb_to_record(app_private.write_verified_review(p_booking_id,null,p_rating,
    p_content,p_pet_fit_outcomes,true)) as result(review_id uuid,booking_id uuid,customer_id uuid,groomer_id uuid,
      rating integer,content text,created_at timestamptz,groomer_rating_avg numeric,groomer_rating_count integer);
$$;

create table app_private.review_evidence_projection (
  outcome_id uuid primary key references public.review_pet_fit_outcomes(id) on delete cascade,
  review_id uuid not null references public.reviews(id) on delete cascade,
  context_revision uuid,
  service_at timestamptz,
  species text,
  service_type text,
  dimension text,
  value text,
  outcome text not null,
  is_valid boolean not null,
  isolation_reason text
);
revoke all on app_private.review_evidence_projection from public,anon,authenticated,service_role;
alter table app_private.review_evidence_projection enable row level security;
create index review_evidence_projection_review_idx on app_private.review_evidence_projection(review_id);

create function app_private.rebuild_review_evidence(p_review uuid)
returns void language plpgsql set search_path = '' as $$
declare c app_private.booking_review_contexts%rowtype;
begin
  select context.* into c from app_private.booking_review_contexts context
    join public.reviews review on review.booking_id=context.booking_id where review.id=p_review;
  delete from app_private.review_evidence_projection where review_id=p_review;
  if c.source_state='privacy_withheld' then return; end if;
  insert into app_private.review_evidence_projection(outcome_id,review_id,context_revision,service_at,
    species,service_type,dimension,value,outcome,is_valid,isolation_reason)
  with normalized as (
    select o.*,app_private.canonical_review_key(o.trait_type,o.trait_value,c.service_type) key
    from public.review_pet_fit_outcomes o where o.review_id=p_review
  ), grouped as (
    select n.*,count(*) filter (where outcome='positive') over(partition by key) positives,
      count(*) filter (where outcome='negative') over(partition by key) negatives,
      row_number() over(partition by key order by created_at,id) ordinal
    from normalized n
  ), classified as (
    select g.*,case
      when c.species is null or c.species not in ('dog','cat') then 'missing_species'
      when c.service_at is null then 'missing_service_time'
      when key is null then 'unrelated_key'
      when not c.allowed_keys @> jsonb_build_array(key) then
        case when key->>'dimension' in ('coat','size','care') and c.service_type<>'nail_trim'
          then 'untrusted_fact' else 'unrelated_key' end
      when positives>0 and negatives>0 then 'conflicting_alias'
      when ordinal>1 then 'duplicate_alias'
      else null end reason
    from grouped g
  )
  select id,review_id,c.context_revision,c.service_at,c.species,c.service_type,key->>'dimension',key->>'value',
    outcome,reason is null,reason from classified;
end $$;
revoke all on function app_private.rebuild_review_evidence(uuid) from public,anon,authenticated,service_role;

create function app_private.refresh_review_evidence()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op<>'INSERT' and exists(select 1 from public.reviews where id=old.review_id) then
    perform app_private.rebuild_review_evidence(old.review_id);
  end if;
  if tg_op<>'DELETE' then perform app_private.rebuild_review_evidence(new.review_id); end if;
  return null;
end $$;
revoke all on function app_private.refresh_review_evidence() from public,anon,authenticated,service_role;
create trigger review_outcomes_project after insert or update or delete on public.review_pet_fit_outcomes
for each row execute function app_private.refresh_review_evidence();

create function app_private.clear_anonymized_review_evidence()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.anonymized_at is null then return new; end if;
  update app_private.booking_review_contexts c set service_at=null,service_time_zone_identifier=null,
    species=null,service_type=null,allowed_keys='[]',source_state='privacy_withheld',context_revision=gen_random_uuid()
    where exists(select 1 from public.bookings b where b.id=c.booking_id
      and (b.customer_id=new.user_id or b.groomer_id=new.user_id)) and c.source_state<>'privacy_withheld';
  delete from app_private.review_evidence_projection e using public.reviews r
    where e.review_id=r.id and (r.customer_id=new.user_id or r.groomer_id=new.user_id);
  return new;
end $$;
revoke all on function app_private.clear_anonymized_review_evidence() from public,anon,authenticated,service_role;
create trigger account_deletion_clear_review_evidence after insert or update of anonymized_at on public.account_deletion_requests
for each row execute function app_private.clear_anonymized_review_evidence();

-- Deployment performs only reconstructible context/projection work, never invents reviews.
do $$ declare record record; begin
  for record in select id from public.bookings where status='completed' loop
    perform app_private.freeze_booking_review_context(record.id);
  end loop;
  for record in select id from public.reviews loop
    perform app_private.rebuild_review_evidence(record.id);
  end loop;
end $$;
