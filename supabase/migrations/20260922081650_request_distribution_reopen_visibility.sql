-- Hidden due to a closed distribution is reversible after explicit reopening.
-- A groomer's dismissal remains final and is never rewritten by this guard.
create or replace function app_private.guard_match_distribution()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status in ('visible','viewed') then
    perform 1 from public.grooming_requests where id=new.request_id for update;
    if not app_private.request_distribution_allows_new_quote(new.request_id,new.groomer_id) then
      if tg_op='INSERT' then return null;end if;
      if old.status='dismissed' or old.dismissed_at is not null then
        new.status:='dismissed';new.dismissed_at:=old.dismissed_at;new.dismiss_reason:=old.dismiss_reason;
      else new.status:='hidden';end if;
    end if;
  end if;
  if new.status='hidden' and new.dismissed_at is null
    and not app_private.request_distribution_allows_new_quote(new.request_id,new.groomer_id) then
    new.eligibility_evaluation:=jsonb_build_object('state','excluded','reason','request_distribution_closed',
      'evaluated_at',statement_timestamp());
  end if;
  return new;
end $$;

update public.request_matches m set eligibility_evaluation=jsonb_build_object(
    'state','excluded','reason','request_distribution_closed','evaluated_at',statement_timestamp())
  from public.grooming_requests r where r.id=m.request_id and r.distribution_version='discovery_v1'
    and r.status in ('open','has_offers') and not r.pool_enabled and m.status='hidden'
    and m.dismissed_at is null and not app_private.request_distribution_allows_new_quote(r.id,m.groomer_id);
