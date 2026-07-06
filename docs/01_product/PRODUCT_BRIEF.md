# Product Brief

## Current Source

This file is the active product summary. The original Fresh Brief is archived at `docs/09_frozen/product_briefs/Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` and is historical context only.

## Product Definition

Pet Groomer Marketplace is an iOS marketplace where a pet owner publishes one open grooming request, matched independent groomers submit offers, and the owner confirms one offer to create a booking.

## Core Product Model

```text
Open Grooming Request
-> Matched Groomers
-> Groomer Offers
-> Customer Confirmation
-> Booking
```

Customers do not repeatedly target individual groomers. A groomer chooses whether to respond to an eligible request, and a booking exists only after the customer accepts an offer.

## Target Users

- Customer: maintains pet profiles, publishes grooming requests, compares offers, manages bookings, chats after booking, and reviews completed service.
- Groomer: maintains profile/services/portfolio metadata, sees eligible requests, makes or withdraws offers, manages bookings, chats with booked customers, and completes service.
- Admin: deferred; no admin dashboard or moderation workflow is approved.

## Current MVP Scope

- Email/password authentication and role onboarding.
- Customer and groomer profiles, pet profiles, and metadata-backed image uploads.
- Grooming request publication and groomer request matching.
- Groomer offer submission and customer offer review.
- Atomic offer acceptance, one booking per request, and groomer overlap protection.
- Role-specific booking lists, participant-only text chat, completion, and one review per completed booking.
- Visible loading, empty, validation, permission, conflict, and general error states.
- Groomly-styled implemented MVP screens.

## Deferred Scope

- Payments, refunds, disputes, subscriptions, and dynamic pricing.
- Push notifications, realtime chat polish, social login, maps, calendars, and AI recommendations.
- Request editing, rebooking, favorites, attachments, read receipts, signed URL image rendering, and admin tooling.
- Persistent request street address/travel range/photo fields shown as UI-only controls in T-048.

## Product Constraints

- Preserve Open Request -> Groomer Offer -> Customer Confirmation -> Booking.
- Backend state is authoritative for profiles, pets after sync, requests, offers, bookings, messages, and reviews.
- Critical transitions use server-side validation and RPCs; UI visibility is not authorization.
- No runtime mock mode, production fallback data, or fake backend success.
- Preview and test fixtures are allowed only in preview and test processes.
- A new screen belongs in `SCREEN_INVENTORY.md`; a new backend state belongs in `docs/03_backend/SUPABASE_CONTRACT.md` before implementation.

## Current State

The implemented app is complete through T-048 at the current contract level. Use `docs/00_memory/CURRENT_STATE.md` and `docs/00_memory/FEATURE_INDEX.md` for current routing and known gaps.
