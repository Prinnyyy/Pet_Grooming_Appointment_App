# Module Boundaries

## Layer Boundaries

| Layer | Allowed Responsibilities | Forbidden Responsibilities |
|---|---|---|
| App composition | Dependency construction, root state, route composition | Feature business rules, data queries |
| SwiftUI View | Layout, input, navigation, accessibility, rendering state | Supabase calls, RLS assumptions, durable mutation sequencing |
| ViewModel / Coordinator | UI state, validation, cancellation, repository calls, error mapping | SQL/Storage policy decisions, view layout |
| Domain model | Stable business concepts and statuses | Supabase response mechanics, screen-only formatting |
| Repository protocol | Feature-facing reads and mutations | UI state and navigation |
| Supabase repository/adapter | Queries, RPC calls, uploads, DTO mapping | Product policy invention, UI presentation |
| Backend RPC | Authorized multi-record transitions and invariants | UI-specific behavior |
| RLS / grants / constraints | Row access, API exposure, ownership, database integrity | Client navigation or messaging copy |

## Feature Ownership

| Feature | Owns | Must Not Own |
|---|---|---|
| Auth / Onboarding | Session, profile existence, role entry | Pet, request, offer, or booking data |
| Pets | Pet records and pet photos | Request snapshots after publication |
| Groomer Profile | Profile, service settings, portfolio | Matching or offer acceptance |
| Requests | Request draft/publication, own request state, assigned match state | Booking creation |
| Offers | Offer form, offer list, offer status | Booking transaction |
| Bookings | Acceptance result, booking lists/details, cancellations | Message bodies or review content |
| Chat | Conversation and message state | Booking authorization rules |
| Reviews | Review eligibility UI and submission | Rating aggregation policy outside backend contract |

## Dependency Direction

- Views depend on feature state and repository protocols, not concrete Supabase clients.
- Feature modules may depend on shared domain/infrastructure abstractions but not on another feature's views.
- Concrete repositories depend inward on feature protocols and outward on the Supabase client through composition.
- Backend schema details do not leak into unrelated SwiftUI screens.

## Shared-Code Rule

Promote code into Core, DesignSystem, Services, or shared Repositories only after it has a stable cross-feature responsibility. Do not create speculative abstractions or a global model to anticipate future tasks.
