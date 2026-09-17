# T-380 Chat Summary Acceptance

WP-09 implementation and deployment on 2026-09-08 under D-048. Applied migration `20260908234932_t380_bounded_chat_summaries.sql` is immutable.

## Contract

One bounded SECURITY INVOKER RPC returns one latest message and latest participant-pair booking per owned conversation. It reuses existing RLS, rejects anonymous/missing/foreign scopes and accepts at most 100 IDs. Timestamp/ID ordering and lateral limits keep results deterministic. The message index is reused; a pair/booking-time/ID index supports booking summaries. No new privilege, persistence or cross-device read semantics.

The client queries exact participant pairs for booking navigation, independent of loaded conversation pages. Failed routing retains its target for retry. Summary failures cannot turn into empty previews, and older loaded thread history cannot override a newer server preview. Existing private avatar and booking-card paths remain intact.

## Evidence

- Metadata and triggers: `/tmp/beckon-t380-read-metadata.json`, `/tmp/beckon-t380-chat-triggers.json`. Actual configured API cap is 1000: `/tmp/beckon-t380-configured-cap.json`, retrieved with the existing CLI credential without logging any credential/config secrets.
- Named rollback fixtures contain 1500 busy messages plus a quiet conversation. Rehearsal and installed role/access/tie/empty/excessive/mixed-missing vectors pass: `/tmp/beckon-t380-summary-rehearsal.log`, `/tmp/beckon-t380-installed-sql.log`. Final cap-specific old-query reproduction is `/tmp/beckon-t380-final-cap-sql.log`.
- Cost probe: `/tmp/beckon-t380-cost-rehearsal.log` returns two summaries/755 bytes; latest-message index scan returns one row, measured 0.459 ms on this fixture. This is not a production latency percentile.
- Actual HTTP empty-scope and inaccessible-scope behavior: `/tmp/beckon-t380-http-empty-denial.log`. Nonempty coverage is installed authenticated SQL plus actual SDK transport fixtures, not persistent HTTP fixture creation.
- Final serial full regression: `/tmp/beckon-t380-final-integration.log`, 565 Swift tests in 56 suites plus XCTest rendering; default UI three executed/six environment-gated skips. Build `/tmp/beckon-t380-final-build.log` and final preflight `/tmp/beckon-t380-final-preflight.log` pass. Scoped Store/SDK tests also pass `/tmp/beckon-t380-targeted.log`.
- Deployment/history/dry run: `/tmp/beckon-t380-deploy.log`, `/tmp/beckon-t380-history-after.log`, `/tmp/beckon-t380-final-dry-run.log`; 80 versions align and dry run is empty.
- `/tmp/beckon-t380-final-access-cleanup.json`: zero fixture messages, invoker mode, anonymous execution denied, authenticated execution allowed. Advisors `/tmp/beckon-t380-advisors.json` retain prior findings and one expected initially unused pair index INFO; no new WARN/ERROR.

## Excluded Runs

The first intended focused invocation used a wrapper that does not forward filters; its unintended parallel full run hit the previously observed feedback-timer/Simulator launch failure. Direct serial targeted and final full runs passed, without changing the test framework. The first HTTP check incorrectly assumed this cleaned-up test account retained a conversation; the corrected HTTP empty/denied checks passed. No unrelated fixture was created to satisfy that assumption.

Notification routing remains WP-10, reminder reconciliation WP-11, core/enrichment ownership WP-13 and release qualification WP-14. No account-timezone settings work.
