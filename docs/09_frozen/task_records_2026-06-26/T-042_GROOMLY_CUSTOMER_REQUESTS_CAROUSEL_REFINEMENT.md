# T-042 Groomly Customer Requests Carousel Refinement

Task ID: `T-042`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Refine the customer Requests page after T-041. Do not show a `start a grooming request` module on the Customer Requests page. The request action buttons must be dynamic: after a quest/request is confirmed, the edit button becomes a detail button and opens that request page. Put each request's brief information at the top of the request progress module. If there are two requests, show the module as a horizontally scrollable card column so another request's brief information, progress, and action buttons swipe together with that request state.

Source reference:

- User follow-up to `T-041_GROOMLY_CUSTOMER_REQUESTS_STATUS_SCREENSHOT_UI.md`; no new screenshot was provided.

## Primary Task

Refine only the Customer Requests tab root page.

Target screen and role:

- Screen: `CustomerRequestsView`
- Role: `Customer`

## Required Context

Read:

1. `AGENTS.md`
2. `docs/06_tasks/T-041_GROOMLY_CUSTOMER_REQUESTS_STATUS_SCREENSHOT_UI.md`
3. `docs/06_tasks/TASK_LEDGER.md`
4. `docs/00_memory/CURRENT_STATE.md`
5. `Features/Customer/Requests/CustomerRequestsView.swift`
6. `Features/Customer/Requests/CustomerRequestsStore.swift`
7. `Core/Models/CustomerRequest.swift`

## Module Analysis

| Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Remove Requests-page start grooming module | visual-only / navigation removal | yes | `CustomerRequestsView` | `CustomerRequestsStore.startCreate()` remains available from Home | implement by removing root-page start card usage |
| Request brief information inside progress module | visual-only | yes | `CustomerRequestsView` | `CustomerGroomingRequest` pet snapshot, service type, time, location, status | implement |
| Multiple requests as horizontal cards | visual-only | yes | `CustomerRequestsView` | existing `CustomerRequestsStore.requests` array | implement without new selection/navigation model |
| Per-card progress timeline | visual-only | yes | `CustomerRequestsView` | `GroomingRequestStatus` | implement by reusing T-041 status mapping inside each card |
| Per-card dynamic buttons | existing-feature rewire / visual-only | partial | `CustomerRequestsView` -> `CustomerRequestDetailView` | existing detail route; no edit/update/cancel repository path | implement `Edit Request` for open states and `Detail` for confirmed/closed states; keep cancel disabled or unavailable without mutation |

## Scope

In scope:

- Requests root page layout refinement only.
- Horizontal request progress carousel using existing request data.
- Dynamic button labels from existing status.
- Existing detail navigation for both edit/detail entry.
- Honest unavailable cancel behavior without mutating request state.

Out of scope:

- New request edit/update backend behavior.
- New request cancellation RPC, repository method, or persistence.
- Customer-side matched groomer list.
- Changes to Home, Bookings, Groomer, Chat, Account, backend, schema, RLS, RPC, or Storage.

## Implementation Plan

1. Replace the single featured request layout with a horizontally scrollable request progress carousel.
2. Move request brief summary into the top of each progress card.
3. Keep the timeline and action buttons inside each card so they scroll with that request.
4. Remove root usage of the start grooming request card and simplify empty state to a read-only notice.
5. Validate with `git diff --check`, `./scripts/ios-build.sh`, and launch the simulator for inspection.

## Validation

Default validation:

```sh
git diff --check
./scripts/ios-build.sh
```

Completion launch:

- Launch the app in the iOS Simulator for user inspection.

## Closeout

Status: `completed`

Changed files:

- `docs/06_tasks/T-042_GROOMLY_CUSTOMER_REQUESTS_CAROUSEL_REFINEMENT.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/06_tasks/TASK_LEDGER.md`

Validation:

- `git diff --check` passed after the final SwiftUI change.
- `./scripts/ios-build.sh` passed after the final SwiftUI change.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Runtime UI reached the Customer Requests tab with the refined request progress card. The current account has one `booked` request, so the runtime state displayed `Confirmed quest`, `Booked`, the completed timeline, `Detail`, and disabled `Cancel`.
- Interaction smoke: `Detail` opened the existing `CustomerRequestDetailView`, then returned to the Requests tab.
- Final screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_36367e8b-24ef-43ed-a5e9-589f8d8e512b.jpg`

Risks:

- The live simulator account currently has only one request, so the multi-card horizontal carousel was compile-validated and covered by DEBUG preview mock data, but not exercised with two live backend requests.
- `Edit Request` is still a label for open/offer states that routes to the existing request detail page; no request edit/update backend path was added.
- `Cancel` does not mutate request state. Open-state cancellation still shows the existing unavailable alert until a controlled backend RPC/repository path exists.
- The Customer Requests page no longer exposes request creation. Request creation remains available from Customer Home.

Next:

- App is running on the Customer Requests tab in Simulator for inspection. Wait for explicit user direction before adding request edit persistence, request cancellation backend behavior, or customer-side matched-groomer display.
