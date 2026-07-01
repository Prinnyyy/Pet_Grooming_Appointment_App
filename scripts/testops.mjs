#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

import {
  ARTIFACT_DIR,
  CUSTOMER_RESOURCE,
  DEFAULT_SCENARIO,
  GROOMER_RESOURCE,
  PROJECT_ROOT,
  REMOTE_WRITE_ENV,
  SERVICE_ROLE_KEY_ENV,
  SupabaseREST,
  buildCleanupPlan,
  cleanupRun,
  envStatus,
  makeBackendPlans,
  parseCustomerProfiles,
  parseGroomerProfiles,
  parseOptions,
  redactedPlan,
  redactedResult,
  relative,
  renderReport,
  requireRemoteWriteApproval,
  requiredEnv,
  requiredOption,
  runMarketplaceLifecycle,
  safeErrorMessage,
  writeArtifacts,
} from "./testops-core.mjs";

const [, , command, ...rawArgs] = process.argv;

main().catch((error) => {
  console.error(`TestOps failed: ${safeErrorMessage(error)}`);
  process.exitCode = 1;
});

async function main() {
  switch (command) {
    case "doctor":
      return doctor(rawArgs);
    case "run":
      return run(rawArgs);
    case "cleanup":
      return cleanupCommand(rawArgs);
    case "report":
      return reportCommand(rawArgs);
    case "help":
    case undefined:
      return usage();
    default:
      throw new Error(`Unknown command: ${command}`);
  }
}

function usage() {
  console.log(`Usage:
  node scripts/testops.mjs doctor [--dry-run]
  node scripts/testops.mjs run backend --scenario ${DEFAULT_SCENARIO} [--customer GTC-001] [--groomer GTG-001] [--matrix smoke5] [--run-id RUN] [--execute] [--cleanup]
  node scripts/testops.mjs cleanup --run-id RUN [--execute]
  node scripts/testops.mjs report --run-id RUN

Remote-write safety:
  Backend run and cleanup require both --execute and ${REMOTE_WRITE_ENV}=1.
  Without --execute, commands only parse resources and print the planned work.`);
}

async function doctor(args) {
  const options = parseOptions(args);
  const customers = parseCustomerProfiles(CUSTOMER_RESOURCE);
  const groomers = parseGroomerProfiles(GROOMER_RESOURCE);

  console.log("TestOps doctor");
  console.log(`Project root: ${PROJECT_ROOT}`);
  console.log(`Customer resource: ${relative(CUSTOMER_RESOURCE)} (${customers.length} profiles)`);
  console.log(`Groomer resource: ${relative(GROOMER_RESOURCE)} (${groomers.length} profiles)`);
  console.log(`SUPABASE_URL: ${envStatus("SUPABASE_URL")}`);
  console.log(`SUPABASE_PUBLISHABLE_KEY: ${envStatus("SUPABASE_PUBLISHABLE_KEY")}`);
  console.log(`Supabase service-role env: ${envStatus(SERVICE_ROLE_KEY_ENV)}`);
  console.log(`${REMOTE_WRITE_ENV}: ${process.env[REMOTE_WRITE_ENV] === "1" ? "set" : "not set"}`);

  if (options.has("dry-run")) {
    console.log("Dry run complete.");
  }
}

async function run(args) {
  const [kind, ...rest] = args;
  if (kind !== "backend" && kind !== "ui") {
    throw new Error("Use `run backend` or `run ui`.");
  }

  if (kind === "ui") {
    console.log(
      "Use scripts/ios-testops-e2e.sh for XCUITest launch wiring. " +
        "The backend verifier remains scripts/testops.mjs run backend."
    );
    return;
  }

  return runBackend(rest);
}

async function runBackend(args) {
  const options = parseOptions(args);
  const scenarioID = optionValue(options, "scenario") ?? DEFAULT_SCENARIO;
  const execute = options.has("execute");
  const cleanupAfterRun = options.has("cleanup");
  const matrix = optionValue(options, "matrix");
  const plans = makeBackendPlans({
    scenarioID,
    matrix,
    runID: optionValue(options, "run-id"),
    customerSeedID: optionValue(options, "customer") ?? "GTC-001",
    groomerSeedID: optionValue(options, "groomer") ?? "GTG-001",
    customerProfiles: parseCustomerProfiles(CUSTOMER_RESOURCE),
    groomerProfiles: parseGroomerProfiles(GROOMER_RESOURCE),
  });

  if (!execute) {
    if (plans.length === 1) {
      console.log(JSON.stringify(redactedPlan(plans[0]), null, 2));
    } else {
      console.log(JSON.stringify({
        matrix,
        count: plans.length,
        plans: plans.map(redactedPlan),
      }, null, 2));
    }
    console.log("Dry run only. Add --execute and set TESTOPS_REMOTE_WRITE_APPROVED=1 to write remote data.");
    return;
  }

  requireRemoteWriteApproval();

  const api = new SupabaseREST(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_PUBLISHABLE_KEY"),
    requiredEnv(SERVICE_ROLE_KEY_ENV)
  );
  const results = [];
  for (const plan of plans) {
    const result = await runMarketplaceLifecycle(api, plan);
    if (cleanupAfterRun) {
      result.cleanup = await cleanupRun(api, plan.runID);
    }
    writeArtifacts(result);
    results.push(result);
  }

  if (results.length === 1) {
    console.log(JSON.stringify(redactedResult(results[0]), null, 2));
  } else {
    console.log(JSON.stringify({
      matrix,
      count: results.length,
      results: results.map(redactedResult),
    }, null, 2));
  }
}

async function cleanupCommand(args) {
  const options = parseOptions(args);
  const runID = requiredOption(options, "run-id");
  const execute = options.has("execute");
  const cleanupPlan = buildCleanupPlan(runID);

  if (!execute) {
    console.log(JSON.stringify({
      ...cleanupPlan,
      dryRun: true,
    }, null, 2));
    console.log("Add --execute and set TESTOPS_REMOTE_WRITE_APPROVED=1 to write remote data.");
    return;
  }

  requireRemoteWriteApproval();
  const api = new SupabaseREST(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_PUBLISHABLE_KEY"),
    requiredEnv(SERVICE_ROLE_KEY_ENV)
  );
  const result = await cleanupRun(api, runID);
  console.log(JSON.stringify(result, null, 2));
}

function reportCommand(args) {
  const options = parseOptions(args);
  const runID = requiredOption(options, "run-id");
  const jsonPath = path.join(ARTIFACT_DIR, `${runID}.json`);
  if (!fs.existsSync(jsonPath)) {
    throw new Error(`No artifact found at ${relative(jsonPath)}`);
  }
  const result = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
  const markdown = renderReport(result);
  const markdownPath = path.join(ARTIFACT_DIR, `${runID}.md`);
  fs.writeFileSync(markdownPath, markdown);
  console.log(markdown);
  console.error(`Wrote ${relative(markdownPath)}`);
}

function optionValue(options, key) {
  const value = options.get(key);
  return typeof value === "string" ? value : undefined;
}
