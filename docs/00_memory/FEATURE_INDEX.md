# Feature Index

Use this as a routing table, not a task history. Read the linked section needed for one active task.

| Area | Current Status | Primary Docs | Code Areas |
|---|---|---|---|
| Workflow and task execution | Single-agent, indexed context model active after T-049 | `docs/05_workflow/README.md`, `docs/06_tasks/TASK_LEDGER.md` | `AGENTS.md`, scripts |
| Auth and role routing | Email/password Auth, atomic role onboarding, authoritative role shells complete | `docs/01_product/USER_ROLES.md`, `docs/03_backend/SUPABASE_CONTRACT.md` | `Features/Auth/`, `App/`, `Core/Repositories/` |
| Customer pets and photos | CRUD, upload/delete metadata paths complete; signed image rendering deferred | `docs/01_product/SCREEN_INVENTORY.md`, `docs/03_backend/STORAGE_POLICY.md` | `Features/Customer/Pets/`, pet repositories/models |
| Customer requests and matching | Request publishing, matching, cancellation, booked handoff, and five-step wizard complete at current contract level | `docs/01_product/NAVIGATION_AND_FLOWS.md`, `docs/03_backend/RLS_RPC_POLICY.md` | `Features/Customer/Requests/`, request repositories/models |
| Groomer requests and offers | Matched feed/detail, dismiss, create/withdraw offer, offer status complete | `docs/01_product/SCREEN_INVENTORY.md`, `docs/03_backend/SUPABASE_CONTRACT.md` | `Features/Groomer/Requests/`, offer models |
| Bookings and reviews | Accept offer, booking lists/detail, cancellation, completion, one customer review complete | `docs/01_product/NAVIGATION_AND_FLOWS.md`, `docs/03_backend/RLS_RPC_POLICY.md` | `Features/Bookings/`, booking repositories/models |
| Participant chat | Text-only participant chat complete; realtime and attachments deferred | `docs/01_product/SCREEN_INVENTORY.md`, `docs/03_backend/SUPABASE_CONTRACT.md` | `Features/Chat/`, chat repositories/models |
| Groomer profile/services/portfolio | Profile/services/portfolio metadata management complete; richer public image rendering deferred | `docs/01_product/USER_ROLES.md`, `docs/03_backend/STORAGE_POLICY.md` | `Features/Groomer/Profile/`, groomer repositories/models |
| Groomly visual system | Implemented MVP screens adapted; future work is screenshot-driven | `docs/01_product/DESIGN_SYSTEM.md`, `docs/08_design/README.md` | `DesignSystem/`, selected feature views |
| iOS build and tests | Scripts available; app validation only when task touches Swift/app behavior | `docs/04_ios/IOS_BUILD_AND_TESTING.md` | `scripts/ios-build.sh`, `scripts/ios-test.sh` |
| Supabase backend | Deployed through T-044 and mirrored in `supabase/migrations/` | `docs/03_backend/SUPABASE_CONTRACT.md`, `docs/03_backend/MIGRATION_RULES.md` | `supabase/migrations/`, repository adapters |

Historical task details are archived under `docs/09_frozen/task_records_2026-07-06/` and should be found with targeted `rg` only when recovery requires them.
