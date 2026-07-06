# Current State

Update this only when future runs need the changed fact.

## Fast Path

- Date: 2026-07-06
- Current branch when last checked: `main`
- Remote: `origin` -> `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App.git`
- Latest implemented app task: T-048, Customer new request five-step wizard rework.
- Latest documentation/workflow task: T-049, active Markdown information architecture repair.
- Next available task ID: T-050.
- Active task file: none.
- Detailed T-001 through T-048 records: `docs/09_frozen/task_records_2026-07-06/`.
- Old Fresh Brief, legacy Codex init plan, external agent reports, and old Groomly prompt: archived under `docs/09_frozen/`; do not treat them as active context.

## Validation Baseline

- Last known app build: `./scripts/ios-build.sh` passed for T-048 on 2026-06-22.
- Last known targeted tests: T-048 Customer new request wizard presentation tests passed on 2026-06-22.
- Last known simulator launch: XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator on 2026-06-22.
- Current docs-only hygiene command: `node scripts/context-hygiene-check.mjs`.
- This T-049 docs repair does not change Swift, Xcode, Supabase, runtime behavior, or app UI.

## Product State

- The implemented MVP marketplace flow is: Customer request -> groomer offers -> customer acceptance -> booking and chat -> groomer completion -> customer review.
- Production routing uses real Supabase Auth, authoritative profile loading, and customer/groomer role separation.
- Implemented iOS areas include Auth, role onboarding, customer pets, customer requests/offers, groomer requests/offers, bookings, participant text chat, groomer profile/services/portfolio metadata, Account, and a sanitized Debug Panel.
- Active product model remains Open Request -> Groomer Offer -> Customer Confirmation -> Booking. Do not reintroduce task-card push flow.
- Groomly UI adaptation is complete for implemented MVP screens. Future Groomly UI changes are screenshot-driven rework tasks that must map screenshot modules to existing SwiftUI/Store/repository/model paths or stop for new-feature approval.

## Known Gaps And Risks

- T-048 request wizard location mode, street address, travel range, and photo tiles are UI-only until a future approved backend/model/repository task persists them.
- Image display is mostly metadata/upload oriented; signed URL rendering and richer media UX remain deferred.
- Deferred features include request editing, rebooking, favorites, realtime chat polish, attachments, payments, push notifications, maps, calendars, cross-device request handoff acknowledgement, and admin tooling.
- Customer Requests booking handoff acknowledgement is same-device local state only.
- Supabase remote writes, migrations, seeds, cleanup, commit, push, and PR creation require explicit user approval.
- The local `supabase_api_key` and `supabase_environment_variables` files are credential-class local files. Do not read, print, or commit them.

## Read Pointers

- Feature lookup: `docs/00_memory/FEATURE_INDEX.md`
- Product rules: `docs/01_product/`
- Architecture rules: `docs/02_architecture/`
- Backend fast path: `docs/03_backend/SUPABASE_CONTRACT.md`
- Workflow: `docs/05_workflow/README.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Frozen archive index: `docs/09_frozen/README.md`
