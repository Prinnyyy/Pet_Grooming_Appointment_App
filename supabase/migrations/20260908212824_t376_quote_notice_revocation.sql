-- Policy changes revoke old consent; schedule-only capacity changes do not.
create or replace function app_private.bump_quote_eligibility_revision()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op='INSERT' then
    new.eligibility_revision:=gen_random_uuid();
    return new;
  end if;
  if tg_table_name='groomer_services' then
    if row(new.is_active,new.accepted_pet_sizes,new.service_type,new.groomer_id)
      is distinct from row(old.is_active,old.accepted_pet_sizes,old.service_type,old.groomer_id)
      or new.eligibility_revision is distinct from old.eligibility_revision then
      new.eligibility_revision:=gen_random_uuid();
    else new.eligibility_revision:=old.eligibility_revision; end if;
  else
    if row(new.is_active,new.service_location_modes,new.service_location_mode,new.service_radius_miles,
      new.address_location_id,new.base_street_address,new.base_address_line_2,new.base_city,new.base_state,new.base_zip_code)
      is distinct from row(old.is_active,old.service_location_modes,old.service_location_mode,old.service_radius_miles,
      old.address_location_id,old.base_street_address,old.base_address_line_2,old.base_city,old.base_state,old.base_zip_code)
      or new.eligibility_revision is distinct from old.eligibility_revision then
      -- Never accept a caller-supplied old revision, including indirect policy invalidation.
      new.eligibility_revision:=gen_random_uuid();
    else new.eligibility_revision:=old.eligibility_revision; end if;
  end if;
  return new;
end $$;
revoke all on function app_private.bump_quote_eligibility_revision() from public,anon,authenticated,service_role;

drop trigger groomer_profiles_lock_match_change on public.groomer_profiles;
create trigger groomer_profiles_lock_match_change before update of is_active,address_location_id,
  service_location_mode,service_location_modes,service_radius_miles,base_street_address,base_address_line_2,
  base_city,base_state,base_zip_code,eligibility_revision on public.groomer_profiles
for each row execute function app_private.lock_match_constraint_change();

create function app_private.revoke_quotes_after_notice_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner uuid; previous_notice integer:=0; next_notice integer:=0;
begin
  if tg_op<>'INSERT' then previous_notice:=old.minimum_advance_notice_days; owner:=old.groomer_id; end if;
  if tg_op<>'DELETE' then next_notice:=new.minimum_advance_notice_days; owner:=new.groomer_id; end if;
  if previous_notice is distinct from next_notice then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner::text,71071));
    update public.groomer_profiles set eligibility_revision=gen_random_uuid() where user_id=owner;
  end if;
  return null;
end $$;
revoke all on function app_private.revoke_quotes_after_notice_change() from public,anon,authenticated,service_role;
create trigger groomer_booking_preferences_revoke_quote_notice
after insert or update or delete on public.groomer_booking_preferences
for each row execute function app_private.revoke_quotes_after_notice_change();
