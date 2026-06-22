# Current State

Update this only when project state meaningfully changes.

## Last Updated

- Date: 2026-06-22
- Updated by: Codex

## Current Task Fast Path

- Latest completed Groomly screenshot task: `docs/06_tasks/T-041_GROOMLY_CUSTOMER_REQUESTS_STATUS_SCREENSHOT_UI.md`.
- Latest completed Groomly UI refinement task: `docs/06_tasks/T-043_GROOMLY_CUSTOMER_REQUESTS_CAROUSEL_EDGE_REFINEMENT.md`.
- Latest completed request feature task: `docs/06_tasks/T-047_GROOMLY_CUSTOMER_REQUEST_BOOKED_CARD_LAYOUT.md`.
- Groomly UI sequence: `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md` is completed for implemented MVP screens.
- Completed Groomly UI phase archive marker: `docs/09_frozen/groomly_ui_completed_2026-06-22/FREEZE_README.md`.
- Active next executable Groomly task: none currently defined; future UI work starts from a user-uploaded screenshot.
- Screenshot-driven task template: `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`.
- Superseded mandatory completion gate task: `docs/06_tasks/WORKFLOW-COMPLETION-GATE-001.md`.
- Lightweight workflow gates task: `docs/06_tasks/WORKFLOW-LIGHTWEIGHT-GATES-001.md`.
- Screenshot ignore rule task: `docs/06_tasks/WORKFLOW-SCREENSHOT-IGNORE-EXTERNAL-ROLE-TOGGLE-001.md`.
- Planned sequence after T-035: no remaining fixed Groomly UI screen slice is currently defined.
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
- T-036 is completed. It introduced the screenshot-driven signed-out landing surface, dropping circular hero animation, floating bubbles, and CTAs into the existing sign-up/sign-in form flow.
- T-037 is completed. The incorrect pre-auth Customer/Groomer toggle and `LandingAudience`-driven derivative UI states were removed; the signed-out landing now uses one dog/Groomly identity, stronger bubble drift, and rebalanced logo/title/CTA layout without changing Auth, profile, backend, or role-routing behavior.
- T-038 is completed. The sign-in page now follows the prototype hierarchy with a left-aligned `Welcome back` header, labeled email/password fields, local Show/Hide password control, primary `Sign In`, and secondary `Create Account`; the bottom DEMO module and pre-auth Customer/Groomer toggle were not implemented.
- T-039 is completed. The two-field sign-in state now tightens only the fields-to-actions spacing while preserving the header-to-fields top anchor and leaving the three-field create-account spacing unchanged.
- T-040 is completed. Customer Home now uses the prototype-inspired dashboard order with a profile display-name welcome header, static notification button, mint request CTA, horizontal pets carousel, add pet tile, active request summary, and next booking summary. It reuses existing pet/request/booking stores and existing pet form, request wizard/detail, and booking detail; notification behavior, avatar URLs, and booking participant names remain unimplemented model/backend gaps.
- T-041 is completed. Customer Requests now uses a prototype-inspired status-first root page with a synced request title, status chip, vertical timeline, action row, preserved create-request entry, and optional other-request access. The prototype matched-groomer list was ignored per user request/current support; its historical unavailable cancellation path was superseded by T-044.
- T-042 is completed. Customer Requests no longer shows a start grooming request module. Requests now render as horizontally scrollable per-request progress cards with request summary, timeline, and actions inside each card.
- T-043 is completed. Customer Requests carousel now bleeds to screen edges and disables ScrollView clipping so request card shadows are not cut by an inner rectangular viewport.
- T-044 is completed. Customer Requests cards now use a fixed `Detail` action and a real `Cancel` action for unconfirmed `open`/`has_offers` requests. The iOS Store/repository calls the deployed `cancel_grooming_request` RPC; booked/cancelled/expired requests keep `Cancel` disabled.
- T-045 is completed. Customer Requests now filters its main cards to `open`/`has_offers` requests plus `booked` request handoff cards backed by matching confirmed bookings. `View Booking` opens the existing Booking detail and removes the handoff from the current UI session only; cancelled/expired requests and completed/cancelled bookings are not shown there.
- T-046 is completed. The booked request handoff no longer uses a separate card style. `booked` requests with matching confirmed bookings now render through the quest action card with the pet avatar retained, handoff title/body text, a compact completed timeline, a green confirmed border, and a single `View Booking` CTA. Opening `View Booking` persists the acknowledgement locally for that customer so the handoff stays hidden after app restart on the same device.
- T-047 is completed. Booked handoff quest cards now use the same quest action card layout metrics as unconfirmed request cards, replace the handoff paragraph with the original request title, add the request address under the confirmed booking time, center the first carousel card, use larger explicit two-line card headlines and two-line time ranges, unify `Detail`/`Cancel`/`View Booking` button structure, and keep T-046 same-device acknowledgement persistence.

## Current Branch

- Local Git state: initialized.
- Current branch: `main`.
- Remote `origin`: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App.git`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.

## Current Build Status

- Last build command: `./scripts/ios-build.sh`.
- Last known build result: passed for T-047 on 2026-06-22.
- Last test command: `xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' test -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests`.
- Last known test result: targeted T-047 CustomerRequestsStoreTests passed on 2026-06-22.
- Last simulator launch: XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`) on 2026-06-22; app launched successfully for inspection. Screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_21a2af42-0578-4de8-bdab-6dd390783648.jpg`.
- Last general check: `git diff --check` passed for T-047 on 2026-06-22.
- Known failing checks: none recorded after T-022.
- Historical per-task validation details live in the relevant `docs/06_tasks/T-*.md` files and `docs/00_memory/WORKLOG.md`.

## Current Product State

- The MVP marketplace flow is complete at the current contract level: Customer publishes an open request -> matched groomers make offers -> customer accepts one offer -> booking and chat are created -> groomer completes booking -> customer leaves a review.
- Production routing uses real Supabase Auth, authoritative profile loading, and customer/groomer role separation. No production path fabricates a session/profile.
- Implemented iOS areas include Auth, role onboarding, customer pets, customer requests/offers, groomer requests/offers, bookings, participant text chat, groomer profile/services/portfolio metadata, Account, and a sanitized Debug Panel.
- Active product model remains Open Request -> Groomer Offer -> Customer Confirmation -> Booking. Do not reintroduce task-card push flow.
- Customer Requests owns only pre-confirmation request work: it shows active `open`/`has_offers` request cards and a `booked` -> Booking handoff when a matching confirmed booking exists. The handoff is displayed inside the same quest action card layout as unconfirmed requests, swaps to a confirmed title and `View Booking` CTA, and is hidden after `View Booking` is acknowledged locally on the same device. Confirmed appointment lifecycle remains in Bookings.
- Groomly UI adaptation is complete for implemented MVP screens and archived as historical context. Future Groomly UI changes are screenshot-driven rework tasks that must map screenshot modules to existing SwiftUI/Store/repository/model paths or stop for new-feature approval. Design sources remain `docs/08_design/Groomly.html`, `docs/08_design/Groomly/`, `docs/08_design/UI_IMPLEMENTATION_NOTES.md`, `docs/08_design/design_tokens.json`, and `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`.

## Current Workflow State

- Lightweight single-agent workflow is active at `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.
- Completion gates are adaptive by task mode and risk: Micro tasks stay lightweight; Quick docs/workflow tasks usually run only `git diff --check`; Standard app/UI tasks run build validation and launch the simulator for visible app changes; Deep tasks require an explicit validation plan.
- Task closeout, durable memory updates, and simulator launch are not required for every small task. They are required when an active task file exists, app behavior changes, future runs need the state, screenshot UI work is implemented, or the user asks for inspection.
- Screenshot analysis must ignore any long oval Customer/Groomer toggle located above the visible app screen frame; treat it as an external prototype/control annotation, not an app module to map, classify, or implement.
- Pre-Groomly rule/task context is frozen at `docs/09_frozen/pre_groomly_ui_2026-06-21/` for recovery only; do not read it during Groomly foundation child tasks unless explicitly needed for recovery.
- Completed Groomly UI phase context is marked at `docs/09_frozen/groomly_ui_completed_2026-06-22/FREEZE_README.md`; completed task files remain in `docs/06_tasks/` for history and should not be treated as active tasks.
- T-001 through T-022 are completed. T-022 post-MVP next-task suggestions are frozen and must not auto-start.
- T-023 is split into five child tasks: T-023A design audit notes, T-023B design tokens JSON, T-023C SwiftUI token foundation, T-023D1 action primitives, and T-023D2 feedback primitives.
- T-023A, T-023B, T-023C, T-023D1, T-023D2, and T-024 through T-035 are completed. No remaining fixed Groomly UI sequence task is currently defined.
- Future screenshot-driven UI tasks must use `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`, analyze the screenshot before SwiftUI edits, reuse existing backend-backed modules through current Store/repository/model boundaries, and stop before implementing new features unless explicitly approved.

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
- T-036 introduced the signed-out AuthenticationView landing-first shell with entry animations, floating bubbles, and CTA routing into the existing sign-up/sign-in form.
- T-037 removes the mistakenly implemented pre-auth Customer/Groomer selector and all `LandingAudience`-derived variants from `AuthenticationView`. The signed-out landing now has a single dog/Groomly hero, more visible bubble drift, rebalanced logo/title/CTA spacing, and fixed customer-accent styling only as a brand treatment.
- T-038 redesigns the `AuthenticationView` sign-in form from the login screenshot: left-aligned title/subtitle, labeled email/password fields, a local Show/Hide password toggle, primary Sign In, and secondary Create Account. The old auth mode segmented picker was removed from the form surface, while `AuthenticationStore.mode` and `submit()` remain the behavioral path.
- T-039 preserves the sign-in form's header-to-fields top spacing and tightens only `fieldsToActionsSpacing` for the two-field `.signIn` state. The `.signUp` three-field spacing remains unchanged.
- T-040 redesigns Customer Home from the uploaded customer-home screenshots: `CustomerTabView` now passes `MarketplaceProfile.displayName` into Home; `CustomerPetsView` owns existing pet/request/booking stores to render the welcome header, static notification button, request CTA, horizontal pet carousel, add pet tile, active request summary, and next booking summary; `CustomerRequestWizardView`, `CustomerRequestDetailView`, `CustomerRequestsStatusView`, and `BookingDetailView` were made module-internal for reuse from Home without new data paths.
- T-041 redesigns the Customer Requests root from the uploaded request-status screenshots: `CustomerRequestsView` now renders a status-first dashboard from existing `CustomerRequestsStore.requests` and `GroomingRequestStatus`, with a hero, status chip, vertical timeline, existing detail navigation, existing create-request entry, and optional other-request list. Its historical unavailable cancellation path was superseded by T-044.
- T-042 refines the Customer Requests root: `CustomerRequestsView` removes the Requests-page create/start card, renders the existing `CustomerRequestsStore.requests` array as horizontally scrollable per-request progress cards, places each request's pet/service/time/location/status summary at the top of its progress card, and keeps the timeline plus actions inside that card. Request update/edit persistence and customer-side matched-groomer display remain out of scope.
- T-043 refines only the Customer Requests carousel container: `CustomerRequestProgressCarousel` lets the horizontal ScrollView bleed past the page content column to screen edges, keeps card content aligned through scroll content margins, and disables scroll clipping so shadows are not cropped into an inner rectangle.
- T-044 adds customer request cancellation: `cancel_grooming_request` is deployed to project `lqmasbuqzvcvtawonjlb`, mirrored under `supabase/migrations/20260622142020_t044_cancel_grooming_request.sql`, exposed only to `authenticated`/`service_role`, and wired through `CustomerRequestRepository`, `SupabaseCustomerRequestRepository`, `CustomerRequestsStore`, and `CustomerRequestsView`.
- T-045 added Customer Requests booking handoff behavior without backend changes by mapping `booked` requests through `Booking.requestID` and routing `View Booking` to the existing `BookingDetailView`.
- T-046 supersedes the separate handoff card style: `CustomerRequestsView` now renders booked handoffs through `CustomerRequestProgressCard`, changes the card header/action content for confirmed bookings, uses a compact completed timeline, and persists same-device acknowledgement through customer-scoped `UserDefaults`.
- T-047 refines the fused Customer Requests quest card: `CustomerRequestProgressCardPresentation` centralizes active/booked header and info-line text, booked cards show the original request title plus booking time and address, active/booked cards share the same card padding, spacing, and timeline density, first-card carousel sizing is centered, headlines are explicit two-line strings, time ranges break after `-`, and all three card actions share one label component with tone-specific styling.
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
- T-023B, T-023C, T-023D1, T-023D2, T-024 through T-043, T-045, T-046, and T-047 required no backend reads or writes. T-044 used explicit user authorization for remote Supabase DDL through MCP. Future backend work must use Supabase MCP only and requires explicit user approval for remote schema writes.
- The local `supabase_api_key` file is ignored and must not be read or embedded in code/docs.

## Known Risks

- Xcode 26.5 object version 77 and the configured iPhone 16 Pro/iOS 18.4 simulator are expected by existing scripts.
- Groomly prototype screens and future uploaded screenshots may show deferred or unsupported ideas. Treat them as visual inspiration only unless a separate task authorizes product/backend work.
- Deferred features remain out of scope for the Groomly foundation sequence, including request editing, rebooking, favorites, signed URL image rendering, realtime chat, attachments, payments, push notifications, maps, calendars, and admin tooling.
- Customer Requests booking handoff acknowledgement is same-device local state after T-046. It survives client restart but not reinstall, app data clearing, or cross-device use. A future backend/model task should add a persisted customer-scoped acknowledgement such as `request_booking_handoff_acknowledged_at` or a small acknowledgement table before relying on cross-device suppression.
- Default email confirmation still requires browser confirmation and returning to Sign In; native deep-link completion and production SMTP remain separate future work.

## Next Recommended Task

- Wait for the user to upload/select one screenshot, then create the next available screenshot-driven Groomly UI task from `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`. Do not start backend, post-MVP feature work, Admin Dashboard work, or new-feature implementation without explicit approval.
