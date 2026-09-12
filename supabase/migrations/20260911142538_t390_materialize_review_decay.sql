-- Bound the internal decay fast path; public rating sums remain exact integers.
create or replace function app_private.score_match_evidence(p_request_id uuid,p_groomer_id uuid,p_score_as_of timestamptz,p_offer_id uuid,p_valid_zones text[])
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype; target jsonb; score jsonb; distance_miles double precision;
begin
  if p_score_as_of is null or not isfinite(p_score_as_of) then
    raise exception using errcode='22023',message='invalid_score_clock';
  end if;
  select * into strict r from public.grooming_requests where id=p_request_id;
  target:=app_private.match_target_keys(p_request_id,p_groomer_id,p_offer_id,p_valid_zones);
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
      case when extract(epoch from (p_score_as_of-c.service_at))<=15552000000.0
        then power(2.0::double precision,-extract(epoch from (p_score_as_of-c.service_at))::double precision/15552000.0)::numeric
        else power(2.0::numeric,-extract(epoch from (p_score_as_of-c.service_at))/15552000.0) end decay
    from public.reviews review join eligible_contexts c on c.booking_id=review.booking_id
    where review.groomer_id=p_groomer_id
  ), quality_weights as (
    select q.*,case when sum(decay) over(partition by customer_id)>0 then
      max(decay) over(partition by customer_id)*decay/sum(decay) over(partition by customer_id) else 0 end weight
    from quality_rows q
  ), related_contexts as materialized (
    select * from eligible_contexts where species=lower(r.pet_snapshot->>'species') and service_type=r.service_type
      and r.service_type<>'custom_request'
  ), fit_rows as materialized (
    select review.id,review.customer_id,c.service_at,
      case when extract(epoch from (p_score_as_of-c.service_at))<=15552000000.0
        then power(2.0::double precision,-extract(epoch from (p_score_as_of-c.service_at))::double precision/15552000.0)::numeric
        else power(2.0::numeric,-extract(epoch from (p_score_as_of-c.service_at))/15552000.0) end decay,
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
