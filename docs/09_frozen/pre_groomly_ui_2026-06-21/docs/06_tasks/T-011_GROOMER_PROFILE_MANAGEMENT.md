# T-011 — Groomer Profile, Services, and Portfolio UI

## Status

Completed.

## Mode

Standard, single-agent.

## Goal

Implement groomer-owned profile management, service settings, and portfolio upload/delete UI on top of the T-010 backend.

## Scope

- Add iOS domain models for groomer profile, services, pet-size choices, and portfolio metadata.
- Add a `GroomerProfileRepository` boundary and Supabase implementation.
- Add `GroomerProfileStore` for loading, validation, saving, service CRUD state, and portfolio upload/delete state.
- Add `GroomerProfileManagementView` under the Groomer Account tab.
- Wire production composition so authenticated groomers use the real repository after authoritative role routing.
- Add focused Swift Testing coverage for validation, path contract, service size semantics, and local state updates.

## Explicit Boundaries

- No Supabase migration or remote DDL.
- No request feed, offer creation, booking, chat, review, marketplace discovery, signed image display, or runtime fixtures.
- SwiftUI views do not call Supabase directly.
- Portfolio image display remains metadata-only; binary upload/delete uses the repository and Storage API path.

## UI Semantics

- Groomer Account tab owns profile management because the current groomer shell has no Profile/Home tab.
- A groomer must provide business name, city, state, and service radius before setting the profile active.
- Empty service size selection means the service accepts all pet sizes; selected sizes are unique and stored in canonical small/medium/large/giant order.

## Validation

- One iOS validation attempt: `./scripts/ios-test.sh`.
- No remote Supabase validation is required because T-011 does not change backend schema or policies.
- Result: passed on 2026-06-20 with 32 Swift Testing tests and 1 XCTest UI smoke test (`** TEST SUCCEEDED **`).

## Closeout

T-011 is complete. The implemented client path is:

- Authenticated groomer route → Groomer tabs → Account tab → `GroomerProfileManagementView`.
- View state and validation live in `GroomerProfileStore`.
- Supabase reads/writes/uploads/deletes live behind `GroomerProfileRepository`.
- Portfolio image display remains metadata-only.

Stop after closeout; do not start T-012.
