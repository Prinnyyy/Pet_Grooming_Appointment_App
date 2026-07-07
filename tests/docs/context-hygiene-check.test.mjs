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
  ].join("\n"));
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    `Current branch and task-numbering baseline: use \`${branch}\`; use \`${next}\` for the next task unless directed otherwise.`,
    "",
    "| ID | Task | Status | Mode | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|",
    `| ${latest} | Fixture task | completed | Quick | docs | check | done |`,
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

  for (const filePath of [
    "docs/00_memory/FEATURE_INDEX.md",
    "docs/00_memory/PROJECT_MEMORY.md",
    "docs/07_decisions/DECISION_LOG.md",
    "docs/01_product/DESIGN_SYSTEM.md",
    "docs/01_product/SCREEN_INVENTORY.md",
    "docs/08_design/UI_IMPLEMENTATION_NOTES.md",
    "docs/03_backend/SUPABASE_CONTRACT.md",
    "docs/03_backend/RLS_RPC_POLICY.md",
    "docs/03_backend/STORAGE_POLICY.md",
    "docs/03_backend/MIGRATION_RULES.md",
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

test("context hygiene reports a clean missing-rg error", () => {
  const root = createFixture();
  const result = runHygiene(root, { PATH: "" });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Unable to run rg/i);
  assert.doesNotMatch(result.stderr, /TypeError|Cannot read properties/i);
});
