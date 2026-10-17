# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-09-10

```text
Decision ID: D-043
Date: 2026-09-08
Decision: Adopt WP-04 eligibility semantics under the user's delegated judgment: explicit accepted service sizes are hard constraints; fit claims/review experience affect ranking only. Empty legacy size configuration and unknown pet size/duration are assessment-required, never confirmed fit. Missing identity/authorization/location is exclusion, not assessment.
Context: Installed matching ignores accepted sizes, labels whole-window checks as time fit and does not refresh existing matches. Empty service sizes currently say Follows Fit Signals, conflating experience with permission.
Consequences: Reuse PostgreSQL interval subtraction to find an uninterrupted service plus buffers inside request consent. Preserve scoring weights and intentional dismissals. Explain estimated fit versus assessment from the same evaluation, and revalidate writers. G-10 uses fixed fully occupied/fragmented/broad-window/size/legacy/DST/changed-input vectors plus existing location cases; measure baseline and candidate on identical data before setting latency/exposure budgets. No accuracy or speedup target is claimed in advance. Full WP-04 acceptance remains pending.
Refresh boundary: Store evaluation metadata and private append-only request/groomer refresh events with no client grants. Producers take no cross-request foreign-key or deduplication row locks. The consumer locks requests with SKIP LOCKED, coalesces visible events and deletes only their captured IDs; newer events survive. An owned read RPC masks stale fit while refresh is pending. Install the worker paused, verify actual linked contention, then activate bounded batches; this is not a general job framework. Deliberate dismissal and pending offers remain intact. Package acceptance still requires installed concurrency, affected-scope and measured cost evidence.
Measured rollout: The same rollback dataset reproduces the old occupied/fragmented false-positives and removes them with the new evaluator; two history-free eligible groomers receive equal-score exposure. Twenty-five repeated closed-window calls: old 1408 ms/new 1405 ms; open-window calls: old 2929 ms/new 2518 ms. Initial regression budgets for these fixed probes are 2000/3500 ms respectively, not production percentiles. Use 25-pair worker batches every 10 seconds (installed pg_cron 1.6.4); broader release-load qualification remains WP-14. See https://supabase.com/docs/guides/cron/quickstart for the supported seconds schedule.
Linked files: docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md, docs/03_backend/SERVICE_TIMING_CONTRACT.md
```
```text
Decision ID: D-042
Date: 2026-09-07
Decision: Adopt the WP-03 service timing contract under delegated product/technical judgment: preserve absolute preference consent, distinguish request/service/schedule timezones, and model explicit duration and groomer buffers separately.
Context: The user directed autonomous completion of necessary plan operations. T-374 verified the deployed helper uses local-calendar-day notice and unbuffered service overlap; no location timezone or buffer fields exist. Existing service settings use 15...720 minutes, notice 0...2 days and quota 1...12.
Consequences: Retain those established bounds and five-minute earliest start; preparation/cleanup each 0...120 and mobile travel each 0...180 minutes require explicit confirmed values, never invented historical defaults. Unknown duration/zone remains assessment/confirmation-required. DST gaps reject and repeated wall times require occurrence choice. Whole service fits consent; complete resource interval fits schedule. Current fulfillment/release remains WP-06. The linked contract resolves G-01, the WP-03 portion of G-02 and the duration portion of G-05; size eligibility and rollout remain WP-04. No claim of deployment or completed runtime acceptance.
Linked files: docs/03_backend/SERVICE_TIMING_CONTRACT.md; docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md.
```
```text
Decision ID: D-041
Date: 2026-09-07
Decision: WP-02 uses the existing owned pet UUID for occupancy and the immutable offer UUID for acceptance idempotency, without a second receipt table or invented legacy identities.
Context: Necessary plan operations and technical judgment are delegated. T-373 linked audit found 43 requests, zero null pet references and no confirmed same-pet overlaps; existing request/pet ownership is enforced by a composite foreign key.
Consequences: Add a non-null booking pet reference tied to request/customer/pet and native time exclusion. Return the original booking/conversation IDs with current lifecycle state on replay. A read-only lookup reconciles account-scoped unresolved client submissions before explicit retry; reload must not create bookings. Existing confirmed/completed occupancy semantics are retained until WP-03. Unrelated pet deletion and reschedule policy are not redefined. No deployment until interacting writer lock order and independent-session races are verified.
Linked files: supabase/migrations/20260907233627_t373_pet_capacity_acceptance.sql; docs/06_tasks/sql_reviews/T-373_ACCEPTANCE_ROLLBACK.sql; docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md.
```
```text
Decision ID: D-040
Date: 2026-09-07
Decision: Implement WP-01 locally using one owned availability snapshot and one controlled atomic save, with an optimistic snapshot fingerprint rather than a new revision table.
Context: The user delegated remaining technical choices and requested execution. T-369 verified the relevant deployed tables and acceptance/backfill code; D-038 approved the business boundary.
Consequences: T-371 implements get/save_groomer_availability RPCs, a shared acceptance advisory lock, final-state-only batch backfill, and revocation of legacy partial table writes. Snapshot fingerprints include row identities/timestamps. The client stages time off, separates profile saves, and fails closed on old deployments. Both migrations are deployed with authorized rollback/access/concurrency and client validation recorded in docs/06_tasks/sql_reviews/T-371_AVAILABILITY_ACCEPTANCE.md. Compatible-client distribution remains WP-14; no whole-backend freshness claim is made.
Linked files: supabase/migrations/20260907215424_t371_atomic_groomer_availability.sql; docs/06_tasks/sql_reviews/T-371_ATOMIC_AVAILABILITY_ROLLBACK_VALIDATION.sql; docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md.
```
```text
Decision ID: D-039
Date: 2026-09-07
Decision: Allow narrowly scoped evidence-refresh inspection before the backend freshness gate passes.
Context: T-370 fixes a circular prerequisite introduced by D-037: current evidence cannot be obtained if its read-only inspection itself requires current evidence.
Consequences: Tooling Policy permits task-relevant local/read-only linked verification despite stale dates, with existing project, credential, sequential CLI, and stop rules. Partial checks do not refresh whole-document dates. Dependent implementation and remote writes still require strict hygiene and applicable approval. No verification date or backend fact was changed by this rule repair.
Linked files: docs/05_workflow/TOOLING_POLICY.md.
```
```text
Decision ID: D-038
Date: 2026-09-07
Decision: Availability Save atomically commits working windows, time off, and booking preferences; failure preserves the previous saved data. Existing confirmed bookings remain unchanged. Profile details and photos save independently.
Context: During T-369 / WP-00 the user explicitly approved this Save boundary. Local Store code currently saves profile/windows/preferences sequentially and time off independently; the repository deletes windows before inserting replacements.
Consequences: WP-01 must stage time-off changes with the availability draft, avoid unrelated profile validation/writes, and commit the approved scope together. This approves the behavior, not a particular schema, remote deployment, or the other G-01 through G-10 policy choices. Backend verification remains pending.
Linked files: docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md; ios/Beckon/Beckon/Features/Groomer/Profile/GroomerProfileStore+ServicesAvailability.swift; ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift.
```
```text
Decision ID: D-037
Date: 2026-09-07
Decision: Scope backend evidence freshness to backend work; identify completed Worklog entries through explicit ledger status.
Context: T-368 addresses false documentation-closeout blockers. A newer blocked checkpoint is not a completed task; unrelated document authoring does not reverify deployed backend facts.
Consequences: General hygiene warns on stale backend dates; backend-dependent work and its closeout require CONTEXT_HYGIENE_REQUIRE_FRESH_BACKEND=1 under Tooling Policy. Other freshness gates and date-integrity checks remain errors. No verification dates or backend facts changed. Regression fixtures use a deterministic clock.
Linked files: docs/05_workflow/TOOLING_POLICY.md; docs/05_workflow/SINGLE_AGENT_WORKFLOW.md; scripts/context-hygiene-check.mjs; scripts/task-closeout.mjs; tests/docs/context-hygiene-check.test.mjs; tests/scripts/task-closeout.test.mjs. Closeout also preserves another pending task's valid active artifacts and backlinks instead of requiring false reassignment or completion.
```
