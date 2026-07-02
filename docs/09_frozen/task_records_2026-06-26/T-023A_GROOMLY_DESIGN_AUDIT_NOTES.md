# T-023A - Groomly Design Audit Notes

- State: planned.
- Mode: Quick.
- Parent: `T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`.
- Depends on: T-022 completion and readable Groomly design files.

## Goal

Inspect the Groomly prototype and write the design handoff summary. This task produces documentation only and does not create design tokens JSON or edit Swift files.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`
4. `docs/08_design/Groomly.html`
5. `docs/08_design/Groomly/`
6. `docs/01_product/SCREEN_INVENTORY.md`
7. the current SwiftUI file list from `rg --files ios/PetGroomerMarketplace/PetGroomerMarketplace`

Do not read archived workflow docs or old agent reports.

## Scope

In scope:

- Inspect the root `Groomly.html`.
- Inspect the extracted `docs/08_design/Groomly/` folder.
- Treat missing `docs/08_design/Groomly.zip` as non-blocking because the extracted folder exists.
- Create `docs/08_design/UI_IMPLEMENTATION_NOTES.md`.
- Update `docs/00_memory/CURRENT_STATE.md`, `docs/00_memory/WORKLOG.md`, and `docs/06_tasks/TASK_LEDGER.md` only enough to mark T-023A completion and T-023B as the next task.

Out of scope:

- Creating or editing `docs/08_design/design_tokens.json`.
- Editing Swift, Xcode, Supabase, scripts, or backend docs.
- Redesigning feature screens.
- Adding assets to the app.
- Implementing any prototype-only or deferred feature.

## Required Output

Create `docs/08_design/UI_IMPLEMENTATION_NOTES.md` with these sections:

1. Design Sources Inspected.
2. Detected Brand Name.
3. Core Visual Direction.
4. Core Colors Observed.
5. Typography Direction.
6. Spacing, Radius, and Shadow Patterns.
7. Major Prototype Screens.
8. Reusable Components Detected.
9. Customer Screens Detected.
10. Groomer Screens Detected.
11. Current App States That Must Be Preserved.
12. Prototype-to-SwiftUI Screen Mapping.
13. Deferred or Unsupported Prototype Ideas.
14. Asset Notes and Open Risks.

The mapping section must connect prototype screens to current SwiftUI files, including at least:

- Auth and onboarding: `Features/Auth/`
- Customer pets: `Features/Customer/Pets/CustomerPetsView.swift`
- Customer requests and offers: `Features/Customer/Requests/CustomerRequestsView.swift`
- Groomer requests and offer creation: `Features/Groomer/Requests/GroomerRequestsView.swift`
- Bookings: `Features/Bookings/BookingsView.swift`
- Chat: `Features/Chat/ChatView.swift`
- Account, groomer profile, and Debug Panel: `Features/Auth/AuthenticatedAccountView.swift`, `Features/Groomer/Profile/GroomerProfileManagementView.swift`, and `Features/Debug/DebugPanelView.swift`

## Validation

Run:

```sh
test -f docs/08_design/UI_IMPLEMENTATION_NOTES.md
git diff --check
```

Do not run `./scripts/ios-build.sh` because this task must not change Swift or project files.

## Acceptance

- `UI_IMPLEMENTATION_NOTES.md` exists.
- The notes identify design sources, brand, colors, typography, layout patterns, screens, components, role-specific screens, preserved app states, file mapping, deferred prototype ideas, and asset risks.
- No Swift, backend, Supabase, script, or Xcode file is changed.
- `git diff --check` passes.
- Task ledger and current state point to T-023B as the next child task.

## Stop Conditions

Stop and report if:

- The Groomly design files cannot be read.
- Asset source or licensing is unclear enough to affect future app asset use.
- The prototype appears to require backend/schema/product-flow changes.
- Existing user changes conflict with this documentation-only task.
