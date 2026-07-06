# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived at `docs/09_frozen/worklogs/WORKLOG_2026-06-20_to_2026-07-01.md`, `docs/09_frozen/worklogs/WORKLOG_2026-07-01_T-132_TO_T-136.md`, and `docs/09_frozen/worklogs/WORKLOG_2026-07-01_T-137_TO_T-140.md`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Older `Next:` lines and branch references are historical closeout notes, not current instructions.

```text
Date: 2026-07-06
Task: T-153 - Customer in-app notification center.
Files changed: `customer_notifications` migration, customer notification model/repository/store/view, Customer Home bell navigation, debug repository wrapper, Swift/SQL tests, screen/feature/memory docs.
Checks: RED SQL migration test and RED Swift store compile test; `node --test tests/migrations/customer-notifications.test.mjs`; `supabase migration list --linked`; `supabase db push --linked --dry-run`; `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Customer Home bell now routes to a Customer notification list backed by repository/store boundaries, with timestamped read/unread system notifications and mark-read actions. The local migration creates the notification table, RLS policies, mark-read RPCs, and first event triggers for request published/cancelled and booking confirmed/cancelled.
Risks: Remote DDL was not applied, and live RLS/RPC/UI verification against Supabase was not run, because remote writes require separate explicit user authorization. Until `20260706203710_t153_customer_notifications.sql` is applied, production Supabase will not have the notification table/RPCs.
Next: Get explicit authorization to apply the T-153 migration and run RLS/RPC/live-flow checks; after that, continue to T-154 unless the user names another task.
```

```text
Date: 2026-07-06
Task: T-152 - Groomer Offers tab.
Files changed: Groomer tab routing, `GroomerOffersView`, `GroomerOffersStore`, groomer offer list models/repository adapter, tests, `SCREEN_INVENTORY`, memory docs.
Checks: RED compile failure for missing offers list surface; `./scripts/ios-test.sh`; `./scripts/ios-build.sh`; XcodeBuildMCP iPhone 17 Offers-tab目检; `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Groomers now have a visible Offers tab showing submitted offers grouped by status with readable request or booking context when available.
Risks: No Supabase schema/RLS/RPC/Storage, migrations, dependencies, seed data, remote writes, commits, or pushes changed. Offer creation and withdrawal remain in Board/request detail.
Next: Use T-153 unless the user names another task ID.
```

```text
Date: 2026-07-06
Task: T-151 - Active Markdown baseline recheck and AGENTS hardening.
Files changed: AGENTS.md, memory docs, ledger/worklog rolling archives, project-structure log.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`; active stale-reference searches.
Result: Active docs use the T-151/T-152 baseline and AGENTS now rejects external reports as authoritative sources.
Risks: Docs-only. No iOS, Supabase, runtime, seed, simulator, commit, or push change.
Next: Use T-152 unless the user names another task ID.
```

```text
Date: 2026-07-06
Task: T-150 - Restore correct task baseline and archive external audit drafts.
Files changed: moved root reports to frozen; updated ignore/search and memory/ledger/archive indexes.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Result: Active baseline is `codex/pet-fit-structure-cleanup`; T-151 is next.
Risks: Docs-only. `main` remote reconciliation needs explicit approval.
Next: Use T-151 unless the user names another task ID.
```

```text
Date: 2026-07-02
Task: T-149 - Active design document slimming.
Files changed: docs/01_product/DESIGN_SYSTEM.md, docs/08_design/UI_IMPLEMENTATION_NOTES.md, docs/09_frozen/design_notes/, scripts/context-hygiene-check.mjs, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs indexes, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. `node scripts/context-hygiene-check.mjs` passed with `DESIGN_SYSTEM.md` and `UI_IMPLEMENTATION_NOTES.md` under the new 900-word budgets. Archive/reference checks confirmed the full pre-slim design texts exist under `docs/09_frozen/design_notes/`.
Simulator launch: Skipped because this was docs/design-context cleanup only and did not affect iOS app/UI behavior.
Result: Active design docs now keep only current design-system rules, Groomly visual summary, screenshot rework boundaries, and source routing. Full historical T-023 through T-035 design-system narrative and prototype audit details are preserved in frozen design-note archives.
Risks: No Swift source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, simulator, or remote state changed.
Next: Use T-150 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-148 - Pointer/template cleanup and Claude path correction.
Files changed: docs/00_memory/DECISION_LOG.md, docs/05_workflow/LIGHTWEIGHT_FINAL_REPORT_TEMPLATE.md, docs/06_tasks/LIGHTWEIGHT_TASK_PROMPT_TEMPLATE.md, docs/06_tasks/TASK_INTAKE_TEMPLATE.md, docs/09_frozen/memory_pointers/, docs/09_frozen/workflow_templates/, docs/09_frozen/task_templates/, CLAUDE.md, CLAUDE_reference/, docs indexes, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. `node scripts/context-hygiene-check.mjs` passed. Active stale-reference search found no deleted active paths outside historical worklog/reorganization audit text.
Simulator launch: Skipped because this was docs/archive cleanup only and did not affect iOS app/UI behavior.
Result: The memory decision-log compatibility pointer and low-use lightweight workflow/task templates were archived under `docs/09_frozen/` and removed from active docs. Claude files remain active, with stale Fresh Brief and Groomly prompt references corrected to current product/design/workflow entrypoints.
Risks: No iOS source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, simulator, or remote state changed.
Next: Use T-149 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-147 - Active historical pointer and root brief cleanup.
Files changed: Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md, docs/09_frozen/product_briefs/FRESH_PET_GROOMER_MARKETPLACE_ENGINEERING_BRIEF_2026-07-02.md, docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md, README.md, PRODUCT_BRIEF.md, UI_IMPLEMENTATION_NOTES.md, DECISION_LOG.md, project-structure indexes, frozen archive index, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. `node scripts/context-hygiene-check.mjs` passed. Active reference search confirmed the deleted active files are no longer used outside the reorganization-log move record and frozen archive pointers.
Simulator launch: Skipped because this was docs/archive cleanup only and did not affect iOS app/UI behavior.
Result: The original root product/engineering brief is now frozen under `docs/09_frozen/product_briefs/` and removed from the repository root. The active Groomly design prompt pointer was deleted because the full prompt is already frozen. Active product/design work now routes through `docs/01_product/PRODUCT_BRIEF.md` and `docs/08_design/UI_IMPLEMENTATION_NOTES.md`.
Risks: No iOS source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, simulator, or remote state changed.
Next: Use T-148 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-146 - AI collaboration context indexing and policy trim.
Files changed: AGENTS.md, workflow/context/stop docs, docs indexes, FEATURE_INDEX.md, backend policy docs, TestOps memory, Groomly design prompt pointer, frozen archives, context hygiene script, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. `node scripts/context-hygiene-check.mjs` passed word budgets, active Markdown link scan, default hidden-path checks, and stale TestOps credential wording checks. Targeted searches confirmed frozen archives remain default-hidden and TestOps credential docs match script behavior.
Simulator launch: Skipped because this was docs/workflow/search-hygiene only and did not affect iOS app/UI behavior.
Result: Active AI collaboration docs now use an explicit L0-L4 access model, stronger context stop conditions, compact single-purpose policy/index files, frozen pre-trim archives for historical trace, and one read-only context hygiene command for future closeouts.
Risks: No iOS source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, simulator, or remote state changed. Historical details remain in frozen archives and should be read only with targeted recovery/comparison reasons.
Next: Use T-147 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-145 - TestOps modern Supabase secret support and authorized remote matching run.
Files changed: scripts/testops-core.mjs, scripts/testops.mjs, tests/testops/testops-edge.test.mjs, Supabase/TestOps docs, decision log, results index, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: RED `node --test tests/testops/testops-edge.test.mjs` failed on missing `sb_secret` server-credential support, then GREEN passed. A second RED caught missing Supabase `access_token` normalization, then GREEN passed. `./scripts/testops-unit.sh` passed 24 Node tests. `node --check scripts/testops-core.mjs`, `node --check scripts/testops.mjs`, `git diff --check`, and context word-count checks passed. Supabase changelog was checked for relevant REST/Auth/API-key breaking-change context.
Remote: After explicit user authorization, `node scripts/testops.mjs run matching --scenario request_matching_eval --matrix matching_baseline --run-id TESTOPS-MATCH-REMOTE-20260702 --execute --cleanup` passed 8/8 against project `lqmasbuqzvcvtawonjlb`. Cleanup deleted each tagged request and associated matches; read-only verification returned `remainingTaggedRequests=0`.
Simulator launch: Skipped because this changed Node TestOps automation/docs and ran backend remote TestOps only, not iOS app/UI behavior.
Result: TestOps now accepts either legacy `SUPABASE_SERVICE_ROLE_KEY=eyJ...` or modern `SUPABASE_SECRET_KEY=sb_secret_...` for server verification and tagged cleanup. Modern secret keys are sent as `apikey` only, never Bearer, and Auth sign-in responses are normalized from `access_token` to internal `accessToken`.
Risks: No Supabase schema/RLS/RPC/Storage, migration, seed data, iOS source, dependency, or persistent remote test data changed. Seed scripts still require JWT-shaped legacy service-role keys until separately updated.
Next: Use T-146 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-144 - Matching TestOps.
Files changed: scripts/testops.mjs, scripts/testops-core.mjs, tests/testops/testops-matching.test.mjs, TestOps docs, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: RED `node --test tests/testops/testops-matching.test.mjs` failed on missing Matching TestOps exports, then GREEN passed after implementation. `./scripts/testops-unit.sh` passed 22 Node tests. `node scripts/testops.mjs run matching --scenario request_matching_eval --matrix matching_baseline --run-id TESTOPS-MATCH-DRYRUN` passed and printed 8 redacted matching plans with local candidate projection. `node --check scripts/testops-core.mjs`, `node --check scripts/testops.mjs`, and `git diff --check` passed.
Simulator launch: Skipped because this changed local Node TestOps automation and docs only, not iOS app/UI behavior.
Result: TestOps now has `request_matching_eval` with the `matching_baseline` matrix. The suite covers target groomer include/exclude assertions, same-day capacity versus exact preferred-window reason fragments, and local hard-filter projection for service type, location mode, and request-day availability using T-129 seed metadata. Remote execution remains gated and creates only tagged grooming requests, with optional tagged cleanup.
Risks: No Supabase schema/RLS/RPC/Storage, migration, seed data, iOS source, dependency, or remote state changed during T-144. Remote matching execute was later run in T-145, which also added modern `sb_secret` TestOps support.
Next: Use T-145 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-143 - TestOps edge unit tests and safety hardening.
Files changed: scripts/testops-core.mjs, scripts/testops-unit.sh, tests/testops/testops-edge.test.mjs, TestOps docs, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: RED `node --test tests/testops/testops-edge.test.mjs` failed on missing edge protections, then GREEN passed after implementation. `node --test tests/testops/testops-core.test.mjs` passed. `./scripts/testops-unit.sh` passed 17 Node tests. `node --check scripts/testops-core.mjs`, `node --check scripts/testops.mjs`, and `git diff --check` passed.
Simulator launch: Skipped because this changed local Node TestOps automation and docs only, not iOS app/UI behavior.
Result: TestOps now has dedicated edge coverage for empty/duplicate/unsafe seed resources, unsafe run ids, service-role credential type mistakes, stronger redaction of modern Supabase keys/JWTs/signed URLs, zero-tag cleanup, and zero-match lifecycle failure messages. `SupabaseREST` rejects non-JWT service-role values during construction so remote execute fails before lifecycle writes, and `./scripts/testops-unit.sh` runs every `tests/testops/*.test.mjs` file.
Risks: No Supabase schema/RLS/RPC/Storage, migration, seed data, remote write, iOS source, or dependency changed during T-143. T-145 later updated TestOps for modern `sb_secret_...` `apikey` semantics.
Next: Use T-144 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-142 - Markdown information architecture and search hygiene optimization.
Files changed: .rgignore, AGENTS.md, decision logs, SUPABASE_CONTRACT.md, test-resource docs, workflow docs, docs indexes, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md, and frozen backend contract snapshot.
Checks: `git diff --check` passed. Active Markdown link check passed. Decision-log reference checks confirmed `docs/07_decisions/DECISION_LOG.md` is the canonical full decision source and `docs/00_memory/DECISION_LOG.md` is a pointer. `.rgignore` behavior checks confirmed default `rg` skips frozen archives and T-129 seed tables while `rg --no-ignore` can target them. T-129 seed parser dry-runs passed for groomer and customer profiles. Word-count checks confirmed active hot files remain below thresholds and `SUPABASE_CONTRACT.md` is now a fast-path file.
Simulator launch: Skipped because this was docs/workflow/search-hygiene only and did not affect app/UI behavior.
Result: The active Markdown information architecture now has one complete decision-log source, a fast-path backend contract with frozen long-form archive, a test-resource index for machine-readable seed tables, and tool-level search defaults that keep frozen/heavy paths out of ordinary `rg` context.
Risks: Docs/workflow/search-hygiene only. No iOS source, Supabase schema/RLS/RPC/Storage, migrations, seed data, dependencies, or remote state changed. T-129 profile tables remain active because seed/TestOps parsers depend on their Markdown row shape.
Next: Use T-143 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-02
Task: T-141 - Automatic context hygiene workflow rules.
Files changed: AGENTS.md, SINGLE_AGENT_WORKFLOW.md, CONTEXT_AND_RECOVERY.md, docs indexes, memory guide, task guide, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: `git diff --check` passed. Context-hygiene rule search found the new AGENTS/workflow rules. Archive path existence check passed. Active-path check returned no frozen startup-source matches. Markdown link check across touched index/rule files passed. Word-count check confirmed `CURRENT_STATE.md`, `WORKLOG.md`, and `TASK_LEDGER.md` remain below thresholds.
Simulator launch: Skipped because this was docs/workflow-only and did not affect app/UI behavior.
Result: Post-task context hygiene is now part of the repository workflow. Future tasks that update durable memory must check active memory sizes and roll old content into frozen archives before final reporting when thresholds are exceeded.
Risks: Docs/workflow-only. No iOS source, Supabase schema/RLS/RPC/Storage, scripts, dependencies, or remote state changed.
Next: Use T-142 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```
