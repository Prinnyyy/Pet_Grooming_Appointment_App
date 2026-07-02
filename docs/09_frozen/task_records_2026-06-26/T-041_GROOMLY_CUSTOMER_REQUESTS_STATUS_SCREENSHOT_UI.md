# T-041 Groomly Customer Requests Status Screenshot UI

Task ID: `T-041`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Rework the customer Requests page from the uploaded prototype screenshots. The two screenshots represent the same screen; the second only shows lower scroll content. Ignore the long oval Customer/Groomer selector above the phone frame. Show request status in the top status module. Ignore the `groomers match your request` module because customer-side matched groomer display is not currently implemented in backend/app support. Wire the final actions to existing behavior or pages where possible.

Screenshot/source reference:

- `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-13.png`
- `docs/08_design/screenshots/screenshot-2026-06-22-am-12-27-26.png`

## Primary Task

Rework only the customer Requests tab root page represented by the screenshot.

Target screen and role:

- Screen: `CustomerRequestsView`
- Role: `Customer`

## Required Context

Read:

1. `AGENTS.md`
2. `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
3. `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`
4. `docs/00_memory/CURRENT_STATE.md`
5. `docs/06_tasks/TASK_LEDGER.md`
6. `docs/01_product/SCREEN_INVENTORY.md`
7. `docs/01_product/DESIGN_SYSTEM.md`
8. `Features/Customer/Requests/CustomerRequestsView.swift`
9. `Features/Customer/Requests/CustomerRequestsStore.swift`
10. `Core/Models/CustomerRequest.swift`
11. `Core/Infrastructure/Supabase/SupabaseCustomerRequestRepository.swift`

## Screenshot Analysis

Ignore rule:

- Ignored the long oval Customer/Groomer toggle above the visible app screen frame. It is an external prototype/control annotation.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Top request state title, subtitle, status chip | visual-only | yes | `CustomerRequestsView` | `CustomerRequestsStore.requests`, `CustomerGroomingRequest.status` | implement using current selected request |
| Vertical request status timeline | visual-only | yes | `CustomerRequestsView` | `GroomingRequestStatus` | implement mapped progress states |
| `groomers match your request` list | new/deferred feature | no customer-side list support | none | backend match rows are groomer feed oriented; customer request model has no matched groomer list | ignore per user request; do not add fake data |
| Bottom edit/manage action | existing-feature rewire / partial | partial | `CustomerRequestsView` -> `CustomerRequestDetailView` | existing detail route | implement as existing request detail entry; no edit mutation |
| Bottom cancel action | visual-only / deferred behavior notice | partial | `CustomerRequestsView` | no customer request cancel RPC/repository method | implement honest unavailable notice; no cancel mutation |
| Empty/no request state | existing-feature rewire | yes | `CustomerRequestsView` | `CustomerRequestsStore.startCreate()` | preserve ability to start a request |
| Loading/error/status feedback | visual-only | yes | `CustomerRequestsView`, `CustomerRequestsStatusView` | existing store state | preserve |

## Scope

In scope:

- Rework the Requests tab root page into a prototype-inspired current request status view.
- Sync displayed copy, chip, and timeline to `GroomingRequestStatus`.
- Reuse the existing request detail view for deeper request information.
- Preserve request creation for empty state / no active request.
- Keep existing loading, error, publish notice, and offer/detail behavior intact.

Out of scope:

- Customer-side matched groomer list.
- New request edit/update RPC, repository method, or persistence.
- New request cancel RPC, repository method, or persistence.
- Backend/schema/RLS/RPC/Storage changes.
- Changes to groomer Requests, Bookings, Chat, Account, or Home.

## Implementation Plan

1. Replace the Requests tab list-first root layout with a status-first dashboard.
2. Add small local subviews for the hero header, status timeline, action row, and optional other requests list.
3. Map timeline stages to existing request statuses without inventing backend state.
4. Keep request detail navigation and request creation sheet wired through the existing store.
5. Record closeout, run validation, and launch the simulator.

## Validation

Default validation:

```sh
./scripts/ios-build.sh
git diff --check
```

Completion launch:

- Launch the app in the iOS Simulator for user inspection.

## Acceptance

- Screenshot modules are implemented only within the approved classification.
- Existing MVP behavior uses existing Store/repository/model/backend paths.
- No unapproved new feature, backend, schema, RLS, RPC, Storage, navigation, or role capability is introduced.
- Required validation passes or the first real error is reported.

## Closeout

Status: `completed`

Changed files:

- `docs/06_tasks/T-041_GROOMLY_CUSTOMER_REQUESTS_STATUS_SCREENSHOT_UI.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/06_tasks/TASK_LEDGER.md`

Validation:

- `git diff --check` passed after the final SwiftUI change.
- `./scripts/ios-build.sh` passed after the final SwiftUI change. One intermediate build failed because `CustomerRequestTimelineStep.offers(state:)` needed an explicit `return`; that local compile error was fixed and the final build succeeded.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Runtime UI reached the Customer Requests tab with the new status-first page. The current local account has a `booked` request, so the visible synced state was `Your booking is confirmed` / `Booked`, with all four timeline steps complete.
- Interaction smoke: `Edit Request` opened the existing `CustomerRequestDetailView`, then returned to the Requests tab. `Cancel Request` was disabled for the booked request state. The current data did not exercise the open-state cancellation alert.
- Final screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_926709ac-ee77-4f06-83af-65a5e6e1d968.jpg`

Risks:

- The customer-side matched groomer list from the prototype was intentionally ignored. Current customer request contracts do not expose a groomer-match list suitable for this module.
- `Edit Request` is an existing detail-page entry, not a request update flow. No request edit/update backend path was added.
- `Cancel Request` does not mutate state. Request cancellation still needs a controlled backend RPC/repository method before it can be implemented.
- Runtime simulator data covered the `booked` state. The `open` / `hasOffers` / `cancelled` / `expired` mappings are implemented from `GroomingRequestStatus` but were not all represented by the current local account data.

Next:

- App is running on the Customer Requests tab in Simulator for inspection. Wait for explicit user direction before changing customer matched-groomer display, request editing, or request cancellation backend behavior.
