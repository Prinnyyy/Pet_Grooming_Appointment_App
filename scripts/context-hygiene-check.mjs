import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = path.resolve(process.env.CONTEXT_HYGIENE_PROJECT_ROOT ?? path.join(import.meta.dirname, ".."));
const args = process.argv.slice(2);
const report = { ok: false, errors: [], warnings: [], checkedFiles: [] };
let catalog = new Set();
const core = ["AGENTS.md", "CLAUDE.md", "README.md", "docs/README.md", "docs/00_memory/CURRENT_STATE.md", "docs/00_memory/FEATURE_INDEX.md", "docs/05_workflow/DEVELOPMENT_GUIDE.md", "docs/06_tasks/ROADMAP.md"];
const error = message => report.errors.push(message);
const nonempty = value => typeof value === "string" && value.trim().length > 0;
const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const taskNumber = value => typeof value === "string" && /^T-\d{3,}$/.test(value) && Number.isSafeInteger(Number(value.slice(2))) && Number(value.slice(2)) > 0 ? Number(value.slice(2)) : null;

function command(name, argv) {
  const result = spawnSync(name, argv, { cwd: root, encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Error(`${name} could not inspect the repository (exit ${result.status ?? "unavailable"})`);
  return result.stdout;
}

function restricted(file) {
  return /(^|\/)\./.test(file)
    || /^(artifacts|docs\/09_frozen)\//.test(file)
    || /^docs\/02_architecture\/test_resources\/T-129_.*_TEST_PROFILES\.md$/.test(file)
    || /^docs\/08_design\/Beckon(?:\/|\.html$)/.test(file)
    || (file.startsWith("docs/ui-redesign/") && file !== "docs/ui-redesign/README.md")
    || ["CloudFlare API.md", "Resend API.md", "supabase_api_key", "supabase_environment_variables"].includes(file);
}

function safeMarkdown(file) {
  if (typeof file !== "string" || path.isAbsolute(file) || !file.endsWith(".md")) {
    error(`Invalid Markdown path: ${String(file)}`); return false;
  }
  const normalized = path.relative(root, path.resolve(root, file));
  if (normalized.startsWith("..") || restricted(normalized) || !catalog.has(normalized)) {
    error(`Restricted Markdown path: ${file}`); return false;
  }
  try {
    const real = fs.realpathSync(path.join(root, normalized));
    const relative = path.relative(fs.realpathSync(root), real);
    if (relative.startsWith("..") || path.isAbsolute(relative) || restricted(relative) || !catalog.has(relative) || !fs.statSync(real).isFile()) {
      error(`Unsafe Markdown target: ${file}`); return false;
    }
    return true;
  } catch {
    error(`Missing or unreadable Markdown file: ${file}`); return false;
  }
}

function readState() {
  const file = core[4];
  if (!safeMarkdown(file)) return null;
  const text = fs.readFileSync(path.join(root, file), "utf8");
  const blocks = [...text.matchAll(/^```json[ \t]*\r?\n([\s\S]*?)^```[ \t]*$/gm)];
  if (blocks.length !== 1) { error("CURRENT_STATE must contain exactly one JSON block"); return null; }
  let state;
  try { state = JSON.parse(blocks[0][1]); } catch { error("CURRENT_STATE contains invalid JSON"); return null; }
  if (!object(state)) { error("CURRENT_STATE must be an object"); return null; }
  for (const key of Object.keys(state)) if (!["next_task_id", "task", "pending_tasks", "last_completed"].includes(key)) error(`Unknown state field: ${key}`);
  const ids = new Set();
  const numbers = [];
  function id(value, label) {
    const number = taskNumber(value);
    if (number === null) error(`Invalid task ID in ${label}`);
    else {
      if (ids.has(number)) error(`Duplicate task ID in ${label}: ${value}`);
      ids.add(number); numbers.push(number);
    }
  }
  function task(value, pending) {
    if (!object(value)) { error("Invalid task record"); return; }
    id(value.id, "task");
    const states = pending ? ["planned", "paused", "blocked"] : ["planned", "active", "paused", "blocked"];
    if (!states.includes(value.status)) error(`Invalid task status: ${value.id}`);
    if (!nonempty(value.goal) || !nonempty(value.next_action)) error(`Missing goal or next_action: ${value.id}`);
    if (value.plan !== null) safeMarkdown(value.plan);
    for (const key of Object.keys(value)) if (!["id", "status", "goal", "plan", "next_action", "authorization", "blockers", "verification", "preserve"].includes(key)) error(`Unknown task field: ${key}`);
    for (const key of ["authorization", "blockers", "preserve"]) {
      if (value[key] !== undefined && (!Array.isArray(value[key]) || !value[key].every(nonempty))) error(`Invalid ${key}: ${value.id}`);
    }
    if (value.verification !== undefined && (!Array.isArray(value.verification) || !value.verification.every(item => object(item) && ["scope", "command", "basis", "result", "evidence"].every(key => nonempty(item[key]))))) error(`Invalid verification: ${value.id}`);
  }
  if (state.task !== null) task(state.task, false);
  if (!Array.isArray(state.pending_tasks)) error("pending_tasks must be an array");
  else state.pending_tasks.forEach(item => task(item, true));
  if (state.last_completed !== null) {
    if (!object(state.last_completed) || Object.keys(state.last_completed).some(key => key !== "id")) error("last_completed must contain only a task ID");
    id(state.last_completed?.id, "last_completed");
  }
  const next = taskNumber(state.next_task_id);
  if (next === null || numbers.some(number => number >= next)) error("next_task_id must exceed all allocated task IDs in state");
  return state;
}

// Ignore examples, not actual navigation. Link targets are stat-ed, never read recursively.
function checkLinks(file) {
  let fence = null;
  const prose = fs.readFileSync(path.join(root, file), "utf8").split(/\r?\n/).map(line => {
    const marker = line.match(/^\s{0,3}(`{3,}|~{3,})/);
    if (marker) {
      if (!fence) fence = marker[1];
      else if (marker[1][0] === fence[0] && marker[1].length >= fence.length) fence = null;
      return "";
    }
    return fence ? "" : line.replace(/(`+)[\s\S]*?\1/g, "");
  }).join("\n");
  const targets = [];
  const refs = new Map();
  const referenceKey = text => text.trim().replace(/\s+/g, " ").toLowerCase();
  for (const match of prose.matchAll(/^\s{0,3}\[([^\]]+)\]:\s*(?:<([^>]+)>|(\S+))/gm)) {
    refs.set(referenceKey(match[1]), match[2] ?? match[3]);
    targets.push(match[2] ?? match[3]);
  }
  for (const match of prose.matchAll(/!?\[[^\]\n]*\]\(\s*(?:<([^>]+)>|((?:\\.|[^\s()]+|\([^()]*\))+))(?:\s+["'][^\n]*?["'])?\s*\)/g)) targets.push(match[1] ?? match[2]);
  for (const match of prose.matchAll(/!?\[([^\]\n]+)\]\[([^\]\n]*)\]/g)) {
    const key = referenceKey(match[2] || match[1]);
    if (!refs.has(key)) error(`${file}: undefined link reference ${key}`);
  }
  for (const raw of new Set(targets)) {
    if (/^(?:[a-z][a-z\d+.-]*:|\/\/|#)/i.test(raw)) continue;
    let target;
    try { target = decodeURIComponent(raw.split(/[?#]/)[0]).replace(/\\([() ])/g, "$1"); }
    catch { error(`${file}: invalid link encoding ${raw}`); continue; }
    if (!target) continue;
    if (!fs.existsSync(path.resolve(root, path.dirname(file), target))) error(`${file}: missing link target ${raw}`);
  }
}

function taskArtifact(file) {
  return /^docs\/superpowers\/(plans|specs)\/.*\.md$/.test(file)
    || file === "docs/06_tasks/APP_FUNCTIONAL_DESIGN_FINDINGS.md"
    || /^docs\/06_tasks\/sql_reviews\/.*\.md$/.test(file);
}

let exitCode = 0;
try {
  if (args.some(arg => !["--full", "--json"].includes(arg))) throw new Error("Usage: node scripts/context-hygiene-check.mjs [--full] [--json]");
  const top = command("git", ["rev-parse", "--show-toplevel"]).trim();
  if (fs.realpathSync(top) !== fs.realpathSync(root)) throw new Error("CONTEXT_HYGIENE_PROJECT_ROOT must be the repository root");
  catalog = new Set(command("git", ["ls-files", "--cached", "--others", "--exclude-standard", "-z"]).split("\0").filter(Boolean));
  const visible = command("rg", ["--files", "-0"]).split("\0").filter(file => file.endsWith(".md"));
  const changed = new Set([
    ...command("git", ["diff", "--name-only", "-z"]).split("\0"),
    ...command("git", ["diff", "--cached", "--name-only", "-z"]).split("\0"),
    ...command("git", ["ls-files", "--others", "--exclude-standard", "-z"]).split("\0"),
  ].filter(Boolean));
  const state = readState();
  const full = args.includes("--full") || changed.has(".rgignore") || changed.has(".gitignore")
    || [...changed].some(file => file.endsWith(".md") && !fs.existsSync(path.join(root, file)));
  const selected = new Set(core);
  for (const file of visible) {
    if (restricted(file)) { error(`Search exposes restricted Markdown: ${file}`); continue; }
    if (full || changed.has(file)) selected.add(file);
  }
  for (const file of changed) if (taskArtifact(file) && fs.existsSync(path.join(root, file))) selected.add(file);
  if (typeof state?.task?.plan === "string") selected.add(state.task.plan);
  for (const file of [...selected].sort()) {
    if (!safeMarkdown(file)) continue;
    report.checkedFiles.push(file);
    checkLinks(file);
  }
  exitCode = report.errors.length ? 1 : 0;
} catch (cause) {
  error(cause.message);
  exitCode = 2;
}
report.errors = [...new Set(report.errors)];
report.ok = exitCode === 0;
if (args.includes("--json")) console.log(JSON.stringify(report));
else {
  console.log(`Context hygiene ${report.ok ? "passed" : "failed"}: ${report.checkedFiles.length} documents, ${report.errors.length} errors, ${report.warnings.length} warnings.`);
  for (const message of report.errors) console.log(`Error: ${message}`);
  for (const message of report.warnings) console.log(`Warning: ${message}`);
}
process.exitCode = exitCode;
