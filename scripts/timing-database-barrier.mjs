import { spawn } from "node:child_process";

export async function runTimingDatabaseBarrier(groomerID, run, {
  spawnProcess = spawn,
  delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds)),
  matchRefreshRequestID = null,
  revisionRequestID = null,
  fulfillmentRace = false,
} = {}) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(groomerID)) {
    throw new Error("Invalid timing barrier groomer identity.");
  }
  if (matchRefreshRequestID !== null && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(matchRefreshRequestID)) {
    throw new Error("Invalid matching barrier request identity.");
  }
  if (revisionRequestID !== null && (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(revisionRequestID)
    || matchRefreshRequestID !== null)) throw new Error("Invalid revision barrier request identity or mixed mode.");
  if (fulfillmentRace && revisionRequestID === null) throw new Error("Fulfillment barrier requires its booking request.");
  const acceptingRPC = fulfillmentRace ? "mutate_booking_fulfillment" : "accept_groomer_offer";
  const competingRPC = fulfillmentRace ? acceptingRPC : revisionRequestID === null ? "save_groomer_availability" : "supersede_grooming_request";
  const holderBlocks = revisionRequestID === null
    ? "pg_backend_pid() = any(pg_blocking_pids(pid))"
    : `exists (with recursive blockers(pid) as (
        select unnest(pg_blocking_pids(activity.pid))
        union select unnest(pg_blocking_pids(blockers.pid)) from blockers
      ) select 1 from blockers where blockers.pid=pg_backend_pid())`;
  const lockSQL = revisionRequestID === null
    ? `select pg_advisory_xact_lock(hashtextextended('${groomerID}',71071));`
    : `select id from public.grooming_requests where id='${revisionRequestID}' for update;`;
  const refreshCheck = matchRefreshRequestID === null ? "" : `
    begin
      perform 1 from public.grooming_requests where id='${matchRefreshRequestID}' for update nowait;
      raise exception 'Matching request was not locked by acceptance';
    exception when lock_not_available then null; end;
    insert into app_private.match_refresh_queue(request_id,groomer_id)
      values('${matchRefreshRequestID}','${groomerID}') returning id into refresh_event_id;
    perform app_private.drain_match_refresh_queue(25);
    if not exists(select 1 from app_private.match_refresh_queue where id=refresh_event_id) then
      raise exception 'Locked request refresh event was lost';
    end if;`;
  // One CLI holder; only HTTP sessions run concurrently. Require each exact RPC
  // to wait on this holder, not unrelated lock traffic from another account.
  const sql = `begin;
    set local statement_timeout = '20s';
    ${lockSQL}
    select pg_sleep(${revisionRequestID === null ? 5 : 2});
    do $$ declare blocked_sessions integer; has_accept boolean; has_save boolean; refresh_event_id bigint; begin
      for attempt in 1..40 loop
        perform pg_stat_clear_snapshot();
        select count(distinct pid),
          coalesce(bool_or(query ~ '${acceptingRPC}'),false),
          coalesce(bool_or(query ~ '${competingRPC}'),false)
          into blocked_sessions,has_accept,has_save from pg_stat_activity activity
          where application_name like 'PostgREST %' and state='active'
            and wait_event_type='Lock'
            and ${holderBlocks}
            and query ~ '(${acceptingRPC}|${competingRPC})';
        exit when blocked_sessions >= 2 and has_accept and has_save;
        perform pg_sleep(0.25);
      end loop;
      if blocked_sessions < 2 or not has_accept or not has_save then
        raise exception 'Timing admission/save database barrier was not verified: %',
          (select jsonb_agg(jsonb_build_object('accept',query ~ '${acceptingRPC}',
            'save',query ~ '${competingRPC}','state',state,'wait',wait_event_type,
            'holder_blocks',pg_backend_pid() = any(pg_blocking_pids(pid))))
            from pg_stat_activity where application_name like 'PostgREST %' and state='active'
              and query ~ '(${acceptingRPC}|${competingRPC})');
      end if;
      ${refreshCheck}
    end $$; commit;`;
  const holder = spawnProcess("supabase", ["db", "query", "--linked", "--output", "json", sql], {
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" }, timeout: 60000,
  });
  holder.stdout.resume();
  let diagnostics = "";
  holder.stderr.on("data", chunk => { diagnostics = (diagnostics + chunk).slice(-16000); });
  const finished = new Promise(resolve => {
    holder.on("error", () => resolve(-1));
    holder.on("close", resolve);
  });
  let result;
  let failure;
  try {
    await delay(1800);
    result = await run();
  } catch (error) { failure = error; }
  const code = await finished;
  if (code !== 0) {
    const error = new Error("Timing admission/save database barrier was not verified.");
    Object.defineProperty(error, "barrierDiagnostics", { value: diagnostics });
    if (failure) throw new AggregateError([failure, error], "Timing operations and database barrier failed.");
    throw error;
  }
  if (failure) throw failure;
  return result;
}
