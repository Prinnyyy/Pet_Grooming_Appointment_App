# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-11
- Updated by: Codex
- Latest completed task: T-273 periodic documentation-governance meta-review.
- Current task: none; T-157 APNs remains externally blocked and Q-104 Dynamic Type/Accessibility remains user-deferred.
- Next task ID: use T-274 for the requested Customer Edit Pet follow-up. Q-104 remains deferred until the user restores its Dynamic Type/Accessibility scope.

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
- Last Supabase migration apply: T-263 `20260711080751_t263_merge_avatar_select_policies.sql` applied to `lqmasbuqzvcvtawonjlb` on 2026-07-11; both T-263 migrations, merged participant-avatar policies, and advisor cleanup were verified.
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
- T-254 completes Q-100: Groomer Messages and Notifications use compact grouped surfaces while preserving unread, pagination, thread, mark-read, Home-route, and row-selector behavior; focused/full iOS gates, build, and live compact/deep-link/a11y inspections pass.
- T-255 completes Q-101: Groomer Account now groups direct business, matching/schedule, and support destinations with truthful live summaries. Edit Profile has one native Back action, a hidden tab bar, and a fixed Save bar while retaining existing Store-owned profile/avatar feedback and mutation behavior.
- T-256 completes Q-102: Services and Availability use compact grouped configuration surfaces with native Back navigation, hidden tabs, and stable saves. Existing service size overrides, weekly hours, daily capacity, advance notice, auto-ready, and time-off Store/repository behavior are preserved; no backend or remote state changed.
- T-257 completes Q-103: Fit Signals separates core selection/size experience from compact skill groups, Evidence has a truthful grouped overview or empty state, and Portfolio uses an image-first gallery plus focused fit-note detail. Existing Store mutations, global feedback, authenticated cache, selectors, and image behavior are preserved; no backend or remote state changed.
- T-258 completes the non-Accessibility portion of the Groomer integration gate: seeded TestOps verifies five direct tabs, six focused Account workspaces, one Back action, hidden editor tabs, and no `More`; default-text compact and large Simulator inspection plus full iOS tests/build/preflight pass. Q-104 remains open only for user-deferred Dynamic Type and Accessibility validation/changes.
- T-263 uses one shared profile-avatar component and participant loader for Groomer imagery across customer Home, offers, bookings/details, and messages; elapsed confirmed bookings group under Past, and Recent Closed Requests is limited to the newest five. Customer access to related Groomer avatar objects is remotely applied through merged RLS/Storage policies.
- T-264 routes the latest cached customer pet photo into request action cards on both Customer Home and Requests, and unifies pet image rendering across Home pet cards, request cards, and the request wizard through `BeckonPetAvatar`.
- T-265 centers request-card pet avatars against the title/service text group, fixes the Requests root subtitle, and gives Request Details one navigation title plus reusable right-aligned module annotations outside each content card; the redundant page header and Cancellation module are removed.
- T-266 enlarges the customer request-card pet avatar to 84pt and uses the card's large spacing token between avatar and text, preserving centerline alignment with the full title/service text group.
- T-267 corrects Request Details annotations to the module's upper-left and sizes the request-card pet avatar to the two-line headline only, with equal top/left/text spacing and top alignment.
- T-268 shares one Customer Requests Store across Home/Requests for immediate cancellation updates, limits Recent Closed Requests to three with pet avatars, persists chat read timestamps across launches, and makes opening Customer Notifications automatically mark all loaded notifications read with Messages-style rows.
- T-269 removes the decorative Home smile avatar, aligns greeting copy to page content, uses system-badge red for the notification bell, preserves the Home badge as the total unread notification count, hides Offers on cancelled request details before republish, and strengthens reusable carousel-card bottom shadows.
- T-270 limits shared card shadows to 8pt, hides vertical scroll indicators app-wide, removes request swipe hints, marks Customer Notifications read on page exit, and reorganizes Edit Pet into annotated Profile/Details cards with a compact integrated avatar, labeled name, and selected horizontal options restored to leading visibility.
- T-271 removes duplicate Customer Profile/Edit Pet page headers, moves Save Profile into scroll content, simplifies republish into a shared template/booking button, centers Edit Pet in the toolbar, aligns pet profile field typography with Customer Profile, and enforces a hidden 80-character single-line pet-name limit without dropping focus.
- T-272 separates the Edit Pet photo into its own card within Pet Profile, standardizes form text roles, keeps selected chip borders inside their bounds, and places Save Profile after every Profile Settings content module.
- T-259 makes one `T-###` per fresh session the default, reserves full iOS tests and batched visual evidence for integration/high-risk gates, and requires clean task or checkpoint commits at session boundaries.
- T-260 adopts UI-R1 through UI-R8 and A11Y-R1 through A11Y-R10 as the active design contract, including approved light-palette contrast pairs and a per-slice accessibility Definition of Done. Token and primitive implementation remains a separate follow-up code task; Q-104 is unchanged.
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
- R-039 Q-97 through Q-103 are implemented: Groomer uses five direct tabs, Home owns Notifications and operational summaries, Requests owns segmented Matches/Offers with grouped lists and focused routes, Schedule has stable day/booking presentation, Messages/Notifications use compact grouped presentation, Account/Edit Profile use focused truthful configuration surfaces, Services/Availability/Time Off use focused grouped configuration editors, and Fit Signals/Evidence/Portfolio use focused density and image hierarchy. T-258 completes default-text viewport and selector coverage; Q-104 remains the user-deferred Dynamic Type and Accessibility gate.
- Local binaries and hosted Auth use `Beckon: Pet Grooming`, `com.hellobeckon.beckon`, and `com.hellobeckon.beckon://auth/callback`. Supabase project/runtime naming and all 100 remote seed users now use Beckon.

## Active Workflow State

- Default context model is L0-L4 in `CONTEXT_AND_RECOVERY.md`.
- Startup reads stay minimal: `AGENTS.md`, then targeted current-state/task-ledger sections only when needed.
- Periodic documentation-governance reviews use `docs/06_tasks/META_REVIEW_TEMPLATE.md` every 10 completed tasks or weekly.
- Last meta-review: T-273 on 2026-07-11.
- V1.0 ideal-operation Q-16...Q-43, Auth package Q-92, and R-038/Q-94...Q-96 are complete. R-039 design T-249 plus Q-97/T-250, Q-98/T-252, Q-99/T-253, Q-100/T-254, Q-101/T-255, Q-102/T-256, Q-103/T-257, and non-Accessibility integration verification T-258 are complete; Q-104 Dynamic Type/Accessibility is user-deferred.
- Changes to `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` must be standalone numbered tasks with a decision-log entry and context hygiene.
- T-180 records standing user approval for task-completion Git commit and push. This approval is limited to current-task changes after validation passes; T-186 requires stopping without auto pull/rebase/merge/reset/force-push if the push fails or is rejected.
- T-245 makes word counts informational only; Ledger uses 18/12, Worklog and active decisions use 14/8, and decision archive pointers use 12/6 trigger/retain windows. Manual compaction follows 65%/80% boundaries against the 353,000-token context.
- T-259 makes session end the default task-boundary context reset; the 65%/80% thresholds now govern only an oversized in-flight task, with checkpoint-and-resume preferred over in-place compaction.
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

- Use T-274 for the requested Customer Edit Pet follow-up covering photo parity, Details typography, bottom action gradient, 20-character name feedback, and carousel-shadow containment. Q-104 remains user-deferred.
