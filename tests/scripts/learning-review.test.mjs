import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import {
  buildLearningReview,
  extractLearningCandidates,
} from "../../scripts/learning-review-core.mjs";

const projectRoot = process.cwd();
const cliPath = path.join(projectRoot, "scripts/learning-review.mjs");

test("extracts preference and skill candidates from review text", () => {
  const source = [
    "User: 不要在没有明确授权时修改 Supabase 远程状态。",
    "Assistant: Next time, when editing workflow docs, run context hygiene before final response.",
    "User: I prefer concise closeout notes with validation first.",
    "Task: T-356",
    "Result: Added a manual learning review script.",
  ].join("\n");

  const candidates = extractLearningCandidates([{ path: "transcript.md", text: source }]);

  assert.deepEqual(candidates.map((candidate) => candidate.type), [
    "preference",
    "skill",
    "preference",
  ]);
  assert.equal(candidates[0].source.path, "transcript.md");
  assert.equal(candidates[0].source.line, 1);
  assert.match(candidates[0].statement, /不要在没有明确授权时修改 Supabase 远程状态/);
  assert.match(candidates[1].statement, /when editing workflow docs/i);
  assert.match(candidates[2].statement, /concise closeout notes/i);
});

test("deduplicates repeated candidate statements case-insensitively", () => {
  const source = [
    "User: Always run context hygiene after durable memory changes.",
    "User: always run context hygiene after durable memory changes.",
  ].join("\n");

  const candidates = extractLearningCandidates([{ path: "repeat.md", text: source }]);

  assert.equal(candidates.length, 1);
  assert.deepEqual(candidates[0].evidence, [
    { path: "repeat.md", line: 1 },
    { path: "repeat.md", line: 2 },
  ]);
});

test("builds a review report with promotion checklist", () => {
  const review = buildLearningReview({
    title: "T-356 Manual Learning Review",
    sources: [{
      path: "fixture.md",
      text: "User: Please avoid adding dependencies for one-off scripts.",
    }],
  });

  assert.match(review, /^# T-356 Manual Learning Review/);
  assert.match(review, /## Preference Candidates/);
  assert.match(review, /avoid adding dependencies/);
  assert.match(review, /## Promotion Checklist/);
  assert.match(review, /Do not promote secrets/);
});

test("CLI writes a review report from input files", () => {
  const root = mkdtempSync(path.join(tmpdir(), "learning-review-"));
  const inputPath = path.join(root, "session.md");
  const outputPath = path.join(root, "review.md");
  writeFileSync(inputPath, "User: Always keep SwiftUI business logic out of views.\n");

  const result = spawnSync("node", [
    cliPath,
    "--input", inputPath,
    "--output", outputPath,
    "--title", "Fixture Review",
  ], { cwd: projectRoot, encoding: "utf8" });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Wrote/);
  const report = readFileSync(outputPath, "utf8");
  assert.match(report, /^# Fixture Review/);
  assert.match(report, /Always keep SwiftUI business logic out of views/);
  assert.match(report, new RegExp(inputPath.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
});
