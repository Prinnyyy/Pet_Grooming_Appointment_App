import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";
import { auditSwiftSource } from "../../scripts/ui-consistency-audit-core.mjs";

const root = new URL("../../ios/Beckon/Beckon/", import.meta.url);
const files = ["Features", "SharedFeatures"].flatMap(dir =>
  readdirSync(new URL(dir + "/", root), { recursive: true })
    .filter(path => path.endsWith(".swift")).map(path => dir + "/" + path));
const sources = files.map(path => [path, readFileSync(new URL(path, root), "utf8")]);

test("Feature colors use opaque semantic surfaces and readable foregrounds", () => {
  const violations = sources.flatMap(([path, source]) => auditSwiftSource({ filePath: path, source })
    .filter(f => ["UI012", "UI013"].includes(f.ruleID)));
  assert.deepEqual(violations, []);
});

test("domain status chips use shared presentations, not local role mappings", () => {
  const violations = sources.filter(([path]) => path.startsWith("Features/")).flatMap(([path, source]) =>
    auditSwiftSource({ filePath: path, source }).filter(f => f.ruleID === "UI014"));
  assert.deepEqual(violations, []);
});

test("transitional role and status color names have been removed", () => {
  const tokens = readFileSync(new URL("DesignSystem/DesignTokens.swift", root), "utf8");
  assert.doesNotMatch(tokens, /static let (?:customerAccent\w*|customerPrimary\w*|customerOnAccent|groomerAccent\w*|groomerOnAccent|notificationUnread|success|warning|error)\b/);
});

test("inline errors share an icon and opaque semantic container", () => {
  const feedback = readFileSync(new URL("DesignSystem/BeckonFeedbackPrimitives.swift", root), "utf8");
  const inline = feedback.split("struct BeckonInlineError: View {")[1].split("struct BeckonErrorBanner")[0];
  assert.match(inline, /Label\(message, systemImage: "exclamationmark.triangle"\)/);
  assert.match(inline, /Colors.statusErrorFill/);
  assert.match(inline, /Colors.statusErrorText/);
});
