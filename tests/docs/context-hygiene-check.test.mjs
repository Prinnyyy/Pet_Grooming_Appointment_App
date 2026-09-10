import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const script = path.resolve(import.meta.dirname, "../../scripts/context-hygiene-check.mjs");
const statePath = "docs/00_memory/CURRENT_STATE.md";
const planPath = "docs/superpowers/plans/current.md";

function writeFixtureFile(root, file, text = "# Fixture\n") {
  mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
  writeFileSync(path.join(root, file), text);
}

function git(root, ...args) {
  const result = spawnSync("git", ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", ...args], { cwd: root, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

function writeState(root, state) {
  writeFixtureFile(root, statePath, `# Current State\n\n\`\`\`json\n${JSON.stringify(state, null, 2)}\n\`\`\`\n`);
}

function createFixture(t) {
  const root = mkdtempSync(path.join(tmpdir(), "lean-governance-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  git(root, "init", "--quiet");
  for (const file of ["AGENTS.md", "CLAUDE.md", "README.md", "docs/README.md", "docs/00_memory/FEATURE_INDEX.md", "docs/05_workflow/DEVELOPMENT_GUIDE.md", "docs/06_tasks/ROADMAP.md", planPath]) writeFixtureFile(root, file);
  writeFixtureFile(root, ".gitignore", "artifacts/\n.env*\n");
  writeFixtureFile(root, ".rgignore", "docs/09_frozen/**\nartifacts/**\ndocs/superpowers/**\ndocs/06_tasks/sql_reviews/**\n!docs/06_tasks/sql_reviews/README.md\ndocs/06_tasks/APP_FUNCTIONAL_DESIGN_FINDINGS.md\ndocs/ui-redesign/*\n!docs/ui-redesign/README.md\ndocs/02_architecture/test_resources/T-129_*_TEST_PROFILES.md\n");
  const state = { next_task_id: "T-003", task: { id: "T-002", status: "active", goal: "Fixture governance", plan: planPath, next_action: "Validate" }, pending_tasks: [], last_completed: { id: "T-001" } };
  writeState(root, state);
  git(root, "add", ".");
  git(root, "commit", "--quiet", "-m", "T-001: test: fixture baseline");
  return { root, state };
}

function run(root, ...args) {
  const result = spawnSync(process.execPath, [script, ...args], { env: { ...process.env, CONTEXT_HYGIENE_PROJECT_ROOT: root }, encoding: "utf8" });
  return { ...result, output: `${result.stdout}\n${result.stderr}` };
}

function snapshot(root) {
  const entries = [];
  function walk(dir) {
    for (const item of readdirSync(path.join(root, dir), { withFileTypes: true })) {
      if (item.name === ".git") continue;
      const file = path.join(dir, item.name);
      if (item.isDirectory()) walk(file);
      else if (item.isFile()) entries.push([file, readFileSync(path.join(root, file), "utf8")]);
    }
  }
  walk("");
  return entries;
}

test("single state works without ledger or worklog and exposes structured read-only output", (t) => {
  const { root } = createFixture(t);
  const before = snapshot(root);
  const result = run(root, "--json");
  assert.equal(result.status, 0, result.output);
  const report = JSON.parse(result.stdout);
  assert.equal(report.ok, true);
  assert.deepEqual(report.errors, []);
  assert.deepEqual(report.warnings, []);
  assert(report.checkedFiles.includes(planPath));
  assert.deepEqual(snapshot(root), before);
});

for (const [name, mutate] of [
  ["illegal id", s => { s.task.id = "task-2"; }],
  ["reused next id", s => { s.next_task_id = "T-002"; }],
  ["illegal status", s => { s.task.status = "completed"; }],
  ["duplicate pending id", s => { s.pending_tasks = [{ ...s.task, status: "paused" }]; }],
  ["active pending task", s => { s.pending_tasks = [{ ...s.task, id: "T-004" }]; s.next_task_id = "T-005"; }],
  ["missing plan", s => { s.task.plan = "docs/missing.md"; }],
  ["missing pending plan", s => { s.pending_tasks = [{ ...s.task, id: "T-004", status: "blocked", plan: "docs/missing.md" }]; s.next_task_id = "T-005"; }],
  ["misplaced authorization", s => { s.authorization = ["not task-scoped"]; }],
  ["incomplete verification", s => { s.task.verification = [{ result: "pass" }]; }],
]) {
  test(`rejects ${name} without changing user content`, (t) => {
    const { root, state } = createFixture(t);
    mutate(state); writeState(root, state);
    const before = snapshot(root);
    const result = run(root, "--json");
    assert.equal(result.status, 1, result.output);
    assert.equal(JSON.parse(result.stdout).ok, false);
    assert.deepEqual(snapshot(root), before);
  });
}

for (const body of ["```json\n{\n```\n", "```json\n{}\n```\n```json\n{}\n```\n", "# No state\n"]) {
  test(`malformed state is an error: ${body.slice(0, 18)}`, (t) => {
    const { root } = createFixture(t);
    writeFixtureFile(root, statePath, body);
    const result = run(root, "--json");
    assert.equal(result.status, 1, result.output);
    assert.equal(readFileSync(path.join(root, statePath), "utf8"), body);
  });
}

test("wording, old dates and task-number gaps do not impose workflow gates", (t) => {
  const { root, state } = createFixture(t);
  state.next_task_id = "T-387"; state.task.id = "T-386";
  writeState(root, state);
  writeFixtureFile(root, "docs/old.md", "Last verified: 2000-01-01.\nLast meta-review: T-001.\n" + "Long prose. ".repeat(2000));
  writeFixtureFile(root, "AGENTS.md", "# Changed wording\nNo fixed ownership sentence or table.\n");
  assert.equal(run(root, "--full").status, 0);
});

for (const file of ["docs/new.md", planPath, "docs/superpowers/plans/new.md", "docs/06_tasks/APP_FUNCTIONAL_DESIGN_FINDINGS.md", "docs/06_tasks/sql_reviews/new.md"]) {
  test(`checks changed or untracked document despite search hiding: ${file}`, (t) => {
    const { root } = createFixture(t);
    writeFixtureFile(root, file, "[broken](missing-target.md)\n");
    for (const args of [[], ["--full"]]) {
      const result = run(root, ...args, "--json");
      assert.equal(result.status, 1, result.output);
      assert(JSON.parse(result.stdout).checkedFiles.includes(file));
    }
  });
}

test("full check adds unchanged visible docs; default includes staged changes", (t) => {
  const { root } = createFixture(t);
  writeFixtureFile(root, "docs/old.md", "[broken](missing.md)\n");
  git(root, "add", "."); git(root, "commit", "--quiet", "-m", "Fixture old document");
  assert.equal(run(root).status, 0);
  assert.equal(run(root, "--full").status, 1);
  writeFixtureFile(root, "docs/staged.md", "[broken](missing.md)\n"); git(root, "add", "docs/staged.md");
  assert.equal(run(root).status, 1);
});

test("deletion checks unchanged backlinks", (t) => {
  const { root } = createFixture(t);
  writeFixtureFile(root, "docs/target.md"); writeFixtureFile(root, "docs/ref.md", "[target](target.md)\n");
  git(root, "add", "."); git(root, "commit", "--quiet", "-m", "Fixture links");
  rmSync(path.join(root, "docs/target.md"));
  assert.equal(run(root).status, 1);
});

test("local links include images and references, not code examples or external URLs", (t) => {
  const { root } = createFixture(t);
  writeFixtureFile(root, "docs/a (b).md");
  writeFixtureFile(root, "docs/links.md", "[a](<a (b).md>)\n[a](a%20(b).md#section)\n[web](https://example.invalid)\n`[example](missing.md)`\n```md\n[example](missing.md)\n```\n[ref][r]\n[r]: <a (b).md>\n");
  assert.equal(run(root).status, 0);
  writeFixtureFile(root, "docs/image.md", "![image](missing.png)\n");
  assert.equal(run(root).status, 1);
});

test("history and heavy bodies remain unread; exposed heavy docs are rejected", (t) => {
  const { root } = createFixture(t);
  for (const file of ["docs/09_frozen/old.md", "docs/ui-redesign/heavy.md", "docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md", "artifacts/private.md"]) writeFixtureFile(root, file, "[sentinel](must-not-read.md)\n");
  assert.equal(run(root, "--full").status, 0);
  writeFixtureFile(root, ".rgignore", "docs/09_frozen/**\nartifacts/**\ndocs/02_architecture/test_resources/T-129_*_TEST_PROFILES.md\n");
  const result = run(root, "--full");
  assert.equal(result.status, 1);
  assert(!result.output.includes("must-not-read"));
});

test("plan pointer cannot read outside repo, secrets, heavy files or escaping symlinks", (t) => {
  const { root, state } = createFixture(t);
  const outside = mkdtempSync(path.join(tmpdir(), "lean-outside-"));
  t.after(() => rmSync(outside, { recursive: true, force: true }));
  writeFixtureFile(outside, "outside.md", "[sentinel](must-not-read.md)\n");
  symlinkSync(path.join(outside, "outside.md"), path.join(root, "docs/link.md"));
  writeFixtureFile(root, "docs/09_frozen/old.md", "[sentinel](must-not-read.md)\n");
  for (const plan of [path.join(outside, "outside.md"), "docs/link.md", "docs/09_frozen/old.md", ".env.local"]) {
    state.task.plan = plan; writeState(root, state);
    const result = run(root, "--json");
    assert.equal(result.status, 1, result.output);
    assert(!result.output.includes("must-not-read"));
  }
});

test("pause, switch, complete and resume retain scoped recovery without hash rewriting", (t) => {
  const { root, state } = createFixture(t);
  const original = { ...state.task, plan: null, authorization: ["Local docs only"], preserve: ["docs/user.md contains user changes"], next_action: "Resume targeted edit" };
  state.pending_tasks = [{ ...original, status: "paused" }];
  state.task = { id: "T-003", status: "active", goal: "Other task", plan: null, next_action: "Finish" }; state.next_task_id = "T-004";
  writeFixtureFile(root, "docs/user.md", "User content\n"); writeState(root, state);
  assert.equal(run(root).status, 0);
  state.last_completed = { id: "T-003" }; state.task = null; writeState(root, state);
  git(root, "add", "."); git(root, "commit", "--quiet", "-m", "T-003: docs: finish fixture");
  assert.match(git(root, "log", "-1", "--format=%s"), /^T-003:/);
  assert.equal(git(root, "status", "--porcelain"), "");
  state.task = { ...state.pending_tasks.pop(), status: "active" }; writeState(root, state);
  assert.equal(run(root).status, 0);
  assert.deepEqual(state.task.authorization, original.authorization);
  const before = readFileSync(path.join(root, "docs/user.md"), "utf8");
  writeFixtureFile(root, "docs/own.md", "Task edit\n\nLater user edit\n");
  const restore = spawnSync("git", ["apply", "--reverse", "--unidiff-zero"], {
    cwd: root, encoding: "utf8",
    input: "--- a/docs/own.md\n+++ b/docs/own.md\n@@ -1 +1 @@\n-Original task line\n+Task edit\n",
  });
  assert.equal(restore.status, 0, restore.stderr);
  assert.equal(readFileSync(path.join(root, "docs/own.md"), "utf8"), "Original task line\n\nLater user edit\n");
  assert.equal(readFileSync(path.join(root, "docs/user.md"), "utf8"), before);
});

test("Git-ignored Markdown cannot be read through a current plan pointer", (t) => {
  const { root, state } = createFixture(t);
  writeFixtureFile(root, ".gitignore", "artifacts/\n.env*\nprivate/\n");
  writeFixtureFile(root, "private/notes.md", "# Private fixture\n");
  state.task.plan = "private/notes.md"; writeState(root, state);
  const result = run(root, "--json");
  assert.equal(result.status, 1, result.output);
  assert(!JSON.parse(result.stdout).checkedFiles.includes("private/notes.md"));
});

test("project-root override must identify the repository root", (t) => {
  const { root } = createFixture(t);
  assert.equal(run(path.join(root, "docs")).status, 2);
});

test("bad arguments and unavailable environment report exit 2", (t) => {
  const { root } = createFixture(t);
  assert.equal(run(root, "--apply").status, 2);
  assert.equal(run(path.join(root, "missing"), "--json").status, 2);
  rmSync(path.join(root, ".git"), { recursive: true });
  assert.equal(run(root).status, 2);
});
