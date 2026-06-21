# User Roles

## Role Matrix

| Role | Description | Allowed MVP Actions | Primary Areas |
|---|---|---|---|
| Customer | Authenticated pet owner | Manage own profile and pets; publish own requests; read offers for own requests; accept one offer through RPC; read and cancel own confirmed bookings through RPC; review own completed booking through RPC after T-021 | Home, Requests, Bookings, Messages, Account |
| Groomer | Authenticated independent groomer | Manage own profile, services, and portfolio; read assigned matched requests; dismiss matches; create/withdraw own offers through controlled backend operations; read own bookings and conversations; complete own confirmed bookings through RPC | Requests, Offers, Bookings, Messages, Account |
| Admin | Deferred role | No MVP client permissions or screens | None |

## Identity and Authorization Rules

- Supabase Auth user ID is the identity boundary. A profile row maps that identity to exactly one `customer` or `groomer` role.
- Role selection occurs during onboarding and is not switchable in normal UI.
- Role and ownership permissions are enforced by RLS and RPCs, not by hidden buttons or client state.
- Authorization must not trust user-editable authentication metadata. Backend profile ownership and validated server-side data are authoritative.
- Customer and groomer shells must never be entered because of preview fixtures or locally fabricated session success.
- Customer request cancellation is deferred until a dedicated request-cancel RPC exists. Booking cancellation does not reopen the original request or offers.

## Privacy Rules

- A groomer sees only requests assigned through `request_matches`.
- Before booking, groomers receive only the pet, service, time, and approximate location data required to evaluate the request.
- A customer sees offers only for owned requests.
- Conversations and messages are visible only to the customer and groomer on the associated booking.
- Admin access, support impersonation, and moderation privileges require a future explicit security design.
