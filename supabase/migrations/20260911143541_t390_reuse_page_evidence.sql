-- Reuse equal scoring inputs only inside one STABLE, fully authorized page read.
create or replace function app_private.ranked_marketplace_page(p_role text,p_request uuid,p_sort text,p_limit integer,p_cursor text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); config app_private.match_ranking_config%rowtype;
  clock timestamptz:=statement_timestamp(); as_of timestamptz; deadline timestamptz; scope text;
  cursor_data jsonb; last_key jsonb; candidates jsonb:='[]'; ranked jsonb; page_rows jsonb;
  fact record; score jsonb; evaluation jsonb; payload jsonb; evidence jsonb; source jsonb;
  candidate_id uuid; item_id uuid; request_id uuid; groomer_id uuid; offer_id uuid;
  group_order integer; primary_value numeric; bucket numeric; tie text; distance_miles double precision;
  revision text; effective text; next_cursor text; pending integer:=0; assessment integer:=0; pending_sources jsonb:='[]';
  score_cache jsonb:='{}'; score_key text;
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
  config.enabled:=config.enabled or actor=any(config.validation_actor_ids);
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
        select jsonb_build_array(groomer_id,lower(r.pet_snapshot->>'species'),r.service_type,
          app_private.match_target_keys(request_id,groomer_id,offer_id,valid_zones),distance_miles,as_of)::text
          into score_key from public.grooming_requests r where r.id=request_id;
        score:=score_cache->score_key;
        if score is null then
          score:=app_private.score_match_evidence(request_id,groomer_id,as_of,offer_id,valid_zones);
          score_cache:=score_cache||jsonb_build_object(score_key,score);
        end if;
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

notify pgrst,'reload schema';
