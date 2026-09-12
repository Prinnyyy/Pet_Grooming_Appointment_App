# T-390 Matching And Rating Acceptance

2026-09-12. MR-01 through MR-06 accepted and enabled. The [adopted plan](../../superpowers/plans/2026-09-10-matching-rating-implementation-plan.md) and [design](../../superpowers/specs/2026-09-10-matching-rating-system-design.md) retain their complete scope.

## Evidence Index

Ignored, credential-protected evidence roots below are repository-relative. SQL rollback fixtures are not real completed appointments; authenticated HTTP and Simulator actions are identified separately.

- D: `artifacts/testops/TESTOPS-T390-20260911-D` contains scoring, privacy/concurrency, role boundaries, 1000-review/26-candidate performance, actual worker and initial publish/quote/accept evidence.
- E: `artifacts/testops/TESTOPS-T390-20260912-E` contains 43 affected real-role HTTP booking regression cases and exact restoration.
- F: `artifacts/testops/TESTOPS-T390-20260912-F` contains the small real-time lifecycle, final Simulator phases, boundary probes, catalog/advisors and restoration.
- Repeatable entry points: `scripts/test-t390-matching-scenarios.mjs`, the T-387 scenario runner's T-390 v3 quote adapter, and `TestOpsBookingAdversarialTests`. Commands retain explicit run-ID and remote-write gates. F's time-dependent UI setup used captured operation/request IDs; do not rerun a restored run ID.

## Work Packages And Matrix

| Scope | Passed evidence |
|---|---|
| MR-01; M31-M35 | D `matching-results-run/admission-db/roles.json`: explicit species/size exclusions, legacy null versus empty scope, unknown facts, 100/100.1/100.001-pound boundaries, missing coordinates, foreign writes and immutable quote revisions. F `ui-ConfirmMatchingServiceSpecies.json`: actual owner saves legacy species. D UI quotes explicitly confirm unknown size/coat/matting; F `fallback-db.json` rejects old v2 bypass. |
| MR-02; M01-M10 | D `matching-results-review-db.json` and its runner assertions: invalid size/coat/aliases rejected, dog evidence does not transfer to cat, missing/future facts excluded, incomplete/unreviewed service does not manufacture feedback, late feedback retains service time, final scheduled date/timezone controls age including leap day. F `live-review-frozen-context.json` plus review UI: pet changed 12 to 200 pounds through owner API; old service still offers S, original coat and three care keys. |
| MR-02; M11-M15 | D `evidence-db-1000.json`: 800x5 + 200x1 = exact 4.20; insertion/update/deletion arithmetic and cascading projection checks. `matching-results-review-race.json`: four concurrent real HTTP submissions create one review. Deployed customer/groomer anonymization rollback, profile-lock and observed review-lock concurrency pass in `privacy-*.json`; actual Auth/Storage deletion was not performed. |
| MR-03; M16-M20 | Independent reference vectors plus D `cohort-db.json`, historical review replay and decay comparisons: repeated-customer influence <=1, ten independent customers differ, 180-day half-life, no late-submission rejuvenation, independent F/Q cohorts. |
| MR-03; M21-M25 | D review assertions and `care-group-db.json`: fixed group denominator, partial answers, missing versus negative, multiple care keys share one group. `claims-portfolio-independence-db.json`: seven claims/five metadata rows do not change any score field. |
| MR-03/05; M26-M30 | Independent vectors, D review/paging probes and F customer-sort/network UI: newcomers discoverable and neutral, custom F neutral, public review count separate from independent customers, negative feedback retained, no_evidence distinct from unavailable, deterministic bounded extremes. F stores a 5-star review with negative full_groom feedback through real UI/API. |
| MR-04; M36-M40 | D `range-oracle-differential.json`: 30 exact-second vectors including LA/Lord Howe/Apia/Kathmandu/Monrovia. F `qualification-clock-db.json`: full qualification across repeated/skipped hours and local notice midnight with 45/30-minute buffers. E concurrent pet/groomer/quota tests; F `release-db.json` proves release event -> pending -> rediscovered. Unchanged unfulfilled release/quota rules reuse [T-377](../../06_tasks/sql_reviews/T-377_FULFILLMENT_ACCEPTANCE.md); new evaluator/event integration uses the same effective resource-end function. |
| MR-05; M41-M45 | D paging/scale/HTTP probes: old second-page best candidate reaches new first page, complete authorized scope, stable HMAC tie and strict bucket order. D/F Simulator explicit groomer/customer modes agree with server oracles. F `radius-score-independence.json`: expanding radius 12 to 50 leaves the complete fixed-distance score unchanged. |
| MR-05; M46-M50 | D cursor and live five-page HTTP tests reject mutation, expiry, signed cross-account/role/scope cursors and tampering. F `ui-MatchingLivePageChanges.json`: actual role HTTP new review and new quote during Simulator browsing each preserve loaded content, stop pagination and recover on manual refresh. Natural expiry disables an already-open confirmation button; F `natural-expiry-api.json` independently rejects acceptance with evaluation reason expired. Store generation/cancellation tests reject late responses and repeated automatic retries. |
| MR-04; M51-M55 | D event/scale/time probes distinguish hard/evidence/rating/display, retain events arriving during consumption, invalidate stale proof, rediscover absent matches and preserve dismissal. Actual cron drains 338 pairs in approximately 71 seconds and remains empty for three cycles; no synthetic clock claim is made for that observation. |
| MR-01/05/06; M56-M60 | Structured zero/assessment/pending/network state tests, real assessment UI, F DEBUG one-shot transport failure with retained list then successful refresh/quote, `fallback-db.json` arithmetic-fault fallback with independent cursor and successful acceptance, old-client confirmation rejection, E replacement/recovery races, F dismissal refresh/relaunch and repeated role switches. Account/role/page-keyed preference and late-session response tests pass. |

## Actual Simulator Lifecycle

All named F `ui-*.json` results have status 0 and their own xcresult. These are executed opt-in tests, separate from default-suite skips.

- Customer four-sort comparison; two accepted requests; customer proposes a new time and groomer accepts it; second booking is cancelled without changing the first.
- First booking `7942528d-f2e9-43d9-aadc-291ab47bdc64`: scheduled 2026-09-12 14:20 UTC; real start 14:20:05.453532, real completion 14:21:12.658175; resource release remains 14:51:12.658175. No device/server clock was changed.
- Owner API changes the new fixture pet; Simulator submits the frozen-context review. Separate API checks verify exactly one review/outcome and accurate rating/projection deltas. The owned review was subsequently replaced through real API during the pagination mutation test, then removed with the fixture.
- Network recovery uses an explicit DEBUG/TestOps-only injected transport failure, not physical Wi-Fi loss. Expiry uses real waiting; page mutations use actual authenticated endpoints. Additional 26 paging requests are labeled controlled SQL UI fixtures, not 26 real customer publications.

## Performance And Quality

- Original budgets unchanged: 25 open/closed oracle calls 2565.977/1641.597 ms, below 3500/2000 ms.
- Historical 1000-review/26-candidate dataset, 30 reads: SQL P95 866.331 ms (first 1238.94); authenticated HTTP P95 326.917 ms (first scope read 274.283), below 1500/2500 ms. D `sql-ranking-historical.json` and `http-ranking-G2-historical.json` retain samples.
- Two rejected optimizations/baselines remain recorded: HTTP P95 3055 ms and later SQL P95 2218 ms. Bounded double-precision decay with numeric aggregation and complete-input per-call reuse fixed them; no persistent score cache or relaxed acceptance budget. Decay error <=4.756e-16; whole-page comparison error <=1e-7.
- Five-page browsing with review changes every ten seconds: 10 attempts, 4 completed, 6 explicit list_changed outcomes, at most 2 consecutive incomplete attempts. This passes the adopted three-consecutive-failure gate; 60% restart under this synthetic churn remains a non-blocking usability limitation, not evidence of production conversion improvement.
- Controlled dog/cat, fixed/custom, sparse/negative, distance and account cohorts preserve eligible discovery. Fixture screen placement is not production exposure. No representative live conversion, wait-time or completion-rate uplift is claimed; no behavioral profiling or extra analytics system was added.

## Integration And Restoration

- Final preflight: 162 migration tests and 10 Edge tests pass. Full Simulator build passes; only the existing unused AppIntents metadata warning remains.
- Full xcresult `Test-Beckon-2026.09.12_07-40-08--0700.xcresult`: 670 passed, 25 environment-gated skipped, zero failed, 695 unique tests (parameterized executions reported separately). F `final-ios-tests.json` preserves the summary. Required T-390 interactive cases executed independently above; skips do not substitute for them.
- Before enable: 106 aligned migrations through `20260911150426`; 15 relevant function signatures/ACLs verified, no disabled public protection triggers or injected scoring fault. Advisors: only the pre-existing Q-93 leaked-password-protection warning; no new performance/security finding.
- Enable migration `20260912144522_t390_enable_matching_ranking.sql` applied after acceptance/restoration: 107 histories align, repeat dry run empty, matching-v1 enabled and validation cohort empty. G1/G2 actual authenticated reads both return fit; their restored lists are empty, not a new performance sample. Customer enabled-path behavior was verified earlier through the private cohort using the same implementation. F `rollout-verification.json` records the post-deploy checks.
- D: 15 baseline comparisons with separate profile timestamp verification, private contexts/projections/candidates/queue all zero. Exactly 78 orphan notices from the old bounded live-worker probe were removed only after provenance and full-row equality checks.
- E: all 15 baseline hashes exact, private rows zero. A transient deleted-request queue drained through the normal worker; cleanup now allows a bounded observation window without weakening the zero-residual requirement.
- F: all 30 scoped requests removed; 14 table hashes exact and every profile business field equal. Legitimate updated_at and eligibility revisions are retained because authorized notice changed 1 -> 0 -> 1; rewinding the revision would revive stale quotes. F `review-profile-restoration.json` records exact transitions. Context/projection/candidate/queue residuals zero; validation cohort empty. New pets/services/reviews, related notices and conversations restored/removed; no Auth/Storage account deletion.

## Failures And Scope Limits

- A real profile/advisory-lock deadlock in anonymization was reproduced and fixed by bounded NOWAIT source-lock attempts with rollback before retry; sustained conflict remains recoverable rather than partially anonymized. Artificial long lock timeout and the final observed-overlap success are both retained.
- Simulator exposed groomer schedule accessibility identifiers being inherited by child controls; the narrow containment fix passed the same reschedule flow. Species switch, inherited confirmation ID and harness field/JSON representation mistakes were corrected without bypassing app controls or database constraints.
- No device/signing/store/APNs work, dependency, ML recommender, implicit preference inference, market-growth claim, unrelated governance rewrite or PR/branch reconciliation is included. Original dirty historical/backend documents remain user work.
