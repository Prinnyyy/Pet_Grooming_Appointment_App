# Navigation and Product Flows

## App Entry

```text
Launch
→ Validate backend configuration
→ Restore authentication session
├─ Signed out → Authentication
├─ Signed in, profile missing → Role Onboarding
├─ Customer profile → Customer Tabs
└─ Groomer profile → Groomer Tabs
```

Production restores the Supabase Auth session, loads the signed-in user's profile, sends a missing profile to role onboarding, and routes an existing or newly created profile to the matching Customer or Groomer tabs. Role creation is authoritative and atomic through `create_my_profile`; explicit shell routes remain available for previews and tests but do not select the production role.

## Primary Navigation

### Customer Tabs

1. Home
2. Requests
3. Bookings
4. Messages
5. Account

### Groomer Tabs

1. Board
2. Schedule
3. Messages
4. Account

Each tab owns a `NavigationStack`. Primary tasks should remain reachable from the corresponding tab without unnecessary modal or navigation depth.

## Customer Flow

```text
Sign up or sign in
→ Select Customer role when profile is missing
→ Create pet and upload pet photo
→ Start request wizard
→ Select pet, service, time window, notes, and photos
→ Review and publish
→ View request and received offers
→ Accept one offer
→ View booking and conversation
→ Groomer completes service
→ Leave one review
```

Publishing calls `create_grooming_request`; acceptance calls `accept_groomer_offer` and then refreshes owned request/offer state; review creation calls `create_review`. Failure keeps the user on the actionable screen with recoverable input intact.

## Pet-Fit Matching V1 Flow

Pet-fit matching v1 preserves the existing request-first flow:

```text
Customer creates pet profile
→ Customer publishes a grooming request with pet/service/location/time context
→ Backend creates eligible request matches with explainable fit reasons
→ Groomers review assigned requests and make concrete offers
→ Customer compares received offers and fit explanations
→ Customer accepts one offer
→ Booking and conversation are created atomically
→ Completed booking review feeds future evidence
```

The customer does not browse a public all-groomer directory or directly reserve a groomer time slot in v1. Groomer availability, portfolio tags, claimed specialties, and structured reviews are used to improve request distribution and offer explanation while keeping booking creation behind offer acceptance.

## Groomer Flow

```text
Sign up or sign in
→ Select Groomer role when profile is missing
→ Complete profile, services, and availability
→ Browse assigned matched requests on Board
→ Open request detail
→ Dismiss or make an offer
→ Customer accepts offer
→ View booking on Schedule and conversation in Messages
→ Complete booking
```

Offer creation calls `create_groomer_offer`, dismiss calls `dismiss_request_match`, and completion calls `complete_booking`. Dismissal is private to the groomer and does not produce a customer-facing rejection event.

## Booking Transition

```text
Pending offer
→ Customer selects offer
→ Backend revalidates ownership, request state, offer state, and time conflict
→ One booking and one conversation are created atomically
→ Selected offer is accepted
→ Competing offers close
→ Request becomes booked
```

The app must not optimistically fabricate a booking before the backend transaction succeeds. After acceptance, both role-specific Bookings tabs read participant `bookings` rows through backend RLS.

Booking cancellation changes only the booking status in the MVP contract. It does not reopen the original request, re-enable the accepted offer, or restore competing offers; a customer who needs another appointment starts a new request. Booking completion is available only to the booked groomer for confirmed bookings, and one customer review is available only after the booking is completed.

## Messaging Flow

```text
Accepted booking
→ Backend-created conversation
→ Customer or groomer opens Messages
→ Participant conversation list loads through RLS with booking context
→ Participant opens a conversation
→ Text messages load and send through `messages`
```

T-020 messaging is text-only. The list/detail can show booking schedule and price context; customers may also see an active groomer's public business name through the existing `groomer_profiles` read policy. Groomer-side customer names remain support references until a customer profile presentation contract exists. Realtime updates, attachments, typing indicators, read receipts, moderation, and push notifications are not part of the current flow.

## Navigation Failure Rules

- Missing or invalid backend configuration remains on a visible blocking state.
- An expired session returns to authentication after clearing protected UI state.
- A signed-in user without a valid profile remains in onboarding.
- Permission and conflict errors keep the current screen, explain the result, and refresh authoritative state when appropriate.
- No production route is selected from local fixtures or launch arguments.
