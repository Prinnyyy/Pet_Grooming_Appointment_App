# T-043 Groomly Customer Requests Carousel Edge Refinement

Task ID: `T-043`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Refine the Customer Requests per-request carousel. The current module looks constrained inside a rectangular display area; the rounded card corners reveal a rectangular clipped shadow area that visually separates from the page background. The preferred behavior is an unframed horizontal display range: while swiping, cards should not be masked by an inner rectangle, and clipping should only happen naturally at the screen edge.

Source reference:

- User follow-up to `T-042_GROOMLY_CUSTOMER_REQUESTS_CAROUSEL_REFINEMENT.md`; no new screenshot was provided.

## Primary Task

Refine only the Customer Requests carousel visual container.

Target screen and role:

- Screen: `CustomerRequestsView`
- Role: `Customer`

## Module Analysis

| Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Carousel display range / clipping | visual-only | yes | `CustomerRequestProgressCarousel` | none | implement by disabling ScrollView clipping and letting the carousel bleed to screen edges |
| Card content, status, actions | existing-feature rewire already implemented | yes | `CustomerRequestProgressCard` | `CustomerRequestsStore.requests`, `CustomerGroomingRequest.status` | preserve |

## Scope

In scope:

- Remove the inner rectangular clipping effect around the horizontal carousel.
- Preserve the card content, state mapping, dynamic action labels, detail route, and cancel unavailable behavior.

Out of scope:

- Backend, repository, model, request edit/cancel persistence, matched groomer list, or adjacent screen changes.

## Implementation Plan

1. Adjust the horizontal ScrollView so its visual range extends to the screen edge instead of the parent content column only.
2. Disable scroll clipping so card shadows are not cut into a rectangular viewport.
3. Keep the content margins aligned to the page rhythm.
4. Validate and launch the app for inspection.

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

- `docs/06_tasks/T-043_GROOMLY_CUSTOMER_REQUESTS_CAROUSEL_EDGE_REFINEMENT.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/06_tasks/TASK_LEDGER.md`

Validation:

- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Runtime UI reached the Customer Requests tab with two requests visible in the carousel.
- Visual inspection: the carousel now bleeds to the screen edge, card shadows are not clipped by an inner rectangular ScrollView viewport, and horizontal swiping brings the second request card into view with only screen-edge clipping.
- Final screenshot after swiping to the second card: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_ed1f0e7d-dbb8-4c8d-b2cd-73b31316a54c.jpg`

Risks:

- This is a visual-only container refinement. Request card content, state mapping, buttons, detail routing, and cancel unavailable behavior were intentionally preserved.
- The first attempted MCP gesture used a delta above the tool limit and failed before changing UI; the follow-up `scroll-left` gesture with a valid delta succeeded.

Next:

- App is running on the Customer Requests tab in Simulator for inspection. Wait for explicit user direction before changing card content, request edit persistence, request cancellation behavior, or matched-groomer display.
