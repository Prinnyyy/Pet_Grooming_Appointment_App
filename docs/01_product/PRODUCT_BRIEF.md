# Product Brief

## Canonical Source

`Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` is the product and engineering source for the fresh rebuild. This document is the concise working summary used by feature tasks.

## Product Definition

Pet Groomer Marketplace is an iOS marketplace where a pet owner publishes one open grooming request, matched independent groomers submit offers, and the owner confirms one offer to create a booking.

## Core Product Model

```text
Open Grooming Request
→ Matched Groomers
→ Groomer Offers
→ Customer Confirmation
→ Booking
```

Customers do not repeatedly target individual groomers. A groomer chooses whether to respond to an eligible request, and a booking exists only after the customer accepts an offer.

## Pet-Fit Matching Direction

The post-MVP direction keeps the request-first marketplace model and makes the matching layer more pet-specific. Groomly should help a customer find a groomer who fits this pet and this service need, then let the groomer compete through a concrete offer.

Pet-fit matching v1 is evidence-based and explainable:

- Customer requests provide pet traits, service need, location mode, photos, and a preferred time window.
- Groomer profiles provide service coverage, availability, portfolio, and low-weight claimed specialties.
- Completed bookings and structured customer reviews create higher-confidence evidence over time.
- Match scores and reasons must be understandable enough to show as user-facing fit explanations.

Groomly is not shifting to a customer-facing public groomer directory, direct slot booking, or AI/ML recommender in v1. Customer choice remains anchored in received offers, not in browsing a static list of all groomers.

## Target Users

- **Customer:** A pet owner who maintains pet profiles, publishes grooming requests, compares offers, manages bookings, chats after booking, and reviews completed service.
- **Groomer:** An independent pet groomer who maintains a profile and services, sees eligible requests, makes or withdraws offers, manages bookings, chats with booked customers, and completes service.
- **Admin:** Not part of the MVP. No admin dashboard or moderation workflow is planned in T-003 through T-022.

## Core Jobs To Be Done

1. A customer can publish one clear request and receive options without repeatedly contacting groomers.
2. A groomer can browse suitable requests and respond only when interested.
3. Both parties can move one accepted offer into a consistent, conflict-safe booking and complete the service lifecycle.

## MVP Scope

- Email/password authentication and role onboarding.
- Customer and groomer profiles, pet profiles, and required image uploads.
- Grooming request publication and groomer request matching.
- Groomer offer submission and customer offer review.
- Atomic offer acceptance, one booking per request, and groomer overlap protection.
- Role-specific booking lists, participant-only chat, completion, and one review per completed booking.
- Visible loading, empty, validation, permission, conflict, and general error states.
- Developer-only diagnostics and backend permission verification without exposing secrets.

## Deferred Scope

- Payments, refunds, disputes, subscriptions, and dynamic pricing.
- Push notifications and social login.
- Complex calendars, map-first experiences, AI recommendations, machine-learning recommendations, public groomer directory browsing, direct customer slot booking, and advanced matching beyond explainable pet-fit v1.
- Realtime chat polish, typing indicators, and read-receipt polish.
- Admin tools and multi-pet request bundles.
- Favorites behavior. The Fresh Brief lists a `favorites` table but defines no fields, user flow, screen, or acceptance criterion; no schema or UI will be created without a separate product decision.

## Product Constraints

- Use the terms Grooming Request, Matched Request, Groomer Offer, Booking, Conversation, Message, and Review.
- The backend is authoritative for profiles, pets after sync, requests, offers, bookings, messages, and reviews.
- Critical transitions use server-side validation and RPCs; UI visibility is not authorization.
- No runtime mock mode, production fallback data, or fake backend success.
- Preview and test fixtures are allowed only in preview and test processes.
- A new screen must be added to `SCREEN_INVENTORY.md`; a backend state must be added to `SUPABASE_CONTRACT.md` before implementation.

## Current State

The MVP marketplace flow is implemented at the current contract level: email/password authentication, role onboarding, customer pet profiles, grooming request creation, groomer matched-request review and offers, customer offer acceptance, bookings, participant text chat, completion, and completed-booking review.

Groomly UI adaptation is complete for implemented MVP screens. Post-MVP pet-fit and availability work now supports fixed pet/request contracts, groomer availability enforcement in matching/offer/acceptance paths, explainable fit evidence, structured review outcomes, groomer fit-signal/portfolio tags, and an owner evidence dashboard. The app remains request-first: no public groomer directory, customer direct slot booking, payments, push notifications, or admin dashboard is active.
