#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const LEGACY_PATTERNS = [
  { pattern: /Groomly/g, token: "Groomly" },
  { pattern: /groomly/g, token: "groomly" },
  { pattern: /PetGroomerMarketplace/g, token: "PetGroomerMarketplace" },
  { pattern: /GTC-\d{3}/g, token: "GTC-###" },
  { pattern: /GTG-\d{3}/g, token: "GTG-###" },
];

const EXACT_EXCLUSIONS = new Set([
  "scripts/beckon-identity-check.mjs",
  "scripts/seed-identity-cutover-core.mjs",
  "tests/brand/beckon-identity-check.test.mjs",
  "tests/testops/seed-identity-cutover.test.mjs",
]);

const PREFIX_EXCLUSIONS = [
  ".git/",
  "artifacts/",
  "docs/09_frozen/",
  "supabase/migrations/",
];

export function isIdentityAuditExcluded(relativePath) {
  const normalized = relativePath.split(path.sep).join("/");
  return EXACT_EXCLUSIONS.has(normalized)
    || PREFIX_EXCLUSIONS.some((prefix) => normalized.startsWith(prefix));
}

function repositoryFiles(root) {
  return execFileSync(
    "git",
    ["ls-files", "--cached", "--others", "--exclude-standard", "-z"],
    { cwd: root, encoding: "utf8" }
  )
    .split("\0")
    .filter(Boolean);
}

export function auditBeckonIdentity(root, relativePaths = repositoryFiles(root)) {
  const violations = [];

  for (const relativePath of relativePaths.sort()) {
    if (isIdentityAuditExcluded(relativePath)) continue;

    const absolutePath = path.join(root, relativePath);
    if (!fs.existsSync(absolutePath) || !fs.statSync(absolutePath).isFile()) continue;

    const content = fs.readFileSync(absolutePath);
    if (content.includes(0)) continue;

    const lines = content.toString("utf8").split("\n");
    lines.forEach((lineText, index) => {
      const lineMatches = [];
      for (const { pattern, token } of LEGACY_PATTERNS) {
        pattern.lastIndex = 0;
        for (const match of lineText.matchAll(pattern)) {
          lineMatches.push({ column: match.index ?? 0, token });
        }
      }
      lineMatches
        .sort((left, right) => left.column - right.column)
        .forEach(({ token }) => {
          violations.push({
            path: relativePath.split(path.sep).join("/"),
            line: index + 1,
            token,
          });
        });
    });
  }

  return { violations };
}

function main() {
  const root = path.resolve(import.meta.dirname, "..");
  const { violations } = auditBeckonIdentity(root);

  if (violations.length === 0) {
    console.log("Beckon identity check passed.");
    return;
  }

  console.error(`Beckon identity check failed with ${violations.length} violation(s):`);
  for (const violation of violations) {
    console.error(`${violation.path}:${violation.line}: ${violation.token}`);
  }
  process.exitCode = 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
