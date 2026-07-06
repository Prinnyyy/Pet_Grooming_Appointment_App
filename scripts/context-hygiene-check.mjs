#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const failures = [];

const budgets = new Map([
  ["AGENTS.md", 1000],
  ["docs/00_memory/CURRENT_STATE.md", 1200],
  ["docs/00_memory/WORKLOG.md", 2500],
  ["docs/00_memory/FEATURE_INDEX.md", 1200],
  ["docs/00_memory/PROJECT_MEMORY.md", 700],
  ["docs/06_tasks/TASK_LEDGER.md", 1800],
]);

const requiredRgignore = [
  "docs/09_frozen/**",
  "artifacts/**",
  "supabase/.temp/**",
  "supabase_environment_variables",
];

function rel(file) {
  return path.relative(root, file).split(path.sep).join("/");
}

function exists(relativePath) {
  return fs.existsSync(path.join(root, relativePath));
}

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function words(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

function walk(dir, files = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    const relative = rel(full);
    if (entry.isDirectory()) {
      if (
        relative === ".git" ||
        relative === "docs/09_frozen" ||
        relative.startsWith("docs/09_frozen/") ||
        relative === "artifacts" ||
        relative.startsWith("artifacts/") ||
        relative === "supabase/.temp" ||
        relative.startsWith("supabase/.temp/")
      ) {
        continue;
      }
      walk(full, files);
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(full);
    }
  }
  return files;
}

for (const [file, maxWords] of budgets.entries()) {
  if (!exists(file)) {
    failures.push(`Missing budgeted file: ${file}`);
    continue;
  }
  const count = words(read(file));
  if (count > maxWords) {
    failures.push(`${file} has ${count} words; budget is ${maxWords}`);
  }
}

if (!exists(".rgignore")) {
  failures.push("Missing .rgignore");
} else {
  const rgignore = read(".rgignore");
  for (const line of requiredRgignore) {
    if (!rgignore.includes(line)) {
      failures.push(`.rgignore missing ${line}`);
    }
  }
}

const activeMarkdown = walk(root);
for (const file of activeMarkdown) {
  const relativeFile = rel(file);
  const text = fs.readFileSync(file, "utf8");
  if (/Fresh Brief is canonical|Fresh_Pet_Groomer_Marketplace_Engineering_Brief\.md is the product/.test(text)) {
    failures.push(`${relativeFile} still treats the Fresh Brief as active canonical context`);
  }
  if (/docs\/06_tasks\/T-\d{3}/.test(text)) {
    failures.push(`${relativeFile} links directly to archived task records under docs/06_tasks`);
  }

  const linkPattern = /\[[^\]]+\]\(([^)]+)\)/g;
  for (const match of text.matchAll(linkPattern)) {
    let target = match[1].trim();
    if (!target || target.startsWith("#") || /^[a-z][a-z0-9+.-]*:/i.test(target)) {
      continue;
    }
    target = target.replace(/^<|>$/g, "").split("#")[0];
    if (!target) {
      continue;
    }
    const decoded = decodeURI(target);
    const resolved = path.resolve(path.dirname(file), decoded);
    if (!resolved.startsWith(root)) {
      failures.push(`${relativeFile} has out-of-root link: ${match[1]}`);
      continue;
    }
    if (!fs.existsSync(resolved)) {
      failures.push(`${relativeFile} has missing local link: ${match[1]}`);
    }
  }
}

if (failures.length > 0) {
  console.error("Context hygiene check failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Context hygiene check passed for ${activeMarkdown.length} active Markdown files.`);
