# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-07-12

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
