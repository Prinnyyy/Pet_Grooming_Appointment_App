import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const projectRoot = process.cwd();
const scriptPath = path.join(projectRoot, "scripts/context-hygiene-check.mjs");

function writeFixtureFile(root, filePath, text) {
  const fullPath = path.join(root, filePath);
  mkdirSync(path.dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, text);
}

function createFixture({ branch = "codex/test-baseline", latest = "T-005", next = "T-006" } = {}) {
  const root = mkdtempSync(path.join(tmpdir(), "context-hygiene-"));
  const small = "# Placeholder\n\nCurrent active placeholder.\n";
  const verified = "Last verified: 2026-07-08.\n\n";

  writeFixtureFile(root, ".rgignore", [
    "docs/09_frozen/**",
    "artifacts/**",
    "docs/02_architecture/test_resources/T-129_*_TEST_PROFILES.md",
    "docs/08_design/Groomly.html",
    "docs/08_design/Groomly/**",
    "",
  ].join("\n"));
  writeFixtureFile(root, "AGENTS.md", `# AGENTS\n\n- Current branch baseline is \`${branch}\`.\n`);
  writeFixtureFile(root, "README.md", "# Root README\n");
  writeFixtureFile(root, "CLAUDE.md", "# Claude\n");
  writeFixtureFile(root, "docs/README.md", "# Docs README\n");
  writeFixtureFile(root, "docs/00_memory/CURRENT_STATE.md", [
    "# Current State",
    "",
    `- Latest completed task: ${latest} fixture task.`,
    `- Next task ID: use ${next} unless directed otherwise.`,
    "",
    "## Branch and Baseline",
    "",
    `- Current branch baseline: \`${branch}\`.`,
    "",
    "## Active Workflow State",
    "",
    `- Last meta-review: ${latest} on 2026-07-08.`,
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    `Current branch and task-numbering baseline: use \`${branch}\`; use \`${next}\` for the next task unless directed otherwise.`,
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    `| ${latest} | Fixture task | completed | Quick | G0 | docs | check | done |`,
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/06_tasks/ROADMAP.md", [
    "# Managed Roadmap",
    "",
    verified.trim(),
    "",
    "| Milestone | Goal | Status | Exit Signal |",
    "|---|---|---|---|",
    `| G0 | Fixture governance | ${latest} complete; ${next}+ candidates. | Indexed. |`,
    "",
    "| Roadmap ID | Milestone | Candidate | Status |",
    "|---|---|---|---|",
    `| R-001 | G0 | Fixture item | Complete ${latest} |`,
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/00_memory/WORKLOG.md", [
    "# Worklog",
    "",
    "```text",
    `Task: ${latest} - Fixture task.`,
    "```",
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/00_memory/FEATURE_INDEX.md", [
    "# Feature Index",
    "",
    verified.trim(),
    "",
    "| Feature Area | Read First | Code Area | Current Status |",
    "|---|---|---|---|",
    "| Fixture feature | `01_product/USER_ROLES.md` | `Features/Fixture/` | Current. |",
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/03_backend/SUPABASE_CONTRACT.md", [
    "# Supabase Contract",
    "",
    verified.trim(),
    "",
    "- Local migration mirror count: 2 files.",
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/03_backend/MIGRATION_RULES.md", [
    "# Migration Rules",
    "",
    verified.trim(),
    "",
    "Current migration rules.",
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/01_product/USER_ROLES.md", small);
  writeFixtureFile(root, "supabase/migrations/20260708000100_fixture_one.sql", "-- one\n");
  writeFixtureFile(root, "supabase/migrations/20260708000200_fixture_two.sql", "-- two\n");

  for (const filePath of [
    "docs/00_memory/PROJECT_MEMORY.md",
    "docs/07_decisions/DECISION_LOG.md",
    "docs/01_product/DESIGN_SYSTEM.md",
    "docs/01_product/SCREEN_INVENTORY.md",
    "docs/08_design/UI_IMPLEMENTATION_NOTES.md",
    "docs/03_backend/RLS_RPC_POLICY.md",
    "docs/03_backend/STORAGE_POLICY.md",
    "docs/04_ios/testops/TESTOPS_MEMORY.md",
    "docs/04_ios/testops/RUNBOOK.md",
    "docs/04_ios/testops/TEST_CASES.md",
    "docs/05_workflow/TOOLING_POLICY.md",
    "docs/10_project_structure/REORGANIZATION_LOG.md",
    "docs/02_architecture/test_resources/README.md",
  ]) {
    writeFixtureFile(root, filePath, small);
  }

  mkdirSync(path.join(root, "docs/09_frozen"), { recursive: true });
  mkdirSync(path.join(root, "docs/08_design"), { recursive: true });
  spawnSync("git", ["init"], { cwd: root, encoding: "utf8" });
  spawnSync("git", ["add", "."], { cwd: root, encoding: "utf8" });
  return root;
}

function runHygiene(root, extraEnv = {}) {
  return spawnSync(process.execPath, [scriptPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      CONTEXT_HYGIENE_PROJECT_ROOT: root,
      ...extraEnv,
    },
    encoding: "utf8",
  });
}

test("context hygiene passes a consistent fixture", () => {
  const root = createFixture();
  const result = runHygiene(root);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Context hygiene check passed/);
});

test("context hygiene fails when current-state and ledger task facts drift", () => {
  const root = createFixture({ latest: "T-005", next: "T-006" });
  writeFixtureFile(root, "docs/00_memory/CURRENT_STATE.md", [
    "# Current State",
    "",
    "- Latest completed task: T-004 stale fixture task.",
    "- Next task ID: use T-005 unless directed otherwise.",
    "",
    "## Branch and Baseline",
    "",
    "- Current branch baseline: `codex/wrong-baseline`.",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /latest completed task mismatch/i);
  assert.match(result.stderr, /next task ID mismatch/i);
  assert.match(result.stderr, /branch baseline mismatch/i);
});

test("context hygiene fails when the managed roadmap exceeds its budget", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/06_tasks/ROADMAP.md", `# Roadmap\n\nLast verified: 2026-07-08.\n\n${"roadmap ".repeat(1801)}\n`);

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /docs\/06_tasks\/ROADMAP\.md has \d+ words, limit 1800/i);
});

test("context hygiene falls back to git ls-files when rg is unavailable", () => {
  const root = createFixture();
  const result = runHygiene(root, { CONTEXT_HYGIENE_FORCE_NO_RG: "1" });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /warn: rg unavailable, \.rgignore behavior checks skipped/i);
  assert.match(result.stdout, /Active Markdown files: \d+/i);
});

test("context hygiene fails when a backtick path is missing", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/01_product/USER_ROLES.md", [
    "# User Roles",
    "",
    "Read `docs/01_product/MISSING.md` before changing roles.",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /docs\/01_product\/USER_ROLES\.md references missing backtick path: docs\/01_product\/MISSING\.md/i);
});

test("context hygiene resolves relative backtick paths and skips placeholders", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/06_tasks/ROADMAP.md", [
    "# Managed Roadmap",
    "",
    "Last verified: 2026-07-08.",
    "",
    "Inputs: `../00_memory/CURRENT_STATE.md`, `docs/09_frozen/**`, and `docs/<area>/EXAMPLE.md`.",
    "",
    "| Roadmap ID | Milestone | Candidate | Status |",
    "|---|---|---|---|",
    "| R-001 | G0 | Fixture item | Complete T-005 |",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Backtick paths checked: \d+/i);
});

test("context hygiene warns when active Markdown total is above the warning ratio", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/01_product/DESIGN_SYSTEM.md", [
    "# Design System",
    "",
    `${"design ".repeat(700)}`,
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/01_product/SCREEN_INVENTORY.md", [
    "# Screen Inventory",
    "",
    `${"screen ".repeat(1200)}`,
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/00_memory/WORKLOG.md", [
    "# Worklog",
    "",
    "```text",
    "Task: T-005 - Fixture task.",
    "```",
    "",
    `${"worklog ".repeat(2300)}`,
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    `Current branch and task-numbering baseline: use \`codex/test-baseline\`; use \`T-006\` for the next task unless directed otherwise.`,
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    "| T-005 | Fixture task | completed | Quick | G0 | docs | check | done |",
    "",
    `${"ledger ".repeat(1700)}`,
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/05_workflow/TOOLING_POLICY.md", [
    "# Tooling Policy",
    "",
    `${"tooling ".repeat(1300)}`,
    "",
  ].join("\n"));
  for (let index = 1; index <= 10; index += 1) {
    writeFixtureFile(root, `docs/98_fixture/extra_${index}.md`, [
      `# Extra Fixture ${index}`,
      "",
      `${"extra ".repeat(2000)}`,
      "",
    ].join("\n"));
  }

  const result = runHygiene(root);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /warn: active Markdown total at \d+% of limit/i);
});

test("context hygiene fails when a last-verified marker is stale", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/00_memory/FEATURE_INDEX.md", [
    "# Feature Index",
    "",
    "Last verified: 2026-05-01.",
    "",
    "| Feature Area | Read First | Code Area | Current Status |",
    "|---|---|---|---|",
    "| Fixture feature | `01_product/USER_ROLES.md` | `Features/Fixture/` | Current. |",
    "",
  ].join("\n"));

  const result = runHygiene(root, { CONTEXT_HYGIENE_NOW: "2026-07-08" });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /FEATURE_INDEX\.md last verified 2026-05-01 is stale/i);
});

test("context hygiene fails when the documented migration count drifts", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/03_backend/SUPABASE_CONTRACT.md", [
    "# Supabase Contract",
    "",
    "Last verified: 2026-07-08.",
    "",
    "- Local migration mirror count: 1 file.",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /migration mirror count mismatch/i);
});

test("context hygiene fails when roadmap task evidence is missing from ledgers", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/06_tasks/ROADMAP.md", [
    "# Managed Roadmap",
    "",
    "Last verified: 2026-07-08.",
    "",
    "| Roadmap ID | Milestone | Candidate | Status |",
    "|---|---|---|---|",
    "| R-001 | G0 | Fixture item | Complete T-999 |",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /ROADMAP.md references T-999 without task-ledger evidence/i);
});

test("context hygiene fails when Feature Index read-first paths are missing", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/00_memory/FEATURE_INDEX.md", [
    "# Feature Index",
    "",
    "Last verified: 2026-07-08.",
    "",
    "| Feature Area | Read First | Code Area | Current Status |",
    "|---|---|---|---|",
    "| Broken feature | `01_product/MISSING.md` | `Features/Broken/` | Current. |",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Feature Index read-first target is missing/i);
});

test("context hygiene allows roadmap completed mapping to mix completed and blocked evidence", () => {
  const root = createFixture({ latest: "T-005", next: "T-006" });
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    "Current branch and task-numbering baseline: use `codex/test-baseline`; use `T-006` for the next task unless directed otherwise.",
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    "| T-005 | Fixture task | completed | Quick | G0 | docs | check | done |",
    "| T-004 | Fixture block | blocked | Deep | M2 | docs | check | waiting |",
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/06_tasks/ROADMAP.md", [
    "# Managed Roadmap",
    "",
    "Last verified: 2026-07-08.",
    "",
    "Completed mapping: T-004 M2 blocked; T-005 G0.",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.equal(result.status, 0, result.stderr);
});

test("context hygiene checks roadmap complete and blocked status per segment", () => {
  const root = createFixture({ latest: "T-005", next: "T-006" });
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    "Current branch and task-numbering baseline: use `codex/test-baseline`; use `T-006` for the next task unless directed otherwise.",
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    "| T-005 | Fixture task | completed | Quick | G0 | docs | check | done |",
    "| T-004 | Fixture block | blocked | Deep | M2 | docs | check | waiting |",
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/06_tasks/ROADMAP.md", [
    "# Managed Roadmap",
    "",
    "Last verified: 2026-07-08.",
    "",
    "| Milestone | Goal | Status | Exit Signal |",
    "|---|---|---|---|",
    "| M2 | Fixture state | T-005 complete; T-004 dispatch blocked; T-006+ candidates. | Clear. |",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.equal(result.status, 0, result.stderr);
});

test("context hygiene fails closed when current-state facts cannot be extracted", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/00_memory/CURRENT_STATE.md", [
    "# Current State",
    "",
    "- Last completed task: T-005 fixture task.",
    "- Next task ID: use T-006 unless directed otherwise.",
    "",
    "## Branch and Baseline",
    "",
    "- Current branch baseline: `codex/test-baseline`.",
    "",
    "## Active Workflow State",
    "",
    "- Last meta-review: T-005 on 2026-07-08.",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /CURRENT_STATE\.md is missing an extractable latest completed task/i);
});

test("context hygiene fails when the meta-review marker is missing", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/00_memory/CURRENT_STATE.md", [
    "# Current State",
    "",
    "- Latest completed task: T-005 fixture task.",
    "- Next task ID: use T-006 unless directed otherwise.",
    "",
    "## Branch and Baseline",
    "",
    "- Current branch baseline: `codex/test-baseline`.",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /CURRENT_STATE\.md is missing an extractable Last meta-review marker/i);
});

test("context hygiene fails when meta-review is ten completed tasks old", () => {
  const root = createFixture({ latest: "T-015", next: "T-016" });
  writeFixtureFile(root, "docs/00_memory/CURRENT_STATE.md", [
    "# Current State",
    "",
    "- Latest completed task: T-015 fixture task.",
    "- Next task ID: use T-016 unless directed otherwise.",
    "",
    "## Branch and Baseline",
    "",
    "- Current branch baseline: `codex/test-baseline`.",
    "",
    "## Active Workflow State",
    "",
    "- Last meta-review: T-005 on 2026-07-08.",
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    "Current branch and task-numbering baseline: use `codex/test-baseline`; use `T-016` for the next task unless directed otherwise.",
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    "| T-015 | Fixture task | completed | Quick | G0 | docs | check | done |",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Last meta-review T-005 is 10 completed tasks behind/i);
});

test("context hygiene allows meta-review at nine completed tasks old", () => {
  const root = createFixture({ latest: "T-014", next: "T-015" });
  writeFixtureFile(root, "docs/00_memory/CURRENT_STATE.md", [
    "# Current State",
    "",
    "- Latest completed task: T-014 fixture task.",
    "- Next task ID: use T-015 unless directed otherwise.",
    "",
    "## Branch and Baseline",
    "",
    "- Current branch baseline: `codex/test-baseline`.",
    "",
    "## Active Workflow State",
    "",
    "- Last meta-review: T-005 on 2026-07-08.",
    "",
  ].join("\n"));
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    "Current branch and task-numbering baseline: use `codex/test-baseline`; use `T-015` for the next task unless directed otherwise.",
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    "| T-014 | Fixture task | completed | Quick | G0 | docs | check | done |",
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.equal(result.status, 0, result.stderr);
});

test("context hygiene fails when a task ledger row is too long", () => {
  const root = createFixture();
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    "Current branch and task-numbering baseline: use `codex/test-baseline`; use `T-006` for the next task unless directed otherwise.",
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    `| T-005 | Fixture task | completed | Quick | G0 | docs | check | ${"long note ".repeat(90)} |`,
    "",
  ].join("\n"));

  const result = runHygiene(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /TASK_LEDGER\.md table row \d+ has \d+ characters, limit 700/i);
});
