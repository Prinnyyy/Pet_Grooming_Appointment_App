-- T-466: explicit partial address projection; unrecognized free text stays private.
begin;
create function app_private.request_street_name(p_street text) returns text
language plpgsql immutable set search_path='' as $function$
declare street text;
begin
  -- Never fall back to returning an unparsed address. Only a recognized street
  -- without a house/unit number is returned; international/unusual forms remain locality-only.
  street:=regexp_replace(btrim(p_street),'^[0-9]+[A-Za-z]?([- /][0-9]+)?[[:space:]]+','','i');
  if street is null or street=btrim(p_street) then return null; end if;
  street:=regexp_replace(street,'([,#\n]|[[:space:]]+(apt|apartment|unit|suite|ste)[[:space:]]).*$', '', 'i');
  if street !~* '^[A-Za-z0-9 .''-]+[[:space:]](street|st|avenue|ave|road|rd|boulevard|blvd|lane|ln|drive|dr|court|ct|place|pl|way|circle|cir|terrace|ter|parkway|pkwy|trail|trl|highway|hwy|pike|loop)[.]?([[:space:]]+(N|S|E|W|NE|NW|SE|SW))?$' then return null; end if;
  return btrim(street);
end $function$;
revoke all on function app_private.request_street_name(text) from public,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION app_private.safe_groomer_request(p_request grooming_requests, p_detail boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select jsonb_build_object('id',p_request.id,'customer_id',p_request.customer_id,'pet_id',p_request.pet_id,
    'pet_snapshot',case when p_detail then p_request.pet_snapshot else
      (select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(p_request.pet_snapshot)
        where key=any(array['id','name','species','breed','coat_type','size','weight_lbs','coat_type_source','matting_confirmed','facts_version'])) end,
    'photo_snapshot',case when p_detail then p_request.photo_snapshot else '[]'::jsonb end,
    'service_type',p_request.service_type,'service_notes',case when p_detail then p_request.service_notes else null end,
    'preferred_start',p_request.preferred_start,'preferred_end',p_request.preferred_end,
    'preference_time_zone_identifier',p_request.preference_time_zone_identifier,'terms_revision',p_request.terms_revision,
    'street_address',case when p_detail then case when exists(select 1 from public.bookings b
      where b.request_id=p_request.id and b.groomer_id=auth.uid()) then p_request.street_address
      else app_private.request_street_name(p_request.street_address) end else null end,
    'address_line_2',case when p_detail and exists(select 1 from public.bookings b
      where b.request_id=p_request.id and b.groomer_id=auth.uid()) then p_request.address_line_2 else null end,
    'zip_code',p_request.zip_code,
    'location_mode',p_request.location_mode,'city',p_request.city,'state',p_request.state,
    'travel_radius_miles',p_request.travel_radius_miles,'status',p_request.status,'expires_at',p_request.expires_at,
    'created_at',p_request.created_at,'updated_at',p_request.updated_at,'pool_enabled',p_request.pool_enabled,
    'invitation_state',app_private.request_invitation_state(p_request.id,(select auth.uid())));
$function$
;
commit;
