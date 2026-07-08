import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = path.resolve(
  process.env.CONTEXT_HYGIENE_PROJECT_ROOT ?? path.resolve(import.meta.dirname, ".."),
);
const ACTIVE_MARKDOWN_TOTAL_LIMIT = 32000;
const WORKLOG_ENTRY_LIMIT = 10;
const TASK_LEDGER_ROW_LIMIT = 15;
const LAST_VERIFIED_MAX_AGE_DAYS = 45;
const CHECK_DATE_TEXT = process.env.CONTEXT_HYGIENE_NOW ?? new Date().toISOString().slice(0, 10);

const WORD_LIMITS = new Map([
  ["AGENTS.md", 800],
  ["README.md", 500],
  ["CLAUDE.md", 600],
  ["docs/README.md", 800],
  ["docs/00_memory/CURRENT_STATE.md", 1200],
  ["docs/00_memory/WORKLOG.md", 2500],
  ["docs/06_tasks/TASK_LEDGER.md", 1800],
  ["docs/06_tasks/ROADMAP.md", 1800],
  ["docs/00_memory/FEATURE_INDEX.md", 1200],
  ["docs/00_memory/PROJECT_MEMORY.md", 600],
  ["docs/07_decisions/DECISION_LOG.md", 2500],
  ["docs/01_product/DESIGN_SYSTEM.md", 900],
  ["docs/01_product/SCREEN_INVENTORY.md", 1500],
  ["docs/08_design/UI_IMPLEMENTATION_NOTES.md", 900],
  ["docs/03_backend/SUPABASE_CONTRACT.md", 1100],
  ["docs/03_backend/RLS_RPC_POLICY.md", 1200],
  ["docs/03_backend/STORAGE_POLICY.md", 700],
  ["docs/03_backend/MIGRATION_RULES.md", 900],
  ["docs/04_ios/testops/TESTOPS_MEMORY.md", 400],
  ["docs/05_workflow/TOOLING_POLICY.md", 1500],
  ["docs/10_project_structure/REORGANIZATION_LOG.md", 2500],
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

const LAST_VERIFIED_DOCS = [
  "docs/00_memory/FEATURE_INDEX.md",
  "docs/03_backend/SUPABASE_CONTRACT.md",
  "docs/03_backend/MIGRATION_RULES.md",
  "docs/06_tasks/ROADMAP.md",
];

const failures = [];

function run(command, args) {
  return spawnSync(command, args, {
    cwd: PROJECT_ROOT,
    encoding: "utf8",
  });
}

function commandSummary(command, args) {
  return `${command} ${args.join(" ")}`;
}

function runRequired(command, args) {
  const result = run(command, args);
  if (result.error) {
    failures.push(`Unable to run ${commandSummary(command, args)}: ${result.error.message}`);
    return null;
  }
  return result;
}

function words(text) {
  return text.match(/\S+/g)?.length ?? 0;
}

function parseDateOnly(dateText) {
  const match = dateText.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    return null;
  }
  const [, year, month, day] = match;
  return Date.UTC(Number(year), Number(month) - 1, Number(day));
}

function read(filePath) {
  return fs.readFileSync(path.join(PROJECT_ROOT, filePath), "utf8");
}

function readOptional(filePath) {
  const fullPath = path.join(PROJECT_ROOT, filePath);
  if (!fs.existsSync(fullPath)) {
    failures.push(`${filePath} is missing`);
    return "";
  }
  return fs.readFileSync(fullPath, "utf8");
}

function activeMarkdownFiles() {
  const result = runRequired("rg", ["--files", "AGENTS.md", "README.md", "docs"]);
  if (!result) {
    return [];
  }
  if (result.status !== 0) {
    failures.push(`rg --files failed: ${(result.stderr ?? result.stdout ?? "").trim()}`);
    return [];
  }
  const files = result.stdout
    .trim()
    .split(/\r?\n/)
    .filter((filePath) => filePath.endsWith(".md"));
  if (fs.existsSync(path.join(PROJECT_ROOT, "CLAUDE.md"))) {
    files.push("CLAUDE.md");
  }
  return [...new Set(files)];
}

function checkWordLimits() {
  console.log("Word budgets:");
  for (const [filePath, limit] of WORD_LIMITS.entries()) {
    const count = words(readOptional(filePath));
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

function checkActiveMarkdownTotal(files) {
  let total = 0;
  for (const filePath of files) {
    total += words(readOptional(filePath));
  }
  const status = total <= ACTIVE_MARKDOWN_TOTAL_LIMIT ? "ok" : "over";
  console.log(`Active Markdown total: ${status} ${total} / ${ACTIVE_MARKDOWN_TOTAL_LIMIT}`);
  if (total > ACTIVE_MARKDOWN_TOTAL_LIMIT) {
    failures.push(`active Markdown has ${total} words, limit ${ACTIVE_MARKDOWN_TOTAL_LIMIT}`);
  }
}

function checkIgnoredPaths() {
  const frozen = runRequired("rg", ["--files", "docs/09_frozen"]);
  if (frozen?.stdout.trim()) {
    failures.push("docs/09_frozen is visible to default rg --files");
  }

  const seed = runRequired("rg", ["--files", "docs/02_architecture/test_resources"]);
  const seedFiles = seed?.stdout.trim().split(/\r?\n/).filter(Boolean) ?? [];
  const expectedSeed = ["docs/02_architecture/test_resources/README.md"];
  if (seedFiles.join("\n") !== expectedSeed.join("\n")) {
    failures.push(`test_resources default rg output changed: ${seedFiles.join(", ")}`);
  }

  const design = runRequired("rg", ["--files", "docs/08_design"]);
  const visibleGroomlyHTML = (design?.stdout ?? "")
    .trim()
    .split(/\r?\n/)
    .filter((filePath) => /Groomly.*\.html$/i.test(filePath));
  if (visibleGroomlyHTML.length > 0) {
    failures.push(`Groomly HTML visible to default rg --files: ${visibleGroomlyHTML.join(", ")}`);
  }
}

function checkCredentialClaims() {
  for (const filePath of CURRENT_CREDENTIAL_DOCS) {
    const text = readOptional(filePath);
    for (const pattern of STALE_CREDENTIAL_PATTERNS) {
      if (pattern.test(text)) {
        failures.push(`${filePath} contains stale TestOps credential wording: ${pattern}`);
      }
    }
  }
}

function extractTaskId(text, labelRegex) {
  const match = text.match(labelRegex);
  return match?.[1] ?? null;
}

function taskNumber(taskId) {
  return taskId ? Number.parseInt(taskId.replace("T-", ""), 10) : null;
}

function extractBranchBaseline(text, regex) {
  return text.match(regex)?.[1] ?? null;
}

function ledgerRows(ledgerText) {
  return [...ledgerText.matchAll(/^\| (T-\d{3}) \| [^|]+ \| ([^|]+) \|/gm)].map((match) => ({
    id: match[1],
    status: match[2].trim().toLowerCase(),
  }));
}

function checkLastVerifiedDates() {
  const today = parseDateOnly(CHECK_DATE_TEXT);
  if (today === null) {
    failures.push(`CONTEXT_HYGIENE_NOW must be YYYY-MM-DD when set; got ${CHECK_DATE_TEXT}`);
    return;
  }

  for (const filePath of LAST_VERIFIED_DOCS) {
    const text = readOptional(filePath);
    const match = text.match(/Last verified:\s*(\d{4}-\d{2}-\d{2})/i);
    if (!match) {
      failures.push(`${filePath} is missing a Last verified: YYYY-MM-DD marker`);
      continue;
    }

    const verifiedAt = parseDateOnly(match[1]);
    if (verifiedAt === null) {
      failures.push(`${filePath} has an invalid Last verified date: ${match[1]}`);
      continue;
    }

    const ageDays = Math.floor((today - verifiedAt) / 86_400_000);
    if (ageDays < 0) {
      failures.push(`${filePath} last verified ${match[1]} is in the future relative to ${CHECK_DATE_TEXT}`);
    } else if (ageDays > LAST_VERIFIED_MAX_AGE_DAYS) {
      failures.push(`${filePath} last verified ${match[1]} is stale: ${ageDays} days old, limit ${LAST_VERIFIED_MAX_AGE_DAYS}`);
    }
  }
}

function checkMigrationMirrorCount() {
  const contract = readOptional("docs/03_backend/SUPABASE_CONTRACT.md");
  const match = contract.match(/Local migration mirror count:\s*(\d+)\s+files?/i);
  if (!match) {
    failures.push("docs/03_backend/SUPABASE_CONTRACT.md is missing Local migration mirror count");
    return;
  }

  const migrationsDir = path.join(PROJECT_ROOT, "supabase/migrations");
  const actualCount = fs.existsSync(migrationsDir)
    ? fs.readdirSync(migrationsDir).filter((entry) => entry.endsWith(".sql")).length
    : 0;
  const documentedCount = Number.parseInt(match[1], 10);
  if (actualCount !== documentedCount) {
    failures.push(`migration mirror count mismatch: SUPABASE_CONTRACT documents ${documentedCount}, filesystem has ${actualCount}`);
  }
}

function expandTaskRange(startId, endId) {
  const start = taskNumber(startId);
  const end = taskNumber(endId);
  if (start === null || end === null || end < start) {
    return [startId];
  }
  const ids = [];
  for (let task = start; task <= end; task += 1) {
    ids.push(`T-${String(task).padStart(3, "0")}`);
  }
  return ids;
}

function taskIdsInText(text) {
  const ids = new Set();
  for (const match of text.matchAll(/\b(T-\d{3})\.\.\.(T-\d{3})\b/g)) {
    for (const id of expandTaskRange(match[1], match[2])) {
      ids.add(id);
    }
  }
  for (const match of text.matchAll(/\b(T-\d{3})(?!\+)\b/g)) {
    ids.add(match[1]);
  }
  return [...ids];
}

function allLedgerRows() {
  const rows = ledgerRows(readOptional("docs/06_tasks/TASK_LEDGER.md"));
  const archiveDir = path.join(PROJECT_ROOT, "docs/09_frozen/task_ledgers");
  if (fs.existsSync(archiveDir)) {
    for (const entry of fs.readdirSync(archiveDir).filter((fileName) => fileName.endsWith(".md"))) {
      rows.push(...ledgerRows(fs.readFileSync(path.join(archiveDir, entry), "utf8")));
    }
  }
  return rows;
}

function roadmapStatusSegments(line) {
  return line
    .split(/[;|]/)
    .map((segment) => segment.trim())
    .filter(Boolean);
}

function checkRoadmapLedgerAlignment() {
  const roadmap = readOptional("docs/06_tasks/ROADMAP.md");
  const statusById = new Map(allLedgerRows().map((row) => [row.id, row.status]));

  for (const line of roadmap.split(/\r?\n/)) {
    const ids = taskIdsInText(line);
    if (ids.length === 0) {
      continue;
    }
    const lower = line.toLowerCase();
    const isCompletedMapping = lower.includes("completed mapping");
    const completedIds = isCompletedMapping
      ? []
      : roadmapStatusSegments(line)
        .filter((segment) => /\bcomplete\b/i.test(segment))
        .flatMap(taskIdsInText);
    const blockedIds = isCompletedMapping
      ? []
      : roadmapStatusSegments(line)
        .filter((segment) => /\bblocked\b/i.test(segment))
        .flatMap(taskIdsInText);

    for (const id of ids) {
      const status = statusById.get(id);
      if (!status) {
        failures.push(`ROADMAP.md references ${id} without task-ledger evidence`);
      } else if (completedIds.includes(id) && status !== "completed") {
        failures.push(`ROADMAP.md marks ${id} complete but task ledger status is ${status}`);
      } else if (blockedIds.includes(id) && status !== "blocked") {
        failures.push(`ROADMAP.md marks ${id} blocked but task ledger status is ${status}`);
      }
    }
  }
}

function resolveFeatureIndexTarget(target) {
  if (target.startsWith("docs/") || target.startsWith("supabase/") || target.startsWith("ios/")) {
    return target;
  }
  return path.join("docs", target);
}

function checkFeatureIndexCoverage() {
  const featureIndex = readOptional("docs/00_memory/FEATURE_INDEX.md");
  let checkedRows = 0;

  for (const line of featureIndex.split(/\r?\n/)) {
    if (!line.startsWith("|") || /^\|\s*-/.test(line) || line.includes("| Feature Area |")) {
      continue;
    }
    const cells = line.split("|").map((cell) => cell.trim());
    const readFirst = cells[2] ?? "";
    const targets = [...readFirst.matchAll(/`([^`]+)`/g)].map((match) => match[1]);
    if (targets.length === 0) {
      failures.push(`Feature Index row has no read-first target: ${line}`);
      continue;
    }
    checkedRows += 1;
    for (const target of targets) {
      const resolved = resolveFeatureIndexTarget(target);
      if (!fs.existsSync(path.join(PROJECT_ROOT, resolved))) {
        failures.push(`Feature Index read-first target is missing: ${target} (${resolved})`);
      }
    }
  }

  if (checkedRows === 0) {
    failures.push("Feature Index has no feature rows to check");
  }
}

function checkCurrentFacts() {
  const currentState = readOptional("docs/00_memory/CURRENT_STATE.md");
  const taskLedger = readOptional("docs/06_tasks/TASK_LEDGER.md");

  const currentLatest = extractTaskId(currentState, /Latest completed task:\s*(T-\d{3})/i);
  const currentNext = extractTaskId(currentState, /Next task ID:\s*(?:use\s*)?(T-\d{3})/i);
  const currentBranch = extractBranchBaseline(currentState, /Current branch baseline:\s*`([^`]+)`/i);

  const ledgerNext = extractTaskId(taskLedger, /use\s+`?(T-\d{3})`?\s+for the next/i);
  const ledgerBranch = extractBranchBaseline(taskLedger, /Current branch and task-numbering baseline:\s*use\s+`([^`]+)`/i);
  const completedRows = ledgerRows(taskLedger).filter((row) => row.status === "completed");
  const latestLedgerCompleted = completedRows
    .map((row) => row.id)
    .sort((a, b) => taskNumber(b) - taskNumber(a))[0] ?? null;

  if (currentLatest && latestLedgerCompleted && currentLatest !== latestLedgerCompleted) {
    failures.push(`latest completed task mismatch: CURRENT_STATE has ${currentLatest}, TASK_LEDGER has ${latestLedgerCompleted}`);
  }
  if (currentNext && ledgerNext && currentNext !== ledgerNext) {
    failures.push(`next task ID mismatch: CURRENT_STATE has ${currentNext}, TASK_LEDGER has ${ledgerNext}`);
  }
  if (currentBranch && ledgerBranch && currentBranch !== ledgerBranch) {
    failures.push(`branch baseline mismatch: CURRENT_STATE has ${currentBranch}, TASK_LEDGER has ${ledgerBranch}`);
  }
}

function checkRollingWindowSizes() {
  const worklog = readOptional("docs/00_memory/WORKLOG.md");
  const taskLedger = readOptional("docs/06_tasks/TASK_LEDGER.md");
  const worklogEntries = [...worklog.matchAll(/^Task:\s*T-\d{3}/gm)].length;
  const taskRows = ledgerRows(taskLedger).length;

  console.log(`Worklog entries: ${worklogEntries} / ${WORKLOG_ENTRY_LIMIT}`);
  console.log(`Task ledger rows: ${taskRows} / ${TASK_LEDGER_ROW_LIMIT}`);

  if (worklogEntries > WORKLOG_ENTRY_LIMIT) {
    failures.push(`WORKLOG.md has ${worklogEntries} active entries, limit ${WORKLOG_ENTRY_LIMIT}`);
  }
  if (taskRows > TASK_LEDGER_ROW_LIMIT) {
    failures.push(`TASK_LEDGER.md has ${taskRows} active rows, limit ${TASK_LEDGER_ROW_LIMIT}`);
  }
}

const activeFiles = activeMarkdownFiles();
checkWordLimits();
checkMarkdownLinks(activeFiles);
checkActiveMarkdownTotal(activeFiles);
checkIgnoredPaths();
checkCredentialClaims();
checkLastVerifiedDates();
checkMigrationMirrorCount();
checkRoadmapLedgerAlignment();
checkFeatureIndexCoverage();
checkCurrentFacts();
checkRollingWindowSizes();

if (failures.length > 0) {
  console.error("\nContext hygiene check failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log("Context hygiene check passed.");
