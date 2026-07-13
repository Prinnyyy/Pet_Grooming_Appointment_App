import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = path.resolve(
  process.env.TASK_CLOSEOUT_PROJECT_ROOT ?? path.resolve(import.meta.dirname, ".."),
);
const CHECK_DATE = process.env.TASK_CLOSEOUT_NOW ?? new Date().toISOString().slice(0, 10);
const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const VERBOSE = args.includes("--verbose");

function argumentValue(flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : null;
}

const TASK_ID = argumentValue("--task");
const allowedArgs = new Set(["--task", "--apply", "--verbose", TASK_ID].filter(Boolean));
const unknownArgs = args.filter((arg) => !allowedArgs.has(arg));

function fail(messages) {
  console.error("Task closeout failed:");
  for (const message of messages) {
    console.error(`- ${message}`);
  }
  process.exit(1);
}

if (!TASK_ID || !/^T-\d{3}$/.test(TASK_ID)) {
  fail(["Pass a task ID with --task T-###."]);
}
if (unknownArgs.length > 0) {
  fail([`Unknown arguments: ${unknownArgs.join(", ")}`]);
}
if (!/^\d{4}-\d{2}-\d{2}$/.test(CHECK_DATE)) {
  fail([`TASK_CLOSEOUT_NOW must be YYYY-MM-DD; got ${CHECK_DATE}.`]);
}

function fullPath(filePath) {
  return path.join(PROJECT_ROOT, filePath);
}

function readRequired(filePath) {
  const target = fullPath(filePath);
  if (!fs.existsSync(target)) {
    fail([`${filePath} is missing.`]);
  }
  return fs.readFileSync(target, "utf8");
}

function nextTaskId(taskIds) {
  const taskNumber = Math.max(
    ...taskIds.map((taskId) => Number.parseInt(taskId.slice(2), 10)),
  ) + 1;
  return `T-${String(taskNumber).padStart(3, "0")}`;
}

function taskRows(text) {
  return text.split(/\r?\n/).map((line) => {
    if (!/^\| T-\d{3} \|/.test(line)) {
      return null;
    }
    const cells = line.split("|").slice(1, -1).map((cell) => cell.trim());
    return { id: cells[0], status: cells[2]?.toLowerCase() ?? "" };
  }).filter(Boolean);
}

function checkTaskFacts() {
  const ledger = readRequired("docs/06_tasks/TASK_LEDGER.md");
  const currentState = readRequired("docs/00_memory/CURRENT_STATE.md");
  const worklog = readRequired("docs/00_memory/WORKLOG.md");
  const errors = [];
  const rows = taskRows(ledger);
  const row = rows.find(({ id }) => id === TASK_ID);
  const expectedNext = nextTaskId(rows.map(({ id }) => id));
  const currentLatest = currentState.match(/Latest completed task:\s*(T-\d{3})/i)?.[1];
  const currentNext = currentState.match(/Next task ID:\s*(?:use\s*)?(T-\d{3})/i)?.[1];
  const ledgerNext = ledger.match(/use\s+`?(T-\d{3})`?\s+for the next/i)?.[1];

  if (!row) {
    errors.push(`TASK_LEDGER.md has no ${TASK_ID} row.`);
  } else if (row.status !== "completed") {
    errors.push(`TASK_LEDGER.md marks ${TASK_ID} as ${row.status || "unknown"}, not completed.`);
  }
  if (!new RegExp(`^Task:\\s*${TASK_ID}\\b`, "m").test(worklog)) {
    errors.push(`WORKLOG.md has no ${TASK_ID} closeout entry.`);
  }
  if (currentLatest !== TASK_ID) {
    errors.push(`CURRENT_STATE.md latest completed task is ${currentLatest ?? "missing"}, expected ${TASK_ID}.`);
  }
  if (currentNext !== expectedNext || ledgerNext !== expectedNext) {
    errors.push(`Current State and Task Ledger must both assign ${expectedNext} as the next task.`);
  }
  return errors;
}

function walkMarkdown(directory, files = []) {
  if (!fs.existsSync(directory)) {
    return files;
  }
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      walkMarkdown(target, files);
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(target);
    }
  }
  return files;
}

function parseArtifactMetadata(filePath, text) {
  const match = text.match(/^\s*<!--\s*task-artifact\s*\r?\n([\s\S]*?)\r?\n-->/i);
  if (!match) {
    return { error: `${filePath} is missing a leading task-artifact metadata block.` };
  }
  const metadata = new Map();
  for (const line of match[1].split(/\r?\n/)) {
    const field = line.match(/^([a-z]+):\s*(.+)$/i);
    if (field) {
      metadata.set(field[1].toLowerCase(), field[2].trim());
    }
  }
  return {
    task: metadata.get("task"),
    status: metadata.get("status")?.toLowerCase(),
    type: metadata.get("type")?.toLowerCase(),
  };
}

function collectArtifacts() {
  const artifactRoot = fullPath("docs/superpowers");
  const errors = [];
  const artifacts = [];
  for (const absolutePath of walkMarkdown(artifactRoot)) {
    const source = path.relative(PROJECT_ROOT, absolutePath);
    if (source === "docs/superpowers/README.md") {
      continue;
    }
    const text = fs.readFileSync(absolutePath, "utf8");
    const metadata = parseArtifactMetadata(source, text);
    if (metadata.error) {
      errors.push(metadata.error);
      continue;
    }
    if (metadata.task !== TASK_ID) {
      errors.push(`${source} declares task ${metadata.task ?? "missing"}, expected ${TASK_ID}.`);
      continue;
    }
    if (metadata.status !== "completed") {
      errors.push(`${source} must declare status: completed before closeout.`);
      continue;
    }
    if (!new Set(["plan", "spec"]).has(metadata.type)) {
      errors.push(`${source} must declare type: plan or type: spec.`);
      continue;
    }
    const family = metadata.type === "plan" ? "plans" : "specs";
    const destination = path.join(
      `docs/09_frozen/superpowers_${CHECK_DATE}`,
      family,
      path.basename(source),
    );
    if (fs.existsSync(fullPath(destination))) {
      errors.push(`${destination} already exists; choose a unique artifact filename.`);
      continue;
    }
    artifacts.push({ source, destination });
  }
  return { artifacts, errors };
}

const ACTIVE_EXCLUDED_PREFIXES = [
  "docs/09_frozen/",
  "docs/02_architecture/test_resources/T-129_",
  "docs/08_design/Beckon",
  "docs/ui-redesign/",
];

function activeMarkdownFiles() {
  const candidates = [];
  for (const rootFile of ["AGENTS.md", "README.md", "CLAUDE.md"]) {
    if (fs.existsSync(fullPath(rootFile))) {
      candidates.push(fullPath(rootFile));
    }
  }
  candidates.push(...walkMarkdown(fullPath("docs")));
  return candidates.filter((absolutePath) => {
    const relative = path.relative(PROJECT_ROOT, absolutePath);
    if (relative === "docs/ui-redesign/README.md") {
      return true;
    }
    return !ACTIVE_EXCLUDED_PREFIXES.some((prefix) => relative.startsWith(prefix));
  });
}

function linksToArtifact(documentPath, text, artifactPath) {
  const artifactAbsolute = path.resolve(PROJECT_ROOT, artifactPath);
  for (const match of text.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const raw = match[1].split("#")[0].trim().replace(/^<|>$/g, "");
    if (!raw || /^[a-z][a-z0-9+.-]*:/i.test(raw)) {
      continue;
    }
    if (path.resolve(path.dirname(documentPath), raw) === artifactAbsolute) {
      return true;
    }
  }
  for (const match of text.matchAll(/`([^`\n]+)`/g)) {
    const raw = match[1].trim();
    if (raw === artifactPath) {
      return true;
    }
    if ((raw.startsWith("./") || raw.startsWith("../"))
      && path.resolve(path.dirname(documentPath), raw) === artifactAbsolute) {
      return true;
    }
  }
  return text.includes(artifactPath);
}

function checkArtifactBacklinks(artifacts) {
  const errors = [];
  const sourceSet = new Set(artifacts.map(({ source }) => fullPath(source)));
  for (const documentPath of activeMarkdownFiles()) {
    if (sourceSet.has(documentPath)) {
      continue;
    }
    const text = fs.readFileSync(documentPath, "utf8");
    for (const artifact of artifacts) {
      if (linksToArtifact(documentPath, text, artifact.source)) {
        const document = path.relative(PROJECT_ROOT, documentPath);
        errors.push(`${document} links to pending artifact ${artifact.source}; remove or replace the active backlink first.`);
      }
    }
  }
  return errors;
}

function runNodeScript(scriptName, scriptArgs = [], environment = {}) {
  const result = spawnSync(process.execPath, [fullPath(`scripts/${scriptName}`), ...scriptArgs], {
    cwd: PROJECT_ROOT,
    env: {
      ...process.env,
      CONTEXT_HYGIENE_PROJECT_ROOT: PROJECT_ROOT,
      CONTEXT_HYGIENE_NOW: CHECK_DATE,
      ...environment,
    },
    encoding: "utf8",
  });
  const combined = `${result.stdout ?? ""}${result.stderr ?? ""}`.trim();
  return { ...result, combined };
}

function ensureGatePassed(label, result) {
  if (result.error) {
    fail([`${label} could not run: ${result.error.message}`]);
  }
  if (result.status !== 0 || /cannot be reached/i.test(result.combined)) {
    fail([`${label} failed.`, result.combined || "No diagnostic output."]);
  }
}

const taskErrors = checkTaskFacts();
const { artifacts, errors: artifactErrors } = collectArtifacts();
const backlinkErrors = checkArtifactBacklinks(artifacts);
const preRotation = runNodeScript("context-rotate.mjs");
const preHygiene = runNodeScript("context-hygiene-check.mjs", [], {
  CONTEXT_HYGIENE_CLOSEOUT_TASK: TASK_ID,
});

if (taskErrors.length || artifactErrors.length || backlinkErrors.length) {
  fail([...taskErrors, ...artifactErrors, ...backlinkErrors]);
}
ensureGatePassed("Context rotation dry run", preRotation);
ensureGatePassed("Context hygiene precheck", preHygiene);

let rotation = preRotation;
let hygiene = preHygiene;
if (APPLY) {
  for (const artifact of artifacts) {
    fs.mkdirSync(path.dirname(fullPath(artifact.destination)), { recursive: true });
    fs.renameSync(fullPath(artifact.source), fullPath(artifact.destination));
  }
  rotation = runNodeScript("context-rotate.mjs", ["--apply"]);
  ensureGatePassed("Context rotation", rotation);
  hygiene = runNodeScript("context-hygiene-check.mjs");
  ensureGatePassed("Context hygiene", hygiene);
}

console.log(`Task closeout: ${TASK_ID}`);
console.log(`Mode: ${APPLY ? "apply" : "dry-run"}`);
console.log("Task facts: completed and aligned");
console.log("Artifact metadata: valid");
console.log(`Artifacts: ${APPLY ? "archived" : "would archive"} ${artifacts.length}`);
console.log("Backlinks: clear");
console.log("Safety precheck: passed");
console.log("Rotation: passed");
console.log("Hygiene: passed");
console.log("Result: task closeout passed");

if (VERBOSE) {
  for (const artifact of artifacts) {
    console.log(`Artifact: ${artifact.source} -> ${artifact.destination}`);
  }
  console.log("Rotation output:");
  console.log(rotation.combined || "(none)");
  console.log("Hygiene output:");
  console.log(hygiene.combined || "(none)");
}
