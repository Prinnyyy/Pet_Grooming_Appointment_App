# T-013 — Customer Grooming Request Wizard

## Status

Completed on 2026-06-20.

## Mode

Standard.

## Goal

Implement the customer-side grooming request publishing flow against the deployed T-012 request backend.

## Scope

- Customer Requests tab only.
- Load customer-owned pets for selection.
- Load customer-owned grooming requests.
- Compose a request with pet, service type, preferred time range, notes, and location.
- Publish through `create_grooming_request`.
- Show publish result and owned request details.

## Out of Scope

- Groomer matched request feed.
- Offers, bookings, chat, reviews.
- Runtime mock success.
- Supabase schema changes or migrations.

## Backend Gap

The T-002 roadmap listed cancellation of an eligible open request in T-013. The deployed T-012 backend does not provide a customer cancel RPC, and `grooming_requests` grants authenticated clients `SELECT` only. This task must not fake cancellation success or directly update request status. Cancellation remains blocked until a dedicated backend task adds and verifies a controlled cancel operation.

## Validation Plan

- Focused Swift tests for request store validation, submission, and failure behavior.
- One iOS validation attempt with `./scripts/ios-test.sh`.

## Stop Condition

Stop after customer publishing and owned request display are implemented, memory is updated, and the missing cancel backend contract is recorded.

## Closeout

- Added customer request models, repository contract, Supabase adapter, store, wizard, list, detail, and Customer Requests tab wiring.
- Added focused state tests covering load/default selection, validation, successful publish/reload, and failure input preservation.
- Validation: the first `./scripts/ios-test.sh` attempt failed on a test variable typo; after the approved targeted correction, the second `./scripts/ios-test.sh` passed with 36 Swift Testing tests and 1 XCTest UI smoke test. The post-review follow-up `./scripts/ios-test.sh` passed with 37 Swift Testing tests and 1 XCTest UI smoke test.
- Cancellation remains blocked by backend scope: T-012 exposes no customer cancel RPC and grants `grooming_requests` as SELECT-only to authenticated clients.
- Next task: T-014 — Groomer matched request feed.

## Review Follow-up

- Added a 5-minute minimum preferred-start lead time so the client does not accept a near-immediate future time that could become invalid by the time `create_grooming_request` reaches the server.
- Added focused test coverage for the near-future boundary.
