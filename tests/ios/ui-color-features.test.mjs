import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const root = new URL("../../ios/Beckon/Beckon/", import.meta.url);
const files = ["Features", "SharedFeatures"].flatMap(dir =>
  readdirSync(new URL(dir + "/", root), { recursive: true })
    .filter(path => path.endsWith(".swift")).map(path => dir + "/" + path));
const sources = files.map(path => [path, readFileSync(new URL(path, root), "utf8")]);

test("Feature colors use opaque semantic surfaces and readable foregrounds", () => {
  const violations = sources.flatMap(([path, source]) => {
    const prohibited = /Colors\.\w+\.opacity\(|(?:foregroundStyle|foregroundColor|tint)\(\s*DesignTokens\.Colors\.(?:customerFill|groomerFill|customerAccent|groomerAccent|success|warning|error)\b/g;
    return [...source.matchAll(prohibited)].map(match => path + ": " + match[0]);
  });
  assert.deepEqual(violations, []);
});

test("domain status chips use shared presentations, not local role mappings", () => {
  const violations = sources.filter(([path]) => path.startsWith("Features/")).flatMap(([path, source]) =>
    [...source.matchAll(/BeckonStatusChip\([\s\S]*?\)/g)]
      .filter(match => /\btone:/.test(match[0])).map(() => path));
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
