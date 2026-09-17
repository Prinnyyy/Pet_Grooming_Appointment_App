import assert from "node:assert/strict";
import {
  chmodSync,
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const projectRoot = process.cwd();

function writeFile(root, filePath, text = "# Placeholder\n") {
  const fullPath = path.join(root, filePath);
  mkdirSync(path.dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, text);
}

function createPreflightFixture(t) {
  const root = mkdtempSync(path.join(tmpdir(), "preflight-fixture-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const gitInit = spawnSync("git", ["init", "--quiet"], {
    cwd: root,
    encoding: "utf8",
  });
  assert.equal(gitInit.status, 0, gitInit.stderr);

  for (const filePath of [
    "AGENTS.md",
    "docs/00_memory/CURRENT_STATE.md",
    "docs/00_memory/FEATURE_INDEX.md",
    "docs/06_tasks/ROADMAP.md",
    "docs/05_workflow/DEVELOPMENT_GUIDE.md",
  ]) {
    writeFile(root, filePath);
  }
  writeFile(root, "tests/migrations/fixture-migration.test.mjs", [
    "console.log('fixture migration test ran');",
    "",
  ].join("\n"));
  writeFile(root, "tests/brand/fixture-brand.test.mjs", "console.log('fixture brand test ran');\n");
  writeFile(root, "tests/functions/fixture-function.test.mjs", [
    "console.log('fixture function test ran');",
    "",
  ].join("\n"));

  mkdirSync(path.join(root, "scripts"), { recursive: true });
  for (const scriptName of [
    "preflight.sh",
    "beckon-identity-check.sh",
    "beckon-identity-check.mjs",
    "ui-consistency-audit-core.mjs",
    "ui-consistency-audit.mjs",
  ]) {
    copyFileSync(
      path.join(projectRoot, "scripts", scriptName),
      path.join(root, "scripts", scriptName)
    );
  }
  writeFile(root, "scripts/ui-consistency-baseline.json", `${JSON.stringify({
    version: 1,
    scope: "ios/Beckon/Beckon/Features",
    lastChange: { reason: "fixture" },
    findings: [],
  }, null, 2)}\n`);
  writeFile(root, "ios/Beckon/Beckon/Features/FixtureView.swift", [
    "import SwiftUI",
    "struct FixtureView: View { var body: some View { Text(\"Fixture\") } }",
    "",
  ].join("\n"));

  const preflightPath = path.join(root, "scripts/preflight.sh");
  chmodSync(preflightPath, 0o755);
  chmodSync(path.join(root, "scripts/beckon-identity-check.sh"), 0o755);
  return { preflightPath, root };
}

function runPreflight(preflightPath, root) {
  const env = { ...process.env };
  for (const key of Object.keys(env)) {
    if (key.startsWith("NODE_TEST")) {
      delete env[key];
    }
  }
  return spawnSync(preflightPath, {
    cwd: root,
    env,
    encoding: "utf8",
  });
}

test("preflight runs brand, UI, migration and function checks with the new guide", (t) => {
  const { preflightPath, root } = createPreflightFixture(t);
  const result = runPreflight(preflightPath, root);
  const output = `${result.stdout}\n${result.stderr}`;
  assert.equal(result.status, 0, output);
  assert.match(output, /Beckon identity check passed/);
  assert.match(output, /UI consistency audit passed/);
  assert.match(output, /fixture brand test ran/);
  assert.match(output, /fixture migration test ran/);
  assert.match(output, /fixture function test ran/);
});

test("preflight rejects a missing guide rather than requiring retired owners", (t) => {
  const { preflightPath, root } = createPreflightFixture(t);
  rmSync(path.join(root, "docs/05_workflow/DEVELOPMENT_GUIDE.md"));
  const result = runPreflight(preflightPath, root);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /Missing required file: docs\/05_workflow\/DEVELOPMENT_GUIDE.md/);
});

test("preflight propagates a failing domain test", (t) => {
  const { preflightPath, root } = createPreflightFixture(t);
  writeFile(root, "tests/migrations/fixture-migration.test.mjs", "throw new Error('fixture domain failure');\n");
  const result = runPreflight(preflightPath, root);
  assert.notEqual(result.status, 0);
  assert(!result.stdout.includes("Preflight passed."));
});
