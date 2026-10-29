# Supabase Contract

Verification is scoped by section. The latest recorded pet-save and linked-history verification is T-406, 2026-10-17. Other domains retain their named acceptance baselines; documentation reconciliation does not revalidate remote behavior.

This is the active fast-path backend contract. It records current authoritative facts and points to the right detailed source instead of embedding every historical table, RPC, Storage, and migration note.

Full pre-trim contract text is archived at `../09_frozen/backend_contracts/SUPABASE_CONTRACT_2026-07-01_PRE_FAST_PATH_TRIM.md`.

## Current Status

- Latest recorded migration verification: T-406 confirms 125 aligned versions through `20261017105527_pet_profile_reliability.sql`, with an empty repeat dry run; see [T-406 acceptance](../superpowers/plans/2026-10-17-pet-profile-reliability-plan.md#7-执行记录). Earlier counts below describe only their named historical baselines.
- T-388 notification/replacement acceptance (2026-09-10): both notification tables expose nullable `related_conversation_id` with indexed `ON DELETE SET NULL` references. Text triggers target the opposite participant's conversation; no historical target inference. Atomic replacement cancels the locked original before unchanged quota-checked publication in the same transaction. Schema/RLS/ACL and real behavior acceptance passed; see [T-388](../04_ios/testops/T-388_BOOKING_REMEDIATION_ACCEPTANCE.md).
- Authorized fresh project: `Beckon`, ref `lqmasbuqzvcvtawonjlb`, organization `Prinnyyy`, region `us-west-1`.
- Forbidden legacy project: `Prinnyyy's Project`, ref `swdiiyypysyxbnfrxxsv`. Do not inspect, branch, migrate, reset, or mutate it for this rebuild.
- T-385 integrated baseline: actual participant Realtime delivery/nonparticipant isolation and dual-Simulator functional acceptance pass; exact fixture restoration, enabled profile triggers and zero tagged requests verified. Installed writer/grant, legacy, matching cost and security evidence is in [final acceptance](../06_tasks/sql_reviews/T-385_RELEASE_CHECKPOINT.md). Physical devices, signing and store distribution are excluded. Earlier admission/Save evidence remains [T-374](../06_tasks/sql_reviews/T-374_TIMING_BACKEND_ACCEPTANCE.md), independent-session races [T-373](../06_tasks/sql_reviews/T-373_ACCEPTANCE_EVIDENCE.md), and availability [T-371](../06_tasks/sql_reviews/T-371_AVAILABILITY_ACCEPTANCE.md). These records do not refresh unrelated assertions.
- Local CLI readiness baseline: T-139 confirmed sequential `supabase projects list`, `supabase migration list --linked`, and `supabase db push --linked --dry-run` work from this checkout without `SUPABASE_DB_PASSWORD`.
- Local migration mirror: `../../supabase/migrations/`. Do not rename or edit applied migrations; use the named acceptance record for its verified history rather than treating older counts as current.
- Full historical contract detail before this fast-path trim is frozen for comparison only. Current implementation truth comes from migrations plus focused active backend policy files.

## Read Order

### Pet Profile Reliability - T-406

Verified 2026-10-17 on the authorized Beckon project; migration `20261017105527_pet_profile_reliability.sql` is applied, linked history aligns and the repeat dry run is empty. This updates only pet saves, not the older domain baselines below. Acceptance and recovery evidence live in the [T-406 plan](../superpowers/plans/2026-10-17-pet-profile-reliability-plan.md#7-执行记录).

- `save_my_pet_v3(p_pet_id, p_facts, p_coat_confirmed, p_operation_id, p_expected_revision)` returns `{pet_id, result_revision, replayed, state, pet}`. Create requires an operation UUID and no expected revision; edit requires the original form revision and no operation UUID. Existing private v2 owns fact validation and coat/weight provenance.
- `pets.revision` advances on actual row changes. A stale edit returns `PT409/pet_revision_conflict` without writing. Missing/deleted owned targets return `PT404/pet_not_found`, never implicit creation.
- Private, RLS-enabled `pet_create_operations` binds actor + operation to a server-normalized intent hash and original pet/revision in the same transaction. Same intent replays current owner-safe data; changed intent returns `PT409/pet_operation_intent_changed`. Deleted targets return `unavailable` and cannot be recreated by replay. Receipts survive pet deletion and are redacted with account anonymization; anonymized actors cannot replay.
- Authenticated direct fact INSERT/UPDATE and private v2 execution are revoked. Public v2 explicitly requires a client update; only owner soft-delete columns retain direct UPDATE. No unsafe client fallback is supported.
- The client persists one immutable account-scoped creation before sending, retries only that intent on explicit confirmation, and requires confirmed reload after an edit conflict/unknown outcome. Store load identity and mutation revision guard list, photo, cache and error writes. Existing request/booking snapshots and independent photo-upload semantics are unchanged.

### Request Discovery And Distribution - T-399

The implementation contract below is defined by the T-399 migrations. Rollout, remote verification and fixture-restoration status are recorded in the [implementation plan](../superpowers/plans/2026-09-21-request-discovery-invitations-plan.md#8-完成标准与执行记录); this section is not independent deployment evidence.

- `get_customer_groomer_profile_v1` reuses active-customer and active-groomer guards, returning public services, portfolio paths/tags, active claims and weekly schedule/notice/date-only time-off summaries. It excludes private time-off titles, precise addresses and private preference fields; table and Storage RLS remain unchanged.
- Owner-private `prepare_request_discovery_v1` sessions last at most 30 minutes, with four unconsumed sessions per customer. `get_request_groomer_candidates_v1` and `get_discovery_groomer_profile_v1` accept owner preview/Request scopes, reuse authoritative context eligibility and matching-v1 scoring, and return marketplace-safe profiles. Ranked pages reuse signed cursors and the shared actor snapshot budget; legal candidates are not cut off at the eight-card UI limit.
- `publish_request_with_distribution_v1` creates one Request with explicit pool consent and recipient IDs. Initial publication and atomic replacement receipts belong only to `request_publish_operations`; accepted replay precedes preview expiry checks. `invite_request_groomers_v1`, `set_request_pool_v1` and `withdraw_request_invitation_v1` use the separate distribution-operation ledger. Five active invitees include selectable invited offers, and each Request/groomer invitation pair is unique.
- Invitations end no later than 24 hours or Request expiry. Request expiry is the earlier of 48 hours and the preference-window end minus five minutes. Pool closure changes distribution revision, not terms revision; it revokes new pool access/quotes while retaining existing offer management. Acceptance remains the existing locked, unique-Booking path.
- `get_customer_request_progress_v1` batches up to 25 owned IDs: authoritative status, terms/distribution revisions, pool state, invitations, valid-offer count, pending-evaluation fact, optional `pool_candidate_count` and check time. Counts use current projections and quote validity, not a new full professional-scoring pass. They do not promise a response or booking.
- `set_groomer_favorite_v1` is private revision-checked desired-state mutation; `get_my_favorite_groomers_v1` uses signed keyset pagination (25 default, 50 maximum), a 500 active-favorite policy and 30-day false-state tombstones. Favorites never alter ranking, eligibility, invitation or booking state. Paused/deleted targets retain only the permitted unavailable representation.
- Discovery rollout and legacy-publication retirement are independent flags. Retirement rejects new unsafe legacy publication while allowing accepted legacy receipt replay. Disabling discovery never restores broad groomer raw-table reads, publicizes directed requests or prevents handling existing quotes/cancellation.

- [Booking fulfillment](BOOKING_FULFILLMENT_CONTRACT.md): deployed WP-06 action, evidence and resource-release contract; [T-377 acceptance](../06_tasks/sql_reviews/T-377_FULFILLMENT_ACCEPTANCE.md).

WP-03's deployed [service timing contract](SERVICE_TIMING_CONTRACT.md) owns timezone, duration, buffer and interval semantics. Existing accounts' missing settings were not fabricated. Original WP-03 acceptance now passes; evidence and later-package/release limits are recorded in the T-374 acceptance files.

### Historical Availability Inspection - T-369

Inspected 2026-09-07 using sequential installed CLI `db query --linked` catalog SELECTs, after matching the linked project to the authorized Beckon ref. The bullets preserve the preparation-time definitions, not current grants or open work.

T-371 authorized continuation: both availability migrations are applied. Rollback/access, Save/Save, Save/acceptance with both orderings, and focused client interactions passed; exact fixtures were restored. Legacy authenticated schedule writes are revoked; old binaries need the compatible client. This extends only scoped evidence; unrelated address/Auth/Storage assertions are not refreshed. See the acceptance record above. The following T-369 bullets describe the pre-implementation inspection, not current write grants or outstanding WP-01 validation.

- Inspected columns, constraints, explicit anon/authenticated grants, RLS and triggers for `groomer_availability_windows`, `groomer_booking_preferences`, and `groomer_time_off_windows`. All three have RLS enabled (not forced), authenticated CRUD grants, and owner/non-anonymous/groomer-role policies. No explicit anon grants appeared in the inspected view; this is not a negative authorization execution test.
- Weekly windows are unique per groomer/weekday and require start before end; weekdays are 1...7. Preferences constrain daily maximum to 1...12 and notice to 0...2 days. Time off uses inclusive date bounds with start <= end. These tables have row timestamps but no aggregate schedule revision column.
- Each row mutation invoked `app_private.backfill_matches_after_groomer_availability_change`, which called `backfill_request_matches_for_groomer` with batch size 250. The inspected backfill selected open/unexpired requests with no existing match and used request-row `SKIP LOCKED`; it did not re-evaluate existing matches. This motivated WP-01's handling of intermediate transaction states and repeated trigger work, rather than transaction wrapping alone.
- Inspected `app_private.accept_groomer_offer` and `groomer_is_available_for_range`. Acceptance locks offer/request/match rows before taking the groomer advisory transaction lock (hash seed 71071), then rechecks availability. Save/acceptance lock ordering and existing direct table writers require explicit treatment; a new Save-only lock cannot protect old writers automatically.
- No application data was selected and no application mutation, migration, RPC execution, authorization scenario, or concurrency test was performed in this inspection. It established definitions, not runtime correctness. Its former WP-01 validation gaps were subsequently closed by the T-371 acceptance above; later timing and final compatibility evidence belongs to T-374 and T-385.

Use the smallest source that answers the task:

1. This file for project boundary, deployed-scope summary, and backend guardrails.
2. `AUTH_EMAIL_DEEP_LINK_DESIGN.md` for production Auth email, SMTP, redirect URL, and iOS callback design.
3. `MIGRATION_RULES.md` for CLI, migration, repair, credential, and remote-write workflow.
4. `RLS_RPC_POLICY.md` for RLS, grants, controlled RPC, access matrix, and required negative-test policy.
5. `STORAGE_POLICY.md` for bucket visibility, object path, and client Storage safety.
6. `INDEX_EVIDENCE_AUDIT.md` for the current performance-advisor index disposition.
7. `../../supabase/migrations/` for exact SQL, constraints, policies, grants, functions, and migration order.
8. The frozen pre-trim contract only when historical comparison or recovery requires the old long-form narrative.

Do not read this file as proof that a future object is deployed. A deployed claim must match local migrations and, for remote work, verified linked project metadata.

## Address Location Contract

T-296/Q-108 deployed the private PostGIS contract. T-299/Q-111 deployed service-role-only list/snapshot-checked atomic backfill/summary RPCs plus exact-tag TestOps location cleanup. T-300/Q-112 removed the temporary text fallback after re-proving zero active gaps. Linked history is aligned and a repeat dry-run reports the remote database up to date.

The deployed contract enables PostGIS in `extensions`, stores exact Apple Maps coordinates and optional Place IDs only in `app_private.address_locations`, adds opaque location references plus Address Line 2 snapshots, and exposes owner-checked profile read/write wrappers. The coordinate-era `create_grooming_request_v3` binds one private operation UUID to one Request and replays the original Request ID/match count on retry. Current discovery publication uses `publish_request_with_distribution_v1`; timing and retained legacy paths use their versioned endpoints subject to the T-399 rollout/retirement rules above. Historical v2 compatibility is not an assurance that new legacy publication remains enabled. Matching requires both private coordinates, uses Customer travel radius for `customer_comes_to_groomer` and Groomer service radius for `groomer_comes_to_customer`, and never uses state/city text as an eligibility fallback. The pre-coordinate `create_grooming_request` endpoint remains present only for migration-history compatibility and has no client execute grant.

Authenticated clients receive no direct table privileges on private address locations. Exact coordinates and full Place IDs are returned only through current-owner profile RPCs. Strict-cutover runtime verification is `../06_tasks/sql_reviews/T-300_STRICT_COORDINATE_ROLLBACK_VALIDATION.sql`; static coverage is `../../tests/migrations/strict-coordinate-cutover.test.mjs`.

The controlled backfill linked 51 Groomers, 50 Customers, and 1 active Request. One Customer support ref remains a reviewed ZIP-conflict exception; Groomer and active Request gaps, incomplete active targets, orphan legacy/TestOps locations, and tagged TestOps Requests are zero. The six-case `matching_radius` matrix verifies near/edge/outside behavior in both service directions. Operational usage is `../04_ios/ADDRESS_BACKFILL.md`; durable evidence is `../04_ios/testops/runs/T-299_ADDRESS_BACKFILL_RADIUS.md`.

## Matching Contract - T-390

T-390 baseline verified 2026-09-12: 107 aligned migrations through `20260912144522_t390_enable_matching_ranking.sql`, empty repeat dry run, matching-v1 enabled and private validation cohort empty. Later amendments are identified below; this historical count does not replace the latest linked-history verification in Current Status. Unrelated evidence keeps its original scope. [Acceptance and limits](../04_ios/testops/T-390_MATCHING_RATING_ACCEPTANCE.md).

- Service species are explicitly confirmed. Unknown weight/size/coat/matting are not invented; the T-406 `save_my_pet_v3` entry reuses private v2 fact/provenance validation without exposing the old writer. `create_groomer_offer_v3` requires applicable unknown-fact confirmations and binds a service configuration/revision. Compatible offer v2 calls cannot bypass confirmations or locked admission.
- `get_booking_review_context` exposes the owning customer's frozen review context. Verified completion retains eligible service keys; a confirmed appointment elapsed past the later of service-zone midnight and scheduled end (except unresolved reported outcomes) permits a review with empty `elapsed_unverified` keys. Elapsed time does not complete fulfillment or generate professional evidence. The client's 14-day active reminder is not a server review deadline. `create_review_v2` validates context revision and answers. Public stars use exact integer sum/count; private professional evidence uses trusted service time and independently bounded customer influence. Claims/portfolio do not raise evidence scores; missing and negative answers remain distinct.
- `get_ranked_matched_requests` and `get_ranked_customer_offers` rank the complete authorized candidate set before paging. Signed cursors bind actor, role, scope, mode, source revision and score clock. Changed/expired pages return list_changed; a soft arithmetic failure uses independent fallback ranking without changing quote/acceptance eligibility.
- T-391 page revisions hash visible payloads, ordering keys and hard eligibility state, not unused raw scores or soft-worker metadata. A star-only change does not interrupt groomer paging when its displayed evidence/order are unchanged; customer-visible ratings still invalidate customer pages. Soft updates that actually change displayed professional evidence still invalidate. Hard events, candidate membership, authorization and quote validation remain authoritative.
- T-392 adds POST `get_ranked_matched_requests_v2` / `get_ranked_customer_offers_v2`: one browse freezes only soft scores, explanations and rating aggregates for at most five minutes, shortened by live deadlines. Every page rechecks current role, ownership, hard facts and membership; account anonymization invalidates old snapshots immediately. Private entries are capped at256KiB and32 per viewer, pruned in bounded minute batches; oversized pools retain strict legacy consistency without truncation. Legacy stable RPCs/cursors remain unchanged. Migration `20260915233821` and the CA-14/CA-16 corrections are deployed; final history has 111 aligned versions. T-392 passed all 60 client cases, 80 first-attempt browses, original latency budgets and exact restoration; see [T-392 acceptance](../04_ios/testops/T-392_CLIENT_ACCEPTANCE.md).
- CA-14 batches timezone-name validation across quote admission and both ranked read versions. Only private, owner-callable overloads accept the statement-local server catalog; public signatures, freshness, capacity/conflict checks, scoring and cursor semantics are unchanged. No persisted timezone cache or client-supplied validation is introduced.
- CA-16 retains an optimistic opening interval for `service_details_unconfirmed` assessments. Only interval-backed assessments share the existing expiry/service-start/advance-notice proof deadline; unknown facts and required confirmations remain unchanged, other assessments retain the60-second fallback, and hard-event invalidation/final admission remain authoritative.
- Hard-source events and expiring feasible-interval proofs share the existing bounded worker. Soft evidence/rating/display events do not repeat schedule analysis. Cancellation, release and dismissal retain their transaction semantics; local sort preferences are explicit and account/role/page scoped.
- Account anonymization clears matching/review-derived personal evidence, retains anonymous commercial facts, and uses bounded rollback/retry for source-lock contention. Auth/Storage deletion boundaries are unchanged. No new private score, signing secret or exact coordinate is exposed to clients.

## Product Contract

The backend implements the request-first marketplace model:

```text
Customer publishes an open grooming request
-> eligible groomers receive matches
-> groomers submit offers
-> customer accepts one offer
-> booking is created and its participant-pair conversation is reused or created
-> groomer completes booking
-> customer leaves one review
```

The client must not bypass this lifecycle with direct multi-row writes, direct booking creation, local match calculation, or fixture-backed production success.

## Deployed Scope Summary

Core deployed data areas:

- Profiles and role markers: `profiles`, `customer_profiles`, `groomer_profiles`.
- Customer pet data: `pets`, `pet_photos`, fixed taxonomy, weight-derived size, nullable coat type, and private pet photo objects.
- Groomer marketplace data: services, portfolio photos, availability windows, booking preferences, time off windows, fit claims, and portfolio fit tags.
- Request lifecycle: grooming requests, request photos, request matches, groomer offers, bookings, participant-pair conversations, typed text/booking-card messages, reviews, and structured pet-fit outcomes.
- Pet-fit matching: private verified-service evidence, exact public rating aggregates, structured explanations including negative/unknown feedback, complete-set ranking and signed pagination, availability-aware eligibility and request day-capacity matching. The T-390 section above owns current matching semantics.
- Address matching: PostGIS, private exact location rows, opaque profile/request references, owner profile address RPCs, coordinate Request v2, direction-correct radius scoring, and strict missing-coordinate exclusion.
- Customer/groomer operational state: `customer_notifications`, `groomer_notifications`, `customer_booking_handoff_acknowledgements`, `customer_push_tokens`, and `account_deletion_requests`.
- Automation: request-expiry cron job, match backfill triggers for groomer activation/availability changes, customer/groomer notification triggers, and account-deletion service-role finalization RPCs.
- Storage buckets: legacy `avatars`, dedicated `groomer-avatars`, dedicated `customer-avatars`, `pet-photos`, `groomer-portfolio`, and `request-photos`. `chat-attachments` remains deferred.
- Edge Functions: `delete-account` version 2 is deployed with JWT verification and service-role Storage API cleanup before Auth soft deletion; `dispatch-customer-push-notifications` source exists but is not deployed until APNs secrets are available.
- Auth email/deep-link design is documented in `AUTH_EMAIL_DEEP_LINK_DESIGN.md`; hosted Site URL/redirect allow list and custom SMTP sender use Beckon. Supabase-generated email/device smoke, HTTPS Universal Links, and associated domains remain release work.

Controlled public RPCs currently include:

- `get_groomer_availability`
- `save_groomer_availability`
- `save_my_pet_v3`
- `create_my_profile`
- `publish_request_with_distribution_v1`
- `create_grooming_request_v3`
- `get_my_customer_profile_address_v2`
- `save_customer_profile_address_v2`
- `get_my_groomer_profile_address_v2`
- `save_groomer_profile_address_v2`
- `cancel_grooming_request`
- `dismiss_request_match`
- `create_groomer_offer`
- `withdraw_groomer_offer`
- `accept_groomer_offer`
- `cancel_booking`
- `complete_booking`
- `create_review`
- `get_my_groomer_pet_fit_evidence_summary`
- `mark_customer_notification_read`
- `mark_all_customer_notifications_read`
- `mark_groomer_notification_read`
- `mark_all_groomer_notifications_read`
- `get_acknowledged_booking_handoff_request_ids`
- `acknowledge_booking_handoff`
- `register_customer_push_token`
- `unregister_customer_push_token`
- `request_account_deletion`

Service-role controlled RPCs currently include:

- `claim_customer_push_notifications`
- `record_customer_push_delivery`
- `record_account_deletion_auth_soft_deleted`
- `record_account_deletion_failure`

Exact signatures, grants, error behavior, table constraints, and policy predicates belong to the owning migrations and `RLS_RPC_POLICY.md`.

## Backend Guardrails

T-371 HTTP conflict correction: the public Save wrapper maps only `availability_revision_conflict` from private SQLSTATE `40001` to `PT409`. Permanent revision conflicts must not trigger PostgREST transaction retries. Concurrent real HTTP submissions initially timed out and required guarded fixture recovery; after the corrective migration, exactly one request succeeded and one returned HTTP 409/PT409, and exact original rows/revision plus booking/match hashes were restored. The opt-in runner is `../../scripts/test-t371-availability-race.mjs`; separate Save/acceptance evidence is recorded in T-371 acceptance, with both later admission/Save lock orderings and exact restoration in [T-374 acceptance](../06_tasks/sql_reviews/T-374_TIMING_BACKEND_ACCEPTANCE.md).

- Supabase Auth supplies identity; app role and ownership come from application tables.
- iOS uses only publishable client configuration. Secret, service-role, project secret, database password, and CLI PAT values must never be embedded in Swift, tracked docs, logs, artifacts, or committed config.
- Repositories and services own Supabase queries, RPC calls, and uploads. SwiftUI views must not call Supabase directly.
- RLS and explicit Data API grants must both be reviewed for every exposed table or function.
- Multi-row writes, status transitions, ownership checks, limits, conflict protection, and server-owned match/review calculations use controlled RPCs.
- Linked Supabase CLI commands must run sequentially. Do not parallelize linked migration, push, query, or advisor commands.
- Keep CLI telemetry disabled (`supabase telemetry disable`) and set `SUPABASE_TELEMETRY_DISABLED=1` in scripted invocations; this prevents shared telemetry-file races when an unrelated CLI process is already active.
- Remote DDL, migration repair, seed execution, cleanup, destructive operations, and remote writes require explicit user authorization.
- `supabase_api_key` / `SUPABASE_SECRET_KEY=sb_secret_...` is not a CLI PAT, not the remote DB password, and not a JWT-shaped service-role key. TestOps and the T-248 identity cutover runner have an explicit `apikey`-only server credential path for `sb_secret_...`; scripts that send service credentials as Bearer auth still need a compatible legacy JWT-shaped service-role key unless explicitly updated.
- The legacy project ref is never a schema, data, migration, or verification source for this rebuild.

## Update Rules

When backend behavior changes:

- Update local migrations and the active backend contract docs in the same task before closeout; verify the linked project according to `MIGRATION_RULES.md` before claiming remote deployment.
- Update this file only for changed deployed scope, guardrails, or source-of-truth routing.
- Update `RLS_RPC_POLICY.md` for access, grants, function security, or negative-test changes.
- Update `STORAGE_POLICY.md` for bucket, object path, MIME/size, or Storage policy changes.
- Update `docs/07_decisions/DECISION_LOG.md` only for durable architecture/product decisions.
- Keep long migration narratives out of this file; use task closeout, worklog, migrations, and frozen archives for trace detail.
