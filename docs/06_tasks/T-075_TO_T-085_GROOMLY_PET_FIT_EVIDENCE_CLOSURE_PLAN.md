# Groomly Pet-Fit Evidence Closure Implementation Plan

> **For agentic workers:** REQUIRED WORKFLOW: Use the lightweight single-agent workflow in `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`. Implement only one primary task per run. Do not use subagents unless the user explicitly re-enables them.

**Goal:** Complete the pet-fit matching evidence loop without changing Groomly into a public groomer directory, direct-booking calendar, ML recommender, or payment product.

**Architecture:** Keep the current request-first marketplace flow: customer publishes a request, eligible groomers receive matches, groomers submit offers, and customers confirm one offer into a booking. The next work should make the evidence loop real: clean pet input data, collect structured customer outcomes, let groomers manage low-confidence starter signals, calibrate match scoring, and present explanations without implying that match score is a groomer ability percentage.

**Tech Stack:** SwiftUI, Observation stores, repository-backed Supabase access, Supabase Postgres migrations, RLS, RPCs, rollback-only SQL validation, `./scripts/ios-build.sh`, targeted Swift tests.

---

## Status

- Status: active sequence; completed through T-082; T-083+ not started
- Date: 2026-06-26
- Current completed pet-fit baseline: T-063 through T-082 and T-081A, plus user-authorized T-050 remote deployment.
- Next executable task: none active; T-083+ requires an explicit user request/authorization.

## Product Guardrails

- Keep `Open Request -> Groomer Offer -> Customer Confirmation -> Booking`.
- Do not add public groomer browsing, direct slot booking, auto-accept, payments, or ML ranking.
- Treat groomer claims and portfolio tags as low-confidence starter signals only.
- Treat completed bookings and structured customer review outcomes as the evidence-backed source.
- Do not expose raw `match_score` as an ability percentage. Prefer short fit explanations and confidence wording.
- Remote Supabase schema writes require explicit user approval for project `lqmasbuqzvcvtawonjlb`.

## Current Grounding

- T-050 iOS pet taxonomy is complete, and its hardened Supabase pet data contract migration is remotely deployed.
- T-066 groomer fit claims and portfolio tags are deployed and consumed by matching. T-079 adds iOS owner management UI for groomer fit claims, and T-080 adds iOS owner management UI for portfolio fit tags.
- T-067 structured review outcomes are deployed, and T-078 now lets iOS submit optional outcomes through the existing review RPC.
- T-068 evidence summary exists as a read-only aggregate view.
- T-073 scoring uses evidence, claims, and portfolio signals. Claims and portfolio tags are capped at low weight.
- T-074 lets customers see backend match evidence only for visible offered matches.
- T-076 adds a pure Swift canonical signal vocabulary for T-065 trait pairs, now reused by T-078 review submission, T-079 groomer claim management, and T-080 portfolio tag management.
- T-077 enriches bookings with existing request pet snapshot context and derives completed-booking reviewable signals.
- T-078 extends iOS review submission so selected positive/negative outcomes are sent as `p_pet_fit_outcomes`, while empty outcomes and rating/content-only reviews remain valid. No Supabase schema change was made.
- T-079 adds a Groomer Account Fit Signals page that manages bounded owner-claimed signals through existing `groomer_fit_claims` table access behind `GroomerProfileRepository`. No Supabase schema change was made.
- T-080 adds per-photo Portfolio fit tag management through existing `groomer_portfolio_fit_tags` table access behind `GroomerProfileRepository`. No Supabase schema change was made.
- T-081A adds the owner-readable aggregate RPC `get_my_groomer_pet_fit_evidence_summary()` so Groomer Account can read completed-booking and structured-review aggregate evidence without broadening request row RLS or exposing raw customer/pet/request/booking/review details.
- T-081 adds the Groomer Account Evidence Dashboard using the T-081A RPC behind `GroomerProfileRepository`. It shows aggregate counts, structured review outcomes, safe timestamps, and confidence tiers only.
- T-082 calibrates `create_grooming_request` fairness so earned negative evidence is not dropped behind neutral top-three evidence and suppresses low-confidence claim/portfolio boosts when negative evidence exists.

## Task Plan

| Order | Task | Mode | Main Change | Completion Standard |
|---|---|---:|---|---|
| T-075 | Pet Data Contract Remote Hardening | Deep | Repair and validate the local T-050 pet migration before remote deployment, with special attention to authenticated writes and private helper permissions. | Remote pet writes accept only fixed species, breed, temperament, and weight; `size` is derived from weight; rollback checks and advisor checks pass with no validation residue. |
| T-076 | iOS Pet-Fit Signal Vocabulary Bridge | Standard | Add one Swift vocabulary type for canonical pet-fit signals used by claims, portfolio tags, structured reviews, and request previews. | Tests prove Swift signal `trait_type` and `trait_value` values align with deployed SQL constraints for breed group, size band, care flag, and service fit. |
| T-077 | Booking Pet-Fit Context Enrichment | Standard | Extend booking model and repository enrichment so completed bookings expose the pet snapshot context needed for structured review suggestions. | Booking detail can derive reviewable signals from the booking request pet snapshot without adding schema or direct Supabase access in views. |
| T-078 | Structured Review iOS Submission | Standard | Extend `BookingReviewDraft`, `BookingsStore`, Supabase encoding, and review UI to submit optional `p_pet_fit_outcomes`. | Rating/content-only reviews still work; selected positive/negative outcomes are sent through `create_review`; empty outcomes are valid. |
| T-079 | Groomer Claimed Fit Signals UI | Standard | Add groomer-owned fit claim loading and saving through `GroomerProfileRepository` and a dedicated Account page. | Groomers can activate/deactivate a small bounded set of claims; UI copy frames claims as starter signals, not expert verification. |
| T-080 | Portfolio Fit Tags UI | Standard | Add owner-managed fit tags for existing portfolio photos through the profile repository and Portfolio page. | Groomers can add/remove up to a bounded number of tags per photo; deleting a photo keeps relying on the existing FK cascade. |
| T-081A | Evidence Dashboard Owner Visibility Backend | Deep | Create a safe owner-readable aggregate evidence contract for Groomer Account without exposing raw customer, pet, request, booking, or review details. | Completed: rollback-only checks prove groomers can read only their own aggregate evidence, cross-owner/customer reads are denied, advisors ran, and no raw private details are returned. |
| T-081 | Groomer Evidence Dashboard | Standard | Surface earned evidence from the T-081A owner aggregate RPC in Groomer Account. | Completed: groomers can see aggregate completed counts, review outcomes, and confidence tiers without customer or pet private details. |
| T-082 | Matching Fairness And Calibration | Deep | Run rollback SQL scenarios and adjust `create_grooming_request` internals only if needed to preserve fair distribution and low claim weight. | Completed: negative earned evidence is prioritized in the evidence set and suppresses low-confidence claim/portfolio boosts while eligible new, claim-only, portfolio-only, and positive evidence groomers still match; RPC signature and grants remain unchanged. |
| T-083 | Score Display De-Emphasis | Standard | Replace raw score-heavy UI copy in groomer request and customer offer surfaces with explanation-first fit evidence wording. | UI no longer reads like `94 match` as an ability percentage; tests cover reason trimming, blank reason hiding, and new copy. |
| T-084 | Pet-Fit End-To-End Validation Scenario | Deep | Validate the full evidence loop with rollback-only SQL: request, match, offer, booking, completion, structured review, next request. | Evidence from the first completed booking changes the next matching reason as expected while RLS and visibility boundaries still hold. |
| T-085 | Request Fit Input Preview | Standard | Show customers the derived pet-fit needs on the request review step before publishing. | Customers can see the app's interpreted needs such as terrier coat, gentle handling, or senior care before submit; no new backend field is added. |

## Task Details

### T-075: Pet Data Contract Remote Hardening

**Primary files:**
- `supabase/migrations/20260623013113_t050_pet_fixed_taxonomy_derived_size.sql`
- `docs/06_tasks/T-075_GROOMLY_PET_DATA_CONTRACT_REMOTE_HARDENING.md`
- backend contract and RLS docs only if deployment changes remote behavior

**Execution notes:**
- Start with rollback or dry validation against the current linked project.
- Check whether `pets_size_derived_from_weight_check` or `pets_derive_size_from_weight` would require authenticated callers to execute private `app_private` helpers.
- If the migration needs correction, keep the trigger/helper permission model explicit and avoid exposing unrelated private helpers.
- Remote apply must stop for explicit user authorization.

**Validation:**
- Metadata checks for constraints, trigger, grants, and bucket settings.
- Rollback-only authenticated insert/update cases for valid pets, invalid species, invalid breed, invalid temperament, out-of-range weight, and derived size.
- `./scripts/supabase-check.sh`
- `git diff --check`

### T-076: iOS Pet-Fit Signal Vocabulary Bridge

**Primary files:**
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomingRequestTaxonomy.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/PetFitTaxonomyTests.swift`

**Execution notes:**
- Add a small `PetFitSignal` value type or enum-backed struct with `traitType`, `traitValue`, `title`, and grouping metadata.
- Reuse existing `PetBreedGroup`, `PetCareFlag`, `PetFitTrait`, `CustomerPetSizeCode`, and `GroomingServiceType`.
- Keep it pure Swift with no repository or UI dependency.

**Validation:**
- Targeted taxonomy tests.
- `git diff --check`
- `./scripts/ios-build.sh`

### T-077: Booking Pet-Fit Context Enrichment

**Primary files:**
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Booking.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/BookingFeatureTests.swift`

**Execution notes:**
- Enrich bookings from the existing related request data path, not from views.
- Add optional pet snapshot fields or a compact request context object to `Booking`.
- Derive `reviewableFitSignals` in the model layer using T-076 vocabulary.

**Validation:**
- Targeted booking tests for signal derivation from poodle, terrier, anxious, senior, and size contexts.
- `git diff --check`
- `./scripts/ios-build.sh`

### T-078: Structured Review iOS Submission

**Primary files:**
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/Booking.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`

**Execution notes:**
- Extend `BookingReviewDraft` with optional structured outcomes.
- Encode the Supabase RPC parameter as `p_pet_fit_outcomes`.
- Review UI should default every suggested signal to no structured outcome. Customers actively choose positive or negative only when confident.
- Do not display outcomes as public accusations or certifications.

**Validation:**
- Targeted Store/repository encoding tests.
- UI presentation tests for empty outcomes and selected outcomes.
- `git diff --check`
- `./scripts/ios-build.sh`
- Simulator launch because review UI changes.

### T-079: Groomer Claimed Fit Signals UI

**Primary files:**
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerProfile.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/GroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`

**Execution notes:**
- Use direct table access behind the repository boundary for `groomer_fit_claims`.
- Bound active claims in the client to avoid "select everything" behavior.
- Prefer service-fit and breed/care signals in UI. Size claims can be lower priority to avoid noisy self-labeling.
- Copy must say signals help route relevant requests and are improved by completed bookings and reviews.

**Validation:**
- Targeted `GroomerProfileStore` tests for load, save, inactive toggling, and limit enforcement.
- `git diff --check`
- `./scripts/ios-build.sh`
- Simulator launch because Account UI changes.

### T-080: Portfolio Fit Tags UI

**Primary files:**
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerProfile.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`

**Execution notes:**
- Load tags grouped by portfolio photo ID.
- Save tags for one photo at a time to keep updates small and recoverable.
- Keep photo upload and Storage behavior unchanged.
- Do not make portfolio tags visible to customers outside match reasons unless a later customer profile surface is explicitly designed.

**Validation:**
- Targeted store tests for per-photo load, add, remove, and delete-photo local cleanup.
- `git diff --check`
- `./scripts/ios-build.sh`
- Simulator launch because Portfolio UI changes.

### T-081: Groomer Evidence Dashboard

**Primary files:**
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerProfile.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/GroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseGroomerProfileRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`

**Backend prerequisite:**
- T-081A created `get_my_groomer_pet_fit_evidence_summary()` as the safe owner-readable aggregate backend contract. The original direct `security_invoker` view is still correctly constrained by underlying RLS, so the iOS dashboard should use the RPC for owner completed-booking evidence.

**Completion notes:**
- `GroomerProfileRepository` now exposes `petFitEvidenceSummary(groomerID:)`.
- The Supabase adapter queries `get_my_groomer_pet_fit_evidence_summary()` through `.rpc(...)`.
- The Store filters and sorts canonical aggregate rows for the active groomer.
- The Account `Evidence Dashboard` page shows only aggregate counts, confidence tiers, and safe timestamps.
- SwiftUI and repositories do not direct-read private request, pet, booking, review, or snapshot data for this dashboard.

**Validation:**
- RED/GREEN targeted Store test.
- Focused `GroomerProfileStoreTests`.
- `git diff --check`.
- `./scripts/ios-build.sh`.
- XcodeBuildMCP simulator launch and Account -> Evidence Dashboard UI snapshots.

### T-082: Matching Fairness And Calibration

**Primary files:**
- `supabase/migrations/20260626033330_t082_matching_fairness_calibration.sql`
- `docs/06_tasks/T-082_GROOMLY_MATCHING_FAIRNESS_AND_CALIBRATION.md`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`

**Execution notes:**
- First run rollback-only scenarios against the current scoring behavior.
- Preserve all hard filters: active profile, service location, city/state eligibility, active fixed service, and availability.
- Keep claims and portfolio signals capped and weaker than earned evidence.
- Do not change RPC signature, result shape, grants, or request lifecycle.

**Validation:**
- Rollback SQL for new groomer with no evidence, claim-only groomer, portfolio-only groomer, positive evidence-backed groomer, and negative-review evidence.
- Metadata/grant checks for `create_grooming_request`.
- Supabase advisors and `./scripts/supabase-check.sh`.
- `git diff --check`

**Completion notes:**
- RED rollback-only SQL proved negative poodle feedback could be dropped behind neutral completed-booking rows, letting low-confidence starter signals lift the negative-evidence groomer to `89.00` versus the no-evidence groomer at `80.00`.
- T-082 replaces only `create_grooming_request` internals. Negative evidence is prioritized into the top evidence set, `pet_fit.has_negative_evidence` suppresses claim/portfolio adjustment and reason text, and hard filters/signature/grants remain unchanged.
- GREEN rollback-only validation before and after remote apply returned five matches with scores: no evidence `80.00`, claim-only `83.00`, portfolio-only `86.00`, positive evidence `94.00`, negative evidence `78.00`.
- Metadata/grant checks, zero-residue checks, advisors, `./scripts/supabase-check.sh`, and `git diff --check` passed.

### T-083: Score Display De-Emphasis

**Primary files:**
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/GroomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/CustomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Requests/GroomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`

**Execution notes:**
- Replace score-first display with explanation-first wording.
- Keep backend score available internally, but do not make it read as a public ability grade.
- Suggested labels: `Fit Evidence`, `Location And Service Fit`, `Earned Evidence`, `Starter Signals`.

**Validation:**
- Targeted presentation tests for blank reason, reason trimming, customer offer evidence, and groomer request evidence.
- `git diff --check`
- `./scripts/ios-build.sh`
- Simulator launch because visible UI changes.

### T-084: Pet-Fit End-To-End Validation Scenario

**Primary files:**
- A task doc for the SQL validation run
- optional SQL review artifact under `docs/06_tasks/sql_reviews/` if the validation is long

**Execution notes:**
- Use rollback-only SQL.
- Scenario should prove: pet traits are derived, eligible groomers are matched, an offer can become a booking, completion enables structured review, review outcomes aggregate into evidence summary, and a later equivalent request receives improved match reason text.
- Do not persist validation users, pets, requests, bookings, reviews, claims, or tags.

**Validation:**
- The rollback SQL itself is the primary validation.
- Supabase metadata checks only if the scenario reveals a needed backend change.
- `git diff --check` for documentation artifacts.

### T-085: Request Fit Input Preview

**Primary files:**
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`

**Execution notes:**
- Derive preview signals from the selected pet and selected service during the request wizard Review step.
- Keep it explanatory and editable through existing pet/service fields.
- Do not add backend fields or a new request state.

**Validation:**
- Targeted customer request presentation tests.
- `git diff --check`
- `./scripts/ios-build.sh`
- Simulator launch because request wizard UI changes.

## Cross-Task Acceptance Criteria

- The customer can publish a request without browsing groomer calendars or choosing a public directory profile.
- Groomers receive matches because they satisfy hard filters, not because they gamed self-claims.
- Customers contribute structured evidence only after completed bookings.
- Completed booking evidence improves future explanations.
- New groomers remain able to receive requests and compete through concrete offers.
- UI copy never claims a groomer is verified, expert, or generally better unless that status has a separate approved contract.

## Validation Defaults By Mode

- Quick docs tasks: `git diff --check`.
- Standard Swift tasks: targeted tests when practical, `git diff --check`, `./scripts/ios-build.sh`, and simulator launch for visible UI.
- Deep backend tasks: explicit validation plan, rollback-only SQL first, user authorization before remote schema writes, metadata/grant/RLS checks, advisors, `./scripts/supabase-check.sh`, and `git diff --check`.

## Assumptions

- No next implementation is active; T-083 and later tasks start only when explicitly requested.
- Each listed row is a separate primary task.
- T-075 through T-085 do not authorize remote writes by themselves.
- Existing branch remains `codex/pet-fit-structure-cleanup` unless the user asks for a different branch.
- Existing T-063 through T-082 behavior remains the baseline unless a task explicitly changes it.
