import fs from "node:fs";
import path from "node:path";

export const PROJECT_ROOT = path.resolve(import.meta.dirname, "..");
export const CUSTOMER_RESOURCE = path.join(
  PROJECT_ROOT,
  "docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md"
);
export const GROOMER_RESOURCE = path.join(
  PROJECT_ROOT,
  "docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md"
);
export const ARTIFACT_DIR = path.join(PROJECT_ROOT, "artifacts/testops");
export const DEFAULT_SCENARIO = "marketplace_full_lifecycle";
export const REMOTE_WRITE_ENV = "TESTOPS_REMOTE_WRITE_APPROVED";
export const SERVICE_ROLE_KEY_ENV = ["SUPABASE", "SERVICE", "ROLE", "KEY"].join("_");

export const SMOKE5_CASES = [
  {
    caseID: "TC-MKT-001",
    customerSeedID: "GTC-001",
    groomerSeedID: "GTG-001",
    purpose: "default LA curly coat full lifecycle",
    preferredWeekdays: [1, 2, 3, 4, 5],
  },
  {
    caseID: "TC-MKT-002",
    customerSeedID: "GTC-003",
    groomerSeedID: "GTG-003",
    purpose: "wire terrier studio full lifecycle",
    preferredWeekdays: [3, 4, 5, 6, 0],
  },
  {
    caseID: "TC-MKT-003",
    customerSeedID: "GTC-004",
    groomerSeedID: "GTG-004",
    purpose: "small drop-coat full lifecycle",
    preferredWeekdays: [1, 2, 3, 4, 6],
  },
  {
    caseID: "TC-MKT-004",
    customerSeedID: "GTC-016",
    groomerSeedID: "GTG-006",
    purpose: "larger double-coat full lifecycle",
    preferredWeekdays: [1, 2, 3, 4, 5],
  },
  {
    caseID: "TC-MKT-005",
    customerSeedID: "GTC-049",
    groomerSeedID: "GTG-041",
    purpose: "Orange County curly full lifecycle",
    preferredWeekdays: [2, 3, 4, 5, 6],
  },
];

export function parseCustomerProfiles(filePath = CUSTOMER_RESOURCE) {
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

export function parseGroomerProfiles(filePath = GROOMER_RESOURCE) {
  const markdown = fs.readFileSync(filePath, "utf8");
  return markdown
    .split(/\r?\n/)
    .filter((line) => line.startsWith("| GTG-"))
    .map((line) => {
      const cells = cellsFromRow(line, 12);
      const [seedID, email, password, displayBusiness, , addressValue] = cells;
      const [displayName, businessName] = displayBusiness
        .split(" / ")
        .map((value) => value.trim());
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

export function parseOptions(args) {
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

export function optionValue(options, key) {
  const value = options.get(key);
  return typeof value === "string" ? value : undefined;
}

export function requiredOption(options, key) {
  const value = optionValue(options, key);
  if (!value) {
    throw new Error(`--${key} is required.`);
  }
  return value;
}

export function requiredEnv(name, env = process.env) {
  const value = env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

export function requireRemoteWriteApproval(env = process.env) {
  if (env[REMOTE_WRITE_ENV] !== "1") {
    throw new Error(`${REMOTE_WRITE_ENV}=1 is required for remote writes.`);
  }
}

export function envStatus(name, env = process.env) {
  return env[name]?.trim() ? "set" : "not set";
}

export function makeBackendPlans({
  scenarioID = DEFAULT_SCENARIO,
  matrix,
  runID,
  customerSeedID = "GTC-001",
  groomerSeedID = "GTG-001",
  customerProfiles = parseCustomerProfiles(),
  groomerProfiles = parseGroomerProfiles(),
} = {}) {
  assertSupportedScenario(scenarioID);

  if (matrix) {
    if (matrix !== "smoke5") {
      throw new Error(`Unsupported matrix: ${matrix}`);
    }

    const baseRunID = runID ?? makeRunID();
    return SMOKE5_CASES.map((entry) =>
      makeBackendPlan({
        runID: `${baseRunID}-${entry.caseID}`,
        scenarioID,
        caseID: entry.caseID,
        purpose: entry.purpose,
        customer: requireSeed(customerProfiles, entry.customerSeedID),
        groomer: requireSeed(groomerProfiles, entry.groomerSeedID),
        preferredWeekdays: entry.preferredWeekdays,
      })
    );
  }

  const caseEntry =
    SMOKE5_CASES.find(
      (entry) =>
        entry.customerSeedID === customerSeedID
          && entry.groomerSeedID === groomerSeedID
    ) ?? {
      caseID: "TC-MKT-CUSTOM",
      purpose: "custom single-case lifecycle",
      preferredWeekdays: [1, 2, 3, 4, 5],
    };

  return [
    makeBackendPlan({
      runID: runID ?? makeRunID(),
      scenarioID,
      caseID: caseEntry.caseID,
      purpose: caseEntry.purpose,
      customer: requireSeed(customerProfiles, customerSeedID),
      groomer: requireSeed(groomerProfiles, groomerSeedID),
      preferredWeekdays: caseEntry.preferredWeekdays,
    }),
  ];
}

export function makeBackendPlan({
  runID,
  scenarioID,
  caseID,
  purpose,
  customer,
  groomer,
  preferredWeekdays = [1, 2, 3, 4, 5],
}) {
  assertSupportedScenario(scenarioID);
  const slot = nextWeekdaySlot(preferredWeekdays);
  return {
    runID,
    scenarioID,
    caseID,
    purpose,
    customer,
    groomer,
    request: {
      serviceType: "full_groom",
      serviceNotes: `TESTOPS:${runID} ${scenarioID} ${caseID} dog full groom lifecycle request.`,
      preferredStart: slot.preferredStart,
      preferredEnd: slot.preferredEnd,
      locationMode: "customer_comes_to_groomer",
      streetAddress: customer.address.street,
      city: customer.address.city,
      state: customer.address.state,
      zipCode: customer.address.zip,
      travelRadiusMiles: 15,
    },
    offer: {
      proposedStart: slot.proposedStart,
      proposedEnd: slot.proposedEnd,
      priceEstimate: 105,
      message: `TESTOPS:${runID} proposed full groom appointment.`,
    },
  };
}

export async function runMarketplaceLifecycle(api, plan) {
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
    api.rpc(
      "create_grooming_request",
      {
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
      },
      customerSession.accessToken
    )
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
    throw new Error(
      `Selected groomer ${plan.groomer.seedID} did not receive request ${requestID}.`
    );
  }

  const offerRows = await timed(phases, "groomer.createOffer", () =>
    api.rpc(
      "create_groomer_offer",
      {
        p_request_id: requestID,
        p_proposed_start: plan.offer.proposedStart,
        p_proposed_end: plan.offer.proposedEnd,
        p_price_estimate: plan.offer.priceEstimate,
        p_message: plan.offer.message,
      },
      groomerSession.accessToken
    )
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
    api.rpc(
      "create_review",
      {
        p_booking_id: bookingID,
        p_rating: 5,
        p_content: `TESTOPS:${plan.runID} completed lifecycle review.`,
        p_pet_fit_outcomes: [],
      },
      customerSession.accessToken
    )
  );
  const reviewID = firstValue(reviewRows, "review_id");

  const verification = await timed(phases, "service.verifyFinalState", () =>
    verifyLifecycle(api, { requestID, offerID, bookingID, reviewID })
  );

  return {
    runID: plan.runID,
    scenarioID: plan.scenarioID,
    caseID: plan.caseID,
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

export async function cleanupRun(api, runID) {
  const serviceToken = api.requireServiceRole();
  const cleanupPlan = buildCleanupPlan(runID);
  const requests = await api.restSelect(
    "grooming_requests",
    `select=id&service_notes=ilike.*${encodeURIComponent(cleanupPlan.tag)}*`,
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

export function buildCleanupPlan(runID) {
  return {
    runID,
    tag: `TESTOPS:${runID}`,
    deleteOrder: [
      "messages",
      "conversations",
      "review_pet_fit_outcomes",
      "reviews",
      "bookings",
      "request_photos",
      "groomer_offers",
      "request_matches",
      "grooming_requests",
    ],
  };
}

export async function verifyLifecycle(api, ids) {
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

export class SupabaseREST {
  constructor(url, publishableKey, serviceRoleKey) {
    this.url = url.replace(/\/$/, "");
    this.publishableKey = publishableKey;
    this.serviceRoleKey = serviceRoleKey;
  }

  async signIn(email, password) {
    return this.request(
      "/auth/v1/token?grant_type=password",
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
      apikey:
        accessToken === this.serviceRoleKey
          ? this.serviceRoleKey
          : this.publishableKey,
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
      const message =
        payload?.message
          ?? payload?.error_description
          ?? payload?.error
          ?? response.statusText;
      throw new Error(`${kind} ${response.status}: ${message}`);
    }
    return payload;
  }
}

export function redactedPlan(plan) {
  return {
    runID: plan.runID,
    scenarioID: plan.scenarioID,
    caseID: plan.caseID,
    purpose: plan.purpose,
    customer: {
      seedID: plan.customer.seedID,
      emailDomain: emailDomain(plan.customer.email),
    },
    groomer: {
      seedID: plan.groomer.seedID,
      emailDomain: emailDomain(plan.groomer.email),
    },
    request: plan.request,
    offer: plan.offer,
  };
}

export function redactedResult(result) {
  return {
    ...result,
    customer: result.customer,
    groomer: result.groomer,
  };
}

export function writeArtifacts(result, artifactDir = ARTIFACT_DIR) {
  fs.mkdirSync(artifactDir, { recursive: true });
  const jsonPath = path.join(artifactDir, `${result.runID}.json`);
  const markdownPath = path.join(artifactDir, `${result.runID}.md`);
  fs.writeFileSync(jsonPath, `${JSON.stringify(result, null, 2)}\n`);
  fs.writeFileSync(markdownPath, renderReport(result));
  return { jsonPath, markdownPath };
}

export function renderReport(result) {
  const phaseRows = result.phases
    .map((phase) =>
      `| ${phase.phase} | ${phase.status} | ${phase.durationMs} | ${safeErrorMessage(phase.error ?? "")} |`
    )
    .join("\n");
  return `# TestOps Run ${result.runID}

| Field | Value |
|---|---|
| Scenario | ${result.scenarioID} |
| Case | ${result.caseID ?? ""} |
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

export function safeActor(profile, userID) {
  return {
    seedID: profile.seedID,
    userRef: shortRef(userID),
    emailDomain: emailDomain(profile.email),
  };
}

export function makeRunID() {
  const stamp = new Date()
    .toISOString()
    .replace(/[-:]/g, "")
    .replace(/\.\d{3}Z$/, "Z");
  return `TESTOPS-${stamp}`;
}

export function emailDomain(email) {
  return email.split("@")[1]?.toLowerCase() ?? "unknown";
}

export function shortRef(value) {
  return value ? String(value).slice(0, 8).toUpperCase() : null;
}

export function safeErrorMessage(error) {
  return String(error?.message ?? error)
    .replace(/[A-Z0-9._%+-]+@([A-Z0-9.-]+\.[A-Z]{2,})/gi, "[email-domain:$1]")
    .replace(/(password|token|authorization|apikey|api_key)(=|:|\s+)[^\s&]+/gi, "$1$2[redacted]")
    .replace(/\b([0-9a-f]{8})-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, "$1");
}

export function relative(filePath) {
  return path.relative(PROJECT_ROOT, filePath);
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

function nextWeekdaySlot(weekdays) {
  const allowed = new Set(weekdays);
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + 4);
  while (!allowed.has(date.getUTCDay())) {
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

function assertSupportedScenario(scenarioID) {
  if (scenarioID !== DEFAULT_SCENARIO) {
    throw new Error(`Unsupported scenario: ${scenarioID}`);
  }
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

function requireSeed(profiles, seedID) {
  const profile = profiles.find((candidate) => candidate.seedID === seedID);
  if (!profile) {
    throw new Error(`Could not find seed ${seedID}.`);
  }
  return profile;
}

function firstValue(rows, key) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return null;
  }
  return rows[0]?.[key] ?? null;
}
