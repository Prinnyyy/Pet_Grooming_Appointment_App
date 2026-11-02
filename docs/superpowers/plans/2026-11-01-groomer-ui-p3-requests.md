<!-- task-artifact
task: T-431
status: completed
type: plan
-->

# Handoff 4 P3 — requests and offers

Reads: section 3 items 5, 6, 13; D6; appendix A P3, B, C. Follow D-069 and the user's latest instruction: preserve the verified new flow, adapt old implementation/design rules.

- [x] One row and one request/offer detail, pure stage/groups, existing form and session guards.
- [x] Separate read/pagination/action errors, keep production operation recovery and all non-retired identifiers.
- [x] Adapt host/test routes, test stage/boundaries/offer form; Debug/Release/static checks.

## Section 10 report

| Production file | Prototype twin / adopted part |
|---|---|
| `Requests/GroomerRequestsView.swift` | `PrototypeGroomerRequestsView`: unanswered Matches, stage groups in Offers, sort row, shared row, collapsed Earlier; real load completion instead of timer |
| `Requests/GroomerRequestStage.swift` | `PrototypeGroomerRequestStage`: subject, stages/holds/problems, groups and request activity; additionally close stale-open requests at the actual deadline |
| `Requests/GroomerRequestRow.swift` | `PrototypeGroomerRequestRow`: time/pet/three-line row, invited highlight, New mark, foot note, accessibility stacking |
| `Requests/GroomerRequestDetailView.swift` | `PrototypeGroomerRequestDetailView`: one request/offer page, confirmation/withdraw/dismiss, pinned submit, activity, booking handoff |
| `Requests/GroomerRequestDetailParts.swift` | `PrototypeGroomerRequestDetailParts`: Why matched via existing shared fit-evidence block, request, offer record and booking link |
| `Requests/GroomerOfferForm.swift` | `PrototypeGroomerOfferForm`: reuse real form state, focus policy, assessment confirmations, service timezone/date handling and identifiers |
| `Features/Groomer/GroomerPetCard.swift` | `PrototypeGroomerPetCard`, using P2 PetAvatar; normalize the global age helper to avoid collision with protected prototype |
| `Features/Customer/Grooming/GroomingDetailParts.swift` | Only Hero.Path and timeline identifier parameters from its twin, required ahead of P4; customer defaults and remaining detail plumbing preserved |
| `Features/Groomer/Offers/GroomerOffersView.swift` | Removed the superseded page/rows/status adapter rather than retain a duplicate runtime implementation |
| `Features/Groomer/GroomerTabView.swift`, Notifications view | Inject shell-owned request/offer Stores, preserve target booking callback, install session validation before Home notification entry |
| Request/offer Stores, both notification Stores/views | Keep all existing repository calls/guards, receipt/cancellation behavior and compatibility errorMessage; add independent read/pagination/action error ownership. Restore old notification open button id beneath new row container id |
| Owned groomer sandbox request repository | Create/withdraw now store actual input, match/offer state and history across reload instead of returning success without mutation |
| TestOps marketplace acceptance tests | Merged detail route, confirmation button and Offer withdrawn activity assertion replace retired intermediate offer page |

Production preserved: Store/repository/backend validation, session invalidation, draft validation, focus and service-timezone behavior, authorized detail and private photo reads, opaque IDs, cancellation/receipt recovery, current customer navigation/launch/chat. D-069 adopts the new semantics; no rank weights, SQL or credential changes. Raw matched records remain available even after leaving Matches so a notification still resolves the same request.

Findings fixed: prototype stages ignored clock expiry when raw status remained open; exact-boundary test reproduced that and now passes. Fixture create/withdraw ACKs did not survive reload, now covered by a submit→reload→withdraw→reload test on real Stores. Full-read/pagination/action errors no longer leak between the footer, page card and toast. The UI follows the validated new layout; these are logic/wiring fixes.

Validation: Debug generic Simulator build passed; initial relevant Store/hosted-form test run **73 passed, 1 failed** (the new intentional expiry regression), zero skips. After corrections, final stage/error/notification run **27/27 passed**, zero skips, including local mutation round trip and exact expiry. Reuse unaffected Store/form-rendering evidence. Release generic Simulator build, preflight, UI audit, document hygiene and whitespace passed. Node boundary/source/audit tests **47/47 passed**; 11 resolved legacy baseline entries pruned, no broad exemption. Evidence: `/tmp/beckon-handoff4/p3-*`. No manual screenshot/visual approval claimed; user performs visual inspection. Local automated tap-through coverage is completed at the final gate; remote TestOps/account mutation flows are not claimed as run.

D1 trait/carrier retained. D2 is approved and remains P7, D3 already implemented, D4 belongs to P4 authorized booking snapshots, D5/P2 remains unchanged, D6 implemented here, D7 keeps T-428 separate, D8 chat unchanged, D9 shared kit/tier rules retained, D10 belongs to P6. Protected prototype trees and user governance/signing edits preserved. Continue immediately to P4.
