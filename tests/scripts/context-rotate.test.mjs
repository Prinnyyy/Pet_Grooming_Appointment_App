import assert from "node:assert/strict";
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const projectRoot = process.cwd();

function writeFile(root, filePath, text) {
  const fullPath = path.join(root, filePath);
  mkdirSync(path.dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, text);
}

test("worklog rotation retains the footer without accumulating blank lines", () => {
  const root = mkdtempSync(path.join(tmpdir(), "context-rotate-fixture-"));
  mkdirSync(path.join(root, "scripts"), { recursive: true });
  for (const scriptName of ["context-rotate.mjs", "context-hygiene-policy.mjs"]) {
    copyFileSync(
      path.join(projectRoot, "scripts", scriptName),
      path.join(root, "scripts", scriptName)
    );
  }

  const entries = Array.from({ length: 15 }, (_, index) => [
    "```text",
    `Task: T-${String(400 - index).padStart(3, "0")} - Fixture.`,
    "Result: Complete.",
    "```",
  ].join("\n"));
  writeFile(root, "docs/00_memory/WORKLOG.md", [
    "# Worklog",
    "",
    ...entries.flatMap((entry) => [entry, ""]),
    "This file is the active recent closeout index.",
    "",
  ].join("\n"));
  writeFile(root, "docs/06_tasks/TASK_LEDGER.md", "# Task Ledger\n");
  writeFile(root, "docs/07_decisions/DECISION_LOG.md", "# Decision Log\n");

  const result = spawnSync(
    process.execPath,
    [path.join(root, "scripts/context-rotate.mjs"), "--apply"],
    {
      env: {
        ...process.env,
        CONTEXT_HYGIENE_PROJECT_ROOT: root,
        CONTEXT_HYGIENE_NOW: "2026-07-12",
      },
      encoding: "utf8",
    }
  );
  const active = readFileSync(path.join(root, "docs/00_memory/WORKLOG.md"), "utf8");

  assert.equal(result.status, 0, result.stderr);
  assert.equal((active.match(/```text/g) ?? []).length, 8);
  assert.match(active, /This file is the active recent closeout index\./);
  assert.doesNotMatch(active, /\n{3,}/);
});
