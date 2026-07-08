import assert from "node:assert/strict";
import { chmodSync, mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const projectRoot = process.cwd();
const preflightPath = path.join(projectRoot, "scripts/preflight.sh");

function writeFile(root, filePath, text = "# Placeholder\n") {
  const fullPath = path.join(root, filePath);
  mkdirSync(path.dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, text);
}

function createPreflightFixture() {
  const root = mkdtempSync(path.join(tmpdir(), "preflight-fixture-"));
  for (const filePath of [
    "AGENTS.md",
    "docs/00_memory/PROJECT_MEMORY.md",
    "docs/00_memory/CURRENT_STATE.md",
    "docs/00_memory/FEATURE_INDEX.md",
    "docs/06_tasks/TASK_LEDGER.md",
    "docs/06_tasks/ROADMAP.md",
    "docs/05_workflow/SINGLE_AGENT_WORKFLOW.md",
    "docs/05_workflow/CONTEXT_AND_RECOVERY.md",
    "docs/05_workflow/TOOLING_POLICY.md",
    "docs/05_workflow/GITHUB_RULES.md",
  ]) {
    writeFile(root, filePath);
  }
  writeFile(root, "tests/migrations/fixture-migration.test.mjs", [
    "console.log('fixture migration test ran');",
    "",
  ].join("\n"));
  writeFile(root, "tests/functions/fixture-function.test.mjs", [
    "console.log('fixture function test ran');",
    "",
  ].join("\n"));
  chmodSync(preflightPath, 0o755);
  return root;
}

test("preflight runs migration and function Node tests when present", () => {
  const root = createPreflightFixture();
  const env = { ...process.env };
  for (const key of Object.keys(env)) {
    if (key.startsWith("NODE_TEST")) {
      delete env[key];
    }
  }
  const result = spawnSync(preflightPath, {
    cwd: root,
    env,
    encoding: "utf8",
  });
  const output = `${result.stdout}\n${result.stderr}`;

  assert.equal(result.status, 0, result.stderr);
  assert.match(output, /fixture migration test ran/);
  assert.match(output, /fixture function test ran/);
});
