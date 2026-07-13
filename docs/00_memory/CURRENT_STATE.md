# Current State

Update this only when project state meaningfully changes. Keep it as a fast path, not a project encyclopedia.

## Last Updated

- Date: 2026-07-12
- Updated by: Codex
- Latest completed task: T-321 Auth and Customer shared keyboard-rule adoption.
- Current task: none; T-157 APNs remains externally blocked and Q-104 Dynamic Type/Accessibility remains user-deferred.
- Next task ID: use T-322 for Groomer and business-editor keyboard-rule adoption. T-323 covers residual/modal/chat inputs; Groomer Q-104 remains deferred.

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

- T-321 connects Authentication, Role Onboarding, Customer Profile, and Pet editing to the existing DesignSystem keyboard-avoidance contract using stable semantic focus IDs only. Pet Save uses the shared stationary page-action layer instead of keyboard-following `safeAreaInset`; Request adopts the same shared page-action naming. Feature files contain no copied keyboard geometry. Full iOS tests/build and repository audit pass; no Store, repository, backend, dependency, or remote state changed.
- T-320 replaces the fixed 55% rule with one reusable DesignSystem keyboard-avoidance modifier: it measures the real scroll viewport and semantic label/control group, performs no scroll when visible, reveals only the nearest hidden edge with field spacing, stabilizes oversized groups, and cancels duplicate or stale work. Request is the verified reference consumer; ZIP sits at semantic clearance above the number pad while Back/Continue remain behind it. Full tests/build and strict/repository audits pass; no Store, repository, backend, dependency, or remote state changed.
- T-319 plans the correction of T-318's fixed 55% anchor before broader rollout. T-320 introduces measured minimum-reveal geometry and revalidates Request; T-321 through T-323 then cover Auth/Customer, Groomer/business, and residual/modal/chat inputs with explicit page-action versus input-accessory classification. No Swift or runtime behavior changed.
- T-318 records the initial keyboard-aware form contract and moves Request's overlap/clearance geometry into `BeckonKeyboardFormLayout`; its fixed 55% anchor is now explicitly superseded by the T-319 plan and must not be propagated. Request remains the only current consumer until T-320 corrects and revalidates it.
- T-317 periodic meta-review confirms branch/upstream, task/roadmap/index facts, intentional root Markdown ignores, zero active conflict markers, the 67-file migration mirror, 13/13 governance tests, context hygiene, and preflight. Active Worklog/Ledger retain four/three task slots; no product, app, backend, dependency, or workflow rule changed.
- T-316 keeps Request Wizard fields keyboard-readable without moving the bottom action area: address and Notes focus scroll their title-plus-control toward a lower visible anchor with natural content-bound clamping; keyboard overlap adds scroll clearance while Back/Continue retain their original screen position behind the keyboard. Focused RED/GREEN, full iOS tests, build/run, ZIP/Notes live inspection, strict/repository UI audits, and build pass; no business, Store, repository, or backend behavior changed.
- T-315 separates complete-field continuation from Apple Maps confirmation: Continue is active once required Time/Location fields are complete, equivalent unique/candidate results auto-confirm and advance, only corrected/ambiguous results open review, Profile autofill cancels stale continuation intent, and confirmation review starts at a compact 330pt detent. Focused RED/GREEN, full iOS tests, build/run, three live paths, UI audit, and build pass; no provider, repository, backend, or remote state changed.
- T-314 refreshes the address confirmation presentation from the current candidate-prefilled form when Continue is tapped, so Entered Address no longer retains the pre-selection search fragment. Focused RED/GREEN, full iOS tests, build/run, live `770` candidate/Continue confirmation inspection, and iOS build pass; no provider, backend, persistence, or publication behavior changed.
- T-313 fixes the Customer Request address/publish path: empty State is neutral until validation, autocomplete renders as one top-layer anchored overlay, candidate selection prefills without opening review, Continue presents address correction and advances after acceptance, publish failures use the Wizard's global bottom feedback, and nullable Apple place IDs encode as explicit RPC null parameters. Full iOS tests, build/run, live autocomplete/confirmation inspection, UI audit, and preflight pass; no backend or remote write changed.
- T-312 completes Q-120 and R-041: all four Customer reference surfaces have zero strict errors; the repository ratchet has 218 baseline entries plus four reviewed warnings with no new errors or stale entries. Full iOS tests/build/preflight and compact/large default/Accessibility 3 integration evidence pass. Remaining debt and migration ordering are published in `docs/04_ios/UI_CONSISTENCY_DEBT.md`; Q-104 remains deferred.
- T-311 completes Q-119: Customer Account ownership is separated from Profile editing and uses shared page/section/grouped/settings-row contracts; authenticated release links use the same row primitive. Default and AX3 identity, Profile navigation, Privacy/Support, DEBUG, and destructive actions render and expose full-row semantic targets. Strict audits, full tests, and build pass; the baseline is 218 entries plus four reviewed warnings. No profile Store/repository/auth/backend behavior changed.
- T-310 completes Q-118: Customer Request Wizard is strict-clean, uses semantic page/field/action/selection contracts, and has explicit default/Accessibility 3 Header, Time Window, and bottom-action layouts. Default and AX3 Pet/Service/Time surfaces render without horizontal clipping or low text scaling; full tests/build pass. The UI baseline is 234 entries plus four reviewed warnings. Store validation/publication, address confirmation, photos, republish, feedback, selectors, and backend contracts are unchanged.
- T-309 completes Q-117: Customer Requests and Bookings share `BeckonPageTitle`; Requests uses semantic page/section/type/action contracts, one canonical card elevation, and adaptive header/chip/action/closed-row layouts. Active and cancelled seeded states render without truncation at default and Accessibility 3; strict audit, full iOS tests, and build pass. The baseline is 261 entries plus two reviewed Home fixed-width warnings. No Store/repository/navigation/backend behavior changed.
- T-308 completes Q-116: Customer Home is strict-clean and uses semantic page/section/type/action contracts; Header/Hero/Pet Cards reflow through Accessibility 3, while Active Request's pre-existing internal truncation remains Q-117 scope. Pet Form moved unchanged to its own file with four relocated legacy findings. The scanner now preserves UTF-16 positions after emoji and safely relocates partial splits; the deterministic baseline is 268 entries plus two reviewed Home fixed-width warnings. No Store/repository/navigation/backend behavior changed.
- T-307 completes Q-115: DesignSystem now owns role accents, page insets, semantic sections/grouped surfaces/selection cards/settings rows/field groups, standard action metrics, and separate primary visual-vs-tap availability. Existing Header/Button/Form/Feedback APIs remain compatible; a DEBUG catalog renders default and Accessibility 3 states without clipping. No Feature business/data/navigation/backend behavior changed.
- T-306 periodic meta-review confirms branch/task/queue/index consistency, intentional root Markdown ignore behavior, zero active conflict markers, the 67-file migration mirror, current backend facts, and UI/preflight governance tests. No product, app, backend, dependency, or workflow rule changed.
- T-305 completes Q-114: DesignTokens now owns business-semantic typography, layout, metrics, AA status text/unread colors, and one canonical soft-card elevation with compatibility aliases. Contract and contrast tests pass; status chips use semantic AA foregrounds. No backend, navigation, or business behavior changed.
- T-304 completes Q-113: `scripts/ui-consistency-audit.mjs` lexes tracked Feature Swift code, enforces deterministic/high-risk/review rules, and ratchets 294 legacy findings without accepting new errors or stale entries. Migrated paths use `strict`; initialize/prune/relocate are guarded; preflight and its hermetic fixture run the gate. No Swift app, backend, dependency, navigation, or product behavior changed.
- T-303 maps R-041 to Q-113 through Q-120 in `docs/superpowers/plans/2026-07-12-ui-consistency-governance-implementation.md`; it changed no Swift, scripts, backend, dependency, navigation, or product flow.
- T-302 restores the hermetic preflight test: its temporary Git fixture copies and executes the real preflight and Beckon identity scripts before proving migration/function discovery. Production preflight is unchanged.
- T-301 approves R-041 in `docs/superpowers/specs/2026-07-12-ui-consistency-governance-design.md`: evolve the existing DesignSystem in place, baseline all-app visual debt, block new violations, and first migrate Customer Home, Requests, Request creation, and Account. No Swift, backend, dependency, navigation, or product-flow change occurred.

- T-239 authorized UI R11 passed publish/offer/accept/chat/complete/review, Debug 6/6 with zero errors, backend final state, and zero residue; full iOS test/build passed.
- Last Supabase migration apply: T-300 applied `20260712044858_t300_strict_coordinate_matching.sql` to `lqmasbuqzvcvtawonjlb` on 2026-07-11; linked history, zero-gap preconditions, strict missing-coordinate rejection, retired legacy RPC grants, private privileges, both radius directions, rollback cleanup, and advisors were verified.
- Last Edge Function deploy: `delete-account` version 2 is active with JWT verification and service-role Storage API cleanup across six user-prefixed image buckets.
- Last TestOps unit validation: T-248 `./scripts/testops-unit.sh` passed 36 Node tests.
- Latest remote TestOps evidence: T-300 coordinate-backed `smoke5` passed 5/5, `matching_baseline` passed 8/8, and `matching_radius` passed 6/6; all run families deleted private Request locations and left zero tagged Requests/orphans.
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
- T-274 brings Edit Pet photo layout/actions into parity with Profile Settings, aligns Details text roles, applies the Request Wizard gradient action bar, limits pet names to 20 characters with red rejection feedback, and contains horizontal request-card shadows inside their scrollers.
- T-275 renames the Home section to Pets, adds birthday-derived age to Pet Cards, shares one photo-editor card between Account and Edit Pet while preserving separate upload Stores, and gives Pet/Request horizontal cards one unclipped shadow contract.
- T-276 restores the original Pet Card height after adding age, left-aligns the label-free birthday date control, and removes Pet-specific photo button/border overrides so the shared photo editor renders identically to Profile Settings.
- T-277 applies SwiftUI-native scroll-indicator suppression at the app root, complementing the UIKit appearance fallback so vertical indicators stay hidden across all current and future page hierarchies.
- T-278 refreshes the shared Customer Notifications Store immediately after successful Request publish/cancel operations and coalesces refreshes that overlap an in-flight notification load, removing delayed unread badges/messages.
- T-279 gives Customer Notifications a coordinated full-width body layout with a red title-adjacent unread dot, simplifies the Requests root title, enlarges Home's Welcome Back copy, and removes the redundant Edit Pet Care Notes label.
- T-280 centers unread notification dots outside the card in the left screen gutter, reuses the exact Bookings tab-title component for Requests, and reduces Home Active Request/Next Booking empty states to description-only copy.
- T-281 aligns Customer Account with Groomer Account's unframed identity header, labeled grouped surfaces, compact summary rows, and support grouping while preserving Customer icon styling; only the active Customer tab may present/dismiss the shared Request Wizard, removing first-open sheet races.
- T-282 introduces a reusable UIKit-delegate-backed limited text field that rejects overflow before it enters the control, including rapid input and paste, with reusable red field/cursor feedback; Pet Name and Request street/city/ZIP fields now use it at their contract limits.
- T-283 removes the T-263 avatar-policy RLS cycle through a private, current-customer-checked relationship helper. Groomer Availability can persist profile/weekly-hour changes again, and rollback-only remote verification proves an eligibility change backfills open Request matches through T-155.
- T-286 applies character-level street/city/ZIP rules before Request address text is displayed and moves MapKit address suggestions into a page-level anchored overlay that does not reflow the form and dismisses on an outside tap.
- T-287 keeps Request content scrolling active while address suggestions remain open, disables sheet drag-dismiss only during that state, searches unit-bearing addresses by their deliverable street base, resolves selected addresses in English, reduces bottom whitespace, and hides the Wizard scroll indicator.
- T-288 restores the T-286 anchor-preference rendering path for Request address suggestions after direct MapKit verification proved T-287 still received results but its independent frame overlay did not present them reliably; T-287 tap/drag behavior remains intact.
- T-289 removes the fake typed-text fallback from shared address search. A debounced en_US geocoder now publishes truthful street/city/state/ZIP candidates, localized Han-script completer rows are excluded, and candidate selection uses the already-resolved address while preserving unit suffixes.
- T-290 replaces T-289's single whole-query geocode with Apple's completion-driven autocomplete flow: MapKit supplies globally ranked address completions without a custom region bias, the leading completions resolve concurrently and retain MapKit order, and en_US reverse geocoding produces up to five truthful English street/city/state/ZIP rows. Unit suffixes remain selection-only.
- T-291 approves R-040 in `docs/06_tasks/APPLE_MAPS_ADDRESS_SYSTEM_PLAN.md`: one shared Apple Maps Address Line 1/Line 2 editor and confirmation flow, optional Place ID with mandatory coordinates, private PostGIS location metadata, direction-correct Customer/Groomer radii, controlled legacy backfill, and strict coordinate cutover through Q-105...Q-112. No implementation or remote state changed.
- T-292 completes Q-105 with provider-neutral address values, complete secondary-address extraction/conflict rules, material-edit confirmation invalidation, direct localized MapKit candidates, compatible-query retention, and selected/manual Apple resolution. Profile/Request UI and persistence remain unchanged until later R-040 packages.
- T-293 completes Q-106 with one provider-injected SwiftUI Address Editor, non-reflowing candidates, global secondary auto-move notice, inline conflict/error state, compact status, manual-result choice, entered-vs-suggested confirmation, and stable selectors. Feature persistence remains deferred to Q-109/Q-110.
- T-294 completes local Q-107 preparation: T-294 is the sole linked pending migration and defines private PostGIS locations, opaque public references, owner profile RPCs, coordinate Request v2, direction-correct radius scoring, explicit legacy fallback, and rollback validation. PostGIS remains remotely uninstalled until authorized Q-108 application.
- T-296 completes Q-108: PostGIS and the private address contract are deployed, authenticated roles have no direct private-location table access, rollback-only runtime verification passes, and all existing address-location references remain null until Q-109 through Q-111 perform confirmed writes/backfill.
- T-297 completes Q-109: Customer Profile and Groomer Edit Profile share `BeckonAddressEditor`, restore owner-scoped confirmed metadata, require reconfirmation after address or Unit changes, save address text/private coordinates through v2 RPCs, preserve legacy unchanged saves and profile snapshots, and export full confirmed Customer Profile address data for Request drafts.
- T-298 completes Q-110: Customer Request reuses `BeckonAddressEditor`, requires current confirmation before Time & Location can advance or publish, carries only current Profile confirmation, publishes Line 2 and private coordinate metadata through `create_grooming_request_v2`, and sends republished templates back through address review. Groomer pre-booking request models still omit Line 2.
- T-299 completes Q-111: service-only snapshot-checked Apple Maps backfill linked 51 Groomers, 50 Customers, and 1 active Request. Customer ref `6D8776F2` remains a reviewed ZIP-conflict exception; it is not matching authority and Q-110 prevents new coordinate-null Requests. Groomer/active Request gaps, incomplete active rows, legacy/manual orphans, and tagged TestOps residue are zero. `matching_radius` passed near/edge/outside in both service directions.
- T-259 makes one `T-###` per fresh session the default, reserves full iOS tests and batched visual evidence for integration/high-risk gates, and requires clean task or checkpoint commits at session boundaries.
- T-260 adopts UI-R1 through UI-R8 and A11Y-R1 through A11Y-R10 as the active design contract, including approved light-palette contrast pairs and a per-slice accessibility Definition of Done. T-305 implements the semantic token/contrast portion; shared primitive work continues in Q-115. Q-104 is unchanged.
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
- Last meta-review: T-317 on 2026-07-12.
- V1.0 ideal-operation Q-16...Q-43, Auth package Q-92, and R-038/Q-94...Q-96 are complete. R-039 design T-249 plus Q-97/T-250, Q-98/T-252, Q-99/T-253, Q-100/T-254, Q-101/T-255, Q-102/T-256, Q-103/T-257, and non-Accessibility integration verification T-258 are complete; Q-104 Dynamic Type/Accessibility is user-deferred.
- Changes to `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` must be standalone numbered tasks with a decision-log entry and context hygiene.
- T-180 records standing user approval for task-completion Git commit and push. This approval is limited to current-task changes after validation passes; T-186 requires stopping without auto pull/rebase/merge/reset/force-push if the push fails or is rejected.
- T-245 makes word counts informational only; Ledger uses 18/12, Worklog and active decisions use 14/8, and decision archive pointers use 12/6 trigger/retain windows. Manual compaction follows 65%/80% boundaries against the 353,000-token context.
- T-259 makes session end the default task-boundary context reset; the 65%/80% thresholds now govern only an oversized in-flight task, with checkpoint-and-resume preferred over in-place compaction.
- T-285 makes an immediately due periodic meta-review the sole automatic second task after a normal closeout. Each task keeps a separate commit; completed meta-reviews invoke callable host compaction or stop with an explicit `/compact` handoff when the host exposes no compaction API.
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

- No package is currently dependency-satisfied. Q-104 Groomer UI Dynamic Type/Accessibility becomes available only when the user restores that scope; otherwise use T-314 for explicitly selected new work.
