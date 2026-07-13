# Customer Form Actions and Keyboard Design

## Scope

T-336 updates four related form interaction contracts without changing persistence, repositories, Supabase, matching, or navigation destinations:

- Move Add/Edit Pet persistence from the bottom `Save Pet` action to a navigation confirmation action.
- Remove the duplicate Request Wizard header back action and allow progress to use the full content width.
- Add concise role-aware descriptions to the shared service-location choices.
- Make the shared keyboard Done accessory available to every production text-entry surface, including Chat.

## Pet Form

`CustomerPetsStore` owns an equatable snapshot of the editable values and whether a new avatar is pending. `startCreate()` and `startEdit(_:)` capture the baseline after populating the form. The navigation confirmation title is `Create` for a new pet and `Save` for an existing pet. It is disabled while saving, while the form is unchanged, or while the current form cannot produce a valid draft. Activating it calls the existing `savePet()` method unchanged. Cancel remains the navigation cancellation action. The stationary bottom Save Pet surface and its excess content clearance are removed.

## Request Wizard

The header contains only the request label, full-width progress track, and current-step label. The bottom Back action remains the single back/dismiss path at every step. Removing the 54-point header action also removes the progress leading-offset calculation; default and Accessibility layouts keep the progress content full width.

## Service Location

`BeckonGroomingLocationModePresentation` owns both title and supporting copy. Customer copy is:

- `My Home`: `A mobile groomer comes to your address.`
- `Groomer's Place`: `You bring your pet to the groomer's location.`

Groomer copy is perspective-aware:

- `Customer's Home`: `You travel to the customer's address.`
- `My Place`: `The customer brings their pet to your location.`

The shared selector renders the description below the title using Beckon supporting typography. Raw values and single/multiple selection behavior do not change.

## Keyboard Done Accessory

The Done toolbar becomes a standalone DesignSystem modifier reused by keyboard avoidance and by non-form input surfaces such as Chat. It resigns first responder through the existing action. The Done label uses one shared inset for its trailing and bottom space so it does not sit against the keyboard edge. No feature creates its own keyboard toolbar.

## Validation

- TDD coverage for Pet dirty-state/action titles, Request full-width progress, location descriptions, and Done accessory policy.
- Complete production input inventory verifies every input-owning screen receives the shared accessory directly or through `.beckonKeyboardAvoidance`.
- Full iOS tests, build, source/UI consistency audits, diff check, context hygiene, and preflight. Manual in-app UI/UX review remains user-owned and is not performed by Codex.
