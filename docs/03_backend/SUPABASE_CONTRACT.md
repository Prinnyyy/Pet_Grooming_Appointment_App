# Supabase Contract

Last verified: 2026-07-11 (T-300 strict coordinate cutover and integration gate).

This is the active fast-path backend contract. It records current authoritative facts and points to the right detailed source instead of embedding every historical table, RPC, Storage, and migration note.

Full pre-trim contract text is archived at `../09_frozen/backend_contracts/SUPABASE_CONTRACT_2026-07-01_PRE_FAST_PATH_TRIM.md`.

## Current Status

- Authorized fresh project: `Beckon`, ref `lqmasbuqzvcvtawonjlb`, organization `Prinnyyy`, region `us-west-1`.
- Forbidden legacy project: `Prinnyyy's Project`, ref `swdiiyypysyxbnfrxxsv`. Do not inspect, branch, migrate, reset, or mutate it for this rebuild.
- Remote verification baseline: linked history aligns through `20260712044858_t300_strict_coordinate_matching.sql` after strict helper, privacy, lifecycle, baseline/radius matching, cleanup, and advisor verification.
- Local CLI readiness baseline: T-139 confirmed sequential `supabase projects list`, `supabase migration list --linked`, and `supabase db push --linked --dry-run` work from this checkout without `SUPABASE_DB_PASSWORD`.
- Local migration mirror: `../../supabase/migrations/` is the append-only source for applied and prepared migrations. Local migration mirror count: 67 files. Do not rename or hand-invent migration filenames.
- Full historical contract detail before this fast-path trim is frozen for comparison only. Current implementation truth comes from migrations plus focused active backend policy files.

## Read Order

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

The deployed contract enables PostGIS in `extensions`, stores exact Apple Maps coordinates and optional Place IDs only in `app_private.address_locations`, adds opaque location references plus Address Line 2 snapshots, and exposes owner-checked profile read/write wrappers and `create_grooming_request_v2`. Matching requires both private coordinates, uses Customer travel radius for `customer_comes_to_groomer` and Groomer service radius for `groomer_comes_to_customer`, and never uses state/city text as an eligibility fallback. The pre-coordinate `create_grooming_request` endpoint remains present only for migration-history compatibility and has no client execute grant.

Authenticated clients receive no direct table privileges on private address locations. Exact coordinates and full Place IDs are returned only through current-owner profile RPCs. Strict-cutover runtime verification is `../06_tasks/sql_reviews/T-300_STRICT_COORDINATE_ROLLBACK_VALIDATION.sql`; static coverage is `../../tests/migrations/strict-coordinate-cutover.test.mjs`.

The controlled backfill linked 51 Groomers, 50 Customers, and 1 active Request. One Customer support ref remains a reviewed ZIP-conflict exception; Groomer and active Request gaps, incomplete active targets, orphan legacy/TestOps locations, and tagged TestOps Requests are zero. The six-case `matching_radius` matrix verifies near/edge/outside behavior in both service directions. Operational usage is `../04_ios/ADDRESS_BACKFILL.md`; durable evidence is `../04_ios/testops/runs/T-299_ADDRESS_BACKFILL_RADIUS.md`.

## Product Contract

The backend implements the request-first marketplace model:

```text
Customer publishes an open grooming request
-> eligible groomers receive matches
-> groomers submit offers
-> customer accepts one offer
-> booking and participant conversation are created
-> groomer completes booking
-> customer leaves one review
```

The client must not bypass this lifecycle with direct multi-row writes, direct booking creation, local match calculation, or fixture-backed production success.

## Deployed Scope Summary

Core deployed data areas:

- Profiles and role markers: `profiles`, `customer_profiles`, `groomer_profiles`.
- Customer pet data: `pets`, `pet_photos`, fixed taxonomy, weight-derived size, nullable coat type, and private pet photo objects.
- Groomer marketplace data: services, portfolio photos, availability windows, booking preferences, time off windows, fit claims, and portfolio fit tags.
- Request lifecycle: grooming requests, request photos, request matches, groomer offers, bookings, conversations, text messages, reviews, and structured pet-fit outcomes.
- Pet-fit matching: private SQL helper functions, evidence summary view, match scoring/reason text, claim/tag low-confidence signals, negative-evidence suppression, availability-aware matching, and request day-capacity matching.
- Address matching: PostGIS, private exact location rows, opaque profile/request references, owner profile address RPCs, coordinate Request v2, direction-correct radius scoring, and strict missing-coordinate exclusion.
- Customer/groomer operational state: `customer_notifications`, `groomer_notifications`, `customer_booking_handoff_acknowledgements`, `customer_push_tokens`, and `account_deletion_requests`.
- Automation: request-expiry cron job, match backfill triggers for groomer activation/availability changes, customer/groomer notification triggers, and account-deletion service-role finalization RPCs.
- Storage buckets: legacy `avatars`, dedicated `groomer-avatars`, dedicated `customer-avatars`, `pet-photos`, `groomer-portfolio`, and `request-photos`. `chat-attachments` remains deferred.
- Edge Functions: `delete-account` version 2 is deployed with JWT verification and service-role Storage API cleanup before Auth soft deletion; `dispatch-customer-push-notifications` source exists but is not deployed until APNs secrets are available.
- Auth email/deep-link design is documented in `AUTH_EMAIL_DEEP_LINK_DESIGN.md`; hosted Site URL/redirect allow list and custom SMTP sender use Beckon. Supabase-generated email/device smoke, HTTPS Universal Links, and associated domains remain release work.

Controlled public RPCs currently include:

- `create_my_profile`
- `create_grooming_request_v2`
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
