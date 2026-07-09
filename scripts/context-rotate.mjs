import fs from "node:fs";
import path from "node:path";
import {
  DECISION_LOG_ENTRY_LIMIT,
  TASK_LEDGER_ROW_LIMIT,
  WORKLOG_ENTRY_LIMIT,
} from "./context-hygiene-policy.mjs";

const PROJECT_ROOT = path.resolve(
  process.env.CONTEXT_HYGIENE_PROJECT_ROOT ?? path.resolve(import.meta.dirname, ".."),
);
const APPLY = process.argv.includes("--apply");
const CHECK_DATE_TEXT = process.env.CONTEXT_HYGIENE_NOW ?? new Date().toISOString().slice(0, 10);

function projectPath(filePath) {
  return path.join(PROJECT_ROOT, filePath);
}

function read(filePath) {
  return fs.readFileSync(projectPath(filePath), "utf8");
}

function write(filePath, text) {
  const fullPath = projectPath(filePath);
  fs.mkdirSync(path.dirname(fullPath), { recursive: true });
  fs.writeFileSync(fullPath, text);
}

function taskNumber(taskId) {
  return Number.parseInt(taskId.replace(/^[A-Z]-/, ""), 10);
}

function idRange(ids) {
  const sorted = [...ids].sort((a, b) => taskNumber(a) - taskNumber(b));
  if (sorted.length === 1) {
    return sorted[0];
  }
  return `${sorted[0]}_TO_${sorted.at(-1)}`;
}

function uniqueArchivePath(filePath) {
  if (!fs.existsSync(projectPath(filePath))) {
    return filePath;
  }
  const parsed = path.parse(filePath);
  for (let index = 2; index < 1000; index += 1) {
    const candidate = path.join(parsed.dir, `${parsed.name}_${index}${parsed.ext}`);
    if (!fs.existsSync(projectPath(candidate))) {
      return candidate;
    }
  }
  throw new Error(`Unable to find unused archive path for ${filePath}`);
}

function tableRows(text) {
  return text.split(/\r?\n/).map((line, index) => {
    const match = line.match(/^\| (T-\d{3}) \| [^|]+ \| ([^|]+) \|/);
    if (!match) {
      return null;
    }
    return {
      id: match[1],
      status: match[2].trim().toLowerCase(),
      line,
      index,
    };
  }).filter(Boolean);
}

function rotateTaskLedger() {
  const filePath = "docs/06_tasks/TASK_LEDGER.md";
  const text = read(filePath);
  const lines = text.split(/\r?\n/);
  const rows = tableRows(text);
  const removeCount = Math.max(0, rows.length - TASK_LEDGER_ROW_LIMIT);
  if (removeCount === 0) {
    return [];
  }

  const removable = rows
    .filter((row) => row.status === "completed")
    .sort((a, b) => taskNumber(a.id) - taskNumber(b.id))
    .slice(0, removeCount);
  if (removable.length === 0) {
    return [`TASK_LEDGER.md has ${rows.length} rows, but no completed rows can be rotated.`];
  }

  const removedIndexes = new Set(removable.map((row) => row.index));
  const ids = removable.map((row) => row.id);
  const archivePath = uniqueArchivePath(`docs/09_frozen/task_ledgers/TASK_LEDGER_${idRange(ids)}_${CHECK_DATE_TEXT}.md`);
  const tableHeaderIndex = lines.findIndex((line) => line.startsWith("| ID | Task | Status |"));
  const tableSeparator = tableHeaderIndex >= 0 ? lines[tableHeaderIndex + 1] : "|---|---|---|---|---|---|---|---|";
  const archiveText = [
    "# Archived Task Ledger Rows",
    "",
    `Source: ${filePath}`,
    `Date archived: ${CHECK_DATE_TEXT}`,
    "",
    lines[tableHeaderIndex] ?? "| ID | Task | Status | Mode | Milestone | Files/Docs | Checks | Notes |",
    tableSeparator,
    ...removable.map((row) => row.line),
    "",
  ].join("\n");
  const nextText = lines.filter((_, index) => !removedIndexes.has(index)).join("\n");

  if (APPLY) {
    write(archivePath, archiveText);
    write(filePath, nextText);
  }

  return [`${APPLY ? "Rotated" : "Would rotate"} TASK_LEDGER.md rows ${ids.join(", ")} -> ${archivePath}`];
}

function worklogEntries(text) {
  const entries = [];
  const pattern = /```text\n([\s\S]*?)\n```/g;
  let match;
  while ((match = pattern.exec(text)) !== null) {
    const taskMatch = match[1].match(/^Task:\s*(T-\d{3})/m);
    if (!taskMatch) {
      continue;
    }
    entries.push({
      id: taskMatch[1],
      text: match[0],
      start: match.index,
      end: match.index + match[0].length,
    });
  }
  return entries;
}

function removeRanges(text, ranges) {
  let nextText = text;
  for (const range of [...ranges].sort((a, b) => b.start - a.start)) {
    let start = range.start;
    let end = range.end;
    if (nextText.slice(end, end + 2) === "\n\n") {
      end += 1;
    } else if (start > 0 && nextText.slice(start - 2, start) === "\n\n") {
      start -= 1;
    }
    nextText = `${nextText.slice(0, start)}${nextText.slice(end)}`;
  }
  return nextText;
}

function collapseExcessBlankLines(text) {
  return text.replace(/\n{4,}/g, "\n\n\n");
}

function rotateWorklog() {
  const filePath = "docs/00_memory/WORKLOG.md";
  const text = read(filePath);
  const entries = worklogEntries(text);
  const removeCount = Math.max(0, entries.length - WORKLOG_ENTRY_LIMIT);
  if (removeCount === 0) {
    return [];
  }

  const removable = entries.slice(-removeCount);
  const ids = removable.map((entry) => entry.id);
  const archivePath = uniqueArchivePath(`docs/09_frozen/worklogs/WORKLOG_${CHECK_DATE_TEXT}_${idRange(ids)}.md`);
  const archiveText = [
    "# Archived Worklog Entries",
    "",
    `Source: ${filePath}`,
    `Date archived: ${CHECK_DATE_TEXT}`,
    "",
    ...removable.map((entry) => entry.text),
    "",
  ].join("\n");
  const nextText = removeRanges(text, removable);

  if (APPLY) {
    write(archivePath, archiveText);
    write(filePath, nextText);
  }

  return [`${APPLY ? "Rotated" : "Would rotate"} WORKLOG.md entries ${ids.join(", ")} -> ${archivePath}`];
}

function decisionEntries(text) {
  const entries = [];
  const pattern = /```text\n(Decision ID:\s*D-\d{3}[\s\S]*?)\n```/g;
  let match;
  while ((match = pattern.exec(text)) !== null) {
    const block = match[1];
    const id = block.match(/^Decision ID:\s*(D-\d{3})/m)?.[1];
    const date = block.match(/^Date:\s*(.+)$/m)?.[1]?.trim() ?? "unknown";
    const decision = block.match(/^Decision:\s*(.+)$/m)?.[1]?.trim() ?? id;
    entries.push({
      id,
      date,
      decision,
      text: match[0],
      start: match.index,
      end: match.index + match[0].length,
    });
  }
  return entries;
}

function insertDecisionIndexes(text, rows) {
  const tableMarker = "| Date | Decision | Current entry point |";
  const markerIndex = text.indexOf(tableMarker);
  if (markerIndex < 0) {
    return `${text.trimEnd()}\n\n## Archived Decision Index\n\n${tableMarker}\n|---|---|---|\n${rows.join("\n")}\n`;
  }
  const separatorIndex = text.indexOf("\n", markerIndex);
  const afterSeparatorIndex = text.indexOf("\n", separatorIndex + 1);
  if (afterSeparatorIndex < 0) {
    return `${text.trimEnd()}\n${rows.join("\n")}\n`;
  }
  return `${text.slice(0, afterSeparatorIndex + 1)}${rows.join("\n")}\n${text.slice(afterSeparatorIndex + 1)}`;
}

function rotateDecisionLog() {
  const filePath = "docs/07_decisions/DECISION_LOG.md";
  const text = read(filePath);
  const entries = decisionEntries(text);
  const removeCount = Math.max(0, entries.length - DECISION_LOG_ENTRY_LIMIT);
  if (removeCount === 0) {
    return [];
  }

  const removable = entries.slice(-removeCount);
  const ids = removable.map((entry) => entry.id);
  const archivePath = uniqueArchivePath(`docs/09_frozen/decisions/DECISION_LOG_${idRange(ids)}_${CHECK_DATE_TEXT}.md`);
  const activePointer = `../${archivePath.replace(/^docs\//, "")}`;
  const archiveText = [
    "# Archived Decision Log Entries",
    "",
    `Source: ${filePath}`,
    `Date archived: ${CHECK_DATE_TEXT}`,
    "",
    ...removable.map((entry) => entry.text),
    "",
  ].join("\n");
  const indexRows = removable.map((entry) => `| ${entry.date} | ${entry.decision} | \`${activePointer}\` |`);
  const withoutEntries = removeRanges(text, removable);
  const nextText = collapseExcessBlankLines(insertDecisionIndexes(withoutEntries, indexRows));

  if (APPLY) {
    write(archivePath, archiveText);
    write(filePath, nextText);
  }

  return [`${APPLY ? "Rotated" : "Would rotate"} DECISION_LOG.md entries ${ids.join(", ")} -> ${archivePath}`];
}

const messages = [
  ...rotateTaskLedger(),
  ...rotateWorklog(),
  ...rotateDecisionLog(),
];

if (messages.length === 0) {
  console.log("No context rotation needed.");
} else {
  for (const message of messages) {
    console.log(message);
  }
  if (!APPLY) {
    console.log("Dry run only. Re-run with --apply to write archive files and update active windows.");
  }
}
