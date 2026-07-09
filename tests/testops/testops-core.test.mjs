import assert from "node:assert/strict";
import path from "node:path";
import { test } from "node:test";

import {
  DEFAULT_SCENARIO,
  SMOKE5_CASES,
  buildCleanupPlan,
  makeBackendPlan,
  makeBackendPlans,
  parseCustomerProfiles,
  parseGroomerProfiles,
  parseOptions,
  redactedPlan,
  redactedResult,
  renderReport,
  requireRemoteWriteApproval,
  safeErrorMessage,
} from "../../scripts/testops-core.mjs";

const projectRoot = path.resolve(import.meta.dirname, "../..");
const customerResource = path.join(
  projectRoot,
  "docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md"
);
const groomerResource = path.join(
  projectRoot,
  "docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md"
);

test("parses the seeded customer and groomer resources", () => {
  const customers = parseCustomerProfiles(customerResource);
  const groomers = parseGroomerProfiles(groomerResource);

  assert.equal(customers.length, 50);
  assert.equal(groomers.length, 50);
  assert.equal(customers[0].seedID, "GTC-001");
  assert.equal(customers[0].email, "groomly.customer001@example.com");
  assert.equal(customers[0].password, "GroomlyTest!2026");
  assert.deepEqual(customers[0].address, {
    street: "3965 Cesar E Chavez Ave",
    city: "Los Angeles",
    state: "CA",
    zip: "90063",
  });
  assert.equal(groomers[0].seedID, "GTG-001");
  assert.equal(groomers[0].email, "groomly.groomer001@example.com");
  assert.equal(groomers[0].password, "GroomlyTest!2026");
  assert.equal(groomers[0].businessName, "South LA Curl & Calm");
});

test("parses CLI options without treating flags as values", () => {
  const options = parseOptions([
    "backend",
    "--scenario",
    "marketplace_full_lifecycle",
    "--matrix",
    "smoke5",
    "--run-id",
    "TESTOPS-LOCAL",
    "--execute",
    "--cleanup",
    "--customer",
    "--groomer",
    "GTG-001",
  ]);

  assert.equal(options.get("scenario"), "marketplace_full_lifecycle");
  assert.equal(options.get("matrix"), "smoke5");
  assert.equal(options.get("run-id"), "TESTOPS-LOCAL");
  assert.equal(options.get("execute"), true);
  assert.equal(options.get("cleanup"), true);
  assert.equal(options.get("customer"), true);
  assert.equal(options.get("groomer"), "GTG-001");
});

test("default backend plan remains the first customer and first groomer", () => {
  const customers = parseCustomerProfiles(customerResource);
  const groomers = parseGroomerProfiles(groomerResource);
  const plan = makeBackendPlans({
    scenarioID: DEFAULT_SCENARIO,
    runID: "TESTOPS-DEFAULT",
    customerProfiles: customers,
    groomerProfiles: groomers,
  })[0];

  assert.equal(plan.runID, "TESTOPS-DEFAULT");
  assert.equal(plan.caseID, "TC-MKT-001");
  assert.equal(plan.customer.seedID, "GTC-001");
  assert.equal(plan.groomer.seedID, "GTG-001");
  assert.equal(plan.request.serviceType, "full_groom");
  assert.equal(plan.request.locationMode, "customer_comes_to_groomer");
  assert.equal(plan.request.travelRadiusMiles, 15);
  assert.match(plan.request.serviceNotes, /^TESTOPS:TESTOPS-DEFAULT /);
  assert.ok(Date.parse(plan.request.preferredStart) > Date.now());
});

test("smoke5 matrix produces fixed unique case run tags", () => {
  const customers = parseCustomerProfiles(customerResource);
  const groomers = parseGroomerProfiles(groomerResource);
  const plans = makeBackendPlans({
    scenarioID: DEFAULT_SCENARIO,
    matrix: "smoke5",
    runID: "TESTOPS-MATRIX",
    customerProfiles: customers,
    groomerProfiles: groomers,
  });

  assert.equal(plans.length, 5);
  assert.deepEqual(
    plans.map((plan) => plan.caseID),
    SMOKE5_CASES.map((entry) => entry.caseID)
  );
  assert.deepEqual(
    plans.map((plan) => `${plan.customer.seedID}+${plan.groomer.seedID}`),
    [
      "GTC-001+GTG-001",
      "GTC-003+GTG-003",
      "GTC-004+GTG-004",
      "GTC-016+GTG-006",
      "GTC-049+GTG-041",
    ]
  );
  assert.equal(new Set(plans.map((plan) => plan.runID)).size, 5);
  assert.ok(plans.every((plan) => plan.runID.startsWith("TESTOPS-MATRIX-TC-MKT-")));
  assert.ok(plans.every((plan) => plan.request.serviceNotes.includes(`TESTOPS:${plan.runID}`)));
  assert.ok(plans.every((plan) => plan.request.travelRadiusMiles === 15));
});

test("plan generation rejects unsupported scenarios and unknown seeds", () => {
  const customers = parseCustomerProfiles(customerResource);
  const groomers = parseGroomerProfiles(groomerResource);

  assert.throws(
    () =>
      makeBackendPlans({
        scenarioID: "unsupported_scenario",
        customerProfiles: customers,
        groomerProfiles: groomers,
      }),
    /Unsupported scenario: unsupported_scenario/
  );
  assert.throws(
    () =>
      makeBackendPlans({
        scenarioID: DEFAULT_SCENARIO,
        customerSeedID: "GTC-999",
        customerProfiles: customers,
        groomerProfiles: groomers,
      }),
    /Could not find seed GTC-999/
  );
  assert.throws(
    () =>
      makeBackendPlans({
        scenarioID: DEFAULT_SCENARIO,
        groomerSeedID: "GTG-999",
        customerProfiles: customers,
        groomerProfiles: groomers,
      }),
    /Could not find seed GTG-999/
  );
});

test("plan redaction removes credentials and full emails", () => {
  const customers = parseCustomerProfiles(customerResource);
  const groomers = parseGroomerProfiles(groomerResource);
  const plan = makeBackendPlan({
    runID: "TESTOPS-REDACT",
    scenarioID: DEFAULT_SCENARIO,
    caseID: "TC-MKT-001",
    customer: customers[0],
    groomer: groomers[0],
  });

  const serialized = JSON.stringify(redactedPlan(plan));

  assert.match(serialized, /"emailDomain":"example.com"/);
  assert.doesNotMatch(serialized, /GroomlyTest!2026/);
  assert.doesNotMatch(serialized, /groomly\.customer001@example\.com/);
  assert.doesNotMatch(serialized, /groomly\.groomer001@example\.com/);
});

test("lifecycle result redaction replaces full entity UUIDs with support refs", () => {
  const redacted = redactedResult({
    runID: "TESTOPS-REDACT-RESULT",
    scenarioID: DEFAULT_SCENARIO,
    caseID: "TC-MKT-001",
    startedAt: "2026-07-09T00:00:00Z",
    finishedAt: "2026-07-09T00:01:00Z",
    customer: { seedID: "GTC-001", userRef: "AAAAAAAA", emailDomain: "example.com" },
    groomer: { seedID: "GTG-001", userRef: "BBBBBBBB", emailDomain: "example.com" },
    ids: {
      requestID: "11111111-1111-4111-8111-111111111111",
      offerID: "22222222-2222-4222-8222-222222222222",
      bookingID: "33333333-3333-4333-8333-333333333333",
      reviewID: "44444444-4444-4444-8444-444444444444",
    },
    matchCount: 1,
    phases: [],
    verification: { bookingStatus: "completed" },
    cleanup: { requestCount: 1 },
  });
  const serialized = JSON.stringify(redacted);

  assert.deepEqual(redacted.ids, {
    requestID: "11111111",
    offerID: "22222222",
    bookingID: "33333333",
    reviewID: "44444444",
  });
  assert.doesNotMatch(serialized, /[0-9a-f]{8}-[0-9a-f-]{27}/i);
});

test("remote write approval rejects execution without the explicit env gate", () => {
  assert.throws(
    () => requireRemoteWriteApproval({ TESTOPS_REMOTE_WRITE_APPROVED: "0" }),
    /TESTOPS_REMOTE_WRITE_APPROVED=1 is required/
  );
  assert.doesNotThrow(() =>
    requireRemoteWriteApproval({ TESTOPS_REMOTE_WRITE_APPROVED: "1" })
  );
});

test("cleanup plan is run-id scoped and dry-run friendly", () => {
  const plan = buildCleanupPlan("TESTOPS-CLEANUP");

  assert.equal(plan.runID, "TESTOPS-CLEANUP");
  assert.equal(plan.tag, "TESTOPS:TESTOPS-CLEANUP");
  assert.deepEqual(plan.deleteOrder, [
    "messages",
    "conversations",
    "review_pet_fit_outcomes",
    "reviews",
    "bookings",
    "request_photos",
    "groomer_offers",
    "request_matches",
    "grooming_requests",
  ]);
});

test("report and error text are sanitized", () => {
  const unsafeError = new Error(
    "token abc password secret user groomly.customer001@example.com id 123e4567-e89b-12d3-a456-426614174000"
  );
  const message = safeErrorMessage(unsafeError);

  assert.doesNotMatch(message, /groomly\.customer001@example\.com/);
  assert.doesNotMatch(message, /secret/);
  assert.doesNotMatch(message, /123e4567-e89b-12d3-a456-426614174000/);
  assert.match(message, /\[email-domain:example\.com\]/);

  const report = renderReport({
    runID: "TESTOPS-REPORT",
    scenarioID: DEFAULT_SCENARIO,
    startedAt: "2026-07-01T00:00:00.000Z",
    finishedAt: "2026-07-01T00:01:00.000Z",
    customer: {
      seedID: "GTC-001",
      userRef: "123E4567",
      email: "groomly.customer001@example.com",
      password: "GroomlyTest!2026",
    },
    groomer: {
      seedID: "GTG-001",
      userRef: "223E4567",
      email: "groomly.groomer001@example.com",
      password: "GroomlyTest!2026",
    },
    ids: {
      requestID: "123e4567-e89b-12d3-a456-426614174000",
      offerID: "223e4567-e89b-12d3-a456-426614174000",
      bookingID: "323e4567-e89b-12d3-a456-426614174000",
      reviewID: "423e4567-e89b-12d3-a456-426614174000",
    },
    matchCount: 2,
    verification: {
      requestStatus: "booked",
      offerStatus: "accepted",
      bookingStatus: "completed",
      reviewCount: 1,
    },
    phases: [
      {
        phase: "customer.signIn",
        status: "failed",
        durationMs: 15,
        error: "password secret token abc groomly.customer001@example.com",
      },
    ],
  });

  assert.doesNotMatch(report, /GroomlyTest!2026/);
  assert.doesNotMatch(report, /groomly\.customer001@example\.com/);
  assert.doesNotMatch(report, /123e4567-e89b-12d3-a456-426614174000/);
  assert.match(report, /123E4567/);
});
