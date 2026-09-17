#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import {
  ADDRESS_BACKFILL_SOURCE_KINDS,
  baseAddressLine1,
  classifyResolution,
  exactCandidates,
  makeBackfillReport,
  parseBackfillOptions,
  requireBackfillRemoteWriteApproval,
  safeBackfillError,
  supportRef,
  validateDecisionArtifact,
  validateExceptionArtifact,
} from "./address-backfill-core.mjs";

const ROOT = path.resolve(import.meta.dirname, "..");
const ARTIFACT_ROOT = path.join(ROOT, "artifacts/address-backfill");
const GEOCODER_SOURCE = path.join(import.meta.dirname, "address-backfill-geocoder.swift");
const GEOCODER_BINARY = path.join(os.tmpdir(), "beckon-address-backfill-geocoder");

async function main() {
  const options = parseBackfillOptions(process.argv.slice(2));
  if (options.has("help")) return usage();
  const execute = options.has("execute");
  const runID = options.get("run-id") ?? `T-299-${new Date().toISOString().replace(/[:.]/g, "-")}`;
  const kind = options.get("kind") ?? "all";
  if (kind !== "all" && !ADDRESS_BACKFILL_SOURCE_KINDS.includes(kind)) {
    throw new Error(`Unknown --kind ${kind}.`);
  }

  const api = new BackfillAPI(requiredEnv("SUPABASE_URL"), requiredServerCredential());
  const allTargets = (await api.rpc("list_address_backfill_targets", {})).map(mapTarget);
  const targets = allTargets
    .filter((target) => kind === "all" || target.sourceKind === kind)
    .sort((lhs, rhs) => sourceRank(lhs.sourceKind) - sourceRank(rhs.sourceKind));
  const summaryBefore = firstRow(await api.rpc("get_address_backfill_summary", {}));

  if (!execute) {
    const resolutions = geocodeTargets(targets);
    const decisions = targets.map((target) => {
      const resolution = resolutions.get(supportRef(target));
      return {
        ...classifyResolution(target, resolution?.candidates ?? []),
        ...(resolution?.errorCode ? { errorCode: resolution.errorCode } : {}),
      };
    });
    const report = makeBackfillReport({ runID, decisions, summary: summaryBefore });
    const directory = writeDryRunArtifacts(runID, report);
    console.log(JSON.stringify({
      mode: "dry-run",
      runID,
      targetCount: targets.length,
      counts: report.counts,
      summary: summaryBefore,
      decisionFile: path.relative(ROOT, path.join(directory, "decisions.json")),
    }, null, 2));
    return;
  }

  requireBackfillRemoteWriteApproval({ execute: true });
  const decisionFile = requiredOption(options, "decision-file");
  const artifact = JSON.parse(fs.readFileSync(path.resolve(decisionFile), "utf8"));
  const targetRefs = new Set(targets.map(supportRef));
  const decisions = validateDecisionArtifact(
    targets,
    (artifact.decisions ?? []).filter((decision) => targetRefs.has(decision.supportRef)),
  );
  const unresolved = decisions.filter((decision) => decision.status !== "approved_exact");
  const exceptions = options.has("exception-file")
    ? validateExceptionArtifact(
        targets,
        (JSON.parse(fs.readFileSync(path.resolve(options.get("exception-file")), "utf8")).exceptions ?? [])
          .filter((exception) => targetRefs.has(exception.supportRef)),
      )
    : [];
  const exceptionRefs = new Set(exceptions.map((exception) => exception.supportRef));
  const undocumented = unresolved.filter((decision) => !exceptionRefs.has(decision.supportRef));
  if (undocumented.length > 0 || decisions.length !== targets.length) {
    throw new Error(
      `Remote write refused: ${undocumented.length} undocumented unresolved and `
        + `${targets.length - decisions.length} unreviewed address targets.`,
    );
  }

  const approvedTargets = targets.filter((target) => !exceptionRefs.has(supportRef(target)));
  const resolutions = geocodeTargets(approvedTargets);
  const resolvedAt = new Date().toISOString();
  const items = approvedTargets.map((target) => {
    const candidates = resolutions.get(supportRef(target))?.candidates ?? [];
    let exact = exactCandidates(target, candidates);
    for (let attempt = 0; exact.length !== 1 && attempt < 2; attempt += 1) {
      sleepMilliseconds(4_000 * (attempt + 1));
      const retry = geocodeTargets([target]);
      exact = exactCandidates(target, retry.get(supportRef(target))?.candidates ?? []);
    }
    if (exact.length !== 1) {
      throw new Error(`Apple Maps resolution changed for ${supportRef(target)}; rerun dry-run.`);
    }
    return writeItem(target, exact[0], resolvedAt);
  });
  const writtenCount = await api.rpc("backfill_address_locations", { p_items: items });
  const remainingTargets = (await api.rpc("list_address_backfill_targets", {})).map(mapTarget);
  const summaryAfter = firstRow(await api.rpc("get_address_backfill_summary", {}));
  const result = {
    mode: "execute",
    runID,
    requestedCount: items.length,
    writtenCount,
    documentedExceptionCount: exceptions.length,
    remainingTargetCount: remainingTargets.length,
    summaryBefore,
    summaryAfter,
  };
  writeExecutionResult(runID, result);
  console.log(JSON.stringify(result, null, 2));
}

function usage() {
  console.log(`Usage:
  node scripts/address-backfill.mjs [--kind all|groomer_profile|customer_profile|active_request] [--run-id ID]
  ADDRESS_BACKFILL_REMOTE_WRITE_APPROVED=1 node scripts/address-backfill.mjs --execute --decision-file PATH [--exception-file PATH] [--run-id ID]

Dry-run is the default. Execute requires both --execute and the dedicated approval environment variable.`);
}

function geocodeTargets(targets) {
  compileGeocoderIfNeeded();
  const input = {
    queries: targets.map((target) => ({
      id: supportRef(target),
      line1: baseAddressLine1(target.line1),
      city: target.city,
      state: target.state,
      zipCode: target.zipCode,
    })),
  };
  const result = spawnSync(GEOCODER_BINARY, [], {
    input: JSON.stringify(input),
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });
  if (result.status !== 0) {
    throw new Error(`Apple Maps geocoder failed: ${result.stderr.trim()}`);
  }
  const output = JSON.parse(result.stdout);
  return new Map(output.results.map((entry) => [entry.id, entry]));
}

function compileGeocoderIfNeeded() {
  const sourceMtime = fs.statSync(GEOCODER_SOURCE).mtimeMs;
  const binaryMtime = fs.existsSync(GEOCODER_BINARY)
    ? fs.statSync(GEOCODER_BINARY).mtimeMs
    : 0;
  if (binaryMtime >= sourceMtime) return;
  const result = spawnSync(
    "xcrun",
    ["swiftc", "-parse-as-library", "-O", GEOCODER_SOURCE, "-o", GEOCODER_BINARY],
    {
    encoding: "utf8",
    },
  );
  if (result.status !== 0) {
    throw new Error(`Could not compile Apple Maps geocoder: ${result.stderr.trim()}`);
  }
}

function writeDryRunArtifacts(runID, report) {
  const directory = path.join(ARTIFACT_ROOT, safeRunID(runID));
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, "decisions.json"), `${JSON.stringify(report, null, 2)}\n`);
  return directory;
}

function writeExecutionResult(runID, result) {
  const directory = path.join(ARTIFACT_ROOT, safeRunID(runID));
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, "execution.json"), `${JSON.stringify(result, null, 2)}\n`);
}

function mapTarget(row) {
  return {
    sourceKind: row.source_kind,
    sourceID: row.source_id,
    ownerID: row.owner_id,
    line1: row.line_1,
    line2: row.line_2 ?? "",
    city: row.city,
    state: row.state,
    zipCode: row.zip_code,
  };
}

function writeItem(target, candidate, resolvedAt) {
  return {
    source_kind: target.sourceKind,
    source_id: target.sourceID,
    expected_line_1: target.line1,
    expected_line_2: target.line2 || null,
    expected_city: target.city,
    expected_state: target.state,
    expected_zip_code: target.zipCode,
    provider: "apple_maps",
    place_id: candidate.placeID,
    country_code: "US",
    latitude: candidate.latitude,
    longitude: candidate.longitude,
    resolved_at: resolvedAt,
  };
}

function sourceRank(kind) {
  return ADDRESS_BACKFILL_SOURCE_KINDS.indexOf(kind);
}

function sleepMilliseconds(milliseconds) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function firstRow(value) {
  return Array.isArray(value) ? (value[0] ?? {}) : value;
}

function requiredOption(options, key) {
  const value = options.get(key);
  if (!value) throw new Error(`Missing --${key}.`);
  return value;
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}.`);
  return value.replace(/\/$/, "");
}

function requiredServerCredential() {
  const value = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!value) throw new Error("Missing SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY.");
  return value;
}

function safeRunID(runID) {
  if (!/^[A-Za-z0-9._-]{1,100}$/.test(runID)) throw new Error("Invalid run ID.");
  return runID;
}

class BackfillAPI {
  constructor(baseURL, credential) {
    this.baseURL = baseURL;
    this.credential = credential;
  }

  async rpc(name, params) {
    const headers = {
      apikey: this.credential,
      "Content-Type": "application/json",
    };
    if (!this.credential.startsWith("sb_secret_")) {
      headers.Authorization = `Bearer ${this.credential}`;
    }
    const response = await fetch(`${this.baseURL}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers,
      body: JSON.stringify(params),
    });
    const text = await response.text();
    if (!response.ok) throw new Error(`${name} returned ${response.status}: ${text}`);
    return text ? JSON.parse(text) : null;
  }
}

main().catch((error) => {
  console.error(`Address backfill failed: ${safeBackfillError(error)}`);
  process.exitCode = 1;
});
