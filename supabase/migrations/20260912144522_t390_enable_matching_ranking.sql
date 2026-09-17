-- T-390: enable the accepted algorithm without relaxing input or transaction guards.
do $$
begin
  if not exists (
    select 1 from app_private.match_ranking_config
    where singleton and algorithm_version='matching-v1'
      and cardinality(validation_actor_ids)=0
  ) then
    raise exception 'matching_rollout_configuration_changed';
  end if;
  update app_private.match_ranking_config set enabled=true where singleton;
end $$;
