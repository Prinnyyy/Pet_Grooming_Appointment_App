import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const root = new URL("../../ios/Beckon/Beckon/", import.meta.url);
const paths = readdirSync(root, { recursive: true }).filter((path) => path.endsWith(".swift"));
const read = (path) => readFileSync(new URL(path, root), "utf8");
const prototypePaths = paths.filter((path) => path.startsWith("FlowSandbox/Prototype/"));
test("prototype UI is DEBUG-only and no production caller depends on it", () => {
  for (const path of prototypePaths) {
    const source = read(path).trim();
    assert.ok(source.startsWith("#if DEBUG"), path);
    assert.ok(source.endsWith("#endif"), path);
    assert.doesNotMatch(source, /\b(?:SupabaseClient|AppComposition|Keychain)\b|UserDefaults\.standard/, path);
  }
  for (const path of paths.filter((path) => !path.startsWith("FlowSandbox/") && !path.includes("FlowSandbox.swift"))) {
    assert.doesNotMatch(read(path), /\bPrototype(?:Customer|Beckon|Booking|Chat|DesignTokens|Authentication)\w*/, path);
  }
});

test("adopted sandbox hosts real views with local dependencies", () => {
  const hosts = paths.filter((path) => path.startsWith("FlowSandbox/Customer/") || path.endsWith("FlowSandbox.swift"));
  for (const path of hosts) {
    const source = read(path).trim();
    assert.ok(source.startsWith("#if DEBUG"), path);
    assert.ok(source.endsWith("#endif"), path);
    assert.doesNotMatch(source, /\bPrototype[A-Z]\w*|\b(?:SupabaseClient|AppComposition|Keychain)\b|UserDefaults\.standard/, path);
  }
  const host = read("FlowSandbox/Customer/CustomerFlowSandbox.swift");
  assert.match(host, /CustomerTabView\(sandbox: session\)/);
  assert.match(host, /CustomerHomeView\(sandbox: session/);
  assert.match(host, /CustomerFavoriteGroomersView\(marketplace: session.marketplace\)/);
  assert.doesNotMatch(host, /sandbox.variant|CustomerGroomerListView|CustomerRequestProgressView/);
  assert.doesNotMatch(read("FlowSandbox/Customer/CustomerSandboxSession.swift"), /feedback.showNotice\("Preview only/);
});
