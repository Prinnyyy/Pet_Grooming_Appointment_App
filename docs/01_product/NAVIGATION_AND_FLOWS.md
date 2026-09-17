# Navigation and Product Flows

## Entry

```text
Launch
-> validate backend configuration
-> restore Supabase Auth session
-> signed out: Authentication
-> signed in without profile: Role Onboarding
-> Customer profile: Customer tabs
-> Groomer profile: Groomer tabs
```

Production role routing comes only from the authoritative profile loaded after Auth restore or `create_my_profile`. Fixture routes are preview/test-only.

## Tabs

- Customer: Home, Requests, Bookings, Messages, Account.
- Groomer: Board, Schedule, Messages, Account.
- Each tab owns a `NavigationStack`; primary tasks should stay shallow.

## Customer Flow

```text
Sign in -> Customer role -> create pet/photo -> request wizard
-> publish request -> review offers -> accept one offer
-> booking + conversation -> groomer completes -> one review
```

Publishing uses coordinate-backed `create_grooming_request_v2`; accepting uses `accept_groomer_offer`; reviews use `create_review`. Failed mutations keep recoverable input and refresh authoritative state.

## Pet-Fit Marketplace V1

```text
Pet/request context -> backend match creation -> groomer offers
-> customer compares offers and fit evidence -> accepted offer creates booking/chat
```

V1 is request-first. Customers do not browse a public all-groomer directory or directly reserve slots. Availability, portfolio tags, claimed specialties, and reviews improve match distribution and offer explanation.

## Groomer Flow

```text
Sign in -> Groomer role -> profile/services/availability
-> matched requests on Board -> dismiss or offer
-> accepted offer -> Schedule + Messages -> complete booking
```

Offer creation uses `create_groomer_offer`; dismissals use `dismiss_request_match` and stay private to the groomer; completion uses `complete_booking`.

## Booking and Messaging

- Offer acceptance is backend-atomic: ownership, request state, offer state, and time conflicts are revalidated before booking/conversation creation.
- The app must not fabricate bookings optimistically.
- Cancellation changes only the booking status; it does not reopen the original request or accepted/competing offers.
- Participant bookings read through backend RLS.
- Messaging is booking-participant text chat through `conversations` and `messages`.
- Realtime, attachments, typing indicators, read receipts, and moderation are out of current scope.
- Customer in-app notifications are active; APNs dispatch remains blocked until T-157 resumes with paid Apple Developer credentials.

## Failure Rules

- Missing backend config stays on a blocking state.
- Expired sessions return to authentication after clearing protected UI.
- Signed-in users without profiles stay in onboarding.
- Permission/conflict errors explain the outcome and refresh authoritative state when useful.
- Production routes must not be selected from fixtures or launch arguments.
