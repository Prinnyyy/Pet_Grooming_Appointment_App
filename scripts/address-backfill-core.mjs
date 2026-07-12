import crypto from "node:crypto";

export const ADDRESS_BACKFILL_REMOTE_WRITE_ENV = "ADDRESS_BACKFILL_REMOTE_WRITE_APPROVED";
export const ADDRESS_BACKFILL_SOURCE_KINDS = [
  "groomer_profile",
  "customer_profile",
  "active_request",
];

const STREET_TOKEN_ALIASES = new Map([
  ["north", "n"],
  ["south", "s"],
  ["east", "e"],
  ["west", "w"],
  ["northeast", "ne"],
  ["northwest", "nw"],
  ["southeast", "se"],
  ["southwest", "sw"],
  ["street", "st"],
  ["avenue", "ave"],
  ["boulevard", "blvd"],
  ["drive", "dr"],
  ["road", "rd"],
  ["lane", "ln"],
  ["court", "ct"],
  ["place", "pl"],
  ["parkway", "pkwy"],
  ["highway", "hwy"],
  ["terrace", "ter"],
  ["circle", "cir"],
  ["saint", "st"],
]);

const SECONDARY_SUFFIX = /\s+(?:(?:apt|apartment|unit|suite|ste|floor|fl|building|bldg|room|rm)\s+[a-z0-9-]+|#\s*[a-z0-9-]+)\s*$/i;
const DIRECTION_TOKENS = new Set(["n", "s", "e", "w", "ne", "nw", "se", "sw"]);
const STREET_TYPE_TOKENS = new Set([
  "st", "ave", "blvd", "dr", "rd", "ln", "ct", "pl", "pkwy", "hwy", "ter", "cir", "way",
]);

export function normalizeAddressComponent(value, { street = false } = {}) {
  const tokens = String(value ?? "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  return tokens
    .map((token) => street ? (STREET_TOKEN_ALIASES.get(token) ?? token) : token)
    .join(" ");
}

export function supportRef(target) {
  return `${target.sourceKind}:${String(target.sourceID).slice(0, 8)}`;
}

export function baseAddressLine1(value) {
  return String(value ?? "").replace(SECONDARY_SUFFIX, "").trim();
}

export function addressFingerprint(target) {
  const canonical = [
    target.sourceKind,
    target.sourceID,
    target.ownerID,
    normalizeAddressComponent(target.line1, { street: true }),
    normalizeAddressComponent(target.line2),
    normalizeAddressComponent(target.city),
    normalizeAddressComponent(target.state),
    normalizePostalCode(target.zipCode),
  ].join("\u001f");
  return crypto.createHash("sha256").update(canonical).digest("hex");
}

export function exactCandidates(target, candidates) {
  return candidates.filter((candidate) =>
    isCompleteUSCandidate(candidate)
      && normalizeResolutionStreet(candidate.line1)
        === normalizeResolutionStreet(target.line1)
      && normalizeAddressComponent(candidate.state)
        === normalizeAddressComponent(target.state)
      && normalizePostalCode(candidate.zipCode)
        === normalizePostalCode(target.zipCode)
  );
}

export function classifyResolution(target, candidates) {
  const base = {
    sourceKind: target.sourceKind,
    supportRef: supportRef(target),
    addressFingerprint: addressFingerprint(target),
    candidateCount: candidates.length,
  };
  if (candidates.length === 0) {
    return { ...base, exactCandidateCount: 0, status: "review_missing" };
  }
  if (candidates.every((candidate) => normalizeCountry(candidate.countryCode) !== "US")) {
    return { ...base, exactCandidateCount: 0, status: "review_non_us" };
  }
  const completeUS = candidates.filter(isCompleteUSCandidate);
  if (completeUS.length === 0) {
    return { ...base, exactCandidateCount: 0, status: "review_incomplete" };
  }
  const exact = exactCandidates(target, completeUS);
  if (exact.length === 1) {
    const cityDiffers = normalizeAddressComponent(exact[0].city)
      !== normalizeAddressComponent(target.city);
    return {
      ...base,
      exactCandidateCount: 1,
      status: "approved_exact",
      ...(cityDiffers ? { displayVariantFields: ["city"] } : {}),
    };
  }
  if (exact.length > 1) {
    return { ...base, exactCandidateCount: exact.length, status: "review_ambiguous" };
  }
  return {
    ...base,
    exactCandidateCount: 0,
    status: "review_component_mismatch",
    mismatchFields: componentMismatchFields(target, completeUS[0]),
  };
}

export function requireBackfillRemoteWriteApproval({ execute, env = process.env }) {
  if (!execute) {
    throw new Error("Address backfill writes require --execute.");
  }
  if (env[ADDRESS_BACKFILL_REMOTE_WRITE_ENV] !== "1") {
    throw new Error(`Address backfill writes require ${ADDRESS_BACKFILL_REMOTE_WRITE_ENV}=1.`);
  }
}

export function validateDecisionArtifact(targets, decisions) {
  const byRef = new Map(targets.map((target) => [supportRef(target), target]));
  return decisions.map((decision) => {
    const target = byRef.get(decision.supportRef);
    if (!target || addressFingerprint(target) !== decision.addressFingerprint) {
      throw new Error(`Address backfill decision is stale for ${decision.supportRef}.`);
    }
    return decision;
  });
}

export function validateExceptionArtifact(targets, exceptions) {
  const byRef = new Map(targets.map((target) => [supportRef(target), target]));
  const seen = new Set();
  return exceptions.map((exception) => {
    const target = byRef.get(exception.supportRef);
    if (!target || addressFingerprint(target) !== exception.addressFingerprint) {
      throw new Error(`Address backfill exception is stale for ${exception.supportRef}.`);
    }
    if (seen.has(exception.supportRef)) {
      throw new Error(`Duplicate address backfill exception for ${exception.supportRef}.`);
    }
    if (!/^[a-z0-9_]{3,80}$/.test(exception.reasonCode ?? "")) {
      throw new Error(`Address backfill exception requires a safe reason code for ${exception.supportRef}.`);
    }
    seen.add(exception.supportRef);
    return exception;
  });
}

export function makeBackfillReport({ runID, decisions, summary = null }) {
  const counts = {};
  for (const decision of decisions) {
    counts[decision.status] = (counts[decision.status] ?? 0) + 1;
  }
  return {
    schemaVersion: 1,
    runID,
    generatedAt: new Date().toISOString(),
    counts,
    summary,
    decisions: decisions.map((decision) => ({ ...decision })),
  };
}

export function parseBackfillOptions(args) {
  const options = new Map();
  for (let index = 0; index < args.length; index += 1) {
    const raw = args[index];
    if (!raw.startsWith("--")) throw new Error(`Unexpected argument: ${raw}`);
    const key = raw.slice(2);
    if (["execute", "help"].includes(key)) {
      options.set(key, true);
      continue;
    }
    const value = args[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`Missing value for --${key}.`);
    options.set(key, value);
    index += 1;
  }
  return options;
}

export function safeBackfillError(error) {
  return String(error?.message ?? error)
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[redacted-email]")
    .replace(/\b[0-9a-f]{8}-[0-9a-f-]{27}\b/gi, "[redacted-id]")
    .replace(/\b(?:sb_secret_|sbp_|eyJ)[A-Za-z0-9._-]+/g, "[redacted-secret]");
}

function isCompleteUSCandidate(candidate) {
  return normalizeCountry(candidate.countryCode) === "US"
    && normalizeAddressComponent(candidate.line1, { street: true }).length > 0
    && normalizeAddressComponent(candidate.city).length > 0
    && normalizeAddressComponent(candidate.state).length > 0
    && normalizePostalCode(candidate.zipCode).length === 5
    && Number.isFinite(candidate.latitude)
    && Number.isFinite(candidate.longitude);
}

function componentMismatchFields(target, candidate) {
  const comparisons = [
    ["line1", normalizeAddressComponent(target.line1, { street: true }), normalizeAddressComponent(candidate.line1, { street: true })],
    ["city", normalizeAddressComponent(target.city), normalizeAddressComponent(candidate.city)],
    ["state", normalizeAddressComponent(target.state), normalizeAddressComponent(candidate.state)],
    ["zipCode", normalizePostalCode(target.zipCode), normalizePostalCode(candidate.zipCode)],
  ];
  return comparisons.filter(([, lhs, rhs]) => lhs !== rhs).map(([field]) => field);
}

function normalizeResolutionStreet(value) {
  const tokens = normalizeAddressComponent(baseAddressLine1(value), { street: true })
    .split(" ")
    .filter((token) => !DIRECTION_TOKENS.has(token));
  if (STREET_TYPE_TOKENS.has(tokens.at(-1))) tokens.pop();
  return tokens.join(" ");
}

function normalizeCountry(value) {
  const normalized = String(value ?? "").trim().toUpperCase();
  return normalized === "USA" || normalized === "UNITED STATES" ? "US" : normalized;
}

function normalizePostalCode(value) {
  return String(value ?? "").match(/\d{5}/)?.[0] ?? "";
}
