#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import {
  auditSwiftSource,
  compareWithBaseline,
  fingerprintFinding,
  UI_RULES,
} from "./ui-consistency-audit-core.mjs";

const scope = "ios/Beckon/Beckon/Features";
const baselinePath = "scripts/ui-consistency-baseline.json";

function failConfig(message) {
  process.stderr.write(`UI consistency audit configuration error: ${message}\n`);
  process.exit(2);
}

function option(args, name) {
  const index = args.indexOf(name);
  if (index < 0 || !args[index + 1] || args[index + 1].startsWith("--")) return undefined;
  return args[index + 1];
}

function normalizePath(filePath) {
  return filePath.replaceAll("\\", "/").replace(/^\.\//, "");
}

function trackedSwiftPaths() {
  try {
    const output = execFileSync(
      "git",
      ["ls-files", "--cached", "--others", "--exclude-standard", "--", `${scope}/**/*.swift`],
      { encoding: "utf8" }
    );
    return output.split("\n").map(normalizePath).filter(Boolean).sort();
  } catch (error) {
    failConfig(`cannot enumerate Swift sources: ${error.message}`);
  }
}

function scan(paths = trackedSwiftPaths()) {
  return paths.flatMap((filePath) => {
    if (!existsSync(filePath)) failConfig(`Swift source does not exist: ${filePath}`);
    return auditSwiftSource({ filePath, source: readFileSync(filePath, "utf8") });
  });
}

function readBaseline() {
  if (!existsSync(baselinePath)) failConfig(`${baselinePath} does not exist; initialize it explicitly`);
  try {
    const baseline = JSON.parse(readFileSync(baselinePath, "utf8"));
    if (baseline.version !== 1 || baseline.scope !== scope || !Array.isArray(baseline.findings)) {
      failConfig(`${baselinePath} has an unsupported shape`);
    }
    return baseline;
  } catch (error) {
    failConfig(`cannot read ${baselinePath}: ${error.message}`);
  }
}

function baselineFinding(finding) {
  return {
    ruleID: finding.ruleID,
    path: finding.path,
    fingerprint: finding.fingerprint,
    expressionHash: finding.expressionHash,
    occurrence: finding.occurrence,
  };
}

function writeBaseline(baseline) {
  writeFileSync(baselinePath, `${JSON.stringify(baseline, null, 2)}\n`);
}

function printFinding(finding) {
  const replacement = finding.replacement ? ` [${finding.replacement}]` : "";
  process.stdout.write(`${finding.path}:${finding.line ?? 1}:${finding.column ?? 1}: ${finding.severity} ${finding.ruleID} ${finding.message ?? "Baseline finding changed."}${replacement}\n`);
}

function printJSON(payload) {
  process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
}

function summary(findings) {
  const counts = new Map(UI_RULES.map(({ id }) => [id, 0]));
  for (const finding of findings) counts.set(finding.ruleID, (counts.get(finding.ruleID) ?? 0) + 1);
  return Object.fromEntries([...counts].filter(([, count]) => count > 0));
}

function runCheck(args) {
  const findings = scan();
  const baseline = readBaseline();
  const result = compareWithBaseline(findings, baseline, []);
  const formatJSON = option(args, "--format") === "json";
  if (formatJSON) {
    printJSON({ counts: summary(findings), ...result });
  } else if (result.newErrors.length || result.staleEntries.length) {
    result.newErrors.forEach(printFinding);
    for (const finding of result.staleEntries) {
      process.stdout.write(`${finding.path}:1:1: error ${finding.ruleID} Stale baseline entry; prune resolved debt explicitly.\n`);
    }
  } else {
    process.stdout.write(`UI consistency audit passed (${findings.length} current findings; ${baseline.findings.length} baselined: ${JSON.stringify(summary(findings))}).\n`);
  }
  process.exit(result.newErrors.length || result.staleEntries.length ? 1 : 0);
}

function runStrict(args) {
  const paths = args.filter((value, index) => !value.startsWith("--") && args[index - 1] !== "--format").map(normalizePath);
  if (!paths.length) failConfig("strict requires at least one Swift path");
  for (const filePath of paths) {
    if (!filePath.startsWith(`${scope}/`) || !filePath.endsWith(".swift")) failConfig(`strict path is outside ${scope}: ${filePath}`);
  }
  const findings = scan(paths);
  const baseline = readBaseline();
  const result = compareWithBaseline(findings, baseline, paths);
  if (option(args, "--format") === "json") printJSON(result);
  else if (result.strictFindings.length) result.strictFindings.forEach(printFinding);
  else process.stdout.write(`UI consistency strict audit passed for ${paths.length} path(s).\n`);
  process.exit(result.strictFindings.length ? 1 : 0);
}

function requireReason(args) {
  const reason = option(args, "--reason");
  if (!reason?.trim()) failConfig("baseline changes require --reason");
  return reason.trim();
}

function initialize(args) {
  const reason = requireReason(args);
  if (existsSync(baselinePath)) failConfig(`${baselinePath} already exists; initialize never overwrites`);
  const findings = scan();
  writeBaseline({ version: 1, scope, lastChange: { reason }, findings: findings.map(baselineFinding) });
  process.stdout.write(`Initialized UI consistency baseline with ${findings.length} findings.\n`);
}

function prune(args) {
  const reason = requireReason(args);
  const findings = scan();
  const baseline = readBaseline();
  const result = compareWithBaseline(findings, baseline, []);
  if (result.newErrors.length) failConfig("prune cannot accept new error findings; resolve them first");
  const stale = new Set(result.staleEntries.map((finding) => finding.fingerprint));
  baseline.findings = baseline.findings.filter((finding) => !stale.has(finding.fingerprint));
  baseline.lastChange = { reason };
  writeBaseline(baseline);
  process.stdout.write(`Pruned ${stale.size} stale UI consistency baseline entries.\n`);
}

function relocate(args) {
  const reason = requireReason(args);
  const from = normalizePath(option(args, "--from") ?? "");
  const to = normalizePath(option(args, "--to") ?? "");
  if (!from || !to || from === to) failConfig("relocate requires distinct --from and --to paths");
  const baseline = readBaseline();
  const sourceEntries = baseline.findings.filter((finding) => finding.path === from);
  if (!sourceEntries.length) failConfig(`no baseline findings exist at ${from}`);
  const currentSourceFindings = scan([from]);
  const destinationFindings = scan([to]);
  const key = (finding) => `${finding.ruleID}\0${finding.expressionHash}\0${finding.occurrence}`;
  const sourceByKey = new Map(currentSourceFindings.map((finding) => [key(finding), finding]));
  const destinationByKey = new Map(destinationFindings.map((finding) => [key(finding), finding]));
  const baselineSourceByKey = new Map(sourceEntries.map((finding) => [key(finding), finding]));
  const baselineDestinationByKey = new Map(
    baseline.findings
      .filter((finding) => finding.path === to)
      .map((finding) => [key(finding), finding])
  );
  const movedKeys = new Set();

  for (const finding of sourceEntries) {
    const findingKey = key(finding);
    const remainsAtSource = sourceByKey.has(findingKey);
    const appearsAtDestination = destinationByKey.has(findingKey);
    if (remainsAtSource === appearsAtDestination) {
      failConfig("relocate requires each source finding to remain or move exactly once without ambiguity");
    }
    if (appearsAtDestination) movedKeys.add(findingKey);
  }
  if (!movedKeys.size) failConfig("relocate found no unchanged findings at the destination");
  if (currentSourceFindings.some((finding) => !baselineSourceByKey.has(key(finding)))) {
    failConfig("relocate cannot accept new findings at the source");
  }
  if (destinationFindings.some((finding) => {
    const findingKey = key(finding);
    return !movedKeys.has(findingKey) && !baselineDestinationByKey.has(findingKey);
  })) {
    failConfig("relocate cannot accept new or changed findings at the destination");
  }
  baseline.findings = baseline.findings.map((finding) => {
    if (finding.path !== from || !movedKeys.has(key(finding))) return finding;
    const moved = { ...finding, path: to };
    moved.fingerprint = fingerprintFinding(moved);
    return moved;
  });
  baseline.lastChange = { reason };
  writeBaseline(baseline);
  process.stdout.write(`Relocated ${movedKeys.size} UI consistency baseline entries.\n`);
}

const [command, subcommand, ...rest] = process.argv.slice(2);
if (command === "check") runCheck([subcommand, ...rest].filter(Boolean));
else if (command === "strict") runStrict([subcommand, ...rest].filter(Boolean));
else if (command === "baseline" && subcommand === "initialize") initialize(rest);
else if (command === "baseline" && subcommand === "prune") prune(rest);
else if (command === "baseline" && subcommand === "relocate") relocate(rest);
else failConfig("use check, strict <paths>, baseline initialize, baseline prune, or baseline relocate");
