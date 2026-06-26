# T-014 — Groomer Matched Request Feed

## Status

- Mode: Standard.
- State: completed.
- Started: 2026-06-20.
- Completed: 2026-06-20.

## Goal

Implement the groomer-side matched request feed backed by the deployed T-012 `request_matches`, `grooming_requests`, and `dismiss_request_match` contract.

## Scope

In scope:

- Groomer Requests tab list for active matched requests.
- Matched request detail with frozen pet snapshot, service, preferred time, location, match metadata, and dismiss action.
- Repository boundary and Supabase adapter.
- Loading, empty, refresh, error, and dismissing states.
- Focused Store tests.

Out of scope:

- Offer creation, withdrawal, pricing, or offer status mutation.
- Booking, chat, reviews, notifications, maps, or signed image display.
- Supabase migrations or backend policy changes.
- Runtime fixture/demo data.

## Implementation Notes

- SwiftUI views use `GroomerRequestRepository`; they do not directly access `SupabaseClient`.
- The Supabase adapter reads only the calling groomer's active match statuses (`visible`, `viewed`, `offered`) and then reads matching open/offer-eligible request rows visible through T-012 RLS.
- Dismiss uses only the controlled `dismiss_request_match` RPC and removes the match locally after the authoritative RPC result.
- `offered` matches are listed for forward compatibility but are not dismissible because the backend RPC only allows `visible` or `viewed`.
- Offer creation is explicitly marked as T-016 and is not connected in this task.

## Validation Plan

- One validation attempt: `./scripts/ios-test.sh`.
- Then run lightweight diff checks (`git diff --stat`, `git diff --check`) and inspect the current diff.
- Do not run Supabase remote validation because this task changes only iOS client code and documentation.

## Validation Result

- `./scripts/ios-test.sh` passed with 41 Swift Testing tests and 1 XCTest UI smoke test.
- `git diff --check` passed.
- Scope scan confirmed SwiftUI/App files do not import Supabase directly; Supabase access is limited to repository adapters.
- No Supabase remote validation was run because this task changed no backend schema, policy, or migration.

## Closeout

T-014 is complete. Groomers can load active matched requests, inspect frozen request details, refresh, and dismiss their own visible/viewed matches through the T-012 controlled RPC. Offer creation remains out of scope and is planned for T-016 after the T-015 backend.
