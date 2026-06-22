# Current State

Update this only when project state meaningfully changes.

## Last Updated

- Date: 2026-06-22
- Updated by: Codex

## Current Task Fast Path

- Active Groomly screen slice: `docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md`.
- Active next executable task: create a new T-025 screen-specific Groomly task file before editing additional non-Auth feature screens.
- T-023A is completed. `docs/08_design/UI_IMPLEMENTATION_NOTES.md` records the Groomly design audit, prototype-to-SwiftUI mapping, deferred prototype ideas, and asset risks.
- T-023B is completed. `docs/08_design/design_tokens.json` is the Groomly token source for colors, spacing, radius, shadow, and typography, with extracted versus inferred values labeled.
- T-023C is completed. `DesignSystem/DesignTokens.swift` now exposes the Groomly SwiftUI token foundation while preserving existing baseline token names.
- T-023D1 is completed. `DesignSystem/GroomlyActionPrimitives.swift` now provides the D1 button, card, and status-chip primitives without wiring them into feature screens.
- T-023D2 is completed. `DesignSystem/GroomlyFeedbackPrimitives.swift` now provides feedback, loading, empty-state, and section-header primitives without wiring them into feature screens.
- T-023A through T-023D2 are the completed Groomly UI foundation sequence.
- T-024 is completed. Auth bootstrap, AuthGate session loading, Sign In, Sign Up, profile loading/error, and Role Onboarding now use Groomly tokens/primitives without changing auth, session, profile, backend, or role-routing behavior.

## Current Branch

- Local Git state: initialized.
- Current branch: `main`.
- Remote `origin`: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App.git`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.

## Current Build Status

- Last build command: `./scripts/ios-build.sh`.
- Last known build result: passed for T-024 on 2026-06-22.
- Last test command: `./scripts/ios-test.sh`.
- Last known test result: passed for T-024 review follow-up on 2026-06-22.
- Last general check: `./scripts/preflight.sh` passed for T-022 on 2026-06-21.
- Known failing checks: none recorded after T-022.
- Historical per-task validation details live in the relevant `docs/06_tasks/T-*.md` files and `docs/00_memory/WORKLOG.md`.

## Current Product State

- The MVP marketplace flow is complete at the current contract level: Customer publishes an open request -> matched groomers make offers -> customer accepts one offer -> booking and chat are created -> groomer completes booking -> customer leaves a review.
- Production routing uses real Supabase Auth, authoritative profile loading, and customer/groomer role separation. No production path fabricates a session/profile.
- Implemented iOS areas include Auth, role onboarding, customer pets, customer requests/offers, groomer requests/offers, bookings, participant text chat, groomer profile/services/portfolio metadata, Account, and a sanitized Debug Panel.
- Active product model remains Open Request -> Groomer Offer -> Customer Confirmation -> Booking. Do not reintroduce task-card push flow.
- Groomly UI adaptation is now the active next phase. Design sources are `docs/08_design/Groomly.html`, `docs/08_design/Groomly/`, `docs/08_design/UI_IMPLEMENTATION_NOTES.md`, `docs/08_design/design_tokens.json`, and `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`.

## Current Workflow State

- Lightweight single-agent workflow is active at `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Pre-Groomly rule/task context is frozen at `docs/09_frozen/pre_groomly_ui_2026-06-21/` for recovery only; do not read it during Groomly foundation child tasks unless explicitly needed for recovery.
- T-001 through T-022 are completed. T-022 post-MVP next-task suggestions are frozen and must not auto-start.
- T-023 is split into five child tasks: T-023A design audit notes, T-023B design tokens JSON, T-023C SwiftUI token foundation, T-023D1 action primitives, and T-023D2 feedback primitives.
- T-023A, T-023B, T-023C, T-023D1, T-023D2, and T-024 are completed. Create a T-025 screen-specific task file before editing additional non-Auth feature screens.

## Current iOS State

- Native project: `ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj`.
- Targets: app, Swift Testing unit tests, and XCTest UI tests; shared scheme `PetGroomerMarketplace`.
- Baseline: Swift 6, minimum iOS 18.0, bundle ID `com.prinnyyy.PetGroomerMarketplace`.
- Structure: feature-first App, Core models/configuration/infrastructure/repositories, DesignSystem, Auth bootstrap, Customer tabs, Customer pets, Customer requests, Bookings, Chat, Debug, Groomer tabs, Groomer requests, and Groomer profile management.
- `DesignSystem/DesignTokens.swift` contains the Groomly SwiftUI token foundation for colors, spacing, radii/shapes, shadows, and Dynamic Type-friendly typography.
- `DesignSystem/GroomlyActionPrimitives.swift` contains `GroomlyPrimaryButtonStyle`, `GroomlySecondaryButtonStyle`, `GroomlyCard`, `GroomlyStatusChip`, and the shared `.groomlyShadow(...)` modifier for DesignSystem primitives.
- `DesignSystem/GroomlyFeedbackPrimitives.swift` contains `GroomlyErrorBanner`, `GroomlyLoadingView`, `GroomlyEmptyState`, and `GroomlySectionHeader`; loading and empty-state primitives support customer/groomer accents for role-specific screens.
- `DesignSystem/GroomlyFormPrimitives.swift` contains `.groomlyFormField()` for token-based Auth/form inputs.
- T-024 wires Groomly primitives into Auth bootstrap, AuthGate loading, Sign In, Sign Up, profile loading/error, and Role Onboarding only.
- SwiftUI views do not access Supabase directly; backend access remains behind repository boundaries.

## Current Backend State

- Authorized Supabase project: `Pet Groomer Marketplace`, ref `lqmasbuqzvcvtawonjlb`.
- Legacy project `swdiiyypysyxbnfrxxsv` is out of scope; do not inspect or mutate it.
- Backend objects needed for the MVP are deployed through T-022 and mirrored under `supabase/migrations/`.
- T-023B, T-023C, T-023D1, T-023D2, and T-024 required no backend reads or writes. Future backend work must use Supabase MCP only and requires explicit user approval for remote schema writes.
- The local `supabase_api_key` file is ignored and must not be read or embedded in code/docs.

## Known Risks

- Xcode 26.5 object version 77 and the configured iPhone 16 Pro/iOS 18.4 simulator are expected by existing scripts.
- Groomly prototype screens may show deferred or unsupported ideas. Treat them as visual inspiration only unless a separate task authorizes product/backend work.
- Deferred features remain out of scope for the Groomly foundation sequence, including request cancellation, favorites, signed URL image rendering, realtime chat, attachments, payments, push notifications, maps, calendars, and admin tooling.
- Default email confirmation still requires browser confirmation and returning to Sign In; native deep-link completion and production SMTP remain separate future work.

## Next Recommended Task

- Create T-025 as the next screen-specific Groomly task file before editing additional non-Auth feature screens. Do not auto-start Customer, Groomer, Bookings, Chat, Account, Debug, or backend work.
