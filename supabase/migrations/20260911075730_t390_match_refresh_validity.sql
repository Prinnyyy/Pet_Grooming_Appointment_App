-- T-390 / MR-04. Producers stay append-only and never lock another business row.
alter table app_private.match_refresh_queue add column reason text not null default 'hard_eligibility'
  check (reason in ('hard_eligibility','evidence','rating','display'));

create table app_private.match_candidate_evaluations (
  request_id uuid not null references public.grooming_requests(id) on delete cascade,
  groomer_id uuid not null references public.groomer_profiles(user_id) on delete cascade,
  result jsonb not null,
  witness jsonb,
  source_revision bigint not null default 0,
  evidence_revision bigint not null default 0,
  rating_revision bigint not null default 0,
  display_revision bigint not null default 0,
  ranking_revision uuid not null default gen_random_uuid(),
  evaluated_at timestamptz not null,
  valid_until timestamptz not null,
  next_evaluation_at timestamptz,
  primary key(request_id,groomer_id)
);
alter table app_private.match_candidate_evaluations enable row level security;
revoke all on app_private.match_candidate_evaluations from public,anon,authenticated,service_role;
create index match_candidate_evaluations_due on app_private.match_candidate_evaluations(next_evaluation_at,request_id,groomer_id)
  where next_evaluation_at is not null;

create function app_private.enqueue_soft_match_refresh(p_groomer uuid,p_reason text)
returns void language plpgsql set search_path = '' as $$
begin
  if p_reason not in ('evidence','rating','display') then
    raise exception using errcode='22023',message='invalid_soft_refresh_reason';
  end if;
  insert into app_private.match_refresh_queue(request_id,groomer_id,reason)
  select distinct r.id,p_groomer,p_reason from public.grooming_requests r
  where r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
    and (exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=p_groomer and m.status<>'dismissed')
      or exists(select 1 from app_private.match_candidate_evaluations c where c.request_id=r.id and c.groomer_id=p_groomer));
end $$;
revoke all on function app_private.enqueue_soft_match_refresh(uuid,text) from public,anon,authenticated,service_role;

create function app_private.refresh_candidate_evaluation(p_request uuid,p_groomer uuid,p_now timestamptz,p_source bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.grooming_requests%rowtype; result jsonb; future_result jsonb; witness jsonb;
  proof_clock timestamptz; deadline timestamptz; due timestamptz; zone text; notice integer;
begin
  if p_now is null or not isfinite(p_now) then raise exception using errcode='22023',message='invalid_clock'; end if;
  select * into r from public.grooming_requests where id=p_request for update;
  if not found then return; end if;
  if r.status not in ('open','has_offers') or r.expires_at<=p_now
    or not exists(select 1 from public.groomer_profiles where user_id=p_groomer)
    or exists(select 1 from public.request_matches where request_id=p_request and groomer_id=p_groomer and status='dismissed') then
    delete from app_private.match_candidate_evaluations where request_id=p_request and groomer_id=p_groomer;
    return;
  end if;
  result:=app_private.evaluate_match_eligibility(p_request,p_groomer,p_now);
  deadline:=least(r.expires_at,p_now+interval '60 seconds');
  due:=deadline;
  if result->>'state'='estimated_fit' then
    proof_clock:=least(p_now+interval '15 minutes',r.expires_at-interval '1 microsecond');
    if proof_clock>p_now then
      future_result:=app_private.evaluate_match_eligibility(p_request,p_groomer,proof_clock);
      if future_result->>'state'='estimated_fit' then result:=future_result; end if;
    end if;
    select min(timezone) into zone from public.groomer_availability_windows where groomer_id=p_groomer;
    select minimum_advance_notice_days into notice from public.groomer_booking_preferences where groomer_id=p_groomer;
    deadline:=least(r.expires_at,(result->>'service_start')::timestamptz-interval '5 minutes');
    if notice>0 then deadline:=least(deadline,timezone(zone,(timezone(zone,p_now)::date+1)::timestamp)); end if;
    due:=deadline;
    witness:=jsonb_build_object('service_start',result->'service_start','service_end',result->'service_end',
      'occupied_start',result->'occupied_start','occupied_end',result->'occupied_end','kind','fixed_source_interval');
  elsif result->>'state'='excluded' and result->>'reason' in (
    'no_continuous_opening','pet_species_excluded','pet_size_excluded','location_excluded',
    'service_unavailable','groomer_unavailable','request_species_confirmation_required',
    'schedule_confirmation_required','service_timezone_confirmation_required','request_unavailable') then
    deadline:=r.expires_at; due:=null;
    witness:=jsonb_build_object('kind','monotone_or_source_only_exclusion','reason',result->>'reason');
  end if;
  result:=result||jsonb_build_object('evaluated_at',p_now,'valid_until',deadline,'source_revision',p_source::text);
  insert into app_private.match_candidate_evaluations(request_id,groomer_id,result,witness,source_revision,evaluated_at,valid_until,next_evaluation_at)
    values(p_request,p_groomer,result,witness,p_source,p_now,deadline,due)
    on conflict(request_id,groomer_id) do update set result=excluded.result,witness=excluded.witness,
      source_revision=greatest(app_private.match_candidate_evaluations.source_revision,excluded.source_revision),
      evaluated_at=excluded.evaluated_at,valid_until=excluded.valid_until,next_evaluation_at=excluded.next_evaluation_at,
      ranking_revision=gen_random_uuid();
  if result->>'state'='excluded' then
    update public.request_matches set status=case when status in ('visible','viewed') then 'hidden' else status end,
      eligibility_evaluation=result where request_id=p_request and groomer_id=p_groomer and status in ('visible','viewed','offered','hidden');
  else
    insert into public.request_matches(request_id,groomer_id,customer_id,status,eligibility_evaluation)
      values(p_request,p_groomer,r.customer_id,'visible',result)
      on conflict on constraint request_matches_request_groomer_key do update set
        eligibility_evaluation=excluded.eligibility_evaluation,
        status=case when public.request_matches.status='hidden' then 'visible' else public.request_matches.status end
      where public.request_matches.status in ('visible','viewed','offered')
        or (public.request_matches.status='hidden' and public.request_matches.eligibility_evaluation->>'state'='excluded');
  end if;
end $$;

create function app_private.read_candidate_evaluation(p_request uuid,p_groomer uuid,p_now timestamptz)
returns jsonb language sql stable set search_path = '' as $$
  select case when p_now is null or not isfinite(p_now) or c.request_id is null or c.valid_until<=p_now
    or exists(select 1 from app_private.match_refresh_queue q where q.request_id=p_request and q.groomer_id=p_groomer
      and q.reason='hard_eligibility') then jsonb_build_object('state','pending','reason','refresh_pending')
    else c.result end from (select 1) singleton left join app_private.match_candidate_evaluations c
      on c.request_id=p_request and c.groomer_id=p_groomer;
$$;
revoke all on function app_private.read_candidate_evaluation(uuid,uuid,timestamptz) from public,anon,authenticated,service_role;

create or replace function app_private.enqueue_profile_match_refresh()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='INSERT' then perform app_private.enqueue_match_refresh(new.user_id);
  elsif new.eligibility_revision is distinct from old.eligibility_revision then perform app_private.enqueue_match_refresh(new.user_id);
  elsif to_jsonb(new)-array['updated_at','eligibility_revision'] is distinct from to_jsonb(old)-array['updated_at','eligibility_revision'] then
    perform app_private.enqueue_soft_match_refresh(new.user_id,'display');
  end if;
  return new;
end $$;
drop trigger groomer_profiles_refresh_matches on public.groomer_profiles;
create trigger groomer_profiles_refresh_matches after insert or update on public.groomer_profiles
for each row execute function app_private.enqueue_profile_match_refresh();

create function app_private.account_match_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare request record;
begin
  if new.role is distinct from old.role then
    perform app_private.enqueue_match_refresh(new.id);
    for request in select id from public.grooming_requests where customer_id=new.id and status in ('open','has_offers') loop
      perform app_private.enqueue_request_match_refresh(request.id);
    end loop;
  else perform app_private.enqueue_soft_match_refresh(new.id,'display');
  end if;
  return new;
end $$;
revoke all on function app_private.account_match_change() from public,anon,authenticated,service_role;
create trigger profiles_candidate_change after update of role,avatar_path on public.profiles
for each row execute function app_private.account_match_change();
revoke all on function app_private.refresh_candidate_evaluation(uuid,uuid,timestamptz,bigint)
  from public,anon,authenticated,service_role;

create or replace function app_private.drain_match_refresh_queue(p_limit integer default 100)
returns integer language plpgsql security definer set search_path = '' as $$
declare item record; processed integer:=0; event_ids bigint[]; hard boolean; source bigint;
  limit_count integer:=least(greatest(coalesce(p_limit,100),2),250); now_at timestamptz:=statement_timestamp();
begin
  delete from app_private.match_refresh_queue where id in (
    select q.id from app_private.match_refresh_queue q where not exists(select 1 from public.grooming_requests r
      where r.id=q.request_id and r.status in ('open','has_offers') and r.expires_at>now_at)
      or not exists(select 1 from public.groomer_profiles where user_id=q.groomer_id) order by q.id limit limit_count);
  for item in
    select r.id request_id,q.groomer_id from public.grooming_requests r join (
      select request_id,groomer_id,min(id) first_id from app_private.match_refresh_queue group by request_id,groomer_id
    ) q on q.request_id=r.id order by q.first_id limit (limit_count+1)/2 for update of r skip locked
  loop
    select array_agg(id),bool_or(reason='hard_eligibility'),max(id) filter(where reason='hard_eligibility')
      into event_ids,hard,source from app_private.match_refresh_queue where request_id=item.request_id and groomer_id=item.groomer_id;
    if hard then perform app_private.refresh_candidate_evaluation(item.request_id,item.groomer_id,now_at,coalesce(source,0)); end if;
    update app_private.match_candidate_evaluations c set
      evidence_revision=greatest(c.evidence_revision,coalesce((select max(id) from app_private.match_refresh_queue where id=any(event_ids) and reason='evidence'),0)),
      rating_revision=greatest(c.rating_revision,coalesce((select max(id) from app_private.match_refresh_queue where id=any(event_ids) and reason='rating'),0)),
      display_revision=greatest(c.display_revision,coalesce((select max(id) from app_private.match_refresh_queue where id=any(event_ids) and reason='display'),0)),
      ranking_revision=gen_random_uuid()
      where c.request_id=item.request_id and c.groomer_id=item.groomer_id;
    delete from app_private.match_refresh_queue where id=any(event_ids);
    processed:=processed+1;
  end loop;
  for item in
    select c.request_id,c.groomer_id,c.source_revision from app_private.match_candidate_evaluations c
      join public.grooming_requests r on r.id=c.request_id
      where c.next_evaluation_at<=now_at and c.evaluated_at<now_at
        and r.status in ('open','has_offers') and r.expires_at>now_at
      order by c.next_evaluation_at,c.request_id,c.groomer_id limit limit_count-processed for update of r skip locked
  loop
    perform app_private.refresh_candidate_evaluation(item.request_id,item.groomer_id,now_at,item.source_revision);
    processed:=processed+1;
  end loop;
  return processed;
end $$;
revoke all on function app_private.drain_match_refresh_queue(integer) from public,anon,authenticated,service_role;

create function app_private.enqueue_request_match_refresh(p_request uuid)
returns void language plpgsql set search_path = '' as $$
begin
  insert into app_private.match_refresh_queue(request_id,groomer_id)
  select r.id,g.user_id from public.grooming_requests r cross join public.groomer_profiles g
  where r.id=p_request and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
    and not exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=g.user_id and m.status='dismissed')
    and (exists(select 1 from public.request_matches m where m.request_id=r.id and m.groomer_id=g.user_id)
      or exists(select 1 from app_private.match_candidate_evaluations c where c.request_id=r.id and c.groomer_id=g.user_id)
      or (g.is_active and exists(select 1 from public.groomer_services s
        where s.groomer_id=g.user_id and s.service_type=r.service_type and s.is_active)
        and exists(select 1 from app_private.address_locations a join app_private.address_locations b
          on b.id=g.address_location_id and b.owner_id=g.user_id
          cross join lateral app_private.evaluate_request_location_fit(a.location,b.location,r.location_mode,
            r.travel_radius_miles,g.service_radius_miles,r.state,r.city,g.base_state,g.base_city) fit
          where a.id=r.address_location_id and a.owner_id=r.customer_id and fit.is_eligible)));
end $$;
revoke all on function app_private.enqueue_request_match_refresh(uuid) from public,anon,authenticated,service_role;

create function app_private.request_candidate_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $$
declare request uuid;
begin
  request:=case when tg_op='DELETE' then old.id else new.id end;
  if tg_op='DELETE' then
    delete from app_private.match_refresh_queue where request_id=request;
    return old;
  end if;
  if new.status not in ('open','has_offers') then
    delete from app_private.match_candidate_evaluations where request_id=request;
    delete from app_private.match_refresh_queue where request_id=request;
  elsif tg_op='INSERT' then perform app_private.enqueue_request_match_refresh(request);
  elsif row(new.terms_revision,new.preference_time_zone_identifier,new.expires_at)
    is distinct from row(old.terms_revision,old.preference_time_zone_identifier,old.expires_at)
    or old.status not in ('open','has_offers') then perform app_private.enqueue_request_match_refresh(request);
  end if;
  return new;
end $$;
revoke all on function app_private.request_candidate_lifecycle() from public,anon,authenticated,service_role;
create trigger grooming_requests_candidate_lifecycle after insert or update or delete on public.grooming_requests
for each row execute function app_private.request_candidate_lifecycle();

create or replace function app_private.enqueue_address_match_refresh()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner uuid; location_id uuid; request record;
begin
  owner:=case when tg_op='DELETE' then old.owner_id else new.owner_id end;
  location_id:=case when tg_op='DELETE' then old.id else new.id end;
  perform app_private.enqueue_match_refresh(owner);
  for request in select id from public.grooming_requests where address_location_id=location_id
    and status in ('open','has_offers') loop perform app_private.enqueue_request_match_refresh(request.id); end loop;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;

create function app_private.pet_candidate_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $$
declare request record;
begin
  for request in select id from public.grooming_requests where pet_id=new.id and status in ('open','has_offers') loop
    perform app_private.enqueue_request_match_refresh(request.id);
  end loop;
  return new;
end $$;
revoke all on function app_private.pet_candidate_lifecycle() from public,anon,authenticated,service_role;
create trigger pets_candidate_lifecycle after update of is_active,deleted_at on public.pets
for each row execute function app_private.pet_candidate_lifecycle();

create function app_private.groomer_candidate_deleted()
returns trigger language plpgsql security definer set search_path = '' as $$
begin delete from app_private.match_refresh_queue where groomer_id=old.user_id; return old; end $$;
revoke all on function app_private.groomer_candidate_deleted() from public,anon,authenticated,service_role;
create trigger groomer_profiles_candidate_deleted after delete on public.groomer_profiles
for each row execute function app_private.groomer_candidate_deleted();

create function app_private.enqueue_review_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare groomer uuid;
begin
  groomer:=case when tg_op='DELETE' then old.groomer_id else new.groomer_id end;
  if tg_op='UPDATE' then
    if new.rating is distinct from old.rating then perform app_private.enqueue_soft_match_refresh(groomer,'rating'); end if;
    if new.content is distinct from old.content then perform app_private.enqueue_soft_match_refresh(groomer,'display'); end if;
  else
    perform app_private.enqueue_soft_match_refresh(groomer,'rating');
    perform app_private.enqueue_soft_match_refresh(groomer,'evidence');
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app_private.enqueue_review_change() from public,anon,authenticated,service_role;
create trigger reviews_candidate_change after insert or update or delete on public.reviews
for each row execute function app_private.enqueue_review_change();

create function app_private.enqueue_outcome_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare groomer uuid;
begin
  groomer:=case when tg_op='DELETE' then old.groomer_id else new.groomer_id end;
  perform app_private.enqueue_soft_match_refresh(groomer,'evidence');
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app_private.enqueue_outcome_change() from public,anon,authenticated,service_role;
create trigger review_outcomes_candidate_change after insert or update or delete on public.review_pet_fit_outcomes
for each row execute function app_private.enqueue_outcome_change();

create function app_private.enqueue_derived_review_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare groomer uuid;
begin
  if tg_table_name='booking_review_contexts' then
    select groomer_id into groomer from public.bookings where id=case when tg_op='DELETE' then old.booking_id else new.booking_id end;
  else
    select groomer_id into groomer from public.reviews where id=case when tg_op='DELETE' then old.review_id else new.review_id end;
  end if;
  if groomer is not null then perform app_private.enqueue_soft_match_refresh(groomer,'evidence'); end if;
  if groomer is not null and tg_table_name='booking_review_contexts' then
    perform app_private.enqueue_soft_match_refresh(groomer,'rating');
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app_private.enqueue_derived_review_change() from public,anon,authenticated,service_role;
create trigger review_contexts_candidate_change after insert or update or delete on app_private.booking_review_contexts
for each row execute function app_private.enqueue_derived_review_change();
create trigger review_projection_candidate_change after insert or update or delete on app_private.review_evidence_projection
for each row execute function app_private.enqueue_derived_review_change();

create function app_private.enqueue_display_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare groomer uuid;
begin
  groomer:=case when tg_op='DELETE' then old.groomer_id else new.groomer_id end;
  perform app_private.enqueue_soft_match_refresh(groomer,'display');
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function app_private.enqueue_display_change() from public,anon,authenticated,service_role;
create trigger groomer_claims_display_change after insert or update or delete on public.groomer_fit_claims
for each row execute function app_private.enqueue_display_change();
create trigger groomer_portfolio_tags_display_change after insert or update or delete on public.groomer_portfolio_fit_tags
for each row execute function app_private.enqueue_display_change();
create trigger groomer_portfolio_display_change after insert or update or delete on public.groomer_portfolio_photos
for each row execute function app_private.enqueue_display_change();

create function app_private.enqueue_service_match_refresh()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='DELETE' then perform app_private.enqueue_match_refresh(old.groomer_id); return old;
  elsif tg_op='INSERT' then perform app_private.enqueue_match_refresh(new.groomer_id);
  elsif new.eligibility_revision is distinct from old.eligibility_revision then
    perform app_private.enqueue_match_refresh(new.groomer_id);
  else perform app_private.enqueue_soft_match_refresh(new.groomer_id,'display');
  end if;
  return new;
end $$;
revoke all on function app_private.enqueue_service_match_refresh() from public,anon,authenticated,service_role;
drop trigger groomer_services_refresh_matches on public.groomer_services;
create trigger groomer_services_refresh_matches after insert or update or delete on public.groomer_services
for each row execute function app_private.enqueue_service_match_refresh();

create function app_private.offer_candidate_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='DELETE' then
    insert into app_private.match_refresh_queue(request_id,groomer_id,reason) values(old.request_id,old.groomer_id,'display');
    return old;
  end if;
  insert into app_private.match_refresh_queue(request_id,groomer_id,reason) values(new.request_id,new.groomer_id,'display');
  return new;
end $$;
revoke all on function app_private.offer_candidate_change() from public,anon,authenticated,service_role;
create trigger groomer_offers_candidate_change after insert or update or delete on public.groomer_offers
for each row execute function app_private.offer_candidate_change();

-- Existing hard events cover availability, preferences, services and released resources.
create or replace function app_private.get_my_matched_requests(p_groomer_id uuid,p_limit integer default 25,p_offset integer default 0)
returns setof public.request_matches language plpgsql stable security definer set search_path = ''
as $$
declare owner uuid:=(select auth.uid());
begin
  if owner is null or owner is distinct from p_groomer_id
    or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles where id=owner and role='groomer') then
    raise exception using errcode='42501',message='groomer_profile_required';
  end if;
  if p_limit is null or p_limit not between 1 and 100 or p_offset is null or p_offset<0 then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  return query
    select display.*
    from public.request_matches m join public.grooming_requests r on r.id=m.request_id
    cross join lateral jsonb_populate_record(null::public.request_matches,to_jsonb(m)||
      jsonb_build_object('eligibility_evaluation',
        app_private.read_candidate_evaluation(m.request_id,m.groomer_id,statement_timestamp()))) display
    where m.groomer_id=owner and m.status in ('visible','viewed','offered')
      and r.status in ('open','has_offers') and r.expires_at>statement_timestamp()
    order by m.created_at desc,m.id desc limit p_limit offset p_offset;
end $$;

-- Bootstrap coarse candidates, including those without request_matches rows.
do $$ declare request record; begin
  for request in select id from public.grooming_requests where status in ('open','has_offers') and expires_at>statement_timestamp() loop
    perform app_private.enqueue_request_match_refresh(request.id);
  end loop;
end $$;
