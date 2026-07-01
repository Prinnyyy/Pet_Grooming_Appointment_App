#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const PROJECT_ROOT = path.resolve(import.meta.dirname, "..");
const CUSTOMER_RESOURCE = path.join(
  PROJECT_ROOT,
  "docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md"
);
const GROOMER_RESOURCE = path.join(
  PROJECT_ROOT,
  "docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md"
);
const ARTIFACT_DIR = path.join(PROJECT_ROOT, "artifacts/testops");
const DEFAULT_SCENARIO = "marketplace_full_lifecycle";
const REMOTE_WRITE_ENV = "TESTOPS_REMOTE_WRITE_APPROVED";
const SERVICE_ROLE_KEY_ENV = ["SUPABASE", "SERVICE", "ROLE", "KEY"].join("_");

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
  node scripts/testops.mjs run backend --scenario ${DEFAULT_SCENARIO} [--customer GTC-001] [--groomer GTG-001] [--run-id RUN] [--execute] [--cleanup]
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
  const scenario = optionValue(options, "scenario") ?? DEFAULT_SCENARIO;
  if (scenario !== DEFAULT_SCENARIO) {
    throw new Error(`Unsupported scenario: ${scenario}`);
  }

  const runID = optionValue(options, "run-id") ?? makeRunID();
  const customerSeedID = optionValue(options, "customer") ?? "GTC-001";
  const groomerSeedID = optionValue(options, "groomer") ?? "GTG-001";
  const execute = options.has("execute");
  const cleanupAfterRun = options.has("cleanup");

  const customer = requireSeed(
    parseCustomerProfiles(CUSTOMER_RESOURCE),
    customerSeedID
  );
  const groomer = requireSeed(
    parseGroomerProfiles(GROOMER_RESOURCE),
    groomerSeedID
  );
  const plan = makeBackendPlan(runID, scenario, customer, groomer);

  if (!execute) {
    console.log(JSON.stringify(redactedPlan(plan), null, 2));
    console.log("Dry run only. Add --execute and set TESTOPS_REMOTE_WRITE_APPROVED=1 to write remote data.");
    return;
  }

  requireRemoteWriteApproval();

  const api = new SupabaseREST(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_PUBLISHABLE_KEY"),
    process.env[SERVICE_ROLE_KEY_ENV]
  );
  const result = await runMarketplaceLifecycle(api, plan);

  if (cleanupAfterRun) {
    if (!api.serviceRoleKey) {
      throw new Error(`${SERVICE_ROLE_KEY_ENV} is required for --cleanup.`);
    }
    result.cleanup = await cleanupRun(api, runID);
  }

  writeArtifacts(result);
  console.log(JSON.stringify(redactedResult(result), null, 2));
}

async function cleanupCommand(args) {
  const options = parseOptions(args);
  const runID = requiredOption(options, "run-id");
  const execute = options.has("execute");

  if (!execute) {
    console.log(`Dry run only. Would clean records tagged TESTOPS:${runID}.`);
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

async function runMarketplaceLifecycle(api, plan) {
  const startedAt = new Date().toISOString();
  const phases = [];
  let requestID = null;
  let offerID = null;
  let bookingID = null;

  const customerSession = await timed(phases, "customer.signIn", () =>
    api.signIn(plan.customer.email, plan.customer.password)
  );
  const customerID = customerSession.user.id;

  const pets = await timed(phases, "customer.loadPets", () =>
    api.restSelect(
      "pets",
      `select=id,name,species,breed&customer_id=eq.${customerID}&is_active=eq.true&order=created_at.asc`,
      customerSession.accessToken
    )
  );
  const dog = pets.find((pet) => pet.species === "Dog") ?? pets[0];
  if (!dog) {
    throw new Error(`No active pet found for ${plan.customer.seedID}.`);
  }

  const requestRows = await timed(phases, "customer.createRequest", () =>
    api.rpc("create_grooming_request", {
      p_pet_id: dog.id,
      p_service_type: plan.request.serviceType,
      p_service_notes: plan.request.serviceNotes,
      p_preferred_start: plan.request.preferredStart,
      p_preferred_end: plan.request.preferredEnd,
      p_location_mode: plan.request.locationMode,
      p_street_address: plan.request.streetAddress,
      p_city: plan.request.city,
      p_state: plan.request.state,
      p_zip_code: plan.request.zipCode,
      p_travel_radius_miles: plan.request.travelRadiusMiles,
    }, customerSession.accessToken)
  );
  requestID = firstValue(requestRows, "request_id");
  const matchCount = Number(firstValue(requestRows, "match_count") ?? 0);
  if (!requestID) {
    throw new Error("create_grooming_request did not return request_id.");
  }
  if (matchCount < 1) {
    throw new Error(`Request ${requestID} produced zero matches.`);
  }

  const groomerSession = await timed(phases, "groomer.signIn", () =>
    api.signIn(plan.groomer.email, plan.groomer.password)
  );
  const groomerID = groomerSession.user.id;

  const matches = await timed(phases, "groomer.verifyMatch", () =>
    api.restSelect(
      "request_matches",
      `select=id,request_id,groomer_id,status,match_reason&request_id=eq.${requestID}&groomer_id=eq.${groomerID}`,
      groomerSession.accessToken
    )
  );
  if (matches.length === 0) {
    throw new Error(`Selected groomer ${plan.groomer.seedID} did not receive request ${requestID}.`);
  }

  const offerRows = await timed(phases, "groomer.createOffer", () =>
    api.rpc("create_groomer_offer", {
      p_request_id: requestID,
      p_proposed_start: plan.offer.proposedStart,
      p_proposed_end: plan.offer.proposedEnd,
      p_price_estimate: plan.offer.priceEstimate,
      p_message: plan.offer.message,
    }, groomerSession.accessToken)
  );
  offerID = firstValue(offerRows, "offer_id");
  if (!offerID) {
    throw new Error("create_groomer_offer did not return offer_id.");
  }

  const bookingRows = await timed(phases, "customer.acceptOffer", () =>
    api.rpc("accept_groomer_offer", { p_offer_id: offerID }, customerSession.accessToken)
  );
  bookingID = firstValue(bookingRows, "booking_id");
  if (!bookingID) {
    throw new Error("accept_groomer_offer did not return booking_id.");
  }

  await timed(phases, "groomer.completeBooking", () =>
    api.rpc("complete_booking", { p_booking_id: bookingID }, groomerSession.accessToken)
  );

  const reviewRows = await timed(phases, "customer.createReview", () =>
    api.rpc("create_review", {
      p_booking_id: bookingID,
      p_rating: 5,
      p_content: `TESTOPS:${plan.runID} completed lifecycle review.`,
      p_pet_fit_outcomes: [],
    }, customerSession.accessToken)
  );
  const reviewID = firstValue(reviewRows, "review_id");

  const verification = await timed(phases, "service.verifyFinalState", () =>
    verifyLifecycle(api, { requestID, offerID, bookingID, reviewID })
  );

  return {
    runID: plan.runID,
    scenarioID: plan.scenarioID,
    startedAt,
    finishedAt: new Date().toISOString(),
    customer: safeActor(plan.customer, customerID),
    groomer: safeActor(plan.groomer, groomerID),
    ids: { requestID, offerID, bookingID, reviewID },
    matchCount,
    phases,
    verification,
  };
}

async function verifyLifecycle(api, ids) {
  const serviceToken = api.requireServiceRole();
  const [requests, offers, bookings, reviews] = await Promise.all([
    api.restSelect("grooming_requests", `select=id,status&id=eq.${ids.requestID}`, serviceToken),
    api.restSelect("groomer_offers", `select=id,status&id=eq.${ids.offerID}`, serviceToken),
    api.restSelect("bookings", `select=id,status&id=eq.${ids.bookingID}`, serviceToken),
    ids.reviewID
      ? api.restSelect("reviews", `select=id,rating&id=eq.${ids.reviewID}`, serviceToken)
      : Promise.resolve([]),
  ]);

  return {
    requestStatus: requests[0]?.status ?? null,
    offerStatus: offers[0]?.status ?? null,
    bookingStatus: bookings[0]?.status ?? null,
    reviewCount: reviews.length,
  };
}

async function cleanupRun(api, runID) {
  const serviceToken = api.requireServiceRole();
  const tag = `TESTOPS:${runID}`;
  const requests = await api.restSelect(
    "grooming_requests",
    `select=id&service_notes=ilike.*${encodeURIComponent(tag)}*`,
    serviceToken
  );
  const requestIDs = requests.map((row) => row.id).filter(Boolean);
  const summary = { runID, requestCount: requestIDs.length, deleted: {} };
  if (requestIDs.length === 0) {
    return summary;
  }

  const requestFilter = `in.(${requestIDs.join(",")})`;
  const bookings = await api.restSelect(
    "bookings",
    `select=id&request_id=${requestFilter}`,
    serviceToken
  );
  const bookingIDs = bookings.map((row) => row.id).filter(Boolean);
  const conversations = await api.restSelect(
    "conversations",
    `select=id&request_id=${requestFilter}`,
    serviceToken
  );
  const conversationIDs = conversations.map((row) => row.id).filter(Boolean);

  if (conversationIDs.length > 0) {
    summary.deleted.messages = await api.restDelete(
      "messages",
      `conversation_id=in.(${conversationIDs.join(",")})`,
      serviceToken
    );
    summary.deleted.conversations = await api.restDelete(
      "conversations",
      `id=in.(${conversationIDs.join(",")})`,
      serviceToken
    );
  }

  if (bookingIDs.length > 0) {
    const bookingFilter = `in.(${bookingIDs.join(",")})`;
    summary.deleted.review_pet_fit_outcomes = await api.restDelete(
      "review_pet_fit_outcomes",
      `booking_id=${bookingFilter}`,
      serviceToken
    );
    summary.deleted.reviews = await api.restDelete(
      "reviews",
      `booking_id=${bookingFilter}`,
      serviceToken
    );
    summary.deleted.bookings = await api.restDelete(
      "bookings",
      `id=${bookingFilter}`,
      serviceToken
    );
  }

  summary.deleted.request_photos = await api.restDelete(
    "request_photos",
    `request_id=${requestFilter}`,
    serviceToken
  );
  summary.deleted.groomer_offers = await api.restDelete(
    "groomer_offers",
    `request_id=${requestFilter}`,
    serviceToken
  );
  summary.deleted.request_matches = await api.restDelete(
    "request_matches",
    `request_id=${requestFilter}`,
    serviceToken
  );
  summary.deleted.grooming_requests = await api.restDelete(
    "grooming_requests",
    `id=${requestFilter}`,
    serviceToken
  );

  return summary;
}

class SupabaseREST {
  constructor(url, publishableKey, serviceRoleKey) {
    this.url = url.replace(/\/$/, "");
    this.publishableKey = publishableKey;
    this.serviceRoleKey = serviceRoleKey;
  }

  async signIn(email, password) {
    return this.request(
      `/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        headers: this.headers(this.publishableKey),
        body: JSON.stringify({ email, password }),
      },
      "auth"
    );
  }

  async rpc(name, params, accessToken) {
    return this.request(
      `/rest/v1/rpc/${name}`,
      {
        method: "POST",
        headers: this.headers(accessToken, { Prefer: "return=representation" }),
        body: JSON.stringify(params),
      },
      "rpc"
    );
  }

  async restSelect(table, query, accessToken) {
    return this.request(
      `/rest/v1/${table}?${query}`,
      {
        method: "GET",
        headers: this.headers(accessToken),
      },
      "rest"
    );
  }

  async restDelete(table, query, accessToken) {
    const response = await this.request(
      `/rest/v1/${table}?${query}`,
      {
        method: "DELETE",
        headers: this.headers(accessToken, { Prefer: "return=representation" }),
      },
      "rest"
    );
    return Array.isArray(response) ? response.length : 0;
  }

  requireServiceRole() {
    if (!this.serviceRoleKey) {
      throw new Error(`${SERVICE_ROLE_KEY_ENV} is required.`);
    }
    return this.serviceRoleKey;
  }

  headers(accessToken, extra = {}) {
    return {
      apikey: accessToken === this.serviceRoleKey ? this.serviceRoleKey : this.publishableKey,
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...extra,
    };
  }

  async request(resourcePath, init, kind) {
    const response = await fetch(`${this.url}${resourcePath}`, init);
    const text = await response.text();
    const payload = text ? JSON.parse(text) : null;
    if (!response.ok) {
      const message = payload?.message ?? payload?.error_description ?? payload?.error ?? response.statusText;
      throw new Error(`${kind} ${response.status}: ${message}`);
    }
    return payload;
  }
}

async function timed(phases, phase, operation) {
  const startedAt = Date.now();
  try {
    const value = await operation();
    phases.push({
      phase,
      status: "passed",
      durationMs: Date.now() - startedAt,
    });
    return value;
  } catch (error) {
    phases.push({
      phase,
      status: "failed",
      durationMs: Date.now() - startedAt,
      error: safeErrorMessage(error),
    });
    throw error;
  }
}

function makeBackendPlan(runID, scenarioID, customer, groomer) {
  const slot = nextWeekdaySlot();
  return {
    runID,
    scenarioID,
    customer,
    groomer,
    request: {
      serviceType: "full_groom",
      serviceNotes: `TESTOPS:${runID} ${scenarioID} dog full groom lifecycle request.`,
      preferredStart: slot.preferredStart,
      preferredEnd: slot.preferredEnd,
      locationMode: "customer_comes_to_groomer",
      streetAddress: customer.address.street,
      city: customer.address.city,
      state: customer.address.state,
      zipCode: customer.address.zip,
      travelRadiusMiles: null,
    },
    offer: {
      proposedStart: slot.proposedStart,
      proposedEnd: slot.proposedEnd,
      priceEstimate: 105,
      message: `TESTOPS:${runID} proposed full groom appointment.`,
    },
  };
}

function nextWeekdaySlot() {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + 4);
  while ([0, 6].includes(date.getUTCDay())) {
    date.setUTCDate(date.getUTCDate() + 1);
  }

  const year = date.getUTCFullYear();
  const month = date.getUTCMonth();
  const day = date.getUTCDate();
  const proposedStart = new Date(Date.UTC(year, month, day, 17, 0, 0));
  const proposedEnd = new Date(Date.UTC(year, month, day, 19, 15, 0));
  const preferredStart = new Date(Date.UTC(year, month, day, 16, 0, 0));
  const preferredEnd = new Date(Date.UTC(year, month, day, 22, 0, 0));

  return {
    proposedStart: proposedStart.toISOString(),
    proposedEnd: proposedEnd.toISOString(),
    preferredStart: preferredStart.toISOString(),
    preferredEnd: preferredEnd.toISOString(),
  };
}

function parseCustomerProfiles(filePath) {
  const markdown = fs.readFileSync(filePath, "utf8");
  return markdown
    .split(/\r?\n/)
    .filter((line) => line.startsWith("| GTC-"))
    .map((line) => {
      const cells = cellsFromRow(line, 7);
      const [seedID, email, password, nicknameContact, addressValue] = cells;
      const [nickname] = nicknameContact.split(" / ").map((value) => value.trim());
      return {
        seedID,
        email,
        password,
        displayName: nickname,
        address: parseAddress(addressValue),
      };
    });
}

function parseGroomerProfiles(filePath) {
  const markdown = fs.readFileSync(filePath, "utf8");
  return markdown
    .split(/\r?\n/)
    .filter((line) => line.startsWith("| GTG-"))
    .map((line) => {
      const cells = cellsFromRow(line, 12);
      const [seedID, email, password, displayBusiness, , addressValue] = cells;
      const [displayName, businessName] = displayBusiness.split(" / ").map((value) => value.trim());
      return {
        seedID,
        email,
        password,
        displayName,
        businessName,
        address: parseAddress(addressValue),
      };
    });
}

function cellsFromRow(line, expectedCount) {
  const cells = line
    .split("|")
    .slice(1, -1)
    .map((cell) => cell.trim());
  if (cells.length !== expectedCount) {
    throw new Error(`Expected ${expectedCount} columns in row: ${line}`);
  }
  return cells;
}

function parseAddress(value) {
  const match = value.match(/^(.+),\s*([^,]+),\s*CA\s+(\d{5}(?:-\d{4})?)$/);
  if (!match) {
    throw new Error(`Invalid California address: ${value}`);
  }
  return {
    street: match[1],
    city: match[2],
    state: "CA",
    zip: match[3],
  };
}

function parseOptions(args) {
  const values = new Map();
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (!arg.startsWith("--")) {
      continue;
    }
    const key = arg.slice(2);
    const next = args[index + 1];
    if (next && !next.startsWith("--")) {
      values.set(key, next);
      index += 1;
    } else {
      values.set(key, true);
    }
  }
  return values;
}

function optionValue(options, key) {
  const value = options.get(key);
  return typeof value === "string" ? value : undefined;
}

function requiredOption(options, key) {
  const value = optionValue(options, key);
  if (!value) {
    throw new Error(`--${key} is required.`);
  }
  return value;
}

function requireSeed(profiles, seedID) {
  const profile = profiles.find((candidate) => candidate.seedID === seedID);
  if (!profile) {
    throw new Error(`Could not find seed ${seedID}.`);
  }
  return profile;
}

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

function requireRemoteWriteApproval() {
  if (process.env[REMOTE_WRITE_ENV] !== "1") {
    throw new Error(`${REMOTE_WRITE_ENV}=1 is required for remote writes.`);
  }
}

function firstValue(rows, key) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return null;
  }
  return rows[0]?.[key] ?? null;
}

function safeActor(profile, userID) {
  return {
    seedID: profile.seedID,
    userRef: shortRef(userID),
    emailDomain: emailDomain(profile.email),
  };
}

function redactedPlan(plan) {
  return {
    runID: plan.runID,
    scenarioID: plan.scenarioID,
    customer: { seedID: plan.customer.seedID, emailDomain: emailDomain(plan.customer.email) },
    groomer: { seedID: plan.groomer.seedID, emailDomain: emailDomain(plan.groomer.email) },
    request: plan.request,
    offer: plan.offer,
  };
}

function redactedResult(result) {
  return {
    ...result,
    customer: result.customer,
    groomer: result.groomer,
  };
}

function writeArtifacts(result) {
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
  const jsonPath = path.join(ARTIFACT_DIR, `${result.runID}.json`);
  const markdownPath = path.join(ARTIFACT_DIR, `${result.runID}.md`);
  fs.writeFileSync(jsonPath, `${JSON.stringify(result, null, 2)}\n`);
  fs.writeFileSync(markdownPath, renderReport(result));
}

function renderReport(result) {
  const phaseRows = result.phases
    .map((phase) => `| ${phase.phase} | ${phase.status} | ${phase.durationMs} | ${phase.error ?? ""} |`)
    .join("\n");
  return `# TestOps Run ${result.runID}

| Field | Value |
|---|---|
| Scenario | ${result.scenarioID} |
| Started | ${result.startedAt} |
| Finished | ${result.finishedAt} |
| Customer | ${result.customer.seedID} / ${result.customer.userRef} |
| Groomer | ${result.groomer.seedID} / ${result.groomer.userRef} |
| Request | ${shortRef(result.ids.requestID)} |
| Offer | ${shortRef(result.ids.offerID)} |
| Booking | ${shortRef(result.ids.bookingID)} |
| Review | ${shortRef(result.ids.reviewID)} |
| Match count | ${result.matchCount} |

## Verification

\`\`\`json
${JSON.stringify(result.verification, null, 2)}
\`\`\`

## Phases

| Phase | Status | Duration ms | Error |
|---|---:|---:|---|
${phaseRows}
`;
}

function makeRunID() {
  const stamp = new Date()
    .toISOString()
    .replace(/[-:]/g, "")
    .replace(/\.\d{3}Z$/, "Z");
  return `TESTOPS-${stamp}`;
}

function emailDomain(email) {
  return email.split("@")[1]?.toLowerCase() ?? "unknown";
}

function shortRef(value) {
  return value ? String(value).slice(0, 8).toUpperCase() : null;
}

function envStatus(name) {
  return process.env[name]?.trim() ? "set" : "not set";
}

function relative(filePath) {
  return path.relative(PROJECT_ROOT, filePath);
}

function safeErrorMessage(error) {
  return String(error?.message ?? error)
    .replace(/[A-Z0-9._%+-]+@([A-Z0-9.-]+\.[A-Z]{2,})/gi, "[email-domain:$1]")
    .replace(/(password|token|authorization|apikey|api_key)(=|:|\s+)[^\s&]+/gi, "$1$2[redacted]")
    .replace(/\b([0-9a-f]{8})-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, "$1");
}
