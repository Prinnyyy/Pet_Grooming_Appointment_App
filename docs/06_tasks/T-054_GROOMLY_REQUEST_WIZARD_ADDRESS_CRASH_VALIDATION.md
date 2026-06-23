# T-054 Groomly Request Wizard Address Crash and Required Validation

Mode: Standard

Date: 2026-06-23

## User Request

Fix a freeze/white-screen/crash after creating a new customer quest, returning to fill the missing address, and typing `760` into the address field. Also prevent advancing to the next wizard page when required fields are missing: the Continue button should look gray, tapping it should show a required-fields message, and required controls should show a red glow until the user interacts with them.

## Scope

In scope:

- Harden customer new-request address autocomplete so duplicate MapKit address candidates cannot crash the app.
- Move wizard step validation into testable app logic and use it to block Pet/Time/Review progression when required fields are missing or invalid.
- Add red invalid styling to required request wizard controls and clear it when the user interacts with the control.
- Keep existing Store/repository/backend contracts unchanged.

Out of scope:

- New address persistence, schema, RLS, RPC, Storage, or repository contracts.
- Changing request publish semantics beyond matching the existing validation.
- New UI screens outside the customer new-request wizard.

## Initial Root-Cause Notes

- The request wizard address field calls `CustomerRequestAddressSearch.update(...)` on every street text change.
- `CustomerRequestAddressSearch.completerDidUpdateResults(_:)` currently builds `completionsByID` using `Dictionary(uniqueKeysWithValues:)` from `"\(completion.title)|\(completion.subtitle)"`.
- If `MKLocalSearchCompleter` returns duplicate title/subtitle pairs for broad input such as `760`, Swift can trigger a fatal duplicate-key error. This matches the user's address-entry crash path.
- Standard DiagnosticReports did not expose a local app crash report during initial inspection, so the fix is based on the deterministic fatal condition in the current code path.

## Implementation Plan

1. Add failing tests for duplicate address suggestion de-duplication and request wizard step validation.
2. Add a small testable address suggestion builder that de-duplicates candidates before storing completion lookups.
3. Add Store-level wizard validation for pet, service, time/location, details, and review.
4. Update the wizard UI so Continue is visually gray but still tappable for validation feedback; missing controls get red glowing borders and clear when touched/edited.
5. Validate with targeted tests, `git diff --check`, `./scripts/ios-build.sh`, and simulator launch.

## Changed Files

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/GroomlyFormPrimitives.swift`
  - Added optional invalid-state styling to `.groomlyFormField(isInvalid:)` with a red border/glow while preserving the default call site behavior.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
  - Moved wizard-step validation into Store-level testable logic.
  - Added required-field validation for pet selection, time/location, details length, and review aggregation.
  - Reused the same street and ZIP validation rules for pre-navigation checks and final publish checks.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
  - Replaced the fatal duplicate-key address autocomplete path with a de-duplicating suggestion builder.
  - Made invalid Continue visually gray but still tappable, showing the required-fields message without advancing.
  - Added red invalid borders/glow to required controls and clears those states when the user edits or taps the field.
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
  - Added coverage for required address validation and duplicate address suggestion de-duplication.

## Validation

- `xcodebuild test -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests`
  - Red before implementation because wizard validation and the address suggestion builder did not exist.
  - Passed after implementation.
- `git diff --check`
  - Passed.
- `./scripts/ios-build.sh`
  - Passed: `BUILD SUCCEEDED`.

## Simulator Launch

- XcodeBuildMCP `build_run_sim` passed on iPhone 17 simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Runtime bundle: `com.prinnyyy.PetGroomerMarketplace`.
- Process: `1889`.
- Log path: `/Users/liafenyua/Library/Developer/XcodeBuildMCP/workspaces/Pet_Grooming_Appointment_App-78bef82efd6d/logs/com.prinnyyy.PetGroomerMarketplace_2026-06-23T19-31-29-880Z_helperpid1867_ownerpid27173_f0198eeb.log`.
- Visual launch check confirmed the Customer Home screen rendered instead of a white screen.
- Manual simulator check:
  - Opened Customer Home -> Start Grooming Request -> Service -> Time/Location.
  - Typed `760` into the street address field.
  - App stayed responsive and showed address suggestions (`760 S Beach Blvd`, `760 Challenger St`, `760 E Lambert Rd`, `760 Epperson Dr`) instead of freezing/crashing.
  - Tapped gray Continue with missing address fields.
  - Wizard stayed on the same page and displayed `Complete the highlighted required fields before continuing.` through the existing request form error surface.

## Closeout

Status: completed

Risks:

- Address autocomplete still depends on MapKit network/service availability; the app should now fail empty instead of crashing when suggestions are noisy or duplicated.
- Required-field glow is UI-side validation only. Final publish validation still remains the authoritative client-side gate before calling the repository, and backend constraints/RPC validation remain unchanged.
