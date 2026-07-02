# Worklog

This file is the active recent closeout index, newest first. It intentionally keeps only the newest entries needed for recovery. Older verbatim history is archived at `docs/09_frozen/worklogs/WORKLOG_2026-06-20_to_2026-07-01.md` and `docs/09_frozen/worklogs/WORKLOG_2026-07-01_T-132_TO_T-136.md`.

Current branch, next task ID, and current baseline live in `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md`. Older `Next:` lines and branch references are historical closeout notes, not current instructions.

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

```text
Date: 2026-07-01
Task: T-140 - Context footprint and memory archive trim.
Files changed: CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md, CONTEXT_AND_RECOVERY.md, and frozen archive snapshots for pre-trim current state, worklog, and task ledger history.
Checks: `git diff --check` passed. `wc -w docs/00_memory/CURRENT_STATE.md docs/00_memory/WORKLOG.md docs/06_tasks/TASK_LEDGER.md` confirmed the three active hot files total under 4k words. Archive-reference `rg` check found the new frozen paths from active memory files. Active-path `rg` check returned no matches, confirming workflow startup docs do not point at frozen context as a default source.
Simulator launch: Skipped because this was docs/workflow-only and did not affect app/UI behavior.
Result: Active context hot files were trimmed from about 48.5k words to about 4.0k words by replacing long active history with fast-path current state, recent worklog entries, and recent task ledger rows. Full pre-trim content is preserved under `docs/09_frozen/`.
Risks: Docs/workflow-only. Historical content is preserved under docs/09_frozen; no iOS source, Supabase schema/RLS/RPC/Storage, scripts, dependencies, or remote state changed.
Next: Use T-141 for the next new bugfix or iteration task unless the user explicitly names another task ID.
```

```text
Date: 2026-07-01
Task: T-139 - Supabase CLI credential taxonomy documentation update.
Files changed: .gitignore, TOOLING_POLICY.md, MIGRATION_RULES.md, SUPABASE_CONTRACT.md, TestOps docs, T-129 seed resource docs, decision logs, project-structure docs, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: Confirmed branch `codex/pet-fit-structure-cleanup`. Reviewed current Supabase CLI/API-key documentation references. Prior sequential `supabase projects list`, `supabase migration list --linked`, and `supabase db push --linked --dry-run` all passed from this checkout. `git diff --check` passed.
Result: Local Supabase docs now consistently separate `SUPABASE_ACCESS_TOKEN=sbp_...` CLI login tokens, `SUPABASE_DB_PASSWORD` remote Postgres passwords, publishable client keys, modern `sb_secret_...` project secret keys, and JWT-shaped legacy `SUPABASE_SERVICE_ROLE_KEY` values. The current local CLI login/link state does not need `SUPABASE_DB_PASSWORD` for normal commands, and current seed/TestOps docs warn not to substitute `sb_secret_...` into scripts that still send service-role auth as Bearer. `supabase_environment_variables` is now ignored alongside `supabase_api_key`.
Risks: Documentation-only plus ignore-rule update. No Supabase schema, RLS, RPC, Storage, migration, seed data, iOS source, build setting, or remote data changed. Existing seed/TestOps scripts still need a future code update before they can use modern `sb_secret_...` project secret keys directly.
Next: Stop unless the user asks to commit/push or starts T-140.
```

```text
Date: 2026-07-01
Task: T-138 - Supabase tooling and credential usage rules update.
Files changed: TOOLING_POLICY.md, MIGRATION_RULES.md, SUPABASE_CONTRACT.md, DECISION_LOG.md, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: Confirmed branch `codex/pet-fit-structure-cleanup`. Reviewed current Supabase CLI docs/changelog references. `supabase --version` returned 2.107.0. Sequential `supabase migration list --linked` succeeded and showed Local/Remote migration history aligned through `20260701050012`. `git diff --check` passed.
Result: Local Supabase operating rules now explicitly forbid parallel linked CLI commands, require one sequential `migration list --linked` before diagnosing `cli_login_postgres`/SASL errors as drift, and preserve `migration repair` as recovery-only. Ignored Supabase credential files may be inspected only after explicit user authorization for the current operation, and only into ephemeral environment variables; later T-139 clarifies that the local `supabase_api_key` value is `sb_secret_...`, not a JWT service-role key. MCP SQL is documented as a read-only verification/tagged-cleanup fallback, not a normal migration path.
Risks: Documentation-only. No Supabase schema, RLS, RPC, Storage, migration, seed data, iOS source, build setting, or remote data changed.
Next: Stop unless the user asks to commit/push current T-137/T-138 local changes or starts T-139.
```

```text
Date: 2026-07-01
Task: T-137 - TestOps unit tests and smoke case catalog.
Files changed: scripts/testops.mjs, scripts/testops-core.mjs, scripts/testops-unit.sh, tests/testops/testops-core.test.mjs, docs/04_ios/testops/TEST_CASES.md, TestOps docs/indexes, IOS_BUILD_AND_TESTING.md, FEATURE_INDEX.md, CURRENT_STATE.md, WORKLOG.md, TASK_LEDGER.md.
Checks: Confirmed branch `codex/pet-fit-structure-cleanup`. Before starting T-137, committed and pushed T-136 as `5ea1665` (`chore: add TestOps automation scaffold`). RED `node --test tests/testops/testops-core.test.mjs` failed before implementation because `scripts/testops-core.mjs` did not exist. GREEN `./scripts/testops-unit.sh` passed after splitting the CLI into a testable core and adding parser, plan, matrix, safety gate, redaction, report, and cleanup tests. `node --check scripts/testops.mjs`, `node --check scripts/testops-core.mjs`, `node scripts/testops.mjs doctor --dry-run`, `node scripts/testops.mjs run backend --scenario marketplace_full_lifecycle --matrix smoke5`, `node scripts/testops.mjs cleanup --run-id TESTOPS-DRYRUN`, `./scripts/supabase-check.sh`, full `./scripts/ios-test.sh`, `./scripts/ios-build.sh`, and `git diff --check` passed. After explicit authorization, remote `smoke5` first exposed an invalid `travelRadiusMiles=null` plan for `customer_comes_to_groomer`; fixing the core to match app behavior with 15 miles made local TestOps unit/check/dry-run pass again. Authorized remote `smoke5` then passed 5/5, SQL final-state verification confirmed 5 booked requests, 5 completed bookings, and 5 five-star reviews, and tagged cleanup deleted 5 requests, 76 matches, 5 offers, 5 bookings, 5 conversations, and 5 reviews with zero tagged requests/offers/reviews remaining.
Result: T-137 is completed locally and the first authorized remote `smoke5` lifecycle has passed with cleanup. TestOps now has a thin CLI, reusable core module, Node built-in unit test script, and the documented `smoke5` backend lifecycle case catalog covering five seeded customer/groomer pairs. Dry-run remains the default and prints sanitized plans; execute/cleanup remain gated by `--execute` plus `TESTOPS_REMOTE_WRITE_APPROVED=1`.
Risks: No Supabase schema, RLS, RPC, Storage bucket/policy, or migration changed. Remote lifecycle test rows were created and then removed by `TESTOPS:<run_id>` tag; local ignored artifacts under `artifacts/testops/` retain the run summaries.
Next: Stop unless the user asks to commit/push T-137 or authorizes remote `smoke5` execution.
```
