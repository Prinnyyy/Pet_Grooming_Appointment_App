import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import {
  DECISION_ARCHIVE_POINTER_RETAIN,
  DECISION_ARCHIVE_POINTER_TRIGGER,
  DECISION_LOG_ENTRY_RETAIN,
  DECISION_LOG_ENTRY_TRIGGER,
  DEFAULT_WORD_REFERENCE,
  TASK_LEDGER_ROW_CHAR_LIMIT,
  TASK_LEDGER_ROW_RETAIN,
  TASK_LEDGER_ROW_TRIGGER,
  WORD_REFERENCES,
  WORKLOG_ENTRY_RETAIN,
  WORKLOG_ENTRY_TRIGGER,
} from "./context-hygiene-policy.mjs";

const PROJECT_ROOT = path.resolve(
  process.env.CONTEXT_HYGIENE_PROJECT_ROOT ?? path.resolve(import.meta.dirname, ".."),
);
const LAST_VERIFIED_MAX_AGE_DAYS = 45;
const CHECK_DATE_TEXT = process.env.CONTEXT_HYGIENE_NOW ?? new Date().toISOString().slice(0, 10);
const FORCE_NO_RG = process.env.CONTEXT_HYGIENE_FORCE_NO_RG === "1";
const CLOSEOUT_TASK = process.env.CONTEXT_HYGIENE_CLOSEOUT_TASK ?? null;
// All console/failure output is English.

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

// Future intentional references to missing example paths must include a reason here.
const BACKTICK_PATH_ALLOWLIST = [];

const failures = [];

function detectRgAvailable() {
  if (FORCE_NO_RG) {
    return false;
  }
  const result = spawnSync("rg", ["--version"], {
    cwd: PROJECT_ROOT,
    encoding: "utf8",
  });
  return !result.error && result.status === 0;
}

const RG_AVAILABLE = detectRgAvailable();

// Keep this in sync with .rgignore for the active Markdown fallback path.
const DEFAULT_CONTEXT_EXCLUDE_PREFIXES = [
  "docs/09_frozen/",
  "docs/02_architecture/test_resources/T-129_",
  "docs/08_design/Beckon",
  "docs/ui-redesign/",
];

const DEFAULT_CONTEXT_INCLUDE_FILES = new Set([
  "docs/ui-redesign/README.md",
]);

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
  if (!RG_AVAILABLE) {
    const result = runRequired("git", [
      "ls-files",
      "--cached",
      "--others",
      "--exclude-standard",
      "--",
      "AGENTS.md",
      "README.md",
      "CLAUDE.md",
      "docs",
    ]);
    if (!result) {
      return [];
    }
    if (result.status !== 0) {
      failures.push(`rg unavailable and git ls-files fallback failed: ${(result.stderr ?? result.stdout ?? "").trim()}`);
      return [];
    }
    return [...new Set(result.stdout
      .trim()
      .split(/\r?\n/)
      .filter(Boolean)
      .filter((filePath) => filePath.endsWith(".md"))
      .filter((filePath) => DEFAULT_CONTEXT_INCLUDE_FILES.has(filePath)
        || !DEFAULT_CONTEXT_EXCLUDE_PREFIXES.some((prefix) => filePath.startsWith(prefix))))];
  }

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

function reportWordReferences(files) {
  console.log("Word references (information only):");
  let referenceTotal = 0;
  for (const filePath of [...files].sort()) {
    const reference = WORD_REFERENCES.get(filePath) ?? DEFAULT_WORD_REFERENCE;
    referenceTotal += reference;
    const count = words(readOptional(filePath));
    const status = count <= reference ? "ok" : "over";
    const source = WORD_REFERENCES.has(filePath) ? "explicit" : "default";
    console.log(`  ${status.padEnd(4)} ${String(count).padStart(5)} / ${String(reference).padStart(5)} reference ${filePath} (${source})`);
  }
  console.log(`Reference coverage: ${files.length}/${files.length} files (sum of references: ${referenceTotal})`);
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

function isCheckableBacktickPath(rawPath) {
  if (/[ *<>#{}]/.test(rawPath)) {
    return false;
  }
  return rawPath.startsWith("docs/")
    || rawPath.startsWith("scripts/")
    || rawPath.startsWith("supabase/")
    || rawPath.startsWith("ios/")
    || rawPath.startsWith("tests/")
    || rawPath.startsWith("../")
    || rawPath.startsWith("./")
    || ["AGENTS.md", "README.md", "CLAUDE.md"].includes(rawPath);
}

function resolveBacktickPath(filePath, rawPath) {
  if (rawPath.startsWith("../")) {
    return path.resolve(PROJECT_ROOT, path.dirname(filePath), rawPath);
  }
  if (rawPath.startsWith("./")) {
    return path.resolve(PROJECT_ROOT, rawPath.slice(2));
  }
  return path.resolve(PROJECT_ROOT, rawPath);
}

function checkBacktickPathIntegrity(files) {
  let checked = 0;
  for (const filePath of files) {
    const lines = read(filePath).split(/\r?\n/);
    let inFence = false;
    for (const line of lines) {
      if (/^\s*```/.test(line)) {
        inFence = !inFence;
        continue;
      }
      if (inFence) {
        continue;
      }

      for (const match of line.matchAll(/`([^`\n]+)`/g)) {
        const rawPath = match[1].trim();
        if (!rawPath || BACKTICK_PATH_ALLOWLIST.includes(rawPath) || !isCheckableBacktickPath(rawPath)) {
          continue;
        }
        checked += 1;
        if (!fs.existsSync(resolveBacktickPath(filePath, rawPath))) {
          failures.push(`${filePath} references missing backtick path: ${rawPath}`);
        }
      }
    }
  }
  console.log(`Backtick paths checked: ${checked}`);
}

function reportActiveMarkdownWords(files) {
  let total = 0;
  for (const filePath of files) {
    total += words(readOptional(filePath));
  }
  console.log(`Active Markdown words (information only): ${total}`);
  console.log("Context capacity: host-managed; Markdown words do not estimate token usage");
}

function checkWorkflowOwnership() {
  const agents = readOptional("AGENTS.md");
  const claude = readOptional("CLAUDE.md");
  const single = readOptional("docs/05_workflow/SINGLE_AGENT_WORKFLOW.md");
  const context = readOptional("docs/05_workflow/CONTEXT_AND_RECOVERY.md");
  const tooling = readOptional("docs/05_workflow/TOOLING_POLICY.md");
  const github = readOptional("docs/05_workflow/GITHUB_RULES.md");
  const stop = readOptional("docs/05_workflow/STOP_CONDITIONS.md");

  const entryLimits = [
    ["AGENTS.md", agents, 600],
    ["CLAUDE.md", claude, 250],
  ];
  for (const [filePath, text, limit] of entryLimits) {
    const count = words(text);
    if (count > limit) {
      failures.push(`${filePath} workflow entry has ${count} words, limit ${limit}`);
    }
  }

  const ownershipMarkers = [
    ["docs/05_workflow/SINGLE_AGENT_WORKFLOW.md", single, /Owns: task lifecycle/i],
    ["docs/05_workflow/CONTEXT_AND_RECOVERY.md", context, /Owns: context access, recovery, compaction, and context hygiene/i],
    ["docs/05_workflow/TOOLING_POLICY.md", tooling, /Owns: validation, tools, credentials, and remote-operation authorization/i],
    ["docs/05_workflow/GITHUB_RULES.md", github, /Owns: Git and GitHub conventions/i],
    ["docs/05_workflow/STOP_CONDITIONS.md", stop, /Owns: the stop-and-report matrix only/i],
  ];
  for (const [filePath, text, marker] of ownershipMarkers) {
    if (!marker.test(text)) {
      failures.push(`${filePath} is missing its workflow ownership marker`);
    }
  }

  const nonToolValidationOwners = [
    ["AGENTS.md", agents],
    ["CLAUDE.md", claude],
    ["docs/05_workflow/SINGLE_AGENT_WORKFLOW.md", single],
    ["docs/05_workflow/CONTEXT_AND_RECOVERY.md", context],
    ["docs/05_workflow/STOP_CONDITIONS.md", stop],
  ];
  for (const [filePath, text] of nonToolValidationOwners) {
    if (/\.\/scripts\/ios-(?:build|test)\.sh|git diff --check/.test(text)) {
      failures.push(`${filePath} duplicates concrete validation commands owned by TOOLING_POLICY.md`);
    }
  }

  const activeRuleText = [agents, claude, single, context, tooling, github, stop].join("\n");
  const forbiddenRules = [
    [/execute the meta-review immediately/i, "same-session automatic meta-review"],
    [/353,?000|229,?000|282,?000|70,?600|\b65%|\b80%/, "static host-context capacity threshold"],
    [/Superpowers is optional|Use at most one directly relevant capability/i, "repository cap on host-required skills"],
    [/The first required build or test attempt fails/i, "first-failure rule that conflicts with development RED states"],
  ];
  for (const [pattern, label] of forbiddenRules) {
    if (pattern.test(activeRuleText)) {
      failures.push(`Active workflow contains forbidden ${label}`);
    }
  }

  const requiredRules = [
    [single, /reserve the next task ID and end the current task/i, "meta-review reservation handoff"],
    [single, /Do not start the review in the same session/i, "single-session task boundary"],
    [tooling, /Expected RED/i, "TDD development-failure distinction"],
    [tooling, /user defers visual review/i, "Simulator user-deferral rule"],
    [tooling, /Host-mandated skills and tool instructions/i, "host skill precedence"],
    [github, /Checkpoint commits and pushes require explicit user approval/i, "checkpoint Git authorization"],
  ];
  for (const [text, pattern, label] of requiredRules) {
    if (!pattern.test(text)) {
      failures.push(`Active workflow is missing ${label}`);
    }
  }
}

function checkIgnoredPaths() {
  if (!RG_AVAILABLE) {
    console.log("warn: rg unavailable, .rgignore behavior checks skipped");
    return;
  }

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
  const visibleBeckonHTML = (design?.stdout ?? "")
    .trim()
    .split(/\r?\n/)
    .filter((filePath) => /Beckon.*\.html$/i.test(filePath));
  if (visibleBeckonHTML.length > 0) {
    failures.push(`Beckon HTML visible to default rg --files: ${visibleBeckonHTML.join(", ")}`);
  }

  const uiRedesign = runRequired("rg", ["--files", "docs/ui-redesign"]);
  const uiRedesignFiles = uiRedesign?.stdout.trim().split(/\r?\n/).filter(Boolean) ?? [];
  const expectedUIRedesign = ["docs/ui-redesign/README.md"];
  if (uiRedesignFiles.join("\n") !== expectedUIRedesign.join("\n")) {
    failures.push(`ui-redesign default rg output changed: ${uiRedesignFiles.join(", ")}`);
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

  const requiredFacts = [
    ["CURRENT_STATE.md", "latest completed task", currentLatest],
    ["CURRENT_STATE.md", "next task ID", currentNext],
    ["CURRENT_STATE.md", "current branch baseline", currentBranch],
    ["TASK_LEDGER.md", "next task ID", ledgerNext],
    ["TASK_LEDGER.md", "branch baseline", ledgerBranch],
    ["TASK_LEDGER.md", "latest completed row", latestLedgerCompleted],
  ];
  for (const [fileName, factName, value] of requiredFacts) {
    if (!value) {
      failures.push(`${fileName} is missing an extractable ${factName} (wording may have drifted from the expected pattern)`);
    }
  }

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

function checkCurrentStateShape() {
  const currentState = readOptional("docs/00_memory/CURRENT_STATE.md");
  const forbiddenSections = [
    /^##\s+Completed Tasks?\b/im,
    /^##\s+(?:Completed )?Task History\b/im,
    /^##\s+Historical Tasks?\b/im,
    /^##\s+Task Timeline\b/im,
  ];
  for (const pattern of forbiddenSections) {
    const match = currentState.match(pattern);
    if (match) {
      failures.push(`CURRENT_STATE.md contains forbidden historical section: ${match[0]}`);
    }
  }
  if (/Next Recommended Task/i.test(currentState)) {
    failures.push("CURRENT_STATE.md contains forbidden historical instruction: Next Recommended Task");
  }
}

function worklogTaskEntries(text) {
  return [...text.matchAll(/```text\n([\s\S]*?)\n```/g)]
    .map((match) => ({
      body: match[1],
      task: match[1].match(/^Task:\s*(T-\d{3})/m)?.[1] ?? null,
    }))
    .filter(({ task }) => task);
}

function checkWorklogHandoffOwnership() {
  const entries = worklogTaskEntries(readOptional("docs/00_memory/WORKLOG.md"));
  const stale = entries.slice(1).filter(({ body }) => /^Next:/m.test(body));
  if (stale.length > 0) {
    failures.push(`WORKLOG.md keeps Next instructions outside its newest entry: ${stale.map(({ task }) => task).join(", ")}`);
  }
}

function markdownFilesBelow(directory) {
  if (!fs.existsSync(directory)) {
    return [];
  }
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...markdownFilesBelow(target));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(target);
    }
  }
  return files;
}

function taskArtifactMetadata(text) {
  const block = text.match(/^\s*<!--\s*task-artifact\s*\r?\n([\s\S]*?)\r?\n-->/i)?.[1];
  if (!block) {
    return null;
  }
  const fields = new Map();
  for (const line of block.split(/\r?\n/)) {
    const match = line.match(/^([a-z]+):\s*(.+)$/i);
    if (match) {
      fields.set(match[1].toLowerCase(), match[2].trim());
    }
  }
  return {
    task: fields.get("task"),
    status: fields.get("status")?.toLowerCase(),
    type: fields.get("type")?.toLowerCase(),
  };
}

function checkTaskArtifactLifecycle() {
  const artifactRoot = path.join(PROJECT_ROOT, "docs/superpowers");
  for (const absolutePath of markdownFilesBelow(artifactRoot)) {
    const filePath = path.relative(PROJECT_ROOT, absolutePath);
    if (filePath === "docs/superpowers/README.md") {
      continue;
    }
    const metadata = taskArtifactMetadata(fs.readFileSync(absolutePath, "utf8"));
    if (!metadata) {
      failures.push(`${filePath} is missing task-artifact metadata`);
      continue;
    }
    if (!/^T-\d{3}$/.test(metadata.task ?? "")) {
      failures.push(`${filePath} has invalid task-artifact task metadata`);
    }
    if (!new Set(["plan", "spec"]).has(metadata.type)) {
      failures.push(`${filePath} has invalid task-artifact type metadata`);
    }
    if (metadata.status === "completed" && metadata.task !== CLOSEOUT_TASK) {
      failures.push(`completed task artifact remains active: ${filePath}`);
    } else if (!new Set(["active", "completed"]).has(metadata.status)) {
      failures.push(`${filePath} has invalid task-artifact status metadata`);
    }
  }
}

function checkRemovedGovernanceEntrypoints() {
  if (fs.existsSync(path.join(PROJECT_ROOT, "scripts/agent-preflight.sh"))) {
    failures.push("scripts/agent-preflight.sh duplicates the canonical governance gates");
  }
}

function checkMetaReviewCadence() {
  const currentState = readOptional("docs/00_memory/CURRENT_STATE.md");
  const match = currentState.match(/Last meta-review:\s*(T-\d{3})\s+on\s+(\d{4}-\d{2}-\d{2})/i);
  if (!match) {
    failures.push("CURRENT_STATE.md is missing an extractable Last meta-review marker (wording may have drifted from the expected pattern)");
    return;
  }

  const [, metaReviewTask] = match;
  const latestCompleted = allLedgerRows()
    .filter((row) => row.status === "completed")
    .map((row) => row.id)
    .sort((a, b) => taskNumber(b) - taskNumber(a))[0] ?? null;

  if (!latestCompleted) {
    failures.push("TASK_LEDGER.md is missing an extractable latest completed row (cannot check meta-review cadence)");
    return;
  }

  const completedDelta = taskNumber(latestCompleted) - taskNumber(metaReviewTask);
  const expectedNextTask = `T-${String(taskNumber(latestCompleted) + 1).padStart(3, "0")}`;
  const nextTask = extractTaskId(
    currentState,
    /Next task ID:\s*(?:use\s*)?(T-\d{3})/i,
  );
  const nextTaskReservesMetaReview = new RegExp(
    `Next task ID:[^\\n]*${expectedNextTask}[^\\n]*required periodic meta-review`,
    "i",
  ).test(currentState);

  if (completedDelta === 10 && nextTask === expectedNextTask && nextTaskReservesMetaReview) {
    console.log(`Meta-review due: ${expectedNextTask} is explicitly reserved`);
  } else if (completedDelta >= 10) {
    failures.push(`Last meta-review ${metaReviewTask} is ${completedDelta} completed tasks behind ${latestCompleted}; run a meta-review task`);
  }
}

function decisionArchivePointerRows(text) {
  const lines = text.split(/\r?\n/);
  const headingIndex = lines.findIndex((line) => line.trim() === "## Archived Decision Index");
  if (headingIndex < 0) {
    return [];
  }
  const headerIndex = lines.findIndex((line, index) => index > headingIndex && line.startsWith("| Date | Decision | Current entry point |"));
  if (headerIndex < 0) {
    return [];
  }
  const nextHeadingIndex = lines.findIndex((line, index) => index > headerIndex && line.startsWith("## "));
  const endIndex = nextHeadingIndex < 0 ? lines.length : nextHeadingIndex;
  return lines.slice(headerIndex + 2, endIndex).filter((line) => /^\| .+ \| .+ \| .+ \|$/.test(line));
}

function checkRollingWindowSizes() {
  const worklog = readOptional("docs/00_memory/WORKLOG.md");
  const taskLedger = readOptional("docs/06_tasks/TASK_LEDGER.md");
  const decisionLog = readOptional("docs/07_decisions/DECISION_LOG.md");
  const worklogEntries = [...worklog.matchAll(/^Task:\s*T-\d{3}/gm)].length;
  const taskRows = ledgerRows(taskLedger).length;
  const decisionEntries = [...decisionLog.matchAll(/```text\s+Decision ID:\s*D-\d{3}[\s\S]*?\n```/g)].length;
  const decisionPointers = decisionArchivePointerRows(decisionLog).length;

  console.log(`Worklog entries: ${worklogEntries} / ${WORKLOG_ENTRY_TRIGGER} trigger; retain ${WORKLOG_ENTRY_RETAIN}; available ${Math.max(0, WORKLOG_ENTRY_TRIGGER - worklogEntries)}`);
  console.log(`Task ledger rows: ${taskRows} / ${TASK_LEDGER_ROW_TRIGGER} trigger; retain ${TASK_LEDGER_ROW_RETAIN}; available ${Math.max(0, TASK_LEDGER_ROW_TRIGGER - taskRows)}`);
  console.log(`Decision log entries: ${decisionEntries} / ${DECISION_LOG_ENTRY_TRIGGER} trigger; retain ${DECISION_LOG_ENTRY_RETAIN}; available ${Math.max(0, DECISION_LOG_ENTRY_TRIGGER - decisionEntries)}`);
  console.log(`Decision archive pointers: ${decisionPointers} / ${DECISION_ARCHIVE_POINTER_TRIGGER} trigger; retain ${DECISION_ARCHIVE_POINTER_RETAIN}; available ${Math.max(0, DECISION_ARCHIVE_POINTER_TRIGGER - decisionPointers)}`);

  if (worklogEntries > WORKLOG_ENTRY_TRIGGER) {
    failures.push(`WORKLOG.md has ${worklogEntries} active entries, trigger ${WORKLOG_ENTRY_TRIGGER}`);
  }
  if (taskRows > TASK_LEDGER_ROW_TRIGGER) {
    failures.push(`TASK_LEDGER.md has ${taskRows} active rows, trigger ${TASK_LEDGER_ROW_TRIGGER}`);
  }
  if (decisionEntries > DECISION_LOG_ENTRY_TRIGGER) {
    failures.push(`DECISION_LOG.md has ${decisionEntries} active decisions, trigger ${DECISION_LOG_ENTRY_TRIGGER}`);
  }
  if (decisionPointers > DECISION_ARCHIVE_POINTER_TRIGGER) {
    failures.push(`DECISION_LOG.md has ${decisionPointers} archive pointers, trigger ${DECISION_ARCHIVE_POINTER_TRIGGER}`);
  }

  for (const [index, line] of taskLedger.split(/\r?\n/).entries()) {
    if (line.startsWith("| T-") && line.length > TASK_LEDGER_ROW_CHAR_LIMIT) {
      failures.push(`TASK_LEDGER.md table row ${index + 1} has ${line.length} characters, limit ${TASK_LEDGER_ROW_CHAR_LIMIT}`);
    }
  }
}

const activeFiles = activeMarkdownFiles();
reportWordReferences(activeFiles);
checkMarkdownLinks(activeFiles);
checkBacktickPathIntegrity(activeFiles);
reportActiveMarkdownWords(activeFiles);
checkIgnoredPaths();
checkWorkflowOwnership();
checkCredentialClaims();
checkLastVerifiedDates();
checkMigrationMirrorCount();
checkRoadmapLedgerAlignment();
checkFeatureIndexCoverage();
checkCurrentFacts();
checkCurrentStateShape();
checkWorklogHandoffOwnership();
checkTaskArtifactLifecycle();
checkRemovedGovernanceEntrypoints();
checkMetaReviewCadence();
checkRollingWindowSizes();

if (failures.length > 0) {
  console.error("\nContext hygiene check failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log("Context hygiene check passed.");
