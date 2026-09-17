import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import {
  auditSwiftSource,
  compareWithBaseline,
  maskSwiftNonCode,
} from "../../scripts/ui-consistency-audit-core.mjs";

const projectRoot = process.cwd();
const cliPath = path.join(projectRoot, "scripts/ui-consistency-audit.mjs");

test("lexer masks comments and strings while preserving positions", () => {
  const source = [
    "Text(\".font(.system(size: 99))\")",
    "// .padding(91)",
    "/* outer /* .cornerRadius(77) */ nested */",
    "Text(title).font(.system(size: 28, weight: .bold))",
  ].join("\n");
  const masked = maskSwiftNonCode(source);
  assert.equal(masked.length, source.length);
  assert.equal(masked.split("\n").length, 4);
  assert.doesNotMatch(masked, /size: 99|padding\(91|cornerRadius\(77/);
  assert.match(masked, /system\(size:\s*28/);
});

test("lexer masks multiline strings and escaped quotes", () => {
  const source = [
    "let sample = \"\"\"",
    ".padding(99)",
    "\"\"\"",
    "let escaped = \"\\\".offset(x: -9)\"",
    "Text(title).padding(13)",
  ].join("\n");
  const masked = maskSwiftNonCode(source);
  assert.equal(masked.length, source.length);
  assert.doesNotMatch(masked, /padding\(99|offset\(x: -9/);
  assert.match(masked, /padding\(13/);
});

test("lexer preserves UTF-16 positions after emoji strings", () => {
  const source = [
    "let icon = \"🐾\"",
    "Text(title).font(.system(size: 28, weight: .bold))",
  ].join("\n");
  const masked = maskSwiftNonCode(source);
  assert.equal(masked.length, source.length);
  const findings = auditSwiftSource({ filePath: "Emoji.swift", source });
  assert.equal(findings[0].expression, ".font(.system(size: 28, weight: .bold))");
});

test("audit classifies deterministic and review findings", () => {
  const findings = auditSwiftSource({
    filePath: "ios/Beckon/Beckon/Features/ExampleView.swift",
    source: "Text(title).font(.system(size: 28)).padding(13).offset(x: -2)",
  });
  assert.deepEqual(findings.map((finding) => finding.ruleID), [
    "UI001", "UI004", "UI102",
  ]);
  assert.deepEqual(findings.map((finding) => finding.severity), [
    "error", "error", "warning",
  ]);
});

test("audit detects governed visual patterns with balanced calls", () => {
  const source = [
    "Text(title).font(.headline)",
    "Text(title).foregroundStyle(Color(red: 0.2, green: 0.3, blue: 0.4))",
    "RoundedRectangle(cornerRadius: 17)",
    ".shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)",
    "private struct LocalButtonStyle: ButtonStyle {}",
    "Text(title).minimumScaleFactor(0.7)",
    "Text(title).frame(height: 20)",
  ].join("\n");
  const findings = auditSwiftSource({ filePath: "Feature.swift", source });
  assert.deepEqual(findings.map(({ ruleID }) => ruleID), [
    "UI002", "UI003", "UI005", "UI006", "UI007", "UI008", "UI101",
  ]);
  assert.match(findings[1].expression, /Color\(red:.*blue: 0\.4\)/);
});

test("audit marks only repeated three-modifier visual stacks for review", () => {
  const source = [
    "Text(first).font(DesignTokens.Typography.body).padding(DesignTokens.Spacing.small).background(DesignTokens.Colors.surface)",
    "Text(second).font(DesignTokens.Typography.body).padding(DesignTokens.Spacing.small).background(DesignTokens.Colors.surface)",
  ].join("\n");
  const findings = auditSwiftSource({ filePath: "Repeated.swift", source });
  assert.deepEqual(findings.map(({ ruleID }) => ruleID), ["UI201"]);
  assert.equal(findings[0].severity, "review");
  assert.equal(findings[0].line, 2);
});

test("semantic components are clean audit replacements", () => {
  const source = [
    "BeckonSection(\"Pets\") { BeckonGroupedSurface { content } }",
    "BeckonSelectionCard(isSelected: true, accent: .customer, action: {}) { content }",
    "BeckonFieldGroup(\"Name\") { field }",
    "BeckonSettingsRowLabel(title: \"Profile\", summary: nil, systemImage: \"person\", accent: .customer)",
    "content.beckonPageInsets()",
  ].join("\n");
  assert.deepEqual(auditSwiftSource({ filePath: "SemanticFeature.swift", source }), []);
});

test("feature audit blocks local keyboard layout policy", () => {
  const source = [
    "content.ignoresSafeArea(.keyboard, edges: .bottom)",
    "content.padding(.bottom, keyboardOverlap)",
    "NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)",
  ].join("\n");
  const findings = auditSwiftSource({ filePath: "ios/Beckon/Beckon/Features/Form.swift", source });
  assert.deepEqual(findings.map(({ ruleID }) => ruleID), ["UI009", "UI010", "UI011"]);
  assert.ok(findings.every(({ severity }) => severity === "error"));
});

test("single-site fixed geometry exception requires the exact directive and reason", () => {
  const allowed = [
    "// beckon-ui-audit: allow UI101 -- Fixed square media crop; text is outside this frame.",
    "Image(uiImage: image).frame(width: 80, height: 80)",
  ].join("\n");
  assert.deepEqual(auditSwiftSource({ filePath: "Allowed.swift", source: allowed }), []);

  const wildcard = [
    "// beckon-ui-audit: allow * -- Fixed square media crop; text is outside this frame.",
    "Image(uiImage: image).frame(width: 80, height: 80)",
  ].join("\n");
  assert.equal(auditSwiftSource({ filePath: "Wildcard.swift", source: wildcard }).length, 1);

  const separated = [
    "// beckon-ui-audit: allow UI101 -- Fixed square media crop; text is outside this frame.",
    "let isDecorative = false",
    "Image(uiImage: image).frame(width: 80, height: 80)",
  ].join("\n");
  assert.equal(auditSwiftSource({ filePath: "Separated.swift", source: separated }).length, 1);
});

test("baseline rejects new errors and stale debt", () => {
  const existing = {
    version: 1,
    scope: "ios/Beckon/Beckon/Features",
    findings: [{
      ruleID: "UI001",
      path: "A.swift",
      fingerprint: "a",
      expressionHash: "same-expression",
      occurrence: 1,
    }],
  };
  const result = compareWithBaseline([
    { ruleID: "UI004", path: "B.swift", fingerprint: "b", occurrence: 1, severity: "error" },
  ], existing, []);
  assert.equal(result.newErrors.length, 1);
  assert.equal(result.staleEntries.length, 1);
});

test("strict paths reject baselined errors", () => {
  const finding = {
    ruleID: "UI001", path: "A.swift", fingerprint: "a", occurrence: 1, severity: "error",
  };
  const baseline = { version: 1, scope: "Features", findings: [{ ...finding }] };
  const result = compareWithBaseline([finding], baseline, ["A.swift"]);
  assert.equal(result.newErrors.length, 0);
  assert.deepEqual(result.strictFindings, [finding]);
});

test("CLI initialize refuses to overwrite an existing baseline", () => {
  const root = mkdtempSync(path.join(tmpdir(), "ui-audit-cli-"));
  mkdirSync(path.join(root, "scripts"), { recursive: true });
  mkdirSync(path.join(root, "ios/Beckon/Beckon/Features"), { recursive: true });
  writeFileSync(path.join(root, "ios/Beckon/Beckon/Features/Clean.swift"), "Text(title)\n");
  const baselinePath = path.join(root, "scripts/ui-consistency-baseline.json");
  writeFileSync(baselinePath, JSON.stringify({ version: 1, scope: "Features", findings: [] }));

  const result = spawnSync("node", [cliPath, "baseline", "initialize", "--reason", "Q-113"], {
    cwd: root,
    encoding: "utf8",
  });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /already exists/);
  assert.equal(JSON.parse(readFileSync(baselinePath, "utf8")).scope, "Features");
});

test("CLI relocate moves an unchanged subset and retains source findings", () => {
  const root = mkdtempSync(path.join(tmpdir(), "ui-audit-relocate-"));
  const sourcePath = "ios/Beckon/Beckon/Features/Source.swift";
  const destinationPath = "ios/Beckon/Beckon/Features/Destination.swift";
  const originalSource = [
    "Text(home).font(.system(size: 28))",
    "Text(form).padding(13)",
  ].join("\n");
  const baselineFindings = auditSwiftSource({ filePath: sourcePath, source: originalSource });

  mkdirSync(path.join(root, "scripts"), { recursive: true });
  mkdirSync(path.join(root, "ios/Beckon/Beckon/Features"), { recursive: true });
  writeFileSync(path.join(root, sourcePath), "Text(home).font(.system(size: 28))\n");
  writeFileSync(path.join(root, destinationPath), "Text(form).padding(13)\n");
  writeFileSync(path.join(root, "scripts/ui-consistency-baseline.json"), JSON.stringify({
    version: 1,
    scope: "ios/Beckon/Beckon/Features",
    lastChange: { reason: "fixture" },
    findings: baselineFindings.map(({ ruleID, path: findingPath, fingerprint, expressionHash, occurrence }) => ({
      ruleID,
      path: findingPath,
      fingerprint,
      expressionHash,
      occurrence,
    })),
  }));

  const result = spawnSync("node", [
    cliPath,
    "baseline", "relocate",
    "--from", sourcePath,
    "--to", destinationPath,
    "--reason", "Q-116",
  ], { cwd: root, encoding: "utf8" });

  assert.equal(result.status, 0, result.stderr);
  const updated = JSON.parse(readFileSync(path.join(root, "scripts/ui-consistency-baseline.json"), "utf8"));
  assert.deepEqual(updated.findings.map(({ ruleID, path: findingPath }) => [ruleID, findingPath]), [
    ["UI001", sourcePath],
    ["UI004", destinationPath],
  ]);
});
