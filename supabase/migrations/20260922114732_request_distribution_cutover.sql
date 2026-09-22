-- T-399: apply only after client acceptance and exact TestOps fixture restoration.
-- UI rollback may disable discovery; keep legacy retirement and privacy restrictions.
do $$
begin
  update app_private.match_ranking_config
    set discovery_enabled=true,legacy_publish_retired=true
    where singleton and not discovery_enabled and not legacy_publish_retired
      and cardinality(discovery_validation_actor_ids)=0;
  if not found then raise exception 'Unexpected discovery rollout state; preserve it';end if;
end $$;
