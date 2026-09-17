-- T-246: prepare the request-expiry cron identity for the Beckon remote cutover.

do $migration$
begin
  if exists (
    select 1
    from cron.job
    where jobname = 'groomly_expire_grooming_requests'
  ) then
    perform cron.unschedule('groomly_expire_grooming_requests');
  end if;

  if exists (
    select 1
    from cron.job
    where jobname = 'beckon_expire_grooming_requests'
  ) then
    perform cron.unschedule('beckon_expire_grooming_requests');
  end if;

  perform cron.schedule(
    'beckon_expire_grooming_requests',
    '*/5 * * * *',
    $command$ select app_private.expire_grooming_requests(250); $command$
  );
end
$migration$;
