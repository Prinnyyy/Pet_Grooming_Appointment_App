# Product Brief

## Canonical Source

This file is the active product source for feature work. It replaces the original root rebuild brief as the daily working entrypoint.

The original rebuild brief is archived at `../09_frozen/product_briefs/FRESH_PET_GROOMER_MARKETPLACE_ENGINEERING_BRIEF_2026-07-02.md`; do not read it by default.

## Product Definition

Pet Groomer Marketplace is an iOS marketplace where a pet owner publishes one open grooming request, matched independent groomers submit offers, and the owner confirms one offer to create a booking.

## Core Product Model

```text
Open Request -> Matches -> Offers -> Customer Confirmation -> Booking
```

Customers do not repeatedly target individual groomers. A groomer chooses whether to respond to an eligible request, and a booking exists only after the customer accepts an offer.

## Pet-Fit Matching Direction

Pet-fit v1 keeps the request-first model and makes matching more pet-specific. Inputs include pet traits, service need, location mode, photos, preferred time, groomer service coverage, availability, portfolio, low-weight claimed specialties, completed bookings, and structured reviews. Match reasons must be explainable enough for user-facing fit copy.

Groomly is not shifting to a public groomer directory, direct slot booking, or AI/ML recommender in v1. Customer choice stays anchored in received offers.

## Target Users

- **Customer:** A pet owner who maintains pet profiles, publishes grooming requests, compares offers, manages bookings, chats after booking, and reviews completed service.
- **Groomer:** An independent pet groomer who maintains a profile and services, sees eligible requests, makes or withdraws offers, manages bookings, chats with booked customers, and completes service.
- **Admin:** Not part of the MVP. No admin dashboard or moderation workflow is planned in T-003 through T-022.

## Core Jobs To Be Done

1. Customers publish clear requests and receive options without repeatedly contacting groomers.
2. Groomers browse suitable requests and respond only when interested.
3. One accepted offer becomes a conflict-safe booking and service lifecycle.

## MVP Scope

- Email/password auth, role onboarding, customer/groomer profiles, pet profiles, and required images.
- Request publication, groomer matching, offer submission/review, atomic offer acceptance, one booking per request, and groomer overlap protection.
- Role-specific bookings, participant-only chat, completion, one review per completed booking, visible async/error states, and safe developer diagnostics.

## Deferred Scope

- Payments, refunds, disputes, subscriptions, dynamic pricing, push notifications, and social login.
- Complex calendars, maps-first discovery, AI/ML recommendations, public groomer directory, direct customer slot booking, and matching beyond explainable pet-fit v1.
- Realtime chat polish, typing indicators, read receipts, admin tools, and multi-pet request bundles.
- Favorites behavior. The Fresh Brief lists a `favorites` table but defines no fields, user flow, screen, or acceptance criterion; no schema or UI will be created without a separate product decision.

## Product Constraints

- Use the terms Grooming Request, Matched Request, Groomer Offer, Booking, Conversation, Message, and Review.
- The backend is authoritative for profiles, pets after sync, requests, offers, bookings, messages, and reviews.
- Critical transitions use server-side validation and RPCs; UI visibility is not authorization.
- No runtime mock mode, production fallback data, or fake backend success.
- Preview and test fixtures are allowed only in preview and test processes.
- A new screen must be added to `SCREEN_INVENTORY.md`; a backend state must be added to `SUPABASE_CONTRACT.md` before implementation.

## Current State

The MVP marketplace flow is implemented at the current contract level, and Groomly UI adaptation is complete for implemented screens. Post-MVP work added fixed pet/request contracts, availability-aware matching/offer/acceptance paths, explainable fit evidence, structured review outcomes, groomer fit-signal/portfolio tags, an owner evidence dashboard, customer in-app notifications, and a blocked APNs foundation. The app remains request-first; APNs dispatch waits for T-157 paid Apple Developer credentials.
