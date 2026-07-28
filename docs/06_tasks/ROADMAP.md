# Managed Roadmap

Last verified: 2026-07-28.

Governed product direction and unresolved packages only. Task status and numbering live in `TASK_LEDGER.md`; adoptable packages live in `ROADMAP_EXECUTION_QUEUE.md`; completed roadmap history is frozen.

## Adoption Rules

- External reports and root roadmap drafts are review input only.
- A roadmap item becomes active only after the user asks to adopt or execute it.
- Roadmap and queue IDs never allocate `T-###`; implementation claims the next task ID from `TASK_LEDGER.md`.
- Split work that combines independent product goals or mixes local implementation with remote writes.
- Product/release scope decisions require an entry in `../07_decisions/DECISION_LOG.md`.
- Do not start another roadmap item automatically after closeout.

## Product Boundary

Beckon's supported marketplace flow is Customer Request -> Groomer Offer -> Customer Acceptance -> Booking/Chat -> Groomer Completion -> Customer Review. SwiftUI uses Store/repository boundaries rather than direct Supabase access, and remote writes require explicit authorization.

Out of scope unless explicitly adopted: payments, subscriptions, public directory, map-first discovery, AI recommendations, multi-pet requests, favorites, chat attachments/read receipts, request editing, moderation/admin tooling, social login, and direct customer slot booking.

## Unresolved Direction

| Roadmap | Package | State | Resume Condition |
|---|---|---|---|
| R-039 | Q-104 Groomer Dynamic Type and Accessibility integration | deferred | The user restores this scope and approves affected cross-screen validation. |
| R-042 | Q-125 Customer Request Journey remediation | ready | Execute Q-125 next. |
| R-030 | Q-90 APNs dispatch deployment | blocked | T-157 receives paid Apple Developer access, APNs credentials, and deploy authorization. |
| R-030 | Q-91 TestFlight/App Store submission | blocked | Paid Apple Developer setup and explicit release/upload authorization exist. |
| R-033 | Q-93 leaked-password protection | blocked | Supabase Pro-or-higher capability and Auth configuration authorization exist. |

R-042 remains adopted but no package is automatically active. T-362 completed Q-124, and Q-125 is the final dependency-satisfied package.

## Customer Request Journey Remediation

T-357 adopts R-042 from the Customer Request Journey audit. The sequence protects Request correctness before changing form, media, decision, and presentation behavior:

1. Q-121 makes publish operations idempotent and separates authoritative Request creation from recoverable photo-upload and refresh failures.
2. Q-122 requires intentional service/custom-detail input, extends date access beyond the quick strip, and aligns Continue validation with its visible state.
3. Q-123 gives Request-specific photos preview, removal, review, and retry behavior without merging them with Pet avatars.
4. Q-124 adds an informed Offer acceptance step and direct Booking handoff while preserving existing stale-offer protection.
5. Q-125 corrects creation entry, loading/empty/error states, carousel position, reviewed copy, contrast, and strict UI-audit debt.

R-042 does not change matching rules, Groomer offer creation, booking lifecycle semantics, dependencies, social login, direct booking, or the user-deferred Groomer Dynamic Type/Accessibility package Q-104. Q-122 through Q-125 are local Standard tasks unless implementation discovers a new backend contract.

## V1 Readiness Signals

- The dual-role marketplace lifecycle completes without placeholder behavior.
- Required fields persist, private images load through authenticated paths, and cancellation/recovery states are clear.
- Account deletion, Privacy Policy, Support, Privacy Manifest, and release metadata remain current.
- Build, focused/full test, TestOps, backend advisor, and cleanup gates are selected by task risk.
- Apple/APNs and paid-plan blockers remain explicit rather than being represented as implemented.

## Historical Record

The pre-rotation roadmap and completed milestone/candidate mappings are preserved in `../09_frozen/roadmaps/T-346_2026-07-13/`. Current architecture and product facts belong in their domain documents, not in restored completed-roadmap tables.
