import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const projectRoot = process.cwd();
const scriptPath = path.join(projectRoot, "scripts/context-rotate.mjs");

function writeFixtureFile(root, filePath, text) {
  const fullPath = path.join(root, filePath);
  mkdirSync(path.dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, text);
}

function runRotate(root, args = []) {
  return spawnSync(process.execPath, [scriptPath, ...args], {
    cwd: projectRoot,
    env: {
      ...process.env,
      CONTEXT_HYGIENE_PROJECT_ROOT: root,
      CONTEXT_HYGIENE_NOW: "2026-07-09",
    },
    encoding: "utf8",
  });
}

function ledgerText(rows) {
  return [
    "# Task Ledger",
    "",
    "Current branch and task-numbering baseline: use `codex/test-baseline`; use `T-014` for the next task unless directed otherwise.",
    "",
    "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    "|---|---|---|---|---|---|---|---|",
    ...rows,
    "",
  ].join("\n");
}

function worklogText(ids) {
  return [
    "# Worklog",
    "",
    ...ids.map((id) => [
      "```text",
      `Date: 2026-07-09`,
      `Task: ${id} - Fixture work.`,
      "Files changed: docs.",
      "Checks: fixture.",
      "Result: fixture.",
      "Risks: fixture.",
      "```",
      "",
    ].join("\n")),
  ].join("\n");
}

function decisionLogText(ids) {
  return [
    "# Decision Log",
    "",
    "## Active Decisions",
    "",
    ...ids.map((id) => [
      "```text",
      `Decision ID: ${id}`,
      "Date: 2026-07-09",
      `Decision: Fixture decision ${id}.`,
      "Context: Fixture.",
      "Consequences: Fixture.",
      "Linked files: docs/00_memory/CURRENT_STATE.md",
      "```",
      "",
    ].join("\n")),
    "## Archived Decision Index",
    "",
    "| Date | Decision | Current entry point |",
    "|---|---|---|",
    "",
  ].join("\n");
}

function createRotationFixture({
  ledgerRows = ["| T-001 | Fixture task | completed | Quick | G0 | docs | check | done |"],
  worklogIds = ["T-001"],
  decisionIds = ["D-001"],
} = {}) {
  const root = mkdtempSync(path.join(tmpdir(), "context-rotate-"));
  writeFixtureFile(root, "docs/06_tasks/TASK_LEDGER.md", ledgerText(ledgerRows));
  writeFixtureFile(root, "docs/00_memory/WORKLOG.md", worklogText(worklogIds));
  writeFixtureFile(root, "docs/07_decisions/DECISION_LOG.md", decisionLogText(decisionIds));
  mkdirSync(path.join(root, "docs/09_frozen/task_ledgers"), { recursive: true });
  mkdirSync(path.join(root, "docs/09_frozen/worklogs"), { recursive: true });
  mkdirSync(path.join(root, "docs/09_frozen/decisions"), { recursive: true });
  return root;
}

function archiveFile(root, directory) {
  const archiveDir = path.join(root, directory);
  const files = readdirSync(archiveDir).filter((fileName) => fileName.endsWith(".md"));
  assert.equal(files.length, 1);
  return path.join(archiveDir, files[0]);
}

test("context rotate dry-runs task ledger rotation without writing files", () => {
  const rows = Array.from({ length: 13 }, (_, index) => {
    const id = `T-${String(13 - index).padStart(3, "0")}`;
    return `| ${id} | Fixture task | completed | Quick | G0 | docs | check | done |`;
  });
  const root = createRotationFixture({ ledgerRows: rows });

  const result = runRotate(root);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Would rotate TASK_LEDGER\.md rows T-001/);
  assert.equal(existsSync(path.join(root, "docs/09_frozen/task_ledgers/TASK_LEDGER_T-001_2026-07-09.md")), false);
  assert.match(readFileSync(path.join(root, "docs/06_tasks/TASK_LEDGER.md"), "utf8"), /\| T-001 \| Fixture task \| completed \|/);
});

test("context rotate applies task ledger rotation and preserves archived row text", () => {
  const rows = Array.from({ length: 13 }, (_, index) => {
    const id = `T-${String(13 - index).padStart(3, "0")}`;
    return `| ${id} | Fixture task | completed | Quick | G0 | docs | check | done |`;
  });
  const root = createRotationFixture({ ledgerRows: rows });

  const result = runRotate(root, ["--apply"]);

  assert.equal(result.status, 0, result.stderr);
  const activeLedger = readFileSync(path.join(root, "docs/06_tasks/TASK_LEDGER.md"), "utf8");
  assert.doesNotMatch(activeLedger, /\| T-001 \| Fixture task \| completed \|/);
  assert.equal([...activeLedger.matchAll(/^\| T-\d{3} \|/gm)].length, 12);
  const archive = readFileSync(archiveFile(root, "docs/09_frozen/task_ledgers"), "utf8");
  assert.match(archive, /\| T-001 \| Fixture task \| completed \| Quick \| G0 \| docs \| check \| done \|/);
});

test("context rotate never moves blocked task ledger rows", () => {
  const completedRows = Array.from({ length: 12 }, (_, index) => {
    const id = `T-${String(13 - index).padStart(3, "0")}`;
    return `| ${id} | Fixture task | completed | Quick | G0 | docs | check | done |`;
  });
  const root = createRotationFixture({
    ledgerRows: [
      ...completedRows,
      "| T-001 | Blocked fixture | blocked | Deep | M2 | docs | check | waiting |",
    ],
  });

  const result = runRotate(root, ["--apply"]);

  assert.equal(result.status, 0, result.stderr);
  const activeLedger = readFileSync(path.join(root, "docs/06_tasks/TASK_LEDGER.md"), "utf8");
  assert.match(activeLedger, /\| T-001 \| Blocked fixture \| blocked \|/);
  assert.doesNotMatch(activeLedger, /\| T-002 \| Fixture task \| completed \|/);
  const archive = readFileSync(archiveFile(root, "docs/09_frozen/task_ledgers"), "utf8");
  assert.match(archive, /\| T-002 \| Fixture task \| completed \|/);
});

test("context rotate applies worklog rotation and preserves archived entry text", () => {
  const ids = Array.from({ length: 9 }, (_, index) => `T-${String(9 - index).padStart(3, "0")}`);
  const root = createRotationFixture({ worklogIds: ids });

  const result = runRotate(root, ["--apply"]);

  assert.equal(result.status, 0, result.stderr);
  const activeWorklog = readFileSync(path.join(root, "docs/00_memory/WORKLOG.md"), "utf8");
  assert.equal([...activeWorklog.matchAll(/^Task:\s*T-\d{3}/gm)].length, 8);
  assert.doesNotMatch(activeWorklog, /Task: T-001 - Fixture work/);
  const archive = readFileSync(archiveFile(root, "docs/09_frozen/worklogs"), "utf8");
  assert.match(archive, /Task: T-001 - Fixture work/);
});

test("context rotate applies decision-log rotation and leaves an active index row", () => {
  const ids = Array.from({ length: 9 }, (_, index) => `D-${String(9 - index).padStart(3, "0")}`);
  const root = createRotationFixture({ decisionIds: ids });

  const result = runRotate(root, ["--apply"]);

  assert.equal(result.status, 0, result.stderr);
  const activeDecisionLog = readFileSync(path.join(root, "docs/07_decisions/DECISION_LOG.md"), "utf8");
  assert.equal([...activeDecisionLog.matchAll(/```text\s+Decision ID:\s*D-\d{3}[\s\S]*?\n```/g)].length, 8);
  assert.doesNotMatch(activeDecisionLog, /Decision ID: D-001/);
  assert.match(activeDecisionLog, /\| 2026-07-09 \| Fixture decision D-001\. \| `\.\.\/09_frozen\/decisions\/DECISION_LOG_D-001_2026-07-09\.md` \|/);
  const archive = readFileSync(archiveFile(root, "docs/09_frozen/decisions"), "utf8");
  assert.match(archive, /Decision ID: D-001/);
});
