# Context Window Rotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace word-triggered Markdown compression and one-entry rotation with informational word telemetry, buffered entry-count windows, and later manual context compaction for the 353,000-token model context.

**Architecture:** `scripts/context-hygiene-policy.mjs` owns reference telemetry and structural high/low watermarks. `scripts/context-hygiene-check.mjs` reports word counts without failing and enforces only structural window maxima. `scripts/context-rotate.mjs` archives one batch from a breached high watermark down to its retained count, while preserving non-completed tasks and bounding decision archive pointers.

**Tech Stack:** Node.js ES modules, `node:test`, Markdown workflow policy, Git.

## Global Constraints

- Word counts are informational only and never warn, fail, stop, compress, or rotate content.
- Ledger uses trigger 18 and retain 12; Worklog and active decisions use trigger 14 and retain 8.
- Every rolling file has six free entries after rotation.
- Decision archive pointers use trigger 12 and retain 6, with one pointer per decision archive batch.
- Blocked and current ledger rows remain active.
- Manual context compaction starts only at task boundaries under the approved 65%/80% policy for a 353,000-token context.
- No Swift, Supabase, dependency, product behavior, or remote-service change.

---

### Task 1: Make Word Budgets Informational

**Files:**
- Modify: `tests/docs/context-hygiene-check.test.mjs`
- Modify: `scripts/context-hygiene-policy.mjs`
- Modify: `scripts/context-hygiene-check.mjs`

**Interfaces:**
- Consumes: current `words()`, active Markdown discovery, and reference maps.
- Produces: `DEFAULT_WORD_REFERENCE`, `WORD_REFERENCES`, `MODEL_CONTEXT_CAPACITY_TOKENS`, informational per-file output, and informational total-word output.

- [ ] **Step 1: Replace word-failure tests with telemetry tests**

Change the managed-roadmap, unlisted-file, structural-warning, and hard-total tests so oversized fixtures expect status 0 and output matching `reference only`, `over`, `Active Markdown words`, and `353000 tokens`. They must assert that stderr contains neither the old per-file failure nor the old 36,000-word hard-limit failure.

- [ ] **Step 2: Run the focused hygiene tests and verify RED**

Run: `node --test tests/docs/context-hygiene-check.test.mjs`

Expected: FAIL because current code still exits nonzero for per-file and total word excess and still prints the 95% warning.

- [ ] **Step 3: Implement telemetry-only word reporting**

Rename the policy exports to:

```js
export const MODEL_CONTEXT_CAPACITY_TOKENS = 353000;
export const DEFAULT_WORD_REFERENCE = 650;
export const WORD_REFERENCES = new Map([...]);
```

Remove `ACTIVE_MARKDOWN_TOTAL_LIMIT` and `ACTIVE_MARKDOWN_STRUCTURE_REVIEW_RATIO`. Replace `checkWordLimits()` with a reporter that prints `reference only`, never appends to `failures`, and reports the sum of references. Replace `checkActiveMarkdownTotal()` with `reportActiveMarkdownWords()` that prints the actual word total plus the 353,000-token model reference without estimating words as tokens.

- [ ] **Step 4: Run the focused hygiene tests and verify GREEN**

Run: `node --test tests/docs/context-hygiene-check.test.mjs`

Expected: all hygiene tests pass.

### Task 2: Add Buffered Structural Windows

**Files:**
- Modify: `tests/docs/context-hygiene-check.test.mjs`
- Modify: `tests/docs/context-rotate.test.mjs`
- Modify: `scripts/context-hygiene-policy.mjs`
- Modify: `scripts/context-hygiene-check.mjs`
- Modify: `scripts/context-rotate.mjs`

**Interfaces:**
- Consumes: fixture builders and current row/entry parsers.
- Produces: `*_TRIGGER` and `*_RETAIN` constants plus one-pass rotation to retained counts.

- [ ] **Step 1: Add RED tests for exact triggers and retained counts**

Add hygiene fixtures proving 18 ledger rows, 14 worklog entries, and 14 active decisions pass while one additional item fails with the structural trigger in the error. Update rotation tests so 19 ledger rows become 12, 15 worklog entries become 8, and 15 decisions become 8. Add a dry-run fixture showing six entries added after a retained state do not rotate. Preserve the blocked-row assertion.

- [ ] **Step 2: Run both focused suites and verify RED**

Run: `node --test tests/docs/context-hygiene-check.test.mjs tests/docs/context-rotate.test.mjs`

Expected: FAIL because current limits are 12/8/8 and rotation removes only the amount above those same limits.

- [ ] **Step 3: Implement high/low watermark constants and rotation**

Use these policy exports:

```js
export const WORKLOG_ENTRY_TRIGGER = 14;
export const WORKLOG_ENTRY_RETAIN = 8;
export const TASK_LEDGER_ROW_TRIGGER = 18;
export const TASK_LEDGER_ROW_RETAIN = 12;
export const TASK_LEDGER_ROW_CHAR_LIMIT = 700;
export const DECISION_LOG_ENTRY_TRIGGER = 14;
export const DECISION_LOG_ENTRY_RETAIN = 8;
```

Hygiene fails only above each trigger. Rotation returns without changes at or below the trigger; above it, it removes enough oldest eligible entries to reach the retain value. If completed ledger rows are insufficient, report the remaining overflow and do not loop.

- [ ] **Step 4: Run both focused suites and verify GREEN**

Run: `node --test tests/docs/context-hygiene-check.test.mjs tests/docs/context-rotate.test.mjs`

Expected: all focused tests pass.

### Task 3: Batch and Bound Decision Archive Pointers

**Files:**
- Modify: `tests/docs/context-hygiene-check.test.mjs`
- Modify: `tests/docs/context-rotate.test.mjs`
- Modify: `scripts/context-hygiene-policy.mjs`
- Modify: `scripts/context-hygiene-check.mjs`
- Modify: `scripts/context-rotate.mjs`

**Interfaces:**
- Consumes: `## Archived Decision Index` Markdown table and decision archive path.
- Produces: one pointer row per archived decision batch and frozen pointer-index archives.

- [ ] **Step 1: Add RED tests for batch pointers and pointer-window rotation**

Update the decision rotation assertion to expect one row such as `Archived decisions D-001 to D-007.` pointing to the batch archive. Add a fixture with 13 archive-pointer rows and assert one apply run retains 6 newest rows and writes the 7 oldest rows verbatim to `docs/09_frozen/decisions/DECISION_ARCHIVE_INDEX_...md`. Add a hygiene test proving 13 active pointers fail the structural check.

- [ ] **Step 2: Run both focused suites and verify RED**

Run: `node --test tests/docs/context-hygiene-check.test.mjs tests/docs/context-rotate.test.mjs`

Expected: FAIL because current rotation inserts one pointer per decision and does not parse or bound pointer rows.

- [ ] **Step 3: Implement batch pointer insertion and pointer rotation**

Add:

```js
export const DECISION_ARCHIVE_POINTER_TRIGGER = 12;
export const DECISION_ARCHIVE_POINTER_RETAIN = 6;
```

Parse only table rows under `## Archived Decision Index`. Insert one newest-first batch row after the table separator. When pointers exceed 12, remove the oldest rows down to 6 and write them with the same table header to a unique frozen decision-index archive. Hygiene reports pointer count and fails only above 12.

- [ ] **Step 4: Run both focused suites and verify GREEN**

Run: `node --test tests/docs/context-hygiene-check.test.mjs tests/docs/context-rotate.test.mjs`

Expected: all focused tests pass.

### Task 4: Align Active Rules and Close Out T-245

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`
- Modify: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
- Modify: `docs/05_workflow/STOP_CONDITIONS.md`
- Modify: `docs/07_decisions/DECISION_LOG.md`
- Modify: `docs/00_memory/CURRENT_STATE.md`
- Modify: `docs/06_tasks/TASK_LEDGER.md`
- Modify: `docs/00_memory/WORKLOG.md`
- Create through script: `docs/09_frozen/decisions/DECISION_ARCHIVE_INDEX_2026-07-09.md`

**Interfaces:**
- Consumes: the approved T-245 design and implemented script output.
- Produces: D-024, T-245 closeout, next task T-246, and one consistent active workflow.

- [ ] **Step 1: Update workflow wording**

State that words are reference telemetry only, rolling windows rotate by entry count in one batch, six task slots are restored, and unresolved structural overflow is the only rotation-related stop. Replace the 30%/50% compaction rules with below-65%, 65%-to-below-80%, and at-or-above-80% task-boundary guidance for 353,000 tokens.

- [ ] **Step 2: Record the durable decision and closeout**

Add D-024 with the high/low watermarks and informational-word semantics. Set CURRENT_STATE latest to T-245 and next to T-246, replace the T-184 budget fact, add the T-245 ledger row, and prepend one concise T-245 Worklog entry.

- [ ] **Step 3: Apply any structural pointer rotation once**

Run: `node scripts/context-rotate.mjs --apply`

Expected: existing decision archive pointers rotate to 6 if they exceed 12; ledger, Worklog, and active decisions remain below their new triggers. The script must not rotate based on words.

### Task 5: Verify, Commit, and Push

**Files:**
- Review all T-245 files only.

**Interfaces:**
- Consumes: completed implementation and closeout records.
- Produces: a validated task-scoped commit pushed to `codex/pet-fit-structure-cleanup`.

- [ ] **Step 1: Run complete task validation**

Run:

```sh
node --test tests/docs/context-hygiene-check.test.mjs tests/docs/context-rotate.test.mjs
node scripts/context-rotate.mjs
git diff --check
node scripts/context-hygiene-check.mjs
```

Expected: tests pass, rotation dry run reports no required rotation, diff check is clean, word telemetry may show `over` but hygiene passes, and every structural window reports at least six available entries from its retained state.

- [ ] **Step 2: Review scope and secrets**

Run: `git status --short`, `git diff --stat`, and targeted diffs for every changed file. Confirm no Swift, Supabase, dependency, credential, or unrelated user file is included.

- [ ] **Step 3: Commit and push under standing approval**

Stage only T-245 files, commit with `T-245: tooling: add buffered context rotation`, and push `codex/pet-fit-structure-cleanup`. If push is rejected, stop without pull, rebase, merge, reset, force-push, or retry reconciliation.
