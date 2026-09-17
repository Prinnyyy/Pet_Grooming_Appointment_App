# Customer Request Offers Entry Design

## Scope

Give each active Customer Request card a direct route to its groomer offers. Preserve the existing Request, Offer, Store, repository, acceptance, refresh, pagination, and error behavior; this task only changes navigation ownership and card actions.

## Interaction Contract

- The first action row contains equal-width `Detail` and `Offers` actions.
- `Offers` is disabled and gray while the request status is `.open`.
- `Offers` is enabled and Customer green when the request status is `.hasOffers`.
- The second row contains one full-width `Cancel Request` action with a red fill and white label.
- Cancel availability and confirmation behavior remain unchanged.
- Booking handoff cards keep their existing `View Booking` action.
- Closed-request rows keep their existing detail and republish flow.

## Navigation And Ownership

- `CustomerRequestOffersView` is the only list owner for a request's offers.
- Entering the Offers page loads offers through `CustomerRequestsStore.loadOffers(for:)`.
- The page reuses the current pending/history grouping, refresh, pagination, groomer avatar, Offer detail, and acceptance behavior.
- `CustomerRequestDetailView` no longer renders Offers and no longer loads them on appearance.
- Offer availability uses the authoritative `GroomingRequestStatus` state machine; cards do not issue eager per-request Offer queries.

## Validation

- Swift Testing locks status-driven Offers availability and the absence of Offers ownership from Request Details.
- Focused Customer Request tests and one iOS build are required.
- UI/UX visual approval remains manual per project policy.
