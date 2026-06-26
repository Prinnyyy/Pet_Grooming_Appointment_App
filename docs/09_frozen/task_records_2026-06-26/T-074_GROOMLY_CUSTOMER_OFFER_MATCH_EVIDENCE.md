# T-074 Groomly Customer Offer Match Evidence

## Status

Completed on 2026-06-25.

## Mode

Deep. This task changes Supabase RLS and customer-facing iOS offer review behavior.

## Goal

Surface existing backend-generated match score/reason evidence in customer offer review only for offers already visible to the owning customer.

## Scope

In scope:

- Add a narrow `request_matches` SELECT policy for authenticated non-anonymous customers.
- Allow customer access only when the match belongs to that customer and has a linked `groomer_offers` row for the same request, match, customer, and groomer.
- Extend `CustomerOfferReview` with optional backend match score/reason presentation.
- Load match evidence in `SupabaseCustomerRequestRepository.offers(...)` through existing repository boundaries.
- Show fit evidence in customer offer summary rows and offer detail.

Out of scope:

- Public groomer directory browsing.
- Customer slot discovery or direct booking.
- New matching, scoring, or claim/portfolio weighting behavior.
- New RPC signatures, tables, Storage policies, or client-authored match evidence.
- Backfilling existing match rows.

## Validation Plan

1. RED rollback-only remote SQL: prove an owning customer cannot read an already offered `request_matches` row before the new policy.
2. Apply the RLS migration and record the migration version.
3. GREEN rollback-only remote SQL:
   - owning customer can read only the offered match evidence;
   - owning customer cannot read an unoffered same-request match;
   - other customer cannot read the first customer's offered match;
   - groomer own-match SELECT policy still works;
   - anonymous authenticated JWT remains denied;
   - validation data rolls back.
4. Metadata/policy check for `request_matches`.
5. Security/performance advisors and `./scripts/supabase-check.sh`.
6. RED/GREEN targeted Swift tests for customer offer evidence presentation.
7. `git diff --check`, `./scripts/ios-build.sh`, and simulator launch because customer offer review UI changes.

## Implementation Summary

- Added local migration `supabase/migrations/20260625085126_t074_customer_offer_match_evidence.sql`.
- Applied the SQL to project `lqmasbuqzvcvtawonjlb` with `supabase db query --linked --file`, then marked the same version applied with `supabase migration repair --linked --status applied 20260625085126`.
- Added corrective migration `supabase/migrations/20260625090429_t074_merge_request_match_select_policies.sql` after the performance advisor identified two authenticated permissive SELECT policies on `request_matches`.
- Applied and repaired `20260625090429`, replacing `request_matches_select_customer_offered` and `request_matches_select_groomer_own` with one merged `request_matches_select_groomer_or_customer_offered` policy that preserves both access paths.
- Added `CustomerOfferFitPresentation` and `CustomerOfferReview.fitEvidencePresentation`.
- Updated customer offer loading to batch-read `request_matches(id, match_score, match_reason)` for offer `match_id` values behind the new RLS policy.
- Added customer-accent fit evidence blocks to offer summary rows and offer detail.
- Preserved match evidence during local offer status updates after acceptance/cancellation.

## Validation

- RED rollback-only remote SQL failed as expected before migration: the customer could not read the offered match evidence row and got 0 rows.
- RED residue check returned zero validation users.
- Remote migration SQL application passed for `20260625085126_t074_customer_offer_match_evidence`.
- Corrective migration SQL application and migration repair passed for `20260625090429_t074_merge_request_match_select_policies`.
- `supabase migration list --linked` confirmed both T-074 migration versions are present locally and remotely.
- GREEN rollback-only remote SQL passed after the merged policy for offered-match visibility, unoffered-match denial, cross-customer denial, groomer own-match visibility, anonymous-authenticated denial, and rollback cleanup.
- Metadata check confirmed `request_matches` has one authenticated SELECT policy: `request_matches_select_groomer_or_customer_offered`.
- Validation residue check returned zero `t074-red-%`/`t074-green-%` auth users.
- Supabase performance advisor passed with no issues after the corrective migration.
- Supabase security advisor reported only existing project warnings for intentional authenticated `SECURITY DEFINER` RPCs and leaked password protection; T-074 added no function.
- `./scripts/supabase-check.sh` passed.
- GREEN targeted Swift tests passed:
  - `PetGroomerMarketplaceTests/CustomerRequestsStoreTests/offerReviewFitEvidencePresentationUsesBackendReasonAndRoundedScore`
  - `PetGroomerMarketplaceTests/CustomerRequestsStoreTests/offerReviewFitEvidencePresentationIgnoresBlankReason`
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17 Pro` iOS 26.5 simulator and launched `com.prinnyyy.PetGroomerMarketplace` with pid `33312`.
- XcodeBuildMCP diagnostics still reported existing Swift concurrency warnings in `GroomerProfileManagementView.swift:806`; T-074 did not touch that surface.

## Risks and Non-Goals

- Customer offer review now depends on the T-074 merged `request_matches` SELECT policy for optional match evidence. If a match row is not visible or lacks reason text, offer review still loads without evidence UI.
- Match evidence remains backend-generated. The iOS client displays score/reason only; it does not calculate or author match quality.
- The new customer policy exposes only matches that already have an offer linked to the owning customer's request. It does not expose unmatched groomers, unoffered matches, or a public directory.
