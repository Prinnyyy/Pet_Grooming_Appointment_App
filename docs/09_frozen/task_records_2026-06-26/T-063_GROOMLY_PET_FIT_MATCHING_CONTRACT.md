# T-063 - Groomly Pet-Fit Matching Contract

## Status

Completed.

## Mode

Quick.

## User Request

Implement the first step of the Groomly Pet-Fit Matching bottom-layer plan:

- isolate the existing T-062 worktree state;
- lock product and backend contract direction before schema or Swift implementation;
- keep each future plan row as a separate primary task.

## Scope

- Preserve the current `Open Request -> Groomer Offer -> Customer Confirmation -> Booking` product model.
- Define pet-fit matching v1 as request distribution with explainable fit reasons.
- Explicitly defer public groomer-directory browsing, direct customer slot booking, AI/ML recommendations, payments, and complex calendar behavior.
- Record planned backend objects and RPC replacement points without deploying schema.

## Out of Scope

- Swift model/view/repository changes.
- Supabase migrations, remote MCP writes, RLS changes, RPC changes, Storage changes, or validation data.
- Customer-facing groomer directory, direct booking, payment, or ML recommender work.
- Any edits to the existing T-062 Swift/script changes.

## Implementation Summary

- Updated product docs to define request-first pet-fit matching v1.
- Updated navigation docs to preserve the current customer request -> groomer offer -> customer acceptance flow.
- Updated UX rules to distinguish claimed groomer specialty labels from evidence-backed fit outcomes.
- Updated Supabase contract docs with planned pet-fit objects, planned evidence summary view, and future RPC replacement points.
- Updated durable memory/index docs so future runs know T-064 is the next implementation task.

## Dirty Worktree Boundary

Before T-063 edits, the workspace already contained uncommitted T-062 files:

- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/GroomerTabView.swift`
- `scripts/ios-build.sh`
- `scripts/ios-test.sh`
- `docs/06_tasks/T-062_GROOMLY_GROOMER_SCHEDULE_SCREENSHOT_UI.md`

T-063 intentionally did not modify the Swift or script files. It only added/edited docs needed for the product/backend contract.

## Validation

- `git diff --check`: passed.

## Next

T-064 should add the pure Swift pet-fit taxonomy foundation:

- `PetBreedGroup`
- `PetCareFlag`
- `PetFitTrait`
- `serviceFit`
- focused unit tests for Westie/terrier, poodle/curly coat, anxious care flags, and senior/age handling.
