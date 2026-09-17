# T-382 Reminder Acceptance

WP-11 on 2026-09-08 under D-050. Applied migration `20260909004101_t382_reminder_snapshot.sql` is immutable.

## Contract

One SECURITY INVOKER scalar snapshot contains complete eligible booking facts for the authenticated account and a server-defined 30-day horizon. It uses existing role/participant RLS, rejects anonymous/foreign callers, and fails above 4096 rows instead of claiming partial completeness. It omits addresses, agreements and image hydration. The scheduler retains the nearest 60 alerts; partial UI lists only request a fresh snapshot and cannot infer cancellation.

Account/session plus booking/time/version identifiers separate stale system writes from newer reminders. UTC calendar triggers preserve absolute appointment time. Auth exit and account-root replacement clear owned pending/delivered alerts; late fetches and notification additions cannot recreate them. Legacy app reminder identifiers are cleared on session initialization; unrelated notifications remain. Foreground, reconnect, loaded pages and explicit mutations refresh authoritative state. Taps resolve current owned booking details, including cancelled/missing targets, and cannot fabricate a completed service.

## Evidence

- Owner-identity RED: `/tmp/beckon-t382-reminder-red.log`. Focused planner/reconciliation/SDK/Auth/Booking/runtime tests pass in `/tmp/beckon-t382-focused.log`.
- `/tmp/beckon-t382-final-integration.log`: serial full regression passes, 580 Swift tests/58 suites plus XCTest rendering; default UI three executed/six environment-gated skips. Includes complete/partial/failing snapshots, other-party changes, permission revocation, auth exit, late fetch/add, older reschedule write, 60-item capacity, UTC and cold/current/foreign taps.
- Inspected `/tmp/beckon-t382-images`: current cancelled Booking detail and missing-target retry, rendered from the actual destination view. They use controlled repository fixtures, not physical delivery evidence.
- `/tmp/beckon-t382-final-rehearsal.log` and `/tmp/beckon-t382-installed-sql.log`: both roles see the same booking; current groomer cancellation removes it from the customer's snapshot; spoofed/foreign/anonymous access is denied. All fixtures are rollback-only.
- Deployment/history/dry run: `/tmp/beckon-t382-deploy.log`, `/tmp/beckon-t382-history-after.log`, `/tmp/beckon-t382-final-dry-run.log`; 82 versions align and dry run is empty. Advisors `/tmp/beckon-t382-advisors.json` retain only existing Q-93 WARN and informational findings.
- `/tmp/beckon-t382-final-build.log` and preflight `/tmp/beckon-t382-preflight.log` pass. `/tmp/beckon-t382-final-access.json` verifies invoker mode, anonymous denial, authenticated execution and zero fixture requests.

The first SQL rehearsal caught an incorrect profile key; the second caught a fixture using the intentionally rejected legacy cancellation RPC. Current-key/versioned-fulfillment rehearsal passes without weakening either guard. A screenshot export initially used an incorrect result path; export from the recorded test result succeeded.

Offline limitation: a remotely cancelled appointment cannot immediately retract an alert already scheduled on an offline device. Reconciliation happens on reconnect/foreground/refresh; taps require a current read. APNs, timezone-settings changes and physical-device release qualification are not claimed here.

Closeout `/tmp/beckon-t382-closeout.log` reports only the 10-task governance meta-review cadence; other structural/freshness checks pass. Continue under the user's explicit original-plan-only continuous execution instruction without changing the true review date or safety/functional gates. This is a recorded exception, not a passing unified closeout claim.
