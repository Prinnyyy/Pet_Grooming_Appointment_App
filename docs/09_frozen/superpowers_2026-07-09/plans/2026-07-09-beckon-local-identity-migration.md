# Beckon Local Identity Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Q-94 by replacing the local Groomly/PetGroomerMarketplace identity with the approved Beckon identity across the iOS app, Xcode project, source symbols, TestOps, seed resources, scripts, active product documentation, design source, and prepared backend runtime changes.

**Architecture:** Treat the approved contract in `docs/06_tasks/BECKON_BRAND_MIGRATION.md` as canonical. A repository identity audit defines the mutable active tree and explicitly excludes immutable history plus the Q-95 workflow boundary. Mechanical renames preserve product behavior while a new, unapplied migration and updated Edge Function prepare the remote Q-96 cutover.

**Tech Stack:** Swift 6, SwiftUI, Xcode `.pbxproj`/shared schemes, Node.js `node:test`, Bash, Supabase PostgreSQL migrations and Edge Functions.

## Global Constraints

- Brand is `Beckon`; App Store name is `Beckon: Pet Grooming`; tagline is `Pet groomers at your beck and call.`
- Xcode project/target/module names are `Beckon`, `BeckonTests`, and `BeckonUITests` under `ios/Beckon/`.
- Bundle ID and URL scheme are `com.hellobeckon.beckon`; callback is `com.hellobeckon.beckon://auth/callback`.
- Seed identities are `beckon.customer001...050@example.com`, `beckon.groomer001...050@example.com`, password `BeckonTest!2026`, IDs `BTC-###`/`BTG-###`, and metadata `beckon_seed`/`beckon_seed_id`.
- Do not edit applied migrations, `docs/09_frozen/**`, Git history, `AGENTS.md`, `CLAUDE.md`, or `docs/05_workflow/**` in Q-94.
- Do not perform remote writes in Q-94.

---

### Task 1: Active Identity Audit

**Files:**
- Create: `scripts/beckon-identity-check.mjs`
- Create: `tests/brand/beckon-identity-check.test.mjs`
- Create: `scripts/beckon-identity-check.sh`

**Interfaces:**
- Produces: `auditBeckonIdentity(root): { violations: Array<{ path, line, token }> }` and a zero/non-zero CLI gate.
- Excludes: `.git/**`, `docs/09_frozen/**`, applied `supabase/migrations/**`, Q-95 workflow files, ignored generated/runtime artifacts, and this migration plan/contract where historical names are required to define the transition.

- [x] Write tests proving the audit detects old product identifiers in a fixture, accepts canonical Beckon identifiers, and ignores immutable/workflow paths.
- [x] Run `node --test tests/brand/beckon-identity-check.test.mjs`; expect RED because the audit module does not exist.
- [x] Implement the deterministic text-file audit and shell wrapper without external dependencies.
- [x] Run the focused test; expect GREEN.
- [x] Run `./scripts/beckon-identity-check.sh`; expect RED against the current active tree and retain the violation list as the rename inventory.

### Task 2: Xcode and Swift Identity

**Files:**
- Move: `ios/PetGroomerMarketplace/` -> `ios/Beckon/`
- Move: app/test/source directories, `.xcodeproj`, shared scheme, `PetGroomerMarketplaceApp.swift`, `Groomly*.swift`, and `GroomlyAddressSearch.swift` to their canonical Beckon names.
- Modify: `ios/Beckon/Beckon.xcodeproj/project.pbxproj`
- Modify: `ios/Beckon/Beckon.xcodeproj/xcshareddata/xcschemes/Beckon.xcscheme`
- Modify: `ios/Beckon/Config/AppInfo.plist`
- Modify: active Swift source and tests under `ios/Beckon/`.

**Interfaces:**
- Produces: app target/module `Beckon`, test imports `@testable import Beckon`, `BeckonApp`, `Beckon*` primitives/types, canonical bundle/scheme/callback identifiers.
- Preserves: existing SwiftUI flows, repository/store boundaries, entitlements, assets, and Supabase runtime behavior.

- [x] Mechanically rename project/source paths and exact old symbols.
- [x] Update `.pbxproj`, shared scheme, plist display/bundle URL identity, test host/module imports, and script references.
- [x] Replace user-facing product copy and add the exact approved tagline on authentication surfaces.
- [x] Rename diagnostic subsystem, support directories, cache namespaces, UserDefaults keys, launch arguments, accessibility identifiers, and notification IDs.
- [x] Run `xcodebuild -list -project ios/Beckon/Beckon.xcodeproj`; expect `Beckon`, `BeckonTests`, and `BeckonUITests` with shared scheme `Beckon`.

### Task 3: TestOps and Seed Identity

**Files:**
- Modify: `scripts/testops.mjs`, `scripts/testops-core.mjs`, `scripts/seed-t129-customers.mjs`, `scripts/seed-t129-groomers.mjs`, and iOS TestOps scripts.
- Modify: `tests/testops/**` and relevant `tests/ios/**`.
- Modify: `docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md` and `T-129_GROOMER_TEST_PROFILES.md`.
- Modify: active TestOps documentation under `docs/04_ios/testops/**`.

**Interfaces:**
- Produces: BTC/BTG selectors and Beckon seed credentials while preserving the same 50+50 profile data and TestOps scenario behavior.
- Preserves: remote-write approval gate, redaction, run tags, cleanup ownership, scenario IDs, and no-screenshot lifecycle semantics.

- [x] Update parser/selector tests first to expect BTC/BTG, Beckon addresses, password, and metadata; run focused tests and observe RED.
- [x] Update resource tables, parsers, matrices, defaults, seed validation, metadata, cleanup filters, and documentation examples.
- [x] Run `./scripts/testops-unit.sh`; expect all tests GREEN.
- [x] Run doctor, lifecycle dry-run, and matching dry-run; confirm no remote writes and only Beckon seed references.

### Task 4: Design, Product Docs, and Prepared Backend Runtime

**Files:**
- Move/modify: `docs/08_design/Groomly.html` and `docs/08_design/Groomly/**` to `Beckon` names/content.
- Modify: active product, architecture, iOS, project-structure, memory, and index Markdown outside the Q-95 boundary.
- Modify: `supabase/functions/dispatch-customer-push-notifications/dispatcher.mjs` and its tests.
- Create: the next CLI-generated migration under `supabase/migrations/` to replace live cron runtime naming during Q-96.

**Interfaces:**
- Produces: `payload.beckon` in prepared dispatcher code and an append-only cron-name migration that unschedules `groomly_expire_grooming_requests` then schedules `beckon_expire_grooming_requests` with the unchanged operation.
- Preserves: applied migration files and undeployed APNs dispatcher status.

- [x] Update dispatcher tests to expect `payload.beckon`; run focused test and observe RED.
- [x] Update dispatcher implementation and create the append-only migration with `supabase migration new t246_prepare_beckon_runtime_identity`.
- [x] Add/update rollback-only migration validation for the cron rename without applying it remotely.
- [x] Mechanically rename design source and active product documentation, retaining explicit historical references only in the contract/audit exception index.
- [x] Run Edge Function, migration, privacy, Supabase local checks, and the active identity audit.

### Task 5: Full Verification and Closeout

**Files:**
- Modify: `docs/06_tasks/TASK_LEDGER.md`, `docs/00_memory/WORKLOG.md`, `docs/00_memory/CURRENT_STATE.md`, `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md`, and `docs/06_tasks/ROADMAP.md`.
- Move: this completed plan to the frozen completed-plan location required by context governance.

**Interfaces:**
- Produces: completed T-246/Q-94 evidence and makes Q-95 the next task.

- [x] Run `./scripts/beckon-identity-check.sh`, `xcodebuild -list`, `./scripts/testops-unit.sh`, TestOps dry-runs, `./scripts/supabase-check.sh`, migration/Edge/privacy tests, `./scripts/ios-test.sh`, `./scripts/ios-build.sh`, and `git diff --check`.
- [x] Launch Beckon in Simulator and verify auth branding/tagline plus customer/groomer surfaces contain no old product name.
- [x] Review the complete diff and ensure no credentials, remote writes, applied migration edits, frozen-record edits, or Q-95 workflow edits occurred.
- [x] Record T-246 closeout, mark Q-94 complete, set Q-95 next, run context rotation if required, then rerun context hygiene and diff checks; record the intentionally deferred Q-95 workflow-path finding.
- [x] Commit only T-246 files as `T-246: migrate local identity to Beckon` and push `codex/pet-fit-structure-cleanup`.

## Self-Review

- Spec coverage: project/target/module, UI/tagline, symbols/files, diagnostics/caches, scripts, TestOps/seeds, design/product docs, backend preparation, historical boundary, and all local gates are assigned above.
- Placeholder scan: no deferred implementation placeholders; remote Q-96 work is intentionally outside Q-94.
- Type consistency: the audit, Beckon Xcode names, BTC/BTG seed contract, `payload.beckon`, and cron identifiers are consistent across tasks.
