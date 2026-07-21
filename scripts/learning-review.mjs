#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { buildLearningReview } from "./learning-review-core.mjs";

function usage() {
  return [
    "Usage: node scripts/learning-review.mjs [--input <path> ...] [--output <path>] [--title <text>]",
    "",
    "Creates a human-reviewed draft of preference and skill candidates from transcript-like text.",
    "If no --input is provided, reads from stdin.",
  ].join("\n");
}

function parseArgs(argv) {
  const args = { inputs: [], output: null, title: "Manual Learning Review" };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--help" || arg === "-h") {
      args.help = true;
    } else if (arg === "--input") {
      args.inputs.push(argv[++index]);
    } else if (arg === "--output") {
      args.output = argv[++index];
    } else if (arg === "--title") {
      args.title = argv[++index];
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

function readStdin() {
  return fs.readFileSync(0, "utf8");
}

function readSources(inputs) {
  if (inputs.length === 0) {
    return [{ path: "<stdin>", text: readStdin() }];
  }
  return inputs.map((inputPath) => ({
    path: inputPath,
    text: fs.readFileSync(inputPath, "utf8"),
  }));
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return;
  }

  const review = buildLearningReview({
    title: args.title,
    sources: readSources(args.inputs),
  });

  if (args.output) {
    fs.mkdirSync(path.dirname(args.output), { recursive: true });
    fs.writeFileSync(args.output, review);
    console.log(`Wrote ${args.output}`);
    return;
  }

  process.stdout.write(review);
}

try {
  main();
} catch (error) {
  console.error(error.message);
  console.error("");
  console.error(usage());
  process.exit(2);
}
