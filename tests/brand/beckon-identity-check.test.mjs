import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  auditBeckonIdentity,
  isIdentityAuditExcluded,
} from "../../scripts/beckon-identity-check.mjs";

test("identity audit reports every legacy product identity in active files", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "beckon-identity-"));
  fs.mkdirSync(path.join(root, "Sources"), { recursive: true });
  fs.writeFileSync(
    path.join(root, "Sources", "Identity.swift"),
    [
      "let brand = \"Groomly\"",
      "let cache = \"groomly.profile\"",
      "let module = \"PetGroomerMarketplace\"",
      "let customer = \"GTC-001\"",
      "let groomer = \"GTG-001\"",
    ].join("\n")
  );

  const result = auditBeckonIdentity(root, ["Sources/Identity.swift"]);

  assert.deepEqual(
    result.violations.map(({ line, token }) => [line, token]),
    [
      [1, "Groomly"],
      [2, "groomly"],
      [3, "PetGroomerMarketplace"],
      [4, "GTC-###"],
      [5, "GTG-###"],
    ]
  );
});

test("identity audit accepts the canonical Beckon identity", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "beckon-identity-"));
  fs.writeFileSync(
    path.join(root, "Identity.txt"),
    "Beckon BeckonTests BeckonUITests com.hellobeckon.beckon BTC-001 BTG-001"
  );

  assert.deepEqual(
    auditBeckonIdentity(root, ["Identity.txt"]).violations,
    []
  );
});

test("identity audit excludes immutable history but audits active workflow sources", () => {
  const excluded = [
    ".git/logs/HEAD",
    "docs/09_frozen/old.md",
    "supabase/migrations/20260701000000_old.sql",
    "docs/06_tasks/BECKON_BRAND_MIGRATION.md",
    "scripts/beckon-identity-check.mjs",
    "tests/brand/beckon-identity-check.test.mjs",
  ];

  for (const file of excluded) {
    assert.equal(isIdentityAuditExcluded(file), true, file);
  }
  for (const file of [
    "AGENTS.md",
    "CLAUDE.md",
    "docs/05_workflow/TOOLING_POLICY.md",
  ]) {
    assert.equal(isIdentityAuditExcluded(file), false, file);
  }
  assert.equal(isIdentityAuditExcluded("ios/Beckon/BeckonApp.swift"), false);
});
