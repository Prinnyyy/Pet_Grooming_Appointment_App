-- Execute inside a rollback-only transaction with existing authorized fixture IDs.
-- A03: compare wrappers and context adapters, while retaining original fixed oracle tests.
do $$
declare input jsonb:=current_setting('app.testops_discovery')::jsonb;
  r public.grooming_requests%rowtype; g uuid:=(input->>'groomer_id')::uuid;
  clock timestamptz:=(input->>'as_of')::timestamptz; zones text[];
  previous jsonb; adapted jsonb; before_counts bigint[]; after_counts bigint[];
begin
  select * into strict r from public.grooming_requests where id=(input->>'request_id')::uuid;
  if not coalesce(r.service_notes like 'TESTOPS:'||(input->>'run_id')||'%',false) then
    raise exception 'request outside owned fixture';
  end if;
  select array_agg(name) into zones from pg_catalog.pg_timezone_names;
  before_counts:=array[(select count(*) from public.grooming_requests),
    (select count(*) from public.request_matches),(select count(*) from public.groomer_notifications)];
  previous:=app_private.evaluate_match_constraints(r.id,g,clock);
  adapted:=app_private.evaluate_context_constraints(r,g,clock);
  if previous is distinct from adapted then raise exception 'constraint adapter drift'; end if;
  previous:=app_private.evaluate_match_eligibility_with_zones(r.id,g,clock,zones);
  adapted:=app_private.evaluate_context_eligibility(r,g,clock,zones);
  if previous is distinct from adapted then raise exception 'qualification adapter drift'; end if;
  previous:=app_private.score_match_evidence(r.id,g,clock,null,zones);
  adapted:=app_private.score_context_evidence(r,g,clock,null,zones);
  if previous is distinct from adapted then raise exception 'score adapter drift'; end if;
  -- Preview has no public row, lifecycle status, or publication ID.
  r.id:=null; r.status:=null;
  if app_private.evaluate_context_eligibility(r,g,clock,zones) is distinct from
      app_private.evaluate_match_eligibility_with_zones((input->>'request_id')::uuid,g,clock,zones) then
    raise exception 'preview requires persisted request';
  end if;
  after_counts:=array[(select count(*) from public.grooming_requests),
    (select count(*) from public.request_matches),(select count(*) from public.groomer_notifications)];
  if before_counts is distinct from after_counts then raise exception 'preview published business rows'; end if;
end $$;
