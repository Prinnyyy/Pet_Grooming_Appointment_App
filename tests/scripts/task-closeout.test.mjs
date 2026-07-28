import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const projectRoot = process.cwd();
const scriptPath = path.join(projectRoot, "scripts/task-closeout.mjs");

function writeFile(root, filePath, text) {
  const fullPath = path.join(root, filePath);
  mkdirSync(path.dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, text);
}

function createFixture({ artifactStatus = "completed", backlink = false } = {}) {
  const root = mkdtempSync(path.join(tmpdir(), "task-closeout-"));
  writeFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    "Current branch and task-numbering baseline: use `codex/test`; use `T-350` for the next new task.",
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    "| T-349 | Closeout automation | completed | Quick | G0 | scripts/docs | checks | done |",
    "",
  ].join("\n"));
  writeFile(root, "docs/00_memory/CURRENT_STATE.md", [
    "# Current State",
    "",
    "- Latest completed task: T-349 Closeout automation.",
    "- Current task: none.",
    "- Next task ID: T-350 for the required periodic meta-review.",
    "",
  ].join("\n"));
  writeFile(root, "docs/00_memory/WORKLOG.md", [
    "# Worklog",
    "",
    "```text",
    "Task: T-349 - Closeout automation.",
    "Result: Complete.",
    "```",
    "",
  ].join("\n"));
  writeFile(root, "docs/superpowers/README.md", "# Task Artifacts\n");
  writeFile(root, "docs/superpowers/plans/fixture-plan.md", [
    "<!-- task-artifact",
    "task: T-349",
    `status: ${artifactStatus}`,
    "type: plan",
    "-->",
    "# Fixture Plan",
    "",
    "Preserve this content verbatim.",
    "",
  ].join("\n"));
  if (backlink) {
    writeFile(root, "docs/README.md", "[Active plan](superpowers/plans/fixture-plan.md)\n");
  }

  writeFile(root, "scripts/context-rotate.mjs", "console.log('No context rotation needed.');\n");
  writeFile(root, "scripts/context-hygiene-check.mjs", "console.log('Context hygiene check passed.');\n");
  chmodSync(path.join(root, "scripts/context-rotate.mjs"), 0o755);
  chmodSync(path.join(root, "scripts/context-hygiene-check.mjs"), 0o755);
  return root;
}

function runCloseout(root, args = ["--task", "T-349", "--apply"]) {
  return spawnSync(process.execPath, [scriptPath, ...args], {
    cwd: projectRoot,
    env: {
      ...process.env,
      TASK_CLOSEOUT_PROJECT_ROOT: root,
      TASK_CLOSEOUT_NOW: "2026-07-13",
    },
    encoding: "utf8",
  });
}

test("task closeout archives a completed task artifact and runs structural gates", () => {
  const root = createFixture();
  const source = path.join(root, "docs/superpowers/plans/fixture-plan.md");
  const original = readFileSync(source, "utf8");

  const result = runCloseout(root);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(source), false);
  const archived = path.join(
    root,
    "docs/09_frozen/superpowers_2026-07-13/plans/fixture-plan.md",
  );
  assert.equal(readFileSync(archived, "utf8"), original);
  assert.match(result.stdout, /Task facts: completed and aligned/);
  assert.match(result.stdout, /Artifacts: archived 1/);
  assert.match(result.stdout, /Rotation: passed/);
  assert.match(result.stdout, /Hygiene: passed/);
  assert.ok(result.stdout.trim().split("\n").length <= 12, result.stdout);
});

test("task closeout blocks archival while an active Markdown backlink remains", () => {
  const root = createFixture({ backlink: true });
  const source = path.join(root, "docs/superpowers/plans/fixture-plan.md");

  const result = runCloseout(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /docs\/README\.md links to pending artifact/);
  assert.equal(existsSync(source), true);
  assert.equal(existsSync(path.join(root, "docs/09_frozen/superpowers_2026-07-13")), false);
});

test("task closeout rejects task artifacts that are not marked completed", () => {
  const root = createFixture({ artifactStatus: "active" });

  const result = runCloseout(root);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must declare status: completed/);
  assert.equal(existsSync(path.join(root, "docs/superpowers/plans/fixture-plan.md")), true);
});

test("task closeout dry run does not move eligible artifacts", () => {
  const root = createFixture();

  const result = runCloseout(root, ["--task", "T-349"]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Mode: dry-run/);
  assert.match(result.stdout, /Artifacts: would archive 1/);
  assert.equal(existsSync(path.join(root, "docs/superpowers/plans/fixture-plan.md")), true);
});

test("task closeout admits a pending structural rotation before apply", () => {
  const root = createFixture();
  writeFile(root, "scripts/context-rotate.mjs", [
    "import fs from 'node:fs';",
    "import path from 'node:path';",
    "const root = process.env.CONTEXT_HYGIENE_PROJECT_ROOT;",
    "if (process.argv.includes('--apply')) {",
    "  fs.writeFileSync(path.join(root, 'rotation-applied'), 'yes');",
    "  console.log('Rotation applied.');",
    "} else {",
    "  console.log('Would rotate structural windows.');",
    "}",
    "",
  ].join("\n"));
  writeFile(root, "scripts/context-hygiene-check.mjs", [
    "import fs from 'node:fs';",
    "import path from 'node:path';",
    "const root = process.env.CONTEXT_HYGIENE_PROJECT_ROOT;",
    "const rotationApplied = fs.existsSync(path.join(root, 'rotation-applied'));",
    "const pendingAllowed = process.env.CONTEXT_HYGIENE_CLOSEOUT_TASK === 'T-349'",
    "  && process.env.CONTEXT_HYGIENE_ALLOW_PENDING_ROTATION === '1';",
    "if (!rotationApplied && !pendingAllowed) {",
    "  console.error('Pending rotation was not authorized for closeout precheck.');",
    "  process.exit(1);",
    "}",
    "console.log('Context hygiene check passed.');",
    "",
  ].join("\n"));

  const result = runCloseout(root);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(path.join(root, "rotation-applied")), true);
});

test("task closeout accepts the next ID after higher completed task rows", () => {
  const root = createFixture();
  writeFile(root, "docs/06_tasks/TASK_LEDGER.md", [
    "# Task Ledger",
    "",
    "Current branch and task-numbering baseline: use `codex/test`; use `T-351` for the next new task.",
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    "| T-350 | Later completed task | completed | Quick | G0 | docs | checks | done |",
    "| T-340 | Historical planned task | completed | Standard | M14 | app | checks | done |",
    "",
  ].join("\n"));
  writeFile(root, "docs/00_memory/CURRENT_STATE.md", [
    "# Current State",
    "",
    "- Latest completed task: T-340 Historical planned task.",
    "- Current task: none.",
    "- Next task ID: T-351 for the next new task.",
    "",
  ].join("\n"));
  writeFile(root, "docs/00_memory/WORKLOG.md", [
    "# Worklog",
    "",
    "```text",
    "Task: T-340 - Historical planned task.",
    "Result: Complete.",
    "```",
    "",
  ].join("\n"));
  writeFile(root, "docs/superpowers/plans/fixture-plan.md", [
    "<!-- task-artifact",
    "task: T-340",
    "status: completed",
    "type: plan",
    "-->",
    "# Fixture Plan",
    "",
  ].join("\n"));

  const result = runCloseout(root, ["--task", "T-340", "--apply"]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Task facts: completed and aligned/);
});
