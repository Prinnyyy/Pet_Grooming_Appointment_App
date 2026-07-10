# Decision Log

Use this for durable architecture/product/workflow decisions. Keep active entries compact; full historical text lives in frozen snapshots.

Full pre-T-174 snapshot: `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

## Format

```text
Decision ID:
Date:
Decision:
Context:
Consequences:
Linked files:
```

## Active Decisions

```text
Decision ID: D-026
Date: 2026-07-10
Decision: Use one Beckon visual foundation with a schedule/action-oriented Groomer workspace and exactly five direct Groomer tabs.
Context: Live Simulator inspection showed the Groomer side using six equal tabs, a system-generated More screen, nested Account navigation, duplicate back buttons in Edit Profile, and card-heavy pages without a stable operational priority. The user approved the first T-249 visual direction and its Requests, Account, and Edit Profile extensions.
Consequences: R-039 targets Home, Requests, Schedule, Messages, and Account. Offers moves into a Requests Matches/Offers segment; Notifications opens from Home; Account is direct; feature editors hide the tab bar. Grouped surfaces and row separators replace per-row floating cards. Existing marketplace/backend contracts remain unchanged, and implementation is split into Q-97 through Q-104.
Linked files: docs/08_design/GROOMER_UI_REDESIGN.md, docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md, docs/01_product/DESIGN_SYSTEM.md
```

```text
Decision ID: D-025
Date: 2026-07-09
Decision: Treat Beckon as the only active product and workflow vocabulary while preserving legacy names solely in immutable history and explicit migration evidence.
Context: Q-94 renamed the local application and source, but the separately governed agent/workflow rules still used the prior product name and old Xcode credential path. Their temporary identity-audit exclusion also allowed future drift.
Consequences: AGENTS.md, CLAUDE.md, and docs/05_workflow use Beckon terminology and current ios/Beckon paths. The active identity audit now checks those files; only frozen records, applied migrations, the migration contract, and audit fixtures may retain legacy literals. Product behavior and remote state are unchanged.
Linked files: AGENTS.md, CLAUDE.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/05_workflow/STOP_CONDITIONS.md, docs/05_workflow/TOOLING_POLICY.md, scripts/beckon-identity-check.mjs
```

```text
Decision ID: D-024
Date: 2026-07-09
Decision: Maintain active Markdown with buffered entry-count windows and treat all word counts as informational telemetry.
Context: The old trigger and retained counts were identical, so every new closeout rotated one item and left the window full. Separate word limits then caused repeated trimming even when document structure was healthy, while manual compaction guidance started at only 30% of the 353,000-token context.
Consequences: Ledger uses trigger/retain 18/12; Worklog and active decisions use 14/8; decision archive pointers use 12/6 with one pointer per archive batch. Each completed rotation restores six entries. Word references never warn, fail, stop, compress, or rotate content. Manual compaction uses 65%/80% task-boundary thresholds, and completed task-specific plans/specs move to dated frozen Superpowers archives. This supersedes D-016 and the Markdown-budget parts of D-017; D-017's failed-push rule remains active.
Linked files: AGENTS.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/STOP_CONDITIONS.md, scripts/context-hygiene-policy.mjs, scripts/context-hygiene-check.mjs, scripts/context-rotate.mjs
```

```text
Decision ID: D-023
Date: 2026-07-09
Decision: Replace the complete active legacy brand/project identity with Beckon through a dependency-ordered local, workflow, and remote cutover.
Context: The user finalized the brand, domain, App Store name, and tagline and explicitly required technical identifiers, files, UI, TestOps seeds, and remote state to follow the same identity.
Consequences: The canonical identity is Beckon, `com.hellobeckon.beckon`, and `com.hellobeckon.beckon://auth/callback`. R-038 uses Q-94 through Q-96 so product/source work, standalone workflow-rule changes, and authorized remote Supabase/seed-user changes remain separately reviewable. Applied migrations, frozen records, and Git history remain immutable; append-only changes replace live old identifiers.
Linked files: docs/06_tasks/BECKON_BRAND_MIGRATION.md, docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md
```

```text
Decision ID: D-022
Date: 2026-07-09
Decision: Convert post-readiness findings into bounded non-Apple remediation packages and require evidence before index changes.
Context: The user asked to turn the unresolved T-222 findings into tasks while excluding APNs and paid Apple Developer work. The remaining findings mix local UI/test gaps, gated Supabase writes, low-traffic advisor signals, and external Auth services.
Consequences: Q-34 through Q-42 cover index evidence/tuning, groomer in-app notification remote parity, remote TestOps, no-screenshot UI lifecycle automation, and visible pagination. Q-92/Q-93 retain non-Apple service blockers. Q-90/Q-91, T-157, and `customer_push_tokens` advisor noise are outside this sequence. No index may be added or removed solely from an advisor label; Q-34 must map findings to actual query, join, cascade, and statistics evidence first.
Linked files: docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md, docs/04_ios/LIST_PAGINATION_AUDIT.md, docs/04_ios/testops/runs/T-221_DUAL_ROLE_E2E_WALKTHROUGH.md, docs/04_ios/release/T-222_IDEAL_OPERATION_READINESS_REHEARSAL.md
```

```text
Decision ID: D-021
Date: 2026-07-09
Decision: Adopt the V1.0 ideal-operation review plan as governed roadmap and queue packages.
Context: The user asked to plan and create tasks from root `V1.0_RELEASE_TASK_PLAN.md`. The root plan is a gitignored external review draft and must not become an active task source or pre-assign future task numbers.
Consequences: `ROADMAP.md` now records the V1.0 ideal-operation target, milestones M6-M8, and external D blockers. `ROADMAP_EXECUTION_QUEUE.md` now starts active adoptable packages at Q-16 and keeps future implementation on next `T-###` assignment from `TASK_LEDGER.md`, one package per task. Supabase migrations, Auth config writes, APNs/TestFlight/App Store work, remote TestOps, seeds, deploys, and other non-Git remote writes still require explicit authorization.
Linked files: docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md, docs/06_tasks/TASK_LEDGER.md, V1.0_RELEASE_TASK_PLAN.md
```

```text
Decision ID: D-020
Date: 2026-07-09
Decision: Use Resend-backed Supabase custom SMTP and HTTPS-first Auth redirects for production email links.
Context: Q-06/R-007 required a production email/deep-link design. Supabase's default hosted mailer is non-production and restricted; current iOS code has no `redirectTo`, URL scheme, associated domain, or callback handler. The project does not yet have a production domain or SMTP credentials.
Consequences: Q-07 must wait for a verified production auth domain and SMTP credentials before remote Auth configuration. Production uses exact HTTPS universal-link redirects first, `com.hellobeckon.beckon://auth/callback` only as dev/test fallback, and no production wildcard redirect URLs. No SMTP secret or callback token may be embedded in Swift, tracked docs, or debug logs.
Linked files: docs/03_backend/AUTH_EMAIL_DEEP_LINK_DESIGN.md, docs/03_backend/SUPABASE_CONTRACT.md, ios/Beckon/Config/AppInfo.plist, ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseAuthSessionRepository.swift
```

```text
Decision ID: D-019
Date: 2026-07-09
Decision: Keep customer request wizard drafts ephemeral to the active sheet.
Context: Q-05/R-006 required a persistence decision for partially entered grooming request input. Cross-session or disk persistence would add stale location/photo risk and cross-account cleanup requirements; silently retaining hidden sheet state after cancel/dismiss also conflicts with the current explicit start-create and republish entry points.
Consequences: Request wizard input is not saved to disk or restored across app launches. Back/cancel and swipe dismiss discard unpublished draft fields/photos and reset the next create flow to defaults. Publish failures preserve input so customers can correct validation/backend errors, and explicit republish remains the only prefilled request flow.
Linked files: ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsStore.swift, ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsView.swift, ios/Beckon/BeckonTests/CustomerRequestFeatureTests.swift
```

```text
Decision ID: D-018
Date: 2026-07-09
Decision: Use a bounded roadmap execution queue between ROADMAP candidates and task-ledger work.
Context: The user asked to plan and create a series of tasks from `docs/06_tasks/ROADMAP.md`. ROADMAP is the governed milestone index and explicitly must not allocate future task IDs.
Consequences: `ROADMAP_EXECUTION_QUEUE.md` now lists adoptable packages Q-01 through Q-15 derived from R-005 through R-015. Future execution still receives the next `T-###` from `TASK_LEDGER.md`, one primary package per run, with blocked packages staying inactive until blockers clear.
Linked files: docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md, docs/06_tasks/TASK_LEDGER.md
```

```text
Decision ID: D-017
Date: 2026-07-08
Decision: Remove stale 85% active-Markdown execution rules and stop on rejected automatic pushes.
Context: T-183/T-184 replaced the 85% cleanup trigger with hard active-Markdown limits, 95% structural-review warnings, and deterministic rolling-window rotation, but older T-182 stop/closeout wording remained active. T-180 standing Git approval also did not define what to do when a push fails or is rejected.
Consequences: Active workflow rules now use `node scripts/context-rotate.mjs --apply` for rolling-window overflow, treat 95% active-Markdown warnings as review scheduling rather than compression targets, and stop only on hard-limit failures that cannot be resolved in scope. If a task-completion push fails or is rejected, Codex must stop and report without auto pull, rebase, merge, reset, force-push, or remote reconciliation.
Linked files: AGENTS.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/STOP_CONDITIONS.md, docs/05_workflow/TOOLING_POLICY.md, docs/05_workflow/GITHUB_RULES.md
```

```text
Decision ID: D-016
Date: 2026-07-09
Decision: Adopt the structural context-budget workflow in active agent rules.
Context: T-183 implemented the 36k active Markdown hard limit, default 650-word budgets, 95% structural-review warning, and deterministic rotation. The active workflow still described the older 85% cleanup trigger.
Consequences: `AGENTS.md` and `CONTEXT_AND_RECOVERY.md` now direct agents to use `node scripts/context-rotate.mjs --apply` for rolling-window overflow, treat active Markdown percentage as a structural signal rather than a compression target, keep WINDOW files bounded, use replacement semantics for INDEX files, and compress FIXED files only by owner-pointer, single-source, frozen-history, or frozen-example criteria. This supersedes D-014's 85% cleanup-trigger rule.
Linked files: AGENTS.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, scripts/context-hygiene-check.mjs, scripts/context-rotate.mjs
```


## Archived Decision Index

Full text for the entries below is preserved in `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

| Date | Decision | Current entry point |
|---|---|---|
| 2026-07-09 | Replace the active Markdown 85% cleanup trigger with structural context-budget tooling. | `../09_frozen/decisions/DECISION_LOG_D-015_2026-07-10.md` |
| 2026-07-09 | Superseded by D-016/D-017: treat the active Markdown 85% waterline as a cleanup trigger. | `../09_frozen/decisions/DECISION_LOG_D-014_2026-07-09.md` |
| 2026-07-08 | Treat task-completion commit and push as standing user-authorized Git actions. | `../09_frozen/decisions/DECISION_LOG_D-013_2026-07-09.md` |
| 2026-07-08 | Reduce active Markdown before raising the 32k total budget. | `../09_frozen/decisions/DECISION_LOG_D-012_2026-07-09.md` |
| 2026-07-08 | Keep branch baseline as a single active fact in CURRENT_STATE. | `../09_frozen/decisions/DECISION_LOG_D-011_2026-07-09.md` |
| 2026-07-08 | Track meta-review cadence by completed-task distance, not wall-clock age. | `../09_frozen/decisions/DECISION_LOG_D-010_2026-07-09.md` |
