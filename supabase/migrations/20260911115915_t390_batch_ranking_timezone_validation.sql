-- T-390: preserve timezone validation while sharing its catalog scan across the page.
create function app_private.review_allowed_keys(p_snapshot jsonb,p_service text,p_service_at timestamptz,p_zone text,p_valid_zones text[])
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
  if p_snapshot->>'birthday' is null or p_snapshot->>'birthday' !~ '^\d{4}-\d{2}-\d{2}$' then return keys; end if;
  if (case when p_valid_zones is null then exists(select 1 from pg_catalog.pg_timezone_names where name=p_zone)
    else p_zone=any(p_valid_zones) end) then
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

create function app_private.match_target_keys(p_request uuid,p_groomer uuid,p_offer uuid,p_valid_zones text[])
returns jsonb language plpgsql stable set search_path = '' as $$
declare r public.grooming_requests%rowtype; o public.groomer_offers%rowtype; zone text; first_keys jsonb; last_keys jsonb;
begin
  select * into strict r from public.grooming_requests where id=p_request;
  if p_offer is not null then
    select * into strict o from public.groomer_offers where id=p_offer and request_id=p_request and groomer_id=p_groomer;
    return app_private.review_allowed_keys(r.pet_snapshot,r.service_type,o.proposed_start,o.service_time_zone_identifier,p_valid_zones);
  end if;
  if r.location_mode='groomer_comes_to_customer' then zone:=r.preference_time_zone_identifier;
  else select a.time_zone_identifier into zone from public.groomer_profiles g
    join app_private.address_locations a on a.id=g.address_location_id and a.owner_id=g.user_id where g.user_id=p_groomer;
  end if;
  first_keys:=app_private.review_allowed_keys(r.pet_snapshot,r.service_type,r.preferred_start,zone,p_valid_zones);
  last_keys:=app_private.review_allowed_keys(r.pet_snapshot,r.service_type,r.preferred_end-interval '1 microsecond',zone,p_valid_zones);
  -- Only age categories stable across the whole window survive this intersection.
  return (select coalesce(jsonb_agg(value order by value->>'dimension',value->>'value'),'[]')
    from jsonb_array_elements(first_keys) where last_keys @> jsonb_build_array(value));
end $$;

create function app_private.score_match_evidence(p_request_id uuid,p_groomer_id uuid,p_score_as_of timestamptz,p_offer_id uuid,p_valid_zones text[])
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

create or replace function app_private.review_allowed_keys(p_snapshot jsonb,p_service text,p_service_at timestamptz,p_zone text)
returns jsonb language sql stable set search_path = '' as $$ select app_private.review_allowed_keys(p_snapshot,p_service,p_service_at,p_zone,null); $$;
create or replace function app_private.match_target_keys(p_request uuid,p_groomer uuid,p_offer uuid default null)
returns jsonb language sql stable set search_path = '' as $$ select app_private.match_target_keys(p_request,p_groomer,p_offer,null); $$;
create or replace function app_private.score_match_evidence(p_request_id uuid,p_groomer_id uuid,p_score_as_of timestamptz,p_offer_id uuid default null)
returns jsonb language sql stable set search_path = '' as $$ select app_private.score_match_evidence(p_request_id,p_groomer_id,p_score_as_of,p_offer_id,null); $$;
revoke all on function app_private.review_allowed_keys(jsonb,text,timestamptz,text,text[]),
  app_private.match_target_keys(uuid,uuid,uuid,text[]),app_private.score_match_evidence(uuid,uuid,timestamptz,uuid,text[])
  from public,anon,authenticated,service_role;

create or replace function app_private.ranked_marketplace_page(p_role text,p_request uuid,p_sort text,p_limit integer,p_cursor text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); config app_private.match_ranking_config%rowtype;
  clock timestamptz:=statement_timestamp(); as_of timestamptz; deadline timestamptz; scope text;
  cursor_data jsonb; last_key jsonb; candidates jsonb:='[]'; ranked jsonb; page_rows jsonb;
  fact record; score jsonb; evaluation jsonb; payload jsonb; evidence jsonb; source jsonb;
  candidate_id uuid; item_id uuid; request_id uuid; groomer_id uuid; offer_id uuid;
  group_order integer; primary_value numeric; bucket numeric; tie text; distance_miles double precision;
  revision text; effective text; next_cursor text; pending integer:=0; assessment integer:=0; pending_sources jsonb:='[]';
  scoring_failed boolean:=false; fact_deadline timestamptz; valid_zones text[];
begin
  if actor is null or coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false)
    or p_role not in ('groomer','customer')
    or not exists(select 1 from public.profiles where id=actor and role::text=p_role) then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  if p_role='customer' and not exists(select 1 from public.grooming_requests where id=p_request and customer_id=actor) then
    raise exception using errcode='42501',message='not_allowed';
  end if;
  if p_limit is null or p_limit not between 1 and 50 or p_sort is null
    or (p_role='groomer' and (p_request is not null or p_sort not in ('fit','distance','newest')))
    or (p_role='customer' and p_sort not in ('balanced','distance','earliest','price')) then
    raise exception using errcode='22023',message='invalid_page';
  end if;
  select * into strict config from app_private.match_ranking_config where singleton;
  scope:=case when p_role='groomer' then 'matches' else p_request::text end;
  as_of:=clock; deadline:=clock+interval '5 minutes';
  if p_cursor is not null then
    cursor_data:=app_private.match_cursor_decode(p_cursor,config.signing_key);
    if cursor_data->>'viewer' is distinct from actor::text or cursor_data->>'role' is distinct from p_role
      or cursor_data->>'scope' is distinct from scope or cursor_data->>'requested_mode' is distinct from p_sort
      or cursor_data->>'algorithm_version' is distinct from config.algorithm_version then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    as_of:=(cursor_data->>'score_as_of')::timestamptz;
    deadline:=(cursor_data->>'valid_until')::timestamptz;
    last_key:=cursor_data->'last_key';
    if as_of is null or deadline is null or not isfinite(as_of) or not isfinite(deadline)
      or as_of>clock or deadline>as_of+interval '5 minutes' or jsonb_typeof(last_key) is distinct from 'array'
      or jsonb_array_length(last_key)<>6 then
      raise exception using errcode='22023',message='invalid_cursor';
    end if;
    if deadline<=clock then raise exception using errcode='PT409',message='list_changed'; end if;
  end if;

  if config.enabled then select array_agg(name) into valid_zones from pg_catalog.pg_timezone_names; end if;
  -- Both branches enumerate the entire authorized scope under this STABLE call's statement snapshot.
  for fact in
    select r.id request_id,actor groomer_id,null::uuid offer_id,m.id item_id,r.id candidate_id,
      jsonb_build_object('match',jsonb_build_object('id',m.id,'request_id',r.id,'groomer_id',actor,
        'customer_id',r.customer_id,'match_score',null,'match_reason',null,'dismiss_reason',m.dismiss_reason,
        'status',m.status,'viewed_at',m.viewed_at,'dismissed_at',m.dismissed_at,
        'created_at',m.created_at,'updated_at',m.updated_at),
        'request',jsonb_build_object('id',r.id,'customer_id',r.customer_id,'pet_id',r.pet_id,
        'pet_snapshot',r.pet_snapshot,'photo_snapshot',r.photo_snapshot,'service_type',r.service_type,
        'service_notes',r.service_notes,'preferred_start',r.preferred_start,'preferred_end',r.preferred_end,
        'preference_time_zone_identifier',r.preference_time_zone_identifier,'location_mode',r.location_mode,
        'street_address',r.street_address,'city',r.city,'state',r.state,'zip_code',r.zip_code,
        'travel_radius_miles',r.travel_radius_miles,'status',r.status,'expires_at',r.expires_at,
        'created_at',r.created_at,'updated_at',r.updated_at,'terms_revision',r.terms_revision)) payload,
      r.created_at newest,null::timestamptz earliest,null::numeric price,r.expires_at expiry,
      to_jsonb(c)-'witness' source
    from public.request_matches m join public.grooming_requests r on r.id=m.request_id
      left join app_private.match_candidate_evaluations c on c.request_id=r.id and c.groomer_id=actor
    where p_role='groomer' and m.groomer_id=actor and m.status in ('visible','viewed')
      and r.status in ('open','has_offers') and r.expires_at>clock
      and not exists(select 1 from public.groomer_offers o where o.request_id=r.id and o.groomer_id=actor and o.status='pending')
    union all
    select r.id,o.groomer_id,o.id,o.id,o.groomer_id,
      jsonb_build_object('offer',jsonb_build_object('id',o.id,'request_id',o.request_id,'match_id',o.match_id,
        'customer_id',o.customer_id,'groomer_id',o.groomer_id,'proposed_start',o.proposed_start,'proposed_end',o.proposed_end,
        'price_estimate',o.price_estimate,'message',o.message,'status',o.status,'expires_at',o.expires_at,
        'withdrawn_at',o.withdrawn_at,'created_at',o.created_at,'updated_at',o.updated_at,
        'applied_timing_buffers',o.applied_timing_buffers,'service_time_zone_identifier',o.service_time_zone_identifier,
        'schedule_time_zone_identifier',o.schedule_time_zone_identifier,'occupied_start',o.occupied_start,
        'occupied_end',o.occupied_end,'agreement_snapshot',o.agreement_snapshot),
        'groomer_profile',case when g.user_id is null then null else jsonb_build_object('user_id',g.user_id,
        'business_name',g.business_name,'bio',g.bio,'years_experience',g.years_experience,'base_city',g.base_city,
        'base_state',g.base_state,'service_radius_miles',g.service_radius_miles,'service_location_mode',g.service_location_mode,
        'rating_avg',g.rating_avg,'rating_count',g.rating_count,'rating_sum',g.rating_sum,
        'is_active',g.is_active,'is_verified',g.is_verified) end),
      o.created_at,o.proposed_start,o.price_estimate,least(o.expires_at,r.expires_at,o.proposed_start-interval '5 minutes'),
      jsonb_build_object('request_revision',r.terms_revision,'profile_revision',g.eligibility_revision,
        'quote',to_jsonb(o),'cache',to_jsonb(c)-'witness')
    from public.groomer_offers o join public.grooming_requests r on r.id=o.request_id
      left join public.groomer_profiles g on g.user_id=o.groomer_id
      left join app_private.match_candidate_evaluations c on c.request_id=r.id and c.groomer_id=o.groomer_id
    where p_role='customer' and r.id=p_request and r.customer_id=actor and o.customer_id=actor
  loop
    request_id:=fact.request_id; groomer_id:=fact.groomer_id; offer_id:=fact.offer_id;
    candidate_id:=fact.candidate_id; item_id:=fact.item_id; payload:=fact.payload;
    if p_role='groomer' then
      evaluation:=app_private.read_candidate_evaluation(request_id,groomer_id,clock);
      if evaluation->>'state'='excluded' then continue; end if;
      group_order:=case evaluation->>'state' when 'estimated_fit' then 0 when 'assessment_required' then 1 else 2 end;
      if group_order=2 then pending:=pending+1; end if;
      if group_order=1 then assessment:=assessment+1; end if;
      payload:=jsonb_set(payload,'{match,eligibility_evaluation}',evaluation);
      fact_deadline:=(evaluation->>'valid_until')::timestamptz;
    else
      evaluation:=app_private.evaluate_quote(offer_id,clock);
      group_order:=case when (evaluation->>'selectable')::boolean then 0 else 1 end;
      payload:=payload||jsonb_build_object('quote_evaluation',evaluation);
      -- Daily advance-notice boundaries can change a quote without source writes.
      select min(timezone(w.timezone,(timezone(w.timezone,clock)::date+1)::timestamp)) into fact_deadline
        from public.groomer_availability_windows w where w.groomer_id=fact.groomer_id
          and exists(select 1 from pg_catalog.pg_timezone_names where name=w.timezone);
    end if;
    if fact.expiry>clock then deadline:=least(deadline,fact.expiry); end if;
    if fact_deadline>clock then deadline:=least(deadline,fact_deadline); end if;
    source:=jsonb_build_object('facts',fact.source,'evaluation',evaluation,'events',
      (select coalesce(jsonb_agg(q.id order by q.id),'[]') from app_private.match_refresh_queue q
        where q.request_id=fact.request_id and q.groomer_id=fact.groomer_id));
    select extensions.st_distance(a.location,b.location)/1609.344 into distance_miles
      from public.grooming_requests r join app_private.address_locations a on a.id=r.address_location_id and a.owner_id=r.customer_id
      join public.groomer_profiles g on g.user_id=fact.groomer_id
      join app_private.address_locations b on b.id=g.address_location_id and b.owner_id=g.user_id where r.id=fact.request_id;
    score:=null;
    if config.enabled then
      begin
        score:=app_private.score_match_evidence(request_id,groomer_id,as_of,offer_id,valid_zones);
      exception when numeric_value_out_of_range or division_by_zero then scoring_failed:=true;
      end;
    end if;
    candidates:=candidates||jsonb_build_array(jsonb_build_object('candidate',candidate_id,'item',item_id,
      'payload',payload,'source',source,'score',score,'group',group_order,'distance',distance_miles,
      'newest',-extract(epoch from fact.newest),'earliest',extract(epoch from fact.earliest),'price',fact.price));
  end loop;

  if p_role='groomer' then
    -- Coarse candidates without an authorized match expose only a count, never request details.
    with coarse as (
      select c.request_id from app_private.match_candidate_evaluations c where c.groomer_id=actor
      union select q.request_id from app_private.match_refresh_queue q where q.groomer_id=actor and q.reason='hard_eligibility'
    )
    select coalesce(jsonb_agg(jsonb_build_object('request',c.request_id,'events',
      (select jsonb_agg(q.id order by q.id) from app_private.match_refresh_queue q
        where q.request_id=c.request_id and q.groomer_id=actor)) order by c.request_id),'[]') into pending_sources
      from coarse c join public.grooming_requests r on r.id=c.request_id
      where r.status in ('open','has_offers') and r.expires_at>clock
        and not exists(select 1 from public.request_matches m where m.request_id=c.request_id and m.groomer_id=actor)
        and app_private.read_candidate_evaluation(c.request_id,actor,clock)->>'state'='pending';
    pending:=pending+jsonb_array_length(pending_sources);
  end if;
  effective:=case when (not config.enabled or scoring_failed) and p_sort in ('fit','balanced') then 'time_fallback' else p_sort end;
  ranked:='[]';
  for fact in select value data from jsonb_array_elements(candidates) loop
    score:=fact.data->'score';
    bucket:=case when not config.enabled or scoring_failed then 0
      else coalesce(floor((score->>case when p_role='groomer' then 'b' else 's' end)::numeric/2),-1) end;
    primary_value:=case effective when 'distance' then (fact.data->>'distance')::numeric
      when 'newest' then (fact.data->>'newest')::numeric when 'price' then (fact.data->>'price')::numeric
      when 'earliest' then (fact.data->>'earliest')::numeric
      when 'time_fallback' then (fact.data->>case when p_role='groomer' then 'newest' else 'earliest' end)::numeric else 0 end;
    tie:=encode(extensions.hmac(convert_to(jsonb_build_array(actor,p_role,scope,p_sort,config.algorithm_version,
      fact.data->>'candidate')::text,'UTF8'),config.signing_key,'sha256'),'hex');
    evidence:=case when config.enabled and not scoring_failed then app_private.public_matching_evidence(score)
      else jsonb_build_object('state','unavailable','algorithm_version',config.algorithm_version,'score_as_of',as_of,
        'related_review_count',0,'independent_customers',0,'completed_count',0,'latest_service_at',null,'coverage','[]'::jsonb) end;
    ranked:=ranked||jsonb_build_array(fact.data||jsonb_build_object('sort_key',jsonb_build_array(
      fact.data->'group',coalesce(primary_value,1e100),-bucket,tie,fact.data->>'candidate',fact.data->>'item'),
      'payload',(fact.data->'payload')||jsonb_build_object('evidence',evidence)));
  end loop;
  select encode(extensions.digest(convert_to(jsonb_build_object('mode',effective,'enabled',config.enabled,
    'pending',pending_sources,'assessment',assessment,'sources',coalesce(jsonb_agg(value order by value->>'item'),'[]'))::text,'UTF8'),'sha256'),'hex')
    into revision from jsonb_array_elements(ranked);
  if p_cursor is not null and (cursor_data->>'ranking_revision' is distinct from revision
    or cursor_data->>'effective_mode' is distinct from effective
    or deadline is distinct from (cursor_data->>'valid_until')::timestamptz) then
    raise exception using errcode='PT409',message='list_changed';
  end if;
  select coalesce(jsonb_agg(value order by value->'sort_key'),'[]') into page_rows from (
    select value from jsonb_array_elements(ranked)
      where last_key is null or value->'sort_key'>last_key
      order by value->'sort_key' limit p_limit+1
  ) page;
  if jsonb_array_length(page_rows)>p_limit then
    next_cursor:=app_private.match_cursor_encode(jsonb_build_object('viewer',actor,'role',p_role,'scope',scope,
      'requested_mode',p_sort,'effective_mode',effective,'algorithm_version',config.algorithm_version,
      'score_as_of',as_of,'valid_until',deadline,'ranking_revision',revision,
      'last_key',page_rows->(p_limit-1)->'sort_key'),config.signing_key);
    page_rows:=page_rows-p_limit;
  end if;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(
    jsonb_set(value->'payload','{evidence,source_revision}',to_jsonb(revision)) order by value->'sort_key'),'[]')
    from jsonb_array_elements(page_rows)),
    'ranking_revision',revision,'score_as_of',as_of,'valid_until',deadline,'algorithm_version',config.algorithm_version,
    'requested_mode',p_sort,'effective_mode',effective,'pending_count',pending,'assessment_count',assessment,'next_cursor',next_cursor);
end $$;
