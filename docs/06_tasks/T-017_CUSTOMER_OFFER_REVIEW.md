# T-017 — Customer Offer Review

## Status

- Mode: Standard.
- State: completed.
- Depends on: T-015 offer backend and T-016 groomer offer creation UI.

## Goal

Implement customer-side read-only offer review for offers submitted to owned grooming requests.

## Scope

In scope:

- Load offers for an owned customer request through `CustomerRequestRepository`.
- Show pending offer list, historical offer list, detail, comparison information, refresh, loading, empty, and scoped error states.
- Show stable offer status, proposed time, price, optional groomer message, and active groomer profile summary when readable.
- Keep Supabase access behind repository boundaries.
- Add focused store tests for offer loading success, pending-first ordering, and failure.

Out of scope:

- Accepting an offer, declining an offer, booking creation, conflict checks, or conversations.
- New Supabase schema, migrations, RLS changes, RPCs, or Storage work.
- Runtime demo data or fake backend success.
- A standalone Offers tab; customer offer review is integrated into owned request detail.

## Implementation Notes

- `CustomerOfferReview` wraps the existing `GroomerOffer` value object plus an optional readable `GroomerProfile`.
- `SupabaseCustomerRequestRepository` reads `groomer_offers` by `customer_id` and `request_id`, then reads active/authorized groomer profile summaries by `user_id`.
- Missing groomer profile summaries do not hide an otherwise readable offer; the UI falls back to a generic groomer label.
- `CustomerRequestsStore` orders pending offers before historical offers so the actionable state is not buried by withdrawn, declined, accepted, or expired history.
- `CustomerRequestDetailView` now includes an Offers section for pending offers, an Offer history section for non-pending offers, loading/empty/error states, refresh, and read-only detail.
- The offer detail explicitly states that acceptance requires the future T-018 backend transaction.
- Offers and groomer profile summaries are read in two Data API calls. This is intentionally eventually consistent for T-017; a groomer may change active/profile visibility between reads, and the UI keeps the readable offer visible with fallback groomer text.

## Validation

Completed validation:

- `./scripts/ios-test.sh` passed with 47 Swift Testing tests and 1 XCTest UI smoke test.

No Supabase remote validation was run because T-017 changes only iOS client code against the already deployed and validated T-015 read contract.

## Closeout

T-017 is complete. Customers can review pending offers first, inspect offer history separately, and compare price, proposed time, status, groomer summary, and optional message while all mutation paths remain unavailable until T-018.
