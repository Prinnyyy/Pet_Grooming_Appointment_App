import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = path.resolve(import.meta.dirname, "..");

const WORD_LIMITS = new Map([
  ["AGENTS.md", 800],
  ["docs/00_memory/CURRENT_STATE.md", 1200],
  ["docs/00_memory/WORKLOG.md", 2500],
  ["docs/06_tasks/TASK_LEDGER.md", 1800],
  ["docs/00_memory/FEATURE_INDEX.md", 1200],
  ["docs/00_memory/PROJECT_MEMORY.md", 600],
  ["docs/07_decisions/DECISION_LOG.md", 2500],
  ["docs/01_product/DESIGN_SYSTEM.md", 900],
  ["docs/08_design/UI_IMPLEMENTATION_NOTES.md", 900],
  ["docs/03_backend/RLS_RPC_POLICY.md", 1200],
  ["docs/03_backend/STORAGE_POLICY.md", 700],
  ["docs/03_backend/MIGRATION_RULES.md", 900],
  ["docs/04_ios/testops/TESTOPS_MEMORY.md", 400],
]);

const STALE_CREDENTIAL_PATTERNS = [
  /current execute mode still expects/i,
  /has not yet been updated to use modern `?sb_secret/i,
  /rejects modern `?sb_secret.*before remote lifecycle writes/i,
  /Do not substitute `?SUPABASE_SECRET_KEY/i,
];

const CURRENT_CREDENTIAL_DOCS = [
  "docs/00_memory/CURRENT_STATE.md",
  "docs/03_backend/SUPABASE_CONTRACT.md",
  "docs/03_backend/MIGRATION_RULES.md",
  "docs/04_ios/testops/RUNBOOK.md",
  "docs/04_ios/testops/TEST_CASES.md",
  "docs/04_ios/testops/TESTOPS_MEMORY.md",
  "docs/05_workflow/TOOLING_POLICY.md",
];

const failures = [];

function run(command, args) {
  return spawnSync(command, args, {
    cwd: PROJECT_ROOT,
    encoding: "utf8",
  });
}

function words(text) {
  return text.match(/\S+/g)?.length ?? 0;
}

function read(filePath) {
  return fs.readFileSync(path.join(PROJECT_ROOT, filePath), "utf8");
}

function activeMarkdownFiles() {
  const result = run("rg", ["--files", "AGENTS.md", "README.md", "docs"]);
  if (result.status !== 0) {
    failures.push(`rg --files failed: ${result.stderr.trim()}`);
    return [];
  }
  return result.stdout
    .trim()
    .split(/\r?\n/)
    .filter((filePath) => filePath.endsWith(".md"));
}

function checkWordLimits() {
  console.log("Word budgets:");
  for (const [filePath, limit] of WORD_LIMITS.entries()) {
    const count = words(read(filePath));
    const status = count <= limit ? "ok" : "over";
    console.log(`  ${status.padEnd(4)} ${String(count).padStart(5)} / ${String(limit).padStart(5)} ${filePath}`);
    if (count > limit) {
      failures.push(`${filePath} has ${count} words, limit ${limit}`);
    }
  }
}

function checkMarkdownLinks(files) {
  let checked = 0;
  for (const filePath of files) {
    const text = read(filePath);
    const dir = path.dirname(filePath);
    const pattern = /\[[^\]]+\]\(([^)]+)\)/g;
    let match;
    while ((match = pattern.exec(text)) !== null) {
      const rawTarget = match[1].split("#")[0].trim().replace(/^<|>$/g, "");
      if (!rawTarget || /^[a-z][a-z0-9+.-]*:/i.test(rawTarget)) {
        continue;
      }
      checked += 1;
      const target = path.resolve(PROJECT_ROOT, dir, rawTarget);
      if (!fs.existsSync(target)) {
        failures.push(`${filePath} links to missing local path: ${match[1]}`);
      }
    }
  }
  console.log(`Active Markdown files: ${files.length}`);
  console.log(`Local Markdown links checked: ${checked}`);
}

function checkIgnoredPaths() {
  const frozen = run("rg", ["--files", "docs/09_frozen"]);
  if (frozen.stdout.trim()) {
    failures.push("docs/09_frozen is visible to default rg --files");
  }

  const seed = run("rg", ["--files", "docs/02_architecture/test_resources"]);
  const seedFiles = seed.stdout.trim().split(/\r?\n/).filter(Boolean);
  const expectedSeed = ["docs/02_architecture/test_resources/README.md"];
  if (seedFiles.join("\n") !== expectedSeed.join("\n")) {
    failures.push(`test_resources default rg output changed: ${seedFiles.join(", ")}`);
  }

  const design = run("rg", ["--files", "docs/08_design"]);
  const visibleGroomlyHTML = design.stdout
    .trim()
    .split(/\r?\n/)
    .filter((filePath) => /Groomly.*\.html$/i.test(filePath));
  if (visibleGroomlyHTML.length > 0) {
    failures.push(`Groomly HTML visible to default rg --files: ${visibleGroomlyHTML.join(", ")}`);
  }
}

function checkCredentialClaims() {
  for (const filePath of CURRENT_CREDENTIAL_DOCS) {
    const text = read(filePath);
    for (const pattern of STALE_CREDENTIAL_PATTERNS) {
      if (pattern.test(text)) {
        failures.push(`${filePath} contains stale TestOps credential wording: ${pattern}`);
      }
    }
  }
}

const activeFiles = activeMarkdownFiles();
checkWordLimits();
checkMarkdownLinks(activeFiles);
checkIgnoredPaths();
checkCredentialClaims();

if (failures.length > 0) {
  console.error("\nContext hygiene check failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log("Context hygiene check passed.");
