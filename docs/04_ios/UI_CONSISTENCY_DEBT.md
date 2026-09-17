# UI Consistency Debt

Last generated: 2026-07-13 by T-343.

This is the active inventory of remaining SwiftUI consistency debt. Rule definitions, severities, commands, baseline lifecycle, and exceptions remain authoritative in `UI_CODE_GOVERNANCE.md`; do not duplicate them here.

## Snapshot

- Repository check: 203 findings, comprising 195 baselined legacy findings and 8 reviewed unbaselined warnings.
- Ratchet state: zero new errors and zero stale baseline entries.
- Migrated-slice strict gate: zero errors across Customer Home, Requests, Request Wizard, and Account.
- Evidence: ignored local artifacts under `artifacts/evidence/Q-120/`; full iOS tests, build, preflight, default/Accessibility 3 compact/large rendering, and semantic inspection passed.

Audit findings are source candidates, not automatically confirmed visual defects. A baseline entry records migration debt rather than approval of the implementation.

## Findings By Rule

| Rule | Count |
|---|---:|
| UI101 fixed-frame review | 75 |
| UI102 layout-repair review | 13 |
| UI001 fixed-size typography | 8 |
| UI002 direct platform typography | 64 |
| UI003 raw color | 3 |
| UI004 numeric spacing | 8 |
| UI005 numeric shape/radius | 14 |
| UI008 low text scaling | 18 |

## Concentration

| Feature area | Count |
|---|---:|
| Groomer | 113 |
| Customer | 25 |
| Chat | 24 |
| Bookings | 23 |
| Auth | 18 |

Highest-count files are `Groomer/Home/GroomerHomeView.swift` (35), `Chat/ChatView.swift` (24), `Bookings/BookingsView.swift` (23), `Groomer/Profile/GroomerFitSignalsEditorView.swift` (20), and `Auth/AuthenticationView.swift` (16).

T-343 moved the Groomer Account/Profile subtree onto shared Account, section, grouped-surface, settings-row, divider, and photo-editor primitives. Remaining Groomer findings are tracked migration candidates; Q-104 Accessibility/Dynamic Type remains deferred.

## Migrated Reference Slice

The following Feature paths have zero strict errors:

- `Customer/Pets/CustomerPetsView.swift`
- `Customer/Requests/CustomerRequestsView.swift`
- `Customer/Requests/CustomerRequestsDashboardView.swift`
- `Customer/Requests/CustomerRequestWizardView.swift`
- `Customer/Profile/CustomerAccountView.swift`

Remaining warnings in this slice are reviewed non-text geometry: notification/badge and hero decoration, pet carousel media tiles, request information icon slots, Wizard progress/photo geometry, and selection/status icon dimensions. Four warnings are intentionally outside the legacy baseline: two 172pt Home carousel tiles, the Wizard progress track, and the 112pt photo picker. They are not source exceptions and remain visible to every audit.

## Recommended Migration Order

1. Groomer Home, because it has the largest single-file concentration and shared workspace impact.
2. Chat, then Bookings, because each is a shared cross-role surface with concentrated debt.
3. Groomer Fit Signals and Availability, followed by the remaining Groomer editors and request surfaces.
4. Authentication and the remaining Customer files after the higher-impact shared surfaces.

Q-104 Groomer Dynamic Type/Accessibility remains explicitly user-deferred. This ordering is planning input only and does not reactivate Q-104 or authorize a broad migration.
