# T-384 Core-First Loading Acceptance

Original WP-13/C-01 accepted on 2026-09-09 under D-052.

## Behavior

Groomer profile, services and authoritative schedule publish before optional portfolio/tags/claims/evidence. Metadata uses four independent reads; each image batch uses at most three downloads. Customer request/booking facts and persisted acceptance recovery precede optional images. Failed optional reads retain known data rather than fabricate empty replacements. Fit/tag editing requires successful metadata loading and exposes retry.

Raw form snapshots preserve edits made before or during refresh. Load identities, cancellation/session checks and mutation revisions reject late results. Profile refresh cannot start during save/upload. Request and booking writers invalidate older list reads; uploaded request photos invalidate older photo reads. No repository, database, dependency or generic loading framework was added.

## Fixed Measurements

Controlled repository fixtures, not production HTTP latency or total wire payload:

| Fixture | Before | After | Unchanged Work |
|---|---|---|---|
| Six profile photos, 20ms per read | Core 160.8ms; total 311.2ms | Core 69.2ms; total 159.2ms | 14 repository reads, 196608 image bytes |
| One request/booking/pet photo, 100ms image delay | Core 102.1ms; total 102.1ms | Core 1.3ms; total 102.8ms | One request read, two photo reads, 32768 image bytes |

Before logs: `/tmp/beckon-t384-baseline-red.log`, `/tmp/beckon-t384-baseline-and-drafts.log`. After: `/tmp/beckon-t384-refined-validation.log`, 189 tests/four suites pass. Peak image concurrency is asserted at three; optional reads assert core publication has already occurred. Timing varies by scheduling and is not a percentile or SLA.

## Verification

- Initial failures reproduced optional-core blocking, dirty-form replacement, stale avatar/profile/service results, cancelled request publication and unsafe empty fit-claim replacement. Focused tests also cover superseding loads and persisted acceptance recovery when the list fails.
- `/tmp/beckon-t384-final-regression.log`: final 602 Swift tests/60 suites, XCTest rendering and four default UI cases pass; six environment-gated UI cases and the opt-in remote recovery test skip. T-383's actual email evidence remains separate. This includes the final save/upload-entry guards and the save-in-progress regression.
- Actual compact runtime images inspected under `/tmp/beckon-t384-rendering/`: core profile remains populated/editable despite optional failure; unavailable fit signals show Retry without empty editable claims or Save. No observed overlap. This is Simulator rendering, not device qualification.
- `/tmp/beckon-t384-final-build.log` and `/tmp/beckon-t384-preflight-final.log` pass. The AppIntents metadata-skipped message is unchanged toolchain information. Manual review found no remaining blocking issue within WP-13.

No backend or security-contract change; existing deployed evidence remains applicable. Missing authoritative booking locations remain governed by the unchanged agreement/readiness tests, not synthesized by this optimization. Original WP-14 two-device, email-app handoff, keyboard and distribution gates remain required. Device inventory currently reports no connected devices.

The existing strict context meta-review cadence failure remains under the user's explicit continuous original-plan exception. No review date or functional/security gate is altered, and unified closeout is not claimed green.
