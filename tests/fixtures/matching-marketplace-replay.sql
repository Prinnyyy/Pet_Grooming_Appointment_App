begin;
-- T-391 synthetic source replay. No persistent writes, Auth mutation or disabled guards.
set local lock_timeout='5s';
set local statement_timeout='150s';
create temporary table marketplace_input(data jsonb) on commit drop;
insert into marketplace_input values (/* INPUT_JSON */);
create temporary table marketplace_requests(alias text primary key,id uuid,customer_id uuid,pet_id uuid,source jsonb) on commit drop;
create temporary table marketplace_offers(alias text primary key,id uuid,request_alias text,source jsonb) on commit drop;
create temporary table marketplace_results(kind text,key text,data jsonb) on commit drop;
create temporary table marketplace_points(name text primary key,lat float8,lon float8) on commit drop;
insert into marketplace_points values
 ('Culver City',34.0211,-118.3965),('West LA',34.043,-118.4465),('Mar Vista',34.003,-118.43),
 ('Pasadena',34.1478,-118.1445),('Burbank',34.18,-118.309),('Koreatown',34.061,-118.3),
 ('Los Feliz',34.112,-118.287),('Sherman Oaks',34.15,-118.449),('Hollywood',34.101,-118.326),
 ('Echo Park',34.078,-118.26),('Santa Monica',34.019,-118.491),('Silver Lake',34.086,-118.27),
 ('Downtown LA',34.045,-118.25),('Glendale',34.142,-118.255);

do $$
declare d jsonb; a jsonb; g jsonb; r jsonb; o jsonb; x jsonb; q jsonb; page jsonb; pages jsonb;
 actor uuid; customer uuid; gid uuid; loc uuid; pet uuid; req uuid; off uuid; revision uuid;
 lat float8; lon float8; shift interval; start_at timestamptz; end_at timestamptz;
 baseline jsonb; cfg jsonb; mode text; cursor_value text; key text; reason text; result jsonb;
 i integer; count_before integer; rec record;
begin
 select data into d from pg_temp.marketplace_input;
 shift:=greatest(1,ceil(((timezone('America/Los_Angeles',now())::date-date '2026-09-14')+2)::numeric/7))::integer*interval '7 days';
 insert into pg_temp.marketplace_results values ('metadata','runtime',jsonb_build_object(
   'as_of',statement_timestamp(),'service_date_shift',shift,'source_kind','synthetic','phase',d->>'phase','batch',d->'batch',
   'transport','SQL authenticated role simulation; not JWT HTTP','invented_ratings_imported',false));
 for a in select value from jsonb_array_elements(d->'actors') loop
   actor:=(a->>'id')::uuid;
   if exists(select 1 from public.grooming_requests where customer_id=actor and status in ('open','has_offers') and expires_at>now())
     or exists(select 1 from public.bookings where (customer_id=actor or groomer_id=actor) and scheduled_end>now()) then
     raise exception 'Non-idle test identity: %',a->>'alias';
   end if;
 end loop;

 for g in select value from jsonb_array_elements(d->'groomers') loop
   select (value->>'id')::uuid into actor from jsonb_array_elements(d->'actors') where value->>'alias'=g->>'id';
   select p.lat,p.lon into lat,lon from pg_temp.marketplace_points p where p.name=g->>'neighborhood';
   insert into app_private.address_locations(owner_id,provider,country_code,latitude,longitude,resolution_source,user_confirmed_at,time_zone_identifier)
     values(actor,'apple_maps','US',lat,lon,'manual_geocode',now(),'America/Los_Angeles') returning id into loc;
   update public.groomer_profiles set address_location_id=loc,is_active=true,business_name=g->>'alias',bio=g->>'context',
     base_street_address='TestOps synthetic location',base_city=g->>'neighborhood',base_state='CA',base_zip_code='90001',
     service_location_mode=g->>'location_mode',service_location_modes=array[g->>'location_mode'],
     service_radius_miles=coalesce((g->>'service_radius_miles')::integer,25) where user_id=actor;
   update public.groomer_services set is_active=false where groomer_id=actor and is_active;
   insert into public.groomer_services(groomer_id,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active,service_type,accepted_species)
     select actor,'Synthetic source service',d->>'marker',100,case s when 'nail_trim' then 20 else 60 end,
       array(select jsonb_array_elements_text(d->'service_size_configurations'->(g->>'id'))),true,s,
       array(select jsonb_array_elements_text(g->'species')) from jsonb_array_elements_text(g->'services') s;
   perform set_config('request.jwt.claim.sub',actor::text,true);
   perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
   perform set_config('role','authenticated',true);
   baseline:=public.get_groomer_availability();
   cfg:=public.save_groomer_availability(baseline->>'revision',
     (select jsonb_agg(jsonb_build_object('weekday',day,'start_time',g->'hours_local'->>0,'end_time',g->'hours_local'->>1,
       'is_enabled',day<>7,'timezone','America/Los_Angeles')) from generate_series(1,7) day),
     jsonb_build_object('max_appointments_per_day',4,'minimum_advance_notice_days',0,'auto_accept_bookings',false,
       'timing_buffers',jsonb_build_object('preparation_minutes',0,'cleanup_minutes',(g->'buffers_minutes'->>1)::integer,
       'inbound_travel_minutes',(g->'buffers_minutes'->>0)::integer,'outbound_travel_minutes',0)), '[]'::jsonb);
   perform set_config('role','none',true);
 end loop;

 -- B01 uses an extra auxiliary pet/request and the normal quote/accept flow.
 for r in select value from jsonb_array_elements((d->'requests')||jsonb_build_array(
   (d->'auxiliary_request')||jsonb_build_object('id','B01','customer_id','C22','offers','[]'::jsonb,
     'pet',(d->'auxiliary_request'->'pet')||jsonb_build_object('name','Auxiliary existing dog'),
     'window',jsonb_build_array('2026-09-17T12:00:00-07:00','2026-09-17T13:45:00-07:00')))) loop
   select (value->>'id')::uuid into actor from jsonb_array_elements(d->'actors') where value->>'alias'=r->>'customer_id';
   select p.lat,p.lon into lat,lon from pg_temp.marketplace_points p where p.name=r->>'neighborhood';
   perform set_config('request.jwt.claim.sub',actor::text,true);
   perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','is_anonymous',false)::text,true);
   perform set_config('role','authenticated',true);
   select id into pet from public.save_my_pet_v2(null,
     ((r->'pet')-'id'-'breed_note')||jsonb_build_object('grooming_notes',d->>'marker',
       'species',initcap(r->'pet'->>'species')),r->'pet'->>'coat_type' is not null);
   select request_id into req from public.create_grooming_request_v4(gen_random_uuid(),jsonb_build_object(
     'pet_id',pet,'service_type',r->>'service_type','service_notes',(d->>'marker')||' '||(r->>'id')||' '||(r->>'customer_text'),
     'preferred_start',(r->'window'->>0)::timestamptz+shift,'preferred_end',(r->'window'->>1)::timestamptz+shift,
     'location_mode',r->>'location_mode','travel_radius_miles',r->'travel_radius_miles',
     'street_address','TestOps synthetic location','city',r->>'neighborhood','state','CA','zip_code','90001',
     'provider','apple_maps','country_code','US','latitude',lat,'longitude',lon,
     'resolution_source','manual_geocode','user_confirmed_at',now()),'America/Los_Angeles');
   perform set_config('role','none',true);
   insert into pg_temp.marketplace_requests values(r->>'id',req,actor,pet,r);
 end loop;
 for i in 1..20 loop
   perform app_private.drain_match_refresh_queue(250);
   exit when not exists(select 1 from app_private.match_refresh_queue where request_id in (select id from pg_temp.marketplace_requests));
 end loop;
 if exists(select 1 from app_private.match_refresh_queue where request_id in (select id from pg_temp.marketplace_requests)) then
   raise exception 'Source queue did not drain within fixed budget';
 end if;
 select id,customer_id into req,customer from pg_temp.marketplace_requests where alias='B01';
 select (value->>'id')::uuid into actor from jsonb_array_elements(d->'actors') where value->>'alias'='G04';
 select terms_revision,preferred_start,preferred_end into revision,start_at,end_at from public.grooming_requests where id=req;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
 perform set_config('role','authenticated',true);
 select offer_id into off from public.create_groomer_offer_v3(req,revision,start_at,end_at,145,d->>'marker','{}');
 perform set_config('role','none',true);
 select quote_revision into revision from public.groomer_offers where id=off;
 perform set_config('request.jwt.claim.sub',customer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated')::text,true);
 perform set_config('role','authenticated',true);
 perform public.accept_groomer_offer_v2(off,revision);
 perform set_config('role','none',true);

 -- Negative calls precede valid quotes so duplicate-offer guards cannot mask the tested reason.
 for x in select value from jsonb_array_elements(d->'rejected_proposals')
   where d->>'phase'='customer' loop
   select id into req from pg_temp.marketplace_requests where alias=x->>'request_id';
   select (value->>'id')::uuid into actor from jsonb_array_elements(d->'actors') where value->>'alias'=x->>'groomer_id';
   select terms_revision into revision from public.grooming_requests where id=req;
   start_at:=(x->>'start')::timestamptz+shift; end_at:=start_at+(x->>'duration_minutes')::integer*interval '1 minute';
   reason:=null;
   begin
     perform set_config('request.jwt.claim.sub',actor::text,true);
     perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
     perform set_config('role','authenticated',true);
     perform public.create_groomer_offer_v3(req,revision,start_at,end_at,(x->>'price_estimate_cents')::numeric/100,
       d->>'marker',array(select jsonb_array_elements_text(coalesce(x->'assessment_confirmations','[]'))));
     perform set_config('role','none',true);
     raise exception using errcode='P9999',message='unexpected_allow';
   exception when others then reason:=sqlerrm;
   end;
   perform set_config('role','none',true);
   insert into pg_temp.marketplace_results values('negative',x->>'id',jsonb_build_object('source',x,'reason',reason));
 end loop;
 for i in 1..20 loop
   perform app_private.drain_match_refresh_queue(250);
   exit when not exists(select 1 from app_private.match_refresh_queue where request_id in (select id from pg_temp.marketplace_requests));
 end loop;
 for g in select value from jsonb_array_elements(d->'groomers') where d->>'phase'='groomer' loop
   select (value->>'id')::uuid into actor from jsonb_array_elements(d->'actors') where value->>'alias'=g->>'id';
   foreach mode in array array['fit','distance','newest'] loop
     perform set_config('request.jwt.claim.sub',actor::text,true);
     perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
     perform set_config('role','authenticated',true);
     cursor_value:=null;pages:='[]';
     for i in 1..10 loop
       page:=public.get_ranked_matched_requests(mode,25,cursor_value);
       pages:=pages||jsonb_build_array(page);cursor_value:=page->>'next_cursor';exit when cursor_value is null;
     end loop;
     perform set_config('role','none',true);
     if cursor_value is not null then raise exception 'Groomer pagination exceeded source bound';end if;
     insert into pg_temp.marketplace_results values('groomer_ranking',(g->>'id')||':'||mode,pages);
   end loop;
 end loop;

 for rec in select * from pg_temp.marketplace_requests where alias<>'B01' and d->>'phase'='customer' order by alias loop
   r:=rec.source;req:=rec.id;
   select terms_revision into revision from public.grooming_requests where id=req;
   for o in select (d->'default_offer')||value from jsonb_array_elements(r->'offers') loop
     select (value->>'id')::uuid into actor from jsonb_array_elements(d->'actors') where value->>'alias'=o->>'groomer_id';
     start_at:=(o->>'start')::timestamptz+shift;end_at:=start_at+(o->>'duration_minutes')::integer*interval '1 minute';
     perform set_config('request.jwt.claim.sub',actor::text,true);
     perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
     perform set_config('role','authenticated',true);
     select offer_id into off from public.create_groomer_offer_v3(req,revision,start_at,end_at,
       (o->>'price_estimate_cents')::numeric/100,o->>'message',array(select jsonb_array_elements_text(o->'assessment_confirmations')));
     if o->>'status'='withdrawn' then perform public.withdraw_groomer_offer(off);end if;
     perform set_config('role','none',true);
     insert into pg_temp.marketplace_offers values(o->>'id',off,r->>'id',o);
     if o->>'exclusion_reason'='expired' then
       select least(expires_at,proposed_start-interval '5 minutes') into start_at from public.groomer_offers where id=off;
       insert into pg_temp.marketplace_results values('expiry',o->>'id',jsonb_build_object(
         'before',app_private.evaluate_quote(off,start_at-interval '1 microsecond'),
         'at',app_private.evaluate_quote(off,start_at),'deadline',start_at));
       -- Do not manufacture a past expiry. Remove this separately checked historical quote normally.
       perform set_config('request.jwt.claim.sub',actor::text,true);
       perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
       perform set_config('role','authenticated',true);
       perform public.withdraw_groomer_offer(off);
       perform set_config('role','none',true);
     end if;
   end loop;
   if not (d->'capture_requests' ? rec.alias) then continue;end if;
   perform set_config('request.jwt.claim.sub',rec.customer_id::text,true);
   perform set_config('request.jwt.claims',jsonb_build_object('sub',rec.customer_id,'role','authenticated')::text,true);
   perform set_config('role','authenticated',true);
   foreach mode in array array['balanced','distance','price','earliest'] loop
     cursor_value:=null;pages:='[]';
     for i in 1..10 loop
       page:=public.get_ranked_customer_offers(req,mode,25,cursor_value);
       pages:=pages||jsonb_build_array(page);cursor_value:=page->>'next_cursor';exit when cursor_value is null;
     end loop;
     if cursor_value is not null then raise exception 'Customer pagination exceeded source bound';end if;
     perform set_config('role','none',true);
     insert into pg_temp.marketplace_results values('customer_ranking',rec.alias||':'||mode,pages);
     perform set_config('role','authenticated',true);
   end loop;
   perform set_config('role','none',true);
 end loop;

 -- Save full quote truth before the following savepoint-style sequence experiments.
 insert into pg_temp.marketplace_results select 'offer',m.alias,jsonb_build_object('id',m.id,
   'evaluation',app_private.evaluate_quote(m.id),'row',to_jsonb(offer_row))
   from pg_temp.marketplace_offers m join public.groomer_offers offer_row on offer_row.id=m.id;
 for x in select value from jsonb_array_elements(d->'sequence_checks')
   where value->>'id' in ('SEQ01','SEQ02','SEQ03','SEQ04') and d->>'phase'='customer'
     and not exists(select 1 from jsonb_array_elements_text(value->'offers') required(alias)
       where not exists(select 1 from pg_temp.marketplace_offers m where m.alias=required.alias)) loop
   result:='[]';
   begin
     for key in select jsonb_array_elements_text(x->'offers') loop
       select m.id,offer_row.quote_revision,offer_row.customer_id into off,revision,customer from pg_temp.marketplace_offers m
         join public.groomer_offers offer_row on offer_row.id=m.id where m.alias=key;
       reason:=null;
       begin
         perform set_config('request.jwt.claim.sub',customer::text,true);
         perform set_config('request.jwt.claims',jsonb_build_object('sub',customer,'role','authenticated')::text,true);
         perform set_config('role','authenticated',true);
         select to_jsonb(b) into q from public.accept_groomer_offer_v2(off,revision) b;
         perform set_config('role','none',true);
       exception when others then reason:=sqlerrm;
       end;
       perform set_config('role','none',true);
       result:=result||jsonb_build_array(jsonb_build_object('offer',key,'accepted',reason is null,'reason',reason));
     end loop;
     raise exception using errcode='P9998',message='rollback_sequence';
   exception when sqlstate 'P9998' then null;
   end;
   insert into pg_temp.marketplace_results values('sequence',x->>'id',result);
 end loop;
 insert into pg_temp.marketplace_results select 'request',alias,to_jsonb(m) from pg_temp.marketplace_requests m where alias<>'B01';
end $$;
select jsonb_build_object(
 'requests',(select jsonb_agg(jsonb_build_object('key',key,'data',data) order by key) from marketplace_results where kind='request'),
 'offers',(select jsonb_agg(jsonb_build_object('key',key,'data',data) order by key) from marketplace_results where kind='offer'),
 'negative',(select jsonb_agg(jsonb_build_object('key',key,'data',data) order by key) from marketplace_results where kind='negative'),
 'sequences',(select jsonb_agg(jsonb_build_object('key',key,'data',data) order by key) from marketplace_results where kind='sequence'),
 'rankings',(select jsonb_agg(jsonb_build_object('kind',kind,'key',key,'pages',data) order by kind,key) from marketplace_results where kind like '%_ranking'),
 'expiry',(select jsonb_agg(data) from marketplace_results where kind='expiry'),
 'metadata',(select data from marketplace_results where kind='metadata')) result;
rollback;
