# AGENTS.md

## Mission

This is an iOS app project. Codex makes small, reversible changes and completes one primary task per run.

## Default Workflow

Use the lightweight single-agent workflow in `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`.

- One primary task; no adjacent features or broad refactors.
- Minimal context: targeted reads/searches only.
- No subagents or multi-agent orchestration unless the user explicitly re-enables them.
- Short plan before non-trivial edits.
- One validation attempt by mode.
- Completion gate is adaptive: match task closeout, validation, and simulator launch to the task mode and risk.
- Update durable memory only when project state changed.
- Write a closeout/checkpoint before `/compact`.
- Stop when the requested task is complete.

## Archived Groomly UI Phase and Active Screenshot Rework

The Groomly foundation sequence `docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md` is completed.

The completed Groomly screen slices are archived historical context:

- `docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md`
- `docs/06_tasks/T-025_GROOMLY_CUSTOMER_PETS_UI.md`
- `docs/06_tasks/T-026_GROOMLY_CUSTOMER_REQUESTS_LIST_STATUS_UI.md`
- `docs/06_tasks/T-027_GROOMLY_CUSTOMER_REQUEST_WIZARD_UI.md`
- `docs/06_tasks/T-028_GROOMLY_CUSTOMER_REQUEST_DETAIL_OFFERS_UI.md`
- `docs/06_tasks/T-029_GROOMLY_GROOMER_REQUESTS_FEED_DETAIL_UI.md`
- `docs/06_tasks/T-030_GROOMLY_GROOMER_OFFER_FORM_STATUS_UI.md`
- `docs/06_tasks/T-031_GROOMLY_GROOMER_PROFILE_SERVICES_UI.md`
- `docs/06_tasks/T-032_GROOMLY_GROOMER_PORTFOLIO_UI.md`
- `docs/06_tasks/T-033_GROOMLY_BOOKINGS_UI.md`
- `docs/06_tasks/T-034_GROOMLY_CHAT_UI.md`
- `docs/06_tasks/T-035_GROOMLY_ACCOUNT_TABS_DEBUG_FINAL_UI.md`

The Groomly UI completion sequence `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md` is completed for implemented MVP screens.

Future Groomly UI work is screenshot-driven. Each uploaded screenshot becomes one bounded UI rework task unless the user explicitly combines or splits scope. Use `docs/06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` for new screenshot tasks, starting from the next available task ID instead of reopening completed T-024 through T-035 files.

- T-022 remains completed, but its post-MVP next-task suggestions are frozen and must not auto-start.
- Use the Groomly design source in `docs/08_design/` only as a visual and interaction reference.
- T-023A through T-023D2 and T-024 through T-035 are completed and archived as historical implementation evidence. Do not rerun or extend them unless the user explicitly requests a review follow-up.
- Run only one primary task per Codex run.
- Before SwiftUI edits for a screenshot task, analyze the screenshot, map each visible module to existing app screens/data owners, and write a short implementation plan.
- When analyzing screenshots, ignore any long oval Customer/Groomer toggle located above the visible app screen frame. Treat it as an external prototype/control annotation, not an app module to map or implement.
- If a screenshot module maps to existing MVP behavior, wire the new UI to the existing Store, repository, model, and backend contract. Do not rebuild backend code or create duplicate data paths.
- Do not redesign additional feature screens, start Admin Dashboard work, or start non-Groomly post-MVP work unless the user explicitly requests it.
- Do not copy HTML/CSS/React code directly into SwiftUI.
- Product correctness and the existing Open Request -> Groomer Offer -> Customer Confirmation -> Booking model take priority over visual matching.
- If screenshot or prototype content implies new persistence, schema, RLS, RPC, Storage behavior, navigation model, role capability, or deferred feature, stop and report the feature, whether it is already supported, likely affected files, validation needed, and the user decision required.

## Minimal Startup Context

Read only what the task needs:

1. `AGENTS.md`
2. the active task file, if provided
3. targeted sections of `docs/00_memory/CURRENT_STATE.md` when current state or risks matter
4. `docs/06_tasks/TASK_LEDGER.md` only when choosing or updating task status

Read product briefs, `PROJECT_MEMORY.md`, architecture/backend docs, historical decisions, archived workflow docs, or old reports only when directly relevant. Do not search `docs/05_workflow/archive_subagent_workflow/` or `docs/05_workflow/agent_reports/` unless the user asks for historical workflow context.

## Working Rules

- Preserve existing user work and inspect `git status` before editing.
- Do not start adjacent features or broad refactors.
- Prefer targeted searches and narrow file reads.
- Keep SwiftUI views thin and business logic outside views.
- Keep backend access behind repository/service boundaries.
- Do not invent Supabase schema facts or perform destructive database operations.
- Do not add dependencies, commit, push, or make remote writes without explicit user approval.

## Validation

- Micro Mode: for read-only answers, status checks, or tiny doc edits; no task file, memory update, build, or simulator launch by default.
- Quick Mode: validate only what changed; docs-only edits usually need only `git diff --check`.
- Standard Mode: make one build attempt by default.
- Deep Mode: state an explicit validation plan before implementation.
- When files are edited, basic validation should include `git diff --check` unless the change is intentionally left as an unvalidated checkpoint.
- For Swift, Xcode project, app behavior, or UI changes, also run `./scripts/ios-build.sh` unless the active task documents a stricter check.
- Launch the iOS Simulator only for app/UI behavior changes, screenshot tasks, or explicit user requests; skip it for docs-only, workflow-only, read-only, and backend-only tasks unless visual inspection is useful.
- UI tests are not default. Unit tests are not default for initialization tasks.
- If validation fails, report the first real error and stop unless the user approves a follow-up.

## Completion

- Briefly review the current diff.
- Record closeout in a task markdown file when one already exists, when the task is Standard/Deep, when the task changes app behavior, or when durable workflow/product state should be preserved. Do not create task files for every micro task.
- Run mode-appropriate validation and report what was run or intentionally skipped.
- Launch the app in the iOS Simulator only when the task affects visible app behavior or the user asks for inspection; if launch is required and fails, record the blocker and report it.
- Update durable memory only when project state meaningfully changed.
- Before `/compact`, write a concise closeout or checkpoint with status, changed files, validation, risks, and next context.
- Report the result concisely and stop.

## Recovery

If interrupted or context is stale, follow `docs/05_workflow/INTERRUPTION_RECOVERY.md`. Do not reconstruct archived subagent state.
