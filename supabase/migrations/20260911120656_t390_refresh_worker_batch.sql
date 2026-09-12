-- T-390: 338-pair measured worker work was 19.14s total; bounded 100-item batches
-- retain the existing ten-second schedule and the hard/due fairness split.
do $$ declare existing_job bigint; begin
  select jobid into strict existing_job from cron.job
    where jobname='beckon_refresh_request_matches' and schedule='10 seconds' and active;
  perform cron.alter_job(existing_job,command:='select app_private.drain_match_refresh_queue(100);');
end $$;
