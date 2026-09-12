-- T-390 / MR-03. Private shadow calculation; no marketplace order changes here.
create index reviews_groomer_customer_service_idx on public.reviews(groomer_id,customer_id,booking_id);
create index review_context_species_service_idx on app_private.booking_review_contexts(species,service_type,service_at,booking_id);
create index review_projection_valid_key_idx on app_private.review_evidence_projection(review_id,dimension,value) where is_valid;

create function app_private.match_target_keys(p_request uuid,p_groomer uuid,p_offer uuid default null)
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype; o public.groomer_offers%rowtype; zone text; first_keys jsonb; last_keys jsonb;
begin
  select * into strict r from public.grooming_requests where id=p_request;
  if p_offer is not null then
    select * into strict o from public.groomer_offers where id=p_offer and request_id=p_request and groomer_id=p_groomer;
    return app_private.review_allowed_keys(r.pet_snapshot,r.service_type,o.proposed_start,o.service_time_zone_identifier);
  end if;
  if r.location_mode='groomer_comes_to_customer' then zone:=r.preference_time_zone_identifier;
  else select a.time_zone_identifier into zone from public.groomer_profiles g
    join app_private.address_locations a on a.id=g.address_location_id and a.owner_id=g.user_id where g.user_id=p_groomer;
  end if;
  first_keys:=app_private.review_allowed_keys(r.pet_snapshot,r.service_type,r.preferred_start,zone);
  last_keys:=app_private.review_allowed_keys(r.pet_snapshot,r.service_type,r.preferred_end-interval '1 microsecond',zone);
  -- Only age categories stable across the whole window survive this intersection.
  return (select coalesce(jsonb_agg(value order by value->>'dimension',value->>'value'),'[]')
    from jsonb_array_elements(first_keys) where last_keys @> jsonb_build_array(value));
end $$;
revoke all on function app_private.match_target_keys(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function app_private.score_match_evidence(p_request_id uuid,p_groomer_id uuid,p_score_as_of timestamptz,p_offer_id uuid default null)
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype; target jsonb; score jsonb; distance_miles double precision;
begin
  if p_score_as_of is null or not isfinite(p_score_as_of) then
    raise exception using errcode='22023',message='invalid_score_clock';
  end if;
  select * into strict r from public.grooming_requests where id=p_request_id;
  target:=app_private.match_target_keys(p_request_id,p_groomer_id,p_offer_id);
  select extensions.st_distance(a.location,b.location)/1609.344 into distance_miles
    from app_private.address_locations a join public.groomer_profiles g on g.user_id=p_groomer_id
    join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=g.user_id
    where a.id=r.address_location_id and a.owner_id=r.customer_id;

  with target_keys as (
    select value->>'dimension' dimension,value->>'value' value from jsonb_array_elements(target)
  ), shares as (
    select k.*,1.0/(select count(distinct dimension) from target_keys)/count(*) over(partition by dimension) share
    from target_keys k
  ), eligible_contexts as materialized (
    select c.*,b.customer_id from app_private.booking_review_contexts c
      join public.bookings b on b.id=c.booking_id
    where b.groomer_id=p_groomer_id and b.status='completed' and c.service_at<=p_score_as_of
      and isfinite(c.service_at)
  ), quality_rows as materialized (
    select review.id,review.customer_id,review.rating,c.service_at,
      power(2.0::numeric,-extract(epoch from (p_score_as_of-c.service_at))/15552000.0) decay
    from public.reviews review join eligible_contexts c on c.booking_id=review.booking_id
    where review.groomer_id=p_groomer_id
  ), quality_weights as (
    select q.*,case when sum(decay) over(partition by customer_id)>0 then
      max(decay) over(partition by customer_id)*decay/sum(decay) over(partition by customer_id) else 0 end weight
    from quality_rows q
  ), related_contexts as materialized (
    select * from eligible_contexts where species=lower(r.pet_snapshot->>'species') and service_type=r.service_type
      and r.service_type<>'custom_request'
  ), fit_rows as (
    select review.id,review.customer_id,c.service_at,
      power(2.0::numeric,-extract(epoch from (p_score_as_of-c.service_at))/15552000.0) decay,
      coalesce(sum(s.share) filter(where e.outcome='positive'),0) positive,
      coalesce(sum(s.share) filter(where e.outcome='negative'),0) negative
    from related_contexts c join public.reviews review on review.booking_id=c.booking_id
      join app_private.review_evidence_projection e on e.review_id=review.id and e.is_valid
      join shares s on s.dimension=e.dimension and s.value=e.value
    group by review.id,review.customer_id,c.service_at
  ), fit_weights as (
    select f.*,case when sum(decay) over(partition by customer_id)>0 then
      max(decay) over(partition by customer_id)*decay/sum(decay) over(partition by customer_id) else 0 end weight
    from fit_rows f
  ), fit_totals as (
    select coalesce(sum(weight*positive),0) p,coalesce(sum(weight*negative),0) n,
      count(*) reviews,count(distinct customer_id) customers,max(service_at) latest from fit_weights
  ), quality_totals as (
    select 100*(2.5+coalesce(sum(weight*(rating-1)/4.0),0))/(5+coalesce(sum(weight),0)) q,
      count(*) reviews,count(distinct customer_id) customers from quality_weights
  ), key_coverage as (
    select s.dimension,s.value,
      (select count(*) from related_contexts c where c.allowed_keys @> jsonb_build_array(
        jsonb_build_object('dimension',s.dimension,'value',s.value))) completed,
      (select count(*) from related_contexts c join public.reviews review on review.booking_id=c.booking_id
        join app_private.review_evidence_projection e on e.review_id=review.id and e.is_valid
        where e.dimension=s.dimension and e.value=s.value and e.outcome='positive') positive,
      (select count(*) from related_contexts c join public.reviews review on review.booking_id=c.booking_id
        join app_private.review_evidence_projection e on e.review_id=review.id and e.is_valid
        where e.dimension=s.dimension and e.value=s.value and e.outcome='negative') negative
    from shares s
  )
  select jsonb_build_object('f',50+50*(f.p-f.n)/(f.p+f.n+5),'q',q.q,
    'd',case when distance_miles is null then null else 100/(1+distance_miles/5) end,
    'positive_weight',f.p,'negative_weight',f.n,'related_review_count',f.reviews,
    'f_customer_count',f.customers,'q_review_count',q.reviews,'q_customer_count',q.customers,
    'completed_count',(select count(*) from related_contexts),'latest_service_at',f.latest,
    'coverage',(select coalesce(jsonb_agg(jsonb_build_object('dimension',dimension,'value',value,
      'completed_count',completed,'positive_count',positive,'negative_count',negative,
      'unknown_count',greatest(0,completed-positive-negative)) order by dimension,value),'[]') from key_coverage),
    'algorithm_version','matching-v1','score_as_of',p_score_as_of,
    'state',case when f.reviews=0 then 'no_evidence' else 'available' end)
    into score from fit_totals f cross join quality_totals q;
  return score||jsonb_build_object('distance_miles',distance_miles,
    'b',0.70*(score->>'f')::numeric+0.30*(score->>'d')::numeric,
    's',0.60*(score->>'f')::numeric+0.25*(score->>'q')::numeric+0.15*(score->>'d')::numeric);
end $$;
revoke all on function app_private.score_match_evidence(uuid,uuid,timestamptz,uuid)
  from public,anon,authenticated,service_role;

create function app_private.public_matching_evidence(p_score jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('state',p_score->'state','algorithm_version',p_score->'algorithm_version',
    'score_as_of',p_score->'score_as_of','related_review_count',p_score->'related_review_count',
    'independent_customers',p_score->'f_customer_count','completed_count',p_score->'completed_count',
    'latest_service_at',p_score->'latest_service_at','coverage',p_score->'coverage');
$$;
revoke all on function app_private.public_matching_evidence(jsonb) from public,anon,authenticated,service_role;

create function app_private.get_my_groomer_pet_fit_evidence_summary_v2()
returns table(groomer_id uuid,trait_type text,trait_value text,completed_booking_count bigint,
  positive_review_outcome_count bigint,negative_review_outcome_count bigint,structured_review_outcome_count bigint,
  last_completed_at timestamptz,last_review_outcome_at timestamptz,evidence_updated_at timestamptz,confidence_tier text)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid());
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or not exists(select 1 from public.profiles where id=actor and role='groomer') then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  return query
    with contexts as materialized (
      select c.*,key->>'dimension' dimension,key->>'value' value from app_private.booking_review_contexts c
        join public.bookings b on b.id=c.booking_id cross join lateral jsonb_array_elements(c.allowed_keys) key
        where b.groomer_id=actor and b.status='completed' and c.service_at<=statement_timestamp() and isfinite(c.service_at)
    )
    select actor,c.dimension,c.value,count(distinct c.booking_id),
      count(e.review_id) filter(where e.outcome='positive'),count(e.review_id) filter(where e.outcome='negative'),
      count(e.review_id),max(c.service_at),max(c.service_at) filter(where e.review_id is not null),statement_timestamp(),'unrated'::text
    from contexts c left join public.reviews r on r.booking_id=c.booking_id and r.groomer_id=actor
      left join app_private.review_evidence_projection e on e.review_id=r.id and e.is_valid
        and e.dimension=c.dimension and e.value=c.value
    group by c.dimension,c.value order by c.dimension,c.value;
end $$;
create function public.get_my_groomer_pet_fit_evidence_summary_v2()
returns table(groomer_id uuid,trait_type text,trait_value text,completed_booking_count bigint,
  positive_review_outcome_count bigint,negative_review_outcome_count bigint,structured_review_outcome_count bigint,
  last_completed_at timestamptz,last_review_outcome_at timestamptz,evidence_updated_at timestamptz,confidence_tier text)
language sql stable security invoker set search_path = '' as $$
  select * from app_private.get_my_groomer_pet_fit_evidence_summary_v2();
$$;
revoke all on function app_private.get_my_groomer_pet_fit_evidence_summary_v2(),public.get_my_groomer_pet_fit_evidence_summary_v2()
  from public,anon,authenticated,service_role;
grant execute on function app_private.get_my_groomer_pet_fit_evidence_summary_v2(),public.get_my_groomer_pet_fit_evidence_summary_v2() to authenticated;
