# T-381 Notification Acceptance

WP-10 implementation and deployment on 2026-09-08 under D-049. Applied migration `20260909001015_t381_exact_notification_targets.sql` is immutable.

## Contract

Both roles resolve current owned request, offer, match, booking or conversation IDs before marking a notification read. Unloaded targets do not depend on list pages; missing or unauthorized targets remain retryable. Existing detail views display cancelled/withdrawn state. Reading never acknowledges a booking handoff or changes fulfillment.

Handoff acknowledgement remains a server-owned cross-client confirmation, independently of notification reading. Only successful server results enter the versioned account cache; failed writes remain retryable. Legacy unverified local hints are ignored, not deleted. Session checks reject late results. The exact groomer match reader retains owner/role checks and the existing pending-evaluation mask.

## Evidence

- `/tmp/beckon-t381-final-integration.log`: serial full regression passes, 570 Swift tests/57 suites plus XCTest rendering; default UI three executed/six environment-gated skips. Every existing notification kind, unloaded/current/missing/foreign targets, independent reads and acknowledgement, retry, legacy cache and late-session responses are covered.
- Independent client caches and authenticated SQL session claims verify shared server acknowledgement and isolation. These are not two physical-device observations; the original two-device release requirement remains open in WP-14.
- `/tmp/beckon-t381-installed-sql.log`: installed rollback-only request cancellation, pending match, owner/foreign/anonymous access and independent read/acknowledgement assertions pass. `/tmp/beckon-t381-http-read.log` verifies actual empty-target and foreign-role denial without application writes.
- `/tmp/beckon-t381-final-ui.log` and inspected `/tmp/beckon-t381-final-images` verify both role notification pages at accessibility size after fixing compressed titles. This presentation-only correction followed the full business regression; its focused runtime tests and final build pass.
- `/tmp/beckon-t381-final-build.log` and `/tmp/beckon-t381-final-preflight.log` pass. `/tmp/beckon-t381-runtime-transport.log` covers actual SDK filtering and routing fixtures.
- Deployment/history/dry run: `/tmp/beckon-t381-deploy.log`, `/tmp/beckon-t381-history-after.log`, `/tmp/beckon-t381-final-dry-run.log`; 81 versions align, dry run empty.
- `/tmp/beckon-t381-final-access.json`: zero fixture notifications, public invoker/private definer, anonymous execution denied and authenticated execution allowed. `/tmp/beckon-t381-advisors.json` has only the existing Q-93 warning and informational findings, no new WARN/ERROR.

Expected acknowledgement RED reproduced permanent local suppression after a failed remote write. Initial development compilation caught private destination visibility and a test enum typo; corrected runs passed. Initial screenshots showed compressed titles; final images supersede them. No timezone-settings changes, APNs deployment or speculative acknowledgement deletion.
