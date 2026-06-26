# T-016 — Groomer Offer Creation UI

## Status

- Mode: Standard.
- State: completed.
- Depends on: T-014 matched request feed and T-015 offer backend.

## Goal

Implement the groomer-side offer creation path against the deployed T-015 backend.

## Scope

In scope:

- Show the latest groomer-owned offer status on matched request rows/details.
- Let a matched groomer enter proposed start/end, price estimate, and optional message.
- Submit through `create_groomer_offer`.
- Withdraw a pending offer through `withdraw_groomer_offer`.
- Keep Supabase access behind repository boundaries.
- Add focused store tests for validation and mutation state.

Out of scope:

- Customer offer list, comparison, acceptance, or booking creation.
- New Supabase schema, migrations, RLS changes, or Storage work.
- Offers tab implementation, notifications, payments, chat, or reviews.
- Runtime demo data or fake backend success.

## Implementation Notes

- Offer creation is integrated into the existing Groomer Requests detail screen instead of creating a separate Offers feature. This keeps T-016 scoped to groomer submission while leaving T-017 customer review and T-018 acceptance/booking separate.
- `GroomerRequestRepository` now reads the latest owned offer for each matched request and exposes controlled create/withdraw methods.
- The Supabase adapter calls the existing T-015 RPCs and maps stable PostgREST/RPC errors to local repository errors.
- The store validates proposed time, price scale/range, message length, duplicate submissions, and non-offerable matches before calling the repository.

## Validation

Completed validation:

- Initial `./scripts/ios-test.sh` failed on a Swift naming collision where the `message` offer-form parameter shadowed the store's `message(for:action:)` error formatter.
- After approved targeted correction, `./scripts/ios-test.sh` passed with 44 Swift Testing tests and 1 XCTest UI smoke test.

No Supabase remote validation or Xcode UI test expansion was run because T-016 changes only iOS client code and uses already validated T-015 backend contracts.

## Closeout

T-016 is complete. Groomers can see latest own offer status on matched requests, submit one valid offer through `create_groomer_offer`, withdraw a pending offer through `withdraw_groomer_offer`, and receive local/backend validation errors without direct Supabase access from SwiftUI views. Customer offer review and acceptance remain separate later tasks.
