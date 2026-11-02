<!-- task-artifact
task: T-437
status: completed
type: plan
-->

# T-437 Refresh continuity

User reports Home counters clearing to Checking and refresh changing module height throughout the app. Completed the code audit and fixes below. Preserve adopted layout, first entrance and explicit Replay; keep session/authorization, business deadlines, writes and real-time fallback intact. User owns visual review. Existing user governance/signing/prototype files remain untouched.

## Delivery

- Home no longer clears known counts at read start. Removed the tile Checking/Not refreshed line and appointment refresh-status row. Counts, existing content and known empty results stay visible; unknown never becomes invented zero. Independent Home reads run concurrently; success clears only its own error, and explicit request/offer access loss revokes the old counters.
- Ordinary tab returns retain settled entrance content. First arrival and explicit Preview Replay remain; cancelled first reads cannot incorrectly stamp the foreground freshness gate.
- Notifications, offers and discovery distinguish unknown from successful-empty. Grooming and Schedule can reveal known scoped content without waiting for unrelated reads; request/offer badges remain present while refreshing.
- Saved groomer browsing no longer waits for request selection or adds a refresh spinner row. Public profiles reuse a bounded session-local Store map, retain unchanged image assets, and retry only unavailable photos. Scoped send controls await verification; explicit access loss clears cached display. Existing session epochs and operation guards remain.
- Fit-signal and portfolio editors no longer insert loading rows over known data. Their editing protections remain unchanged. Empty evidence has its own successful-read flag, independent of claim readiness.
- Reviewed remaining loading branches: first-load placeholders, explicit pull-refresh feedback, chat's recipient subtitle, genuine assessment/matching states and pagination keep their existing responsibilities. No new persistence, backend change, dependency or live-account mutation. Cross-restart snapshots remain T-428.

## Acceptance and evidence

- Counter/cancelled-first-read tests reproduced failures before the fix. Focused runs then passed; actual count tile height is stable at default, AX3 and AX5, and finite rendering verifies settled content remains visible across tab activation changes.
- The first serial integration stalled. A process sample and new failing Observation test identified this task's inadvertently observable profile-cache dictionary/LRU bookkeeping; both are now ObservationIgnored. The affected renderer and remaining tests were recovered, reusing only 22 unchanged passing XCTest cases. The interrupted run is not passing evidence.
- Recovered integration: 917 passed, 47 opt-in skipped, one timing failure. The existing renderer passed 458 customer and 72 groomer state/size samples; cache-consumer Observation regression and functional UI smoke passed. Result: `/tmp/beckon-t437-recovered.xcresult`.
- Final additional refresh/profile validation: 69/69 passed, including success-empty evidence during a failed retry and unchanged editing protection. Result: `/tmp/beckon-t437-final-refresh.xcresult`. Combined unique evidence: **940 passed, 47 skipped, one existing failure** across 988 cases (`/tmp/beckon-t437-validation-union.json`), not a fully green regression.
- The unchanged native-route scheduling assertion requires <0.5s: recovered code measured 0.521s. A bounded sample located UIKit navigation-bar reconciliation; notification/grooming visibility and lazy-favorites trials were reverted. An isolated export of unmodified parent `a70cc725` also failed at 0.592s (`/tmp/beckon-t437-parent-route.xcresult`). This is a confirmed pre-existing, non-blocking navigation-performance finding, not a refresh regression or rendered-frame measurement. The threshold and test remain unchanged; no additional performance work is adopted here.
- Standard preflight passed (`/tmp/beckon-t437-preflight.log`); unchanged backend checks reused. Final source contracts 27/27 and UI consistency audit passed, no new baseline exemptions. Final generic Simulator build passed (`/tmp/beckon-t437-final-build.log`); full documentation hygiene and diff review passed at closeout. No repeated visual click tour; visual quality remains for the user's inspection.

Design direction is fixed in [Lively UI Spec](../../01_product/LIVELY_UI_SPEC.md#refresh-continuity-d-070-t-437) and D-070 in [Decision Log](../../07_decisions/DECISION_LOG.md). T-428 reuses this work and retains its separate persistence scope. No navigation redesign or unrelated task was started.
