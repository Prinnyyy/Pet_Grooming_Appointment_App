# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-10
- Updated by: Codex
- Latest completed task: T-253 Groomer Schedule and booking presentation.
- Current task: none; T-157 APNs remains externally blocked.
- Next task ID: use T-254 for Q-100 unless the user resumes T-157 after Apple Developer Program upgrade.

## Fast Path

- Task source of truth: `docs/06_tasks/TASK_LEDGER.md`.
- Managed roadmap: `docs/06_tasks/ROADMAP.md`.
- Roadmap execution queue: `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md`.
- Closeouts: `docs/00_memory/WORKLOG.md`.
- Decisions: `docs/07_decisions/DECISION_LOG.md`.
- Feature/workflow routing: `docs/00_memory/FEATURE_INDEX.md`, `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`, `docs/05_workflow/CONTEXT_AND_RECOVERY.md`, `docs/05_workflow/TOOLING_POLICY.md`, `docs/05_workflow/GITHUB_RULES.md`.
- Context hygiene command: `node scripts/context-hygiene-check.mjs`.
- Frozen archives: `docs/09_frozen/README.md`.

## Branch and Baseline

- Current branch baseline: `codex/pet-fit-structure-cleanup`.
- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`.
- Continue implementation, docs, commit, and push work from this branch unless the user names another branch.
- Do not treat `main` as the current work baseline. T-173 reviewed main-only commit `2fddf7b`; it is superseded and must not be merged back into this branch.
- Standing Git approval is active: after required validation passes, commit and push each completed task's own changes on this branch automatically.
- PRs, tags, branch deletion, merge/rebase/reset, seeds, migrations, Supabase writes, repository settings, and other non-Git remote writes require approval. T-242's remote authorization is consumed.

## Validation Baseline

- T-239 authorized UI R11 passed publish/offer/accept/chat/complete/review, Debug 6/6 with zero errors, backend final state, and zero residue; full iOS test/build passed.
- Last Supabase migration apply: T-246 `20260710052620_t246_prepare_beckon_runtime_identity.sql` applied to `lqmasbuqzvcvtawonjlb` on 2026-07-09; parity, cron rename, and linked dry-run were verified.
- Last Edge Function deploy: `delete-account` version 2 is active with JWT verification and service-role Storage API cleanup across six user-prefixed image buckets.
- Last TestOps unit validation: T-248 `./scripts/testops-unit.sh` passed 36 Node tests.
- Latest remote TestOps evidence: T-248 `smoke5` passed 5/5 and `matching_baseline` passed 8/8; both run families left zero tagged requests and only redacted local artifacts.
- T-242 verified public DMARC, accepted a Resend delivery smoke, and persisted Supabase Custom SMTP plus exact Auth callback URLs.
- T-246 completed Q-94: local Xcode/app/source/TestOps identity is Beckon and the Q-96 cron migration is prepared but unapplied.
- T-247 completed Q-95: active agent/workflow sources use Beckon and are checked by the identity audit.
- T-248 completed Q-96: project/Auth/runtime identity and all 100 seed users use Beckon; UUID mapping is unchanged, remote lifecycle passed 5/5, matching passed 8/8, tagged residue is zero, and full local gates pass.
- T-249 approved current/target Groomer visual evidence, the five-tab workspace contract, and Q-97 through Q-104. No app or backend implementation changed.
- T-250 completes Q-97: five direct Groomer tabs, live Home summaries, Home notification entry, cache-first avatar, authenticated next-booking photo, and a data-ready Availability deep link pass focused/full iOS gates and live Simulator inspection.
- T-251 verifies active docs, links, ignore behavior, the 60-file migration mirror, branch/task facts, and R-039 routing. It also allows an exactly due meta-review to be explicitly reserved as the next task without blocking the preceding commit; overdue cadence still fails.
- T-252 completes Q-98: Requests owns Matches/Offers segmentation, correct Home/notification routes, grouped lists, focused targets, preserved pagination/mutations, and the approved request-detail hierarchy; focused/full iOS gates and live compact-viewport inspection pass.
- T-253 completes Q-99: Groomer Schedule has fixed date controls, a truthful summary-or-empty hierarchy, grouped operational rows, and role-correct booking Cancel/Complete actions; focused/full iOS gates, build, and compact empty-state inspection pass.
- T-244 normalizes the rotated Worklog EOF to one newline.
- T-245 context-script validation passes 32 Node tests; word counts are informational and rolling windows use buffered high/retain entry counts.
- T-246 passes the Beckon identity audit, 31 TestOps tests, 48 migration tests, 10 Edge tests, privacy/preflight/Supabase checks, full iOS tests/build, and Simulator auth branding inspection.
- Known iOS validation failure: none currently recorded.

## Active Product State

- MVP marketplace flow is complete at the current contract level: customer request -> groomer offers -> customer accepts -> booking/chat -> groomer completes -> customer reviews.
- Production uses real Supabase Auth, authoritative profile loading, and role separation. No production path fabricates a session/profile.
- T-217 implements the iOS custom-scheme callback. T-242 configures the same exact Supabase Site/redirect URL plus verified Resend SMTP for `hellobeckon.com`. HTTPS universal links and associated domains remain deferred.
- Implemented iOS areas include auth/onboarding, marketplace flow, notifications, foreground chat, profile/account surfaces, privacy/support links, private images, Debug Console, ops evidence, accessibility/copy checks, and TestOps.
- Customer/groomer tab roots load shared notification/chat badge sources. Customer Home, Groomer Home's notification bell, and both Messages tabs expose unread state; chat unread state is local/session-scoped and clears on thread open.
- TestOps has support-ref selectors and a no-screenshot dual-role lifecycle driver. Its wrapper verifies Debug/backend state and run-tag cleanup; UI uses one seed pair while backend `smoke5` is multi-pair.
- Customer request UI and groomer profile UI were split into focused SwiftUI files in T-211/T-212.
- Request, offer, booking, message, and notification repositories use bounded limit+1 page reads. All supported list surfaces expose retry-preserving, deduplicating terminal-page controls; message threads fetch the newest window first and preserve their reader anchor when prepending history.
- Private Storage images use authenticated `.download(path:)` through `PrivateImageLoader`; cache hashes paths, retries transient downloads once, and clears on local account cleanup.
- Customers can create a new request from cancelled requests/bookings via explicit republish. Republish tolerates missing request photos and expired preferred windows. Unpublished wizard drafts are sheet-ephemeral.
- Beckon UI adaptation is complete for implemented MVP screens. Future UI work is screenshot-driven and must map modules to existing SwiftUI/Store/repository/model paths or stop for approval.
- R-039 Q-97 through Q-99 are implemented: Groomer uses five direct tabs, Home owns Notifications and operational summaries, Requests owns segmented Matches/Offers with grouped lists and focused routes, and Schedule has stable day/booking presentation. Remaining screen/editor redesign continues in Q-100 through Q-104.
- Local binaries and hosted Auth use `Beckon: Pet Grooming`, `com.hellobeckon.beckon`, and `com.hellobeckon.beckon://auth/callback`. Supabase project/runtime naming and all 100 remote seed users now use Beckon.

## Active Workflow State

- Default context model is L0-L4 in `CONTEXT_AND_RECOVERY.md`.
- Startup reads stay minimal: `AGENTS.md`, then targeted current-state/task-ledger sections only when needed.
- Periodic documentation-governance reviews use `docs/06_tasks/META_REVIEW_TEMPLATE.md` every 10 completed tasks or weekly.
- Last meta-review: T-251 on 2026-07-10.
- V1.0 ideal-operation Q-16...Q-43, Auth package Q-92, and R-038/Q-94...Q-96 are complete. R-039 design T-249 plus Q-97/T-250, Q-98/T-252, and Q-99/T-253 are complete; Q-100 through Q-104 are queued.
- Changes to `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` must be standalone numbered tasks with a decision-log entry and context hygiene.
- T-180 records standing user approval for task-completion Git commit and push. This approval is limited to current-task changes after validation passes; T-186 requires stopping without auto pull/rebase/merge/reset/force-push if the push fails or is rejected.
- T-245 makes word counts informational only; Ledger uses 18/12, Worklog and active decisions use 14/8, and decision archive pointers use 12/6 trigger/retain windows. Manual compaction follows 65%/80% boundaries against the 353,000-token context.
- Main reconciliation: `2fddf7b` is reviewed/superseded; carry this branch's governed docs forward.
- Decision log is an active index backed by frozen snapshots. The pre-T-174 full text lives in `docs/09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.
- Default `rg` searches honor `.rgignore`; do not use broad `rg --files -g '*.md'` as the default Markdown inventory.
- Do not read full `WORKLOG.md`, full `TASK_LEDGER.md`, frozen archives, Beckon HTML/export, or T-129 seed tables by default.
- After durable memory, ledger, workflow, or coordination-doc changes, run context hygiene; if an entry window exceeds its trigger, rotate once to its retained count.

## Supabase and TestOps Guardrails

- Authorized Supabase project: `Beckon`, ref `lqmasbuqzvcvtawonjlb`.
- Legacy ref `swdiiyypysyxbnfrxxsv` is out of scope; do not inspect or mutate it.
- Linked Supabase CLI commands must run sequentially.
- Supabase CLI telemetry is disabled locally. Use `SUPABASE_TELEMETRY_DISABLED=1` for scripted linked commands so concurrent external processes cannot race on `~/.supabase/telemetry.json`.
- `SUPABASE_DB_PASSWORD` is not currently needed for normal local linked CLI use while saved credentials remain valid.
- `SUPABASE_SECRET_KEY=sb_secret_...` is not a CLI PAT, DB password, JWT, or Bearer token.
- TestOps and the T-248 identity cutover runner accept either legacy `SUPABASE_SERVICE_ROLE_KEY=eyJ...` or modern `SUPABASE_SECRET_KEY=sb_secret_...`; modern secrets are sent as `apikey` only. The older T-129 account-creation scripts still expect JWT-shaped legacy service-role keys.

## Current Known Risks

- Active memory/task files are intentionally concise. Do not expand them into full history.
- Backend policy files are now current-rule indexes; use migrations or frozen pre-trim snapshots for detailed historical trace.
- Historical briefs, design prompts, pre-slim notes, removed pointers/templates, Claude snapshots, and external audits are frozen under `docs/09_frozen/`. T-185 moved remaining root external drafts into `docs/09_frozen/external_agent_reports/`. Active entrypoints are ROADMAP, PRODUCT_BRIEF, DESIGN_SYSTEM, UI_IMPLEMENTATION_NOTES, DECISION_LOG, CLAUDE, and workflow/task docs. External reports are review input only.
- T-129 seed profile Markdown files are machine-readable parser inputs and excluded from default search. Do not reformat or archive them without updating scripts/tests.
- Deferred unless explicitly requested: public directory, direct booking, payments, chat attachments/read receipts, maps/calendar integrations, moderation/disputes, admin tooling.
- Customer in-app notifications are active. T-157 APNs database/iOS foundation is remotely applied; push dispatch waits for Apple Developer credentials and APNs secrets.
- Large Swift context risks `CustomerRequestsView.swift` and `GroomerProfileManagementView.swift` were split in T-211/T-212.
- Active cross-task risk: T-157 APNs deployment remains blocked.
- Approved R-039 mock data and generated photos are illustrative; implementations must use live models and existing authenticated image paths.
- T-234 applied the 2 T-228-evidenced FK indexes; the remaining 10 FK findings already have usable indexes. Q-93 remains blocked by Supabase Free, and APNs remains excluded.

## Next Recommended Task

- Q-100 Messages and Notifications is the next dependency-satisfied package and uses T-254 only when explicitly started.
