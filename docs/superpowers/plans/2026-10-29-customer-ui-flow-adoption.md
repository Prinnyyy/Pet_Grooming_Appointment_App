<!-- task-artifact
task: T-421
status: completed
type: plan
-->
# Customer UI flow adoption — handoff 2

The user adopted the new customer flow on 2026-10-29 and authorized necessary client/backend work. Design source: local `CLAUDE_sandbox/CLAUDE_CODEX_HANDOFF_2.md`, page map, and frozen S-090 prototype. These references remain unchanged. This plan is the single implementation progress/evidence record; Current State owns recovery.

## Decisions and boundaries
- New interaction flow is authoritative. Preserve production protections and data integrity while adapting contracts; do not force the old UX back into the design.
- 2026-10-29 user clarification: customer flow need not connect to current groomer UI modules/pages; groomer UX will be redesigned later. Reuse shared data, domain rules and protections, without introducing navigation/adapters merely to preserve old groomer screens.
- One customer Grooming journey, four tabs, one detail page. Existing request/booking stores remain reusable services; route and feed projections unify their presentation.
- Finished occurs on verified completion or the service-day boundary (later of next midnight and scheduled end); unresolved reported outcomes retain their existing exception. Review eligibility must support elapsed bookings server-side without inventing verified service evidence. Fourteen days controls active-card retention only; History still permits eligible reviews.
- Customer-safe groomer profile read supplies real content, public schedule summaries, and request-scoped fit. Do not expose private schedule notes or loosen table RLS.
- Typed navigation replaces the offer-selection segment after successful confirmation. One Confirm booking action retains pending-operation recovery. Keep internal .requests and customer.tab.requests titled Grooming; .bookings stays a legacy enum value for the frozen prototype but is absent from customer allCases.
- Six-step wizard keeps wall-clock choices when address timezone arrives, returns directly to Review after editing, and closes immediately on clean Send without changing the originating tab. Preserve uncertain/partial-operation recovery.
- Adopt the prototype wording, information density and motion. Keep existing precise operational errors and accessibility behavior. No unsolicited redesign.
- Work continuously through packages. Reuse existing tests/tools and valid evidence; full regression at integration. Existing user edits, signing, frozen prototype, and groomer-role layouts are preserved. No subagents. Only the validated whole objective receives a completion commit/push on the current main branch.

## Packages and acceptance
1. [x] Foundations: journey, carousel, short times, icons, selection morph, sheet/pinned chrome, shared kit. Compile and focused boundary/style checks.
2. [x] Grooming shell/Home/detail/History with canonical feed, routes, completion/review backend contract; ownership, timezone/DST, review evidence and retention tests.
3. [x] Wizard: new modules, editable Review, address timezone, Send/Back/recovery behavior; focused state and interaction tests.
4. [x] Offer acceptance: one confirmation, durable result handling, replace navigation segment; duplicate/pending/failure checks.
5. [x] Favorites/picker/profile: request selection, batch sending, consistent profile selection, safe real reads and image viewer; customer/stranger/inactive/privacy checks.
6. [x] Authentication: landing, forms and recovery, existing real auth retained; keyboard and motion checks.
7. [x] Smaller pages/routes and production-backed sandbox fixtures; preserve independent prototype.
8. [x] Vocabulary/docs/audit rules: current design, screen ownership, accessibility/motion, decisions; retire obsolete customer code after checking consumers.
9. [x] Integration: required build, unit/UI regression, Simulator interaction/AX/Reduce Motion, Release build, preflight; authorized backend deployment + negative/transaction/cleanup evidence; final diff review and scoped Git completion.

## Acceptance evidence

Evidence files below are under ignored `artifacts/evidence/T-421/`; durable tests and migrations are committed with the implementation.

| Scope | Result / evidence |
|---|---|
| Integration regression | `scripts/ios-test.sh`: 876 passed, 7 failed, 47 explicitly gated skips. The 7 failures were investigated and fixed: four obsolete assertions, auth child identifiers (two cases), selected pet-card geometry. Follow-up suites below cover the corrections; this is not a claim that skipped remote suites ran. |
| Customer Stores / lifecycle / address | `customer-follow-up.log`: 144 tests across four suites passed, including metadata fallbacks, missing-zone notice and wizard timezone behavior. |
| Auth / layout / motion | `integration-fixes-isolated2.log`: auth UI 3/3 and brand/layout checks passed. The two stale card expectations in that run were subsequently corrected and passed in the 144-test suite. |
| Screen render sweep | `final-native-fixed.log`: 458 declared screen/state/size combinations at normal and AX3 sizes, brand/layout checks and 16 app-entry/profile/lifecycle tests passed. Rendering coverage is not visual-equivalence proof or a spoken VoiceOver audit. |
| Review recovery / wire decoding | `review-recovery-red-suite.log` → `review-recovery-green.log`: Confirmed/Completed × three uncertain-result cases; the elapsed Confirmed cases failed before the fix. All 44 booking/profile tests then passed. Populated deployed profile wire shape is covered. |
| Interactive Simulator journey | `local-journey.log`, `local-journey-observations.json`: pet/service/time/details → editable Review → profile selection → Send closes to Home; offer confirmation once → one Back to Grooming; favorites request→selection→Send; AX3 review input/submission. Real production Views, existing local mock repositories. |
| Final accessibility / motion interaction | `local-final-ax.log`: system Reduce Motion confirmed active; portfolio photo fullscreen/swipe/close, review input identifiers, Grooming→History→reviewed detail and four tab identifiers verified. Simulator ReduceMotionEnabled restored from 1 to its original 0. |
| Deployed backend | Both T-421 migrations applied; 127-entry linked migration history aligned and repeat dry-run empty. `runtime-validation.log`: authenticated-role SQL prepare→directed publication→quote→accept→elapsed unverified review after 30 days; role/stranger/inactive/privacy/revision/duplicate/fake-fit/report/timezone negatives. Rollback-only; `runtime-restoration.json` confirms exact T374 snapshot restoration. This is SQL transport, not a remote-client UI run. |
| Concurrency reuse | Existing `artifacts/testops/TESTOPS-T390-20260911-D/matching-results-review-race.json`: four HTTP writes, one created, three duplicates rejected, rating restored. `review-lock-comparison.json` confirms the write body is unchanged except eligibility; live unique booking index unchanged. New elapsed predicate/context/duplicate assertions were tested separately. No new elapsed HTTP race claimed. |
| Backend security | `advisors.json`, `rpc-security-metadata.json`, `review-uniqueness-metadata.json`: safe search paths, anonymous denial, intended invoker/definer grants and uniqueness retained; no table/Storage policy widening. Advisors: 32 existing policy/index INFO and one Auth leaked-password-protection WARN, no new function/grant finding. |
| Boundaries | Frozen prototype boundary tests 2/2 passed. No edits to frozen design sources, local signing or user governance changes. No groomer page redesign, device/signing/store/APNs scope added. |

## Resolved integration findings and limits

- Retired old customer Requests/dashboard/request-detail and booking-detail pages after moving shared policy/photo helpers; Home and Grooming use one canonical feed/detail. One request modal presenter serves all customer tabs and standalone production-backed fixtures.
- Fixed selected pet-card depth shift, child accessibility identifiers overridden by container identifiers, and the missing associated request in DEBUG fixtures. Actual tab identifiers were verified after navigation settled; no speculative UIKit identifier bridge was retained.
- Release initially found two unused preview helper structs referencing DEBUG-only types. Removed the unused helpers; Release passed. Final incremental Debug/test-target and dual-architecture Release builds passed (`final-driver-build.log`, `release-final.log`). The History label focused suite and final arm64 Release build passed (`history-label-green.log`, `release-closeout.log`). New closure isolation warnings in the adopted request controls were corrected; unrelated existing pet-form warnings remain.
- History now labels elapsed and verified finished grooming consistently as Finished, while preserving the underlying fulfillment status; the existing lifecycle suite reproduced the old Confirmed label before correction, then all 7 cases passed (`history-label-red.log`, `history-label-green.log`), including deterministic future-date boundaries.
- Review uncertain-result recovery now uses the shared finished predicate, with the existing session/booking/customer/groomer identity checks and a single readback; no automatic write retry. Method-only Swift Testing filtering selected no recovery cases, so the whole focused suite was run instead.
- Historical TestOps normal publication/confirmation/route selectors were adapted and compiled. Remote scenario suites were not rerun. Older T392 publication fault-injection cases still describe the pre-discovery RPC; current discovery recovery remains covered by existing discovery/Store tests, not those historical cases.
- Default DerivedData was locked by the user's Xcode session. Task-local DerivedData reused existing packages; user Xcode/Preview/signing were left intact. The Supabase connector identity could not read advisors; installed linked CLI completed the check without changing writer or authorization.

## Closeout

Implementation and scoped acceptance complete. Final Debug/test-target and Release builds, preflight (`preflight-final.log`) and full context hygiene passed. Completion contains 109 task-owned paths; local signing, user governance edits and frozen prototypes remain excluded. Git owns the completion commit/push evidence.
