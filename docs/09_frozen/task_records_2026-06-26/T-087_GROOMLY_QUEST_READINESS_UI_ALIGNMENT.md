# T-087: Groomly Quest Readiness UI Alignment

## Status

- Status: implemented; customer simulator visual inspection blocked
- Date: 2026-06-26
- Mode: Standard
- Branch: `codex/pet-fit-structure-cleanup`

## User Request

Based on the UI/flow audit for the request-first pet-fit marketplace, write a follow-up task that aligns the current customer and groomer UI with the real inputs required to start or receive a quest.

## Primary Task

Align visible customer and groomer UI copy, ordering, and tab availability with the current product contract:

- Customers start a quest by having at least one pet profile and completing the request wizard.
- Groomers receive quests by having an active profile, active services, and availability.
- Fit Signals, Portfolio tags, and Evidence Dashboard improve explanation and matching evidence, but are not hard gates.
- The app remains request-first: no customer direct booking, no public groomer directory, and no separate direct-booking slot surface.

This task is app-visible UI alignment only. It must not change Supabase schema, RLS, RPC contracts, repositories, matching score logic, request lifecycle, offer lifecycle, booking creation semantics, or Storage behavior.

## Audit Findings To Address

1. Customer Home disables `Start Grooming Request` when there are no pets, but the disabled state does not clearly tell the user to add a pet first.
2. The request wizard step is labeled `Time` even though the step also contains required location fields.
3. The Review step says contact details stay hidden, but groomers currently see request location details. The copy should be precise: phone/email stay hidden; location details needed for offering are visible.
4. Groomer Account shows Profile, Services, Portfolio, Fit Signals, Evidence Dashboard, then Availability. This over-emphasizes evidence features before the actual readiness gates.
5. Groomer Availability copy says customers can `find and book you`, and auto-accept copy says `Skip approval during open hours`, which conflicts with the request-first flow.
6. Groomer `Offers` exists as a visible tab but falls into the disconnected placeholder path. Offers are currently managed from the Board/request detail flow, so the visible tab should not imply a separate connected offer inbox.

## Files To Inspect

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
  - Customer Home `Start Grooming Request` card and disabled state.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
  - `CustomerRequestWizardStep` titles/headlines/subtitles and validation.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
  - Wizard step content, Review-step matching/privacy copy, existing Fit Needs preview.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
  - Account menu order, Availability copy, Booking Preferences/auto-accept copy.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/GroomerTab.swift`
  - Groomer tab list/title/image contract.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/GroomerTabView.swift`
  - Visible tab iteration and disconnected placeholder fallback.
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
  - Wizard step title/progression expectations.
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/AppEntryModelsTests.swift`
  - Groomer tab title/order expectations.

## Implementation Plan

### 1. Customer quest start readiness copy

- In `CustomerPetsView.swift`, keep the existing disabled `Start Grooming Request` behavior when `store.pets.isEmpty`.
- Add a small helper/notice near the CTA only when disabled. The text should be direct, for example:
  - `Add a pet profile before starting a grooming request.`
- Do not open the request wizard without a pet.
- Do not change `CustomerPetsStore`, pet validation, repository calls, or backend pet contract.

### 2. Request wizard step label and review copy

- In `CustomerRequestsStore.swift`, rename the `.time` step title from `Time` to `Time & Location`.
- Update the `.time` headline/subtitle so the step explicitly covers both preferred time and location. Suggested copy:
  - Headline: `When and Where Works Best?`
  - Subtitle: `Choose a preferred time and the location details groomers need before making an offer.`
- In `CustomerRequestsView.swift`, keep the existing `timeStep` structure and `locationSection`; only adjust copy/presentation needed for clarity.
- Replace Review-step privacy copy with a precise version. Suggested copy:
  - `Your phone and email stay hidden until you accept an offer. Groomers see the request location details needed to decide whether to offer.`
- Do not change request validation fields, publish draft fields, `create_grooming_request` inputs, or matching behavior.

### 3. Groomer readiness information architecture

- In `GroomerProfileManagementView.swift`, reorder the Account menu so readiness gates appear first:
  1. `Edit Profile`
  2. `Services`
  3. `Availability`
  4. `Fit Signals`
  5. `Portfolio`
  6. `Evidence Dashboard`
- Keep all existing destinations and repository-backed screens.
- Do not remove Fit Signals, Portfolio, or Evidence Dashboard; they remain supporting evidence tools after the required setup items.

### 4. Groomer availability request-first copy

- In `GroomerAvailabilityActiveCard`, replace direct-booking language:
  - `Available for bookings` -> `Available for requests`
  - `New clients can find and book you` -> `Matching requests can be sent to you during available windows.`
  - Toggle accessibility/title should match the visible request-first wording.
- In the Booking Preferences card, replace auto-accept direct-booking language:
  - `Auto-accept bookings` -> `Auto-ready during open hours` or `Auto-ready for offers`
  - `Skip approval during open hours` -> `Use your open hours when checking request and offer availability.`
- Preserve existing `autoAcceptBookings` model/storage wiring. If the current backend does not use this flag for automatic booking, the copy must avoid promising automatic customer booking.

### 5. Groomer Offers tab cleanup

- Remove or hide the disconnected visible `Offers` tab from the groomer tab bar.
- Preferred implementation: keep offer domain models and request-detail offer behavior unchanged, but expose only these visible groomer tabs:
  - `Board`
  - `Schedule`
  - `Messages`
  - `Account`
- If keeping `GroomerTab.offers` internally is safer for compatibility, add a dedicated `visibleCases` collection and make `GroomerTabView` iterate that instead of `allCases`.
- Update `AppEntryModelsTests` to assert the visible groomer tab order and avoid expecting a connected standalone Offers tab.
- Do not delete offer models, offer repositories, `create_groomer_offer`, `withdraw_groomer_offer`, customer offer review UI, or backend offer tables/RPCs.

## Expected Output

- Customer Home clearly tells a no-pet customer what is missing before starting a quest.
- Customer Request wizard labels the combined time/location step accurately.
- Review copy no longer over-promises location privacy.
- Groomer Account teaches setup order: profile, services, availability first; evidence tools second.
- Groomer Availability copy is request-first and does not imply customer direct booking.
- Groomer tab bar no longer exposes a placeholder standalone Offers tab.

## Out Of Scope

- Public groomer directory.
- Customer direct slot booking.
- New availability selection UI for customers.
- New Supabase migration, RLS policy, RPC, Storage policy, or repository contract.
- New matching algorithm or score calibration.
- New profile completeness gate logic.
- New portfolio/evidence proof system.
- Payments, notifications, maps, calendar sync, or admin tooling.

## Required Validation

Because this is a Standard app-visible UI task:

1. Update focused tests before or alongside implementation:
   - `CustomerRequestFeatureTests.requestWizardStepsMatchPrototypeProgression` should expect `Time & Location`.
   - `AppEntryModelsTests` should expect the visible groomer tab order without a standalone placeholder `Offers` tab.
2. Run the focused tests touched by the changes if practical.
3. Run `./scripts/ios-build.sh`.
4. Run `git diff --check`.
5. Launch the iOS app in Simulator after the build and visually inspect at least:
   - Customer Home no-pet state.
   - Customer Request wizard progress labels and Review copy.
   - Groomer Account menu order.
   - Groomer Availability copy.
   - Groomer tab bar without a standalone Offers placeholder.

## Risk Level

Medium.

The implementation should be mostly UI/copy/order changes, but it touches visible navigation by hiding/removing the groomer Offers tab. Keep the offer domain behavior intact and verify Board/request-detail offer creation still remains the groomer offer entry point.

## Completion Gate

`app-visible`

- Close out this task file after implementation.
- Run app validation.
- Launch the simulator for visible UI inspection.
- Update durable memory because this changes user-facing flow alignment.

## Stop Condition

Stop after T-087 aligns the UI surfaces listed above and passes the required validation. Do not start backend readiness gates, direct booking, public directory, or additional pet-fit work in the same run.

## Closeout

Status: implemented; partial simulator validation

Changed files:

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/GroomerTab.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/GroomerTabView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/AppEntryModelsTests.swift`
- `docs/06_tasks/T-087_GROOMLY_QUEST_READINESS_UI_ALIGNMENT.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`

Validation:

- RED focused test run failed as expected before implementation because `GroomerTab.visibleCases` did not exist.
- GREEN focused test run passed:
  - `PetGroomerMarketplaceTests/CustomerRequestsStoreTests/requestWizardStepsMatchPrototypeProgression`
  - `PetGroomerMarketplaceTests/TabModelsTests/groomerTabsHaveExactOrderTitlesAndSymbols`
- `./scripts/ios-build.sh` passed with `generic/platform=iOS Simulator`.
- `git diff --check` passed.
- No-index whitespace check passed for the untracked T-087 task doc after retrying the zsh script with a non-reserved variable name.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on iPhone 17 Pro (`45D452E8-DC6C-4CD4-A747-4D21671E68A6`).
- Groomer runtime snapshots confirmed:
  - Tab bar shows `Board`, `Schedule`, `Messages`, and `Account`; no standalone `Offers` tab is visible.
  - Account menu order is `Edit Profile`, `Services`, `Availability`, `Fit Signals`, `Portfolio`, `Evidence Dashboard`.
  - Availability top copy says `Available for requests` and `Matching requests can be sent to you during available windows.`
  - Availability preference copy says `REQUEST PREFERENCES`, `Auto-ready during open hours`, and `Use your open hours when checking request and offer availability.`
- Customer Home no-pet state and Customer Request wizard runtime inspection were not completed because the simulator restored a groomer production session, and the app has no approved customer test account or launch argument for a customer preview route. The customer copy changes are covered by focused tests/build and code review, but runtime visual inspection still needs a customer simulator session or explicit authorization for a remote test account.

Risks:

- `GroomerTab.offers` remains internally available for compatibility, but the production groomer tab bar now iterates `GroomerTab.visibleCases`.
- Customer-facing runtime visual validation remains pending due to simulator login state, not because of a compile/build failure.
- No Supabase schema, RLS, RPC, Storage, repository contract, matching, request lifecycle, offer lifecycle, or booking semantics changed.

Next:

- If customer runtime visual inspection is required, provide a customer simulator session or explicitly authorize a remote customer test account path. Do not start backend readiness gates, public directory, direct booking, or additional pet-fit work as part of T-087.
