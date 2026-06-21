# T-022 — MVP Hardening and Acceptance

- State: completed.
- Mode: Deep.
- Depends on: T-020 and T-021.
- Scope: MVP state pass, safe developer diagnostics, security/RLS negative checks, booking conflict boundaries, and core end-to-end acceptance.

## Goal

Harden and validate the Fresh Brief MVP without starting deferred features.

## Boundaries

In scope:

- Review existing loading, empty, error, and validation surfaces for the implemented MVP screens.
- Add a developer-only safe Debug Panel.
- Validate core customer-to-groomer flow through rollback-only Supabase MCP checks.
- Validate booking uniqueness/conflict boundaries and required RLS negative cases.
- Run local iOS and repository checks once, with one approved targeted retry for the compile issue found in validation.

Out of scope:

- Payments, push notifications, social login, maps/calendar polish, realtime chat, attachments, admin tools, moderation, subscriptions, request cancellation, rebooking, review editing, and new backend contracts.
- Supabase DDL or new migrations.
- Commits or pushes.

## Implemented Work

- Added `Features/Debug/DebugDiagnostics.swift`.
- Added `Features/Debug/DebugPanelView.swift`.
- Added a Debug-build Account entry to `AuthenticatedAccountView`.
- Added a focused diagnostic safety test in `AppEntryModelsTests`.

The Debug Panel exposes only:

- build configuration,
- bundle identifier,
- role,
- short support reference,
- email domain,
- Supabase URL scheme and host,
- publishable-key configured/missing status.

It does not display access tokens, refresh tokens, passwords, complete API keys, service-role keys, or full user identifiers.

## MVP State Pass

Targeted source review confirmed the implemented MVP screens expose loading, empty, error, and validation states through their existing stores/views:

- Auth and profile entry.
- Customer pets.
- Customer requests and offer review/acceptance.
- Groomer profile/services/portfolio.
- Groomer matched requests and offers.
- Bookings cancellation/completion/review.
- Participant chat conversations/messages.

No broad UX refactor was made in T-022.

## Supabase MCP Validation

No schema migration or remote DDL was applied.

MCP checks used the authorized fresh project only:

- Project: `lqmasbuqzvcvtawonjlb`.
- Legacy project: not inspected or mutated.

Rollback-only validation passed for:

- customer request creation;
- groomer offer creation by two matched groomers;
- customer acceptance into booking and conversation;
- competing pending offer closure;
- participant message insert/read;
- non-participant booking/message/review invisibility;
- non-participant message insert denial;
- direct authenticated booking insert denial;
- boundary-touching groomer booking acceptance;
- overlapping groomer booking rejection with `booking_conflict`;
- groomer completion;
- customer review creation with server-trimmed content;
- direct authenticated review insert denial.

Residue check after rollback:

- remaining validation Auth users: `0`;
- remaining validation profiles: `0`;
- remaining validation requests: `0`;
- remaining validation bookings: `0`;
- remaining validation reviews: `0`.

Advisor checkpoint:

- Security advisor still reports the eight expected intentional `SECURITY DEFINER` WARNs for controlled RPCs.
- Performance advisor reports existing non-blocking composite-FK and unused-index INFOs; no new schema changes were made.

## Local Validation

Commands run:

```sh
./scripts/supabase-check.sh
./scripts/ios-test.sh
./scripts/preflight.sh
git diff --check
```

Initial `./scripts/ios-test.sh` failed before tests completed.

First real error:

```text
Call to main actor-isolated static method 'parse(urlValue:publishableKeyValue:)'
in a synchronous nonisolated context
```

Root cause:

- The new Debug diagnostics test accessed MainActor-isolated app types while the test method was not MainActor-isolated.

Approved targeted fix:

- Added `@MainActor` to `diagnosticsHideSecretsAndUseSupportReferences()`.

Final validation:

- `./scripts/supabase-check.sh` passed.
- `./scripts/ios-test.sh` passed with `** TEST SUCCEEDED **`; Swift Testing suite and 1 XCTest UI smoke passed.
- `./scripts/preflight.sh` passed.
- `git diff --check` passed.

## Closeout

T-022 is complete. The MVP is hardened and accepted at the current contract level. Remaining items are explicit post-MVP/product decisions rather than unclosed T-022 scope.

Recommended next step: choose the next phase deliberately, such as request cancellation/rebooking, richer participant summaries, realtime chat, production Auth/email setup, or App Store readiness.
