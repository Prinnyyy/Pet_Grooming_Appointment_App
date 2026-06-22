# Current State

Update this only when project state meaningfully changes.

## Last Updated

- Date: 2026-06-22
- Updated by: Codex

## Current Task Fast Path

- Latest completed Groomly screen slice: `docs/06_tasks/T-035_GROOMLY_ACCOUNT_TABS_DEBUG_FINAL_UI.md`.
- Groomly UI sequence: `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md` is completed for implemented MVP screens.
- Active next executable Groomly task: none currently defined.
- Planned sequence after T-035: no remaining Groomly UI screen slice is currently defined.
- T-023A is completed. `docs/08_design/UI_IMPLEMENTATION_NOTES.md` records the Groomly design audit, prototype-to-SwiftUI mapping, deferred prototype ideas, and asset risks.
- T-023B is completed. `docs/08_design/design_tokens.json` is the Groomly token source for colors, spacing, radius, shadow, and typography, with extracted versus inferred values labeled.
- T-023C is completed. `DesignSystem/DesignTokens.swift` now exposes the Groomly SwiftUI token foundation while preserving existing baseline token names.
- T-023D1 is completed. `DesignSystem/GroomlyActionPrimitives.swift` now provides the D1 button, card, and status-chip primitives without wiring them into feature screens.
- T-023D2 is completed. `DesignSystem/GroomlyFeedbackPrimitives.swift` now provides feedback, loading, empty-state, and section-header primitives without wiring them into feature screens.
- T-023A through T-023D2 are the completed Groomly UI foundation sequence.
- T-024 is completed. Auth bootstrap, AuthGate session loading, Sign In, Sign Up, profile loading/error, and Role Onboarding now use Groomly tokens/primitives without changing auth, session, profile, backend, or role-routing behavior.
- T-025 is completed. Customer Home/Pets now uses Groomly background, cards, loading, empty, error, notice, status, button, and form styling without changing pet Store, repository, model, photo metadata, upload/delete, or Storage behavior.
- T-026 is completed. Customer Requests tab shell, request list, summary rows, loading, empty, error, and bottom status states now use Groomly styling without changing request Store, repository, model, navigation, wizard, detail, offer, booking, or backend behavior.
- T-027 is completed. Customer Request wizard form, card grouping, fields, review summary, error banner, and publish action now use Groomly styling without changing request validation, Store calls, RPC inputs, repository, model, detail, offers, booking, or backend behavior.
- T-028 is completed. Customer-owned request detail, pending/history offer review, offer detail, and offer acceptance entry now use Groomly styling without changing offer loading, acceptance semantics, booking creation side effects, Store ownership, repositories, models, or backend behavior.
- T-029 is completed. Groomer matched-request feed, summary rows, detail shell, dismiss action, and bottom status feedback now use Groomly styling without changing matching, dismissal, offer eligibility, Store ownership, repositories, models, or backend behavior.
- T-030 is completed. Groomer offer creation fields, existing offer status blocks, withdraw action, closed-offer notice, and submit action now use Groomly styling without changing create/withdraw semantics, validation, Store ownership, repositories, models, or backend behavior.
- T-031 is completed. Groomer profile form, services list, service create/edit sheet, and profile/service status feedback now use Groomly styling without changing profile/service validation, Store ownership, repositories, models, portfolio Storage behavior, or backend behavior.
- T-032 is completed. Groomer portfolio metadata rows, upload action, delete action, empty state, and upload progress feedback now use Groomly styling without changing portfolio Storage metadata behavior, Store ownership, repositories, models, signed URL support, or backend behavior.
- T-033 is completed. Shared customer/groomer booking lists, booking detail, lifecycle actions, review display/form, and booking status feedback now use Groomly styling without changing booking Store, repository, model, backend, status semantics, or role behavior.
- T-034 is completed. Participant conversation list, chat thread, message rows, composer, and chat status feedback now use Groomly styling without changing chat Store, repository, model, backend, text-only message behavior, or participant access assumptions.
- T-035 is completed. Authenticated Account, customer/groomer tab shells, disconnected placeholder fallback, and the sanitized Debug Panel now use Groomly styling without changing sign-out, tab ownership, debug diagnostic data sources, repositories, models, or backend behavior.

## Current Branch

- Local Git state: initialized.
- Current branch: `main`.
- Remote `origin`: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App.git`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.

## Current Build Status

- Last build command: `./scripts/ios-build.sh`.
- Last known build result: passed for T-035 on 2026-06-22.
- Last test command: `./scripts/ios-test.sh`.
- Last known test result: passed for T-035 review follow-up on 2026-06-22.
- Last general check: `./scripts/preflight.sh` passed for T-035 review follow-up on 2026-06-22.
- Known failing checks: none recorded after T-022.
- Historical per-task validation details live in the relevant `docs/06_tasks/T-*.md` files and `docs/00_memory/WORKLOG.md`.

## Current Product State

- The MVP marketplace flow is complete at the current contract level: Customer publishes an open request -> matched groomers make offers -> customer accepts one offer -> booking and chat are created -> groomer completes booking -> customer leaves a review.
- Production routing uses real Supabase Auth, authoritative profile loading, and customer/groomer role separation. No production path fabricates a session/profile.
- Implemented iOS areas include Auth, role onboarding, customer pets, customer requests/offers, groomer requests/offers, bookings, participant text chat, groomer profile/services/portfolio metadata, Account, and a sanitized Debug Panel.
- Active product model remains Open Request -> Groomer Offer -> Customer Confirmation -> Booking. Do not reintroduce task-card push flow.
- Groomly UI adaptation is complete for implemented MVP screens. Design sources remain `docs/08_design/Groomly.html`, `docs/08_design/Groomly/`, `docs/08_design/UI_IMPLEMENTATION_NOTES.md`, `docs/08_design/design_tokens.json`, and `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`.

## Current Workflow State

- Lightweight single-agent workflow is active at `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Pre-Groomly rule/task context is frozen at `docs/09_frozen/pre_groomly_ui_2026-06-21/` for recovery only; do not read it during Groomly foundation child tasks unless explicitly needed for recovery.
- T-001 through T-022 are completed. T-022 post-MVP next-task suggestions are frozen and must not auto-start.
- T-023 is split into five child tasks: T-023A design audit notes, T-023B design tokens JSON, T-023C SwiftUI token foundation, T-023D1 action primitives, and T-023D2 feedback primitives.
- T-023A, T-023B, T-023C, T-023D1, T-023D2, and T-024 through T-035 are completed. No remaining Groomly UI sequence task is currently defined.

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
- T-025 wires Groomly primitives into Customer Home/Pets, including the pet list, pet cards, photo metadata rows, loading/empty/error/notice states, and add/edit pet form styling only.
- T-026 wires Groomly primitives into the Customer Requests tab shell, request list, summary rows, loading/empty/error states, new-request entry card, and bottom status feedback only.
- T-027 wires Groomly primitives into the Customer Request wizard form, field cards, review summary, wizard error banner, and publish action only.
- T-028 wires Groomly primitives into Customer Request detail, offer review pending/history groups, offer detail, and offer acceptance entry only.
- T-029 wires Groomly primitives into Groomer Requests feed, matched request summary rows, detail shell metadata cards, dismiss action, and bottom status feedback only.
- T-030 wires Groomly primitives into the Groomer offer creation form, existing offer status blocks, withdraw action, closed-offer notice, and submit action only.
- T-031 wires Groomly primitives into Groomer profile form, services list, service create/edit sheet, and profile/service status feedback only.
- T-032 wires Groomly primitives into Groomer portfolio metadata rows, upload/delete controls, empty state, and upload progress feedback only; remote portfolio image rendering remains deferred.
- T-033 wires Groomly primitives into shared customer/groomer booking lists, booking detail sections, cancellation/completion controls, review display/form, and booking status feedback only.
- T-034 wires Groomly primitives into participant conversation lists, chat thread sections, message bubbles, composer styling, and chat status feedback only; realtime chat and attachments remain deferred.
- T-035 wires Groomly primitives into Authenticated Account, customer/groomer tab shells, disconnected placeholder fallback, and the sanitized Debug Panel only; Admin Dashboard remains deferred.
- SwiftUI views do not access Supabase directly; backend access remains behind repository boundaries.

## Current Backend State

- Authorized Supabase project: `Pet Groomer Marketplace`, ref `lqmasbuqzvcvtawonjlb`.
- Legacy project `swdiiyypysyxbnfrxxsv` is out of scope; do not inspect or mutate it.
- Backend objects needed for the MVP are deployed through T-022 and mirrored under `supabase/migrations/`.
- T-023B, T-023C, T-023D1, T-023D2, and T-024 through T-035 required no backend reads or writes. Future backend work must use Supabase MCP only and requires explicit user approval for remote schema writes.
- The local `supabase_api_key` file is ignored and must not be read or embedded in code/docs.

## Known Risks

- Xcode 26.5 object version 77 and the configured iPhone 16 Pro/iOS 18.4 simulator are expected by existing scripts.
- Groomly prototype screens may show deferred or unsupported ideas. Treat them as visual inspiration only unless a separate task authorizes product/backend work.
- Deferred features remain out of scope for the Groomly foundation sequence, including request cancellation, favorites, signed URL image rendering, realtime chat, attachments, payments, push notifications, maps, calendars, and admin tooling.
- Default email confirmation still requires browser confirmation and returning to Sign In; native deep-link completion and production SMTP remain separate future work.

## Next Recommended Task

- No next Groomly UI task is currently defined. Wait for an explicit user-selected task before starting backend, post-MVP feature work, or Admin Dashboard work.
