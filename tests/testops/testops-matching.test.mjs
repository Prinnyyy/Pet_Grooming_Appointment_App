import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import {
  MATCHING_BASELINE_CASES,
  MATCHING_SCENARIO,
  MATCHING_RADIUS_CASES,
  MATCHING_RADIUS_MATRIX,
  destinationCoordinateWGS84,
  makeMatchingPlans,
  parseCustomerProfiles,
  parseGroomerProfiles,
  projectMatchingCandidates,
  redactedMatchingPlan,
  redactedMatchingResult,
  renderMatchingReport,
  runMatchingEvaluation,
  writeMatchingArtifacts,
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

test("matching baseline plans cover positive, same-day, and hard-filter cases", () => {
  const plans = makeMatchingPlans({
    scenarioID: MATCHING_SCENARIO,
    matrix: "matching_baseline",
    runID: "TESTOPS-MATCH",
    customerProfiles: parseCustomerProfiles(customerResource),
    groomerProfiles: parseGroomerProfiles(groomerResource),
  });

  assert.equal(plans.length, MATCHING_BASELINE_CASES.length);
  assert.equal(plans[0].caseID, "TC-MATCH-001");
  assert.equal(plans[0].expectation.targetShouldMatch, true);
  assert.ok(plans.some((plan) => plan.expectation.reasonIncludes.includes("Preferred time fits")));
  assert.ok(
    plans.some((plan) =>
      plan.expectation.reasonIncludes.includes("Can suggest another time on your preferred day")
    )
  );
  assert.ok(plans.some((plan) => plan.expectation.targetShouldMatch === false));
  assert.equal(new Set(plans.map((plan) => plan.runID)).size, plans.length);
  assert.ok(plans.every((plan) => plan.runID.startsWith("TESTOPS-MATCH-TC-MATCH-")));
  assert.ok(plans.every((plan) => plan.request.serviceNotes.includes(`TESTOPS:${plan.runID}`)));

  const serialized = JSON.stringify(plans.map(redactedMatchingPlan));
  assert.doesNotMatch(serialized, /BeckonTest!2026/);
  assert.doesNotMatch(serialized, /beckon\.customer001@example\.com/);
  assert.doesNotMatch(serialized, /beckon\.groomer001@example\.com/);
  assert.match(serialized, /"emailDomain":"example.com"/);
});

test("radius matrix covers near, edge, and outside for both service directions", () => {
  const plans = makeMatchingPlans({
    scenarioID: MATCHING_SCENARIO,
    matrix: MATCHING_RADIUS_MATRIX,
    runID: "TESTOPS-RADIUS",
    customerProfiles: parseCustomerProfiles(customerResource),
    groomerProfiles: parseGroomerProfiles(groomerResource),
  });
  assert.equal(plans.length, MATCHING_RADIUS_CASES.length);
  assert.deepEqual(new Set(plans.map((plan) => plan.radius.boundary)), new Set(["near", "edge", "outside"]));
  assert.deepEqual(
    new Set(plans.map((plan) => plan.request.locationMode)),
    new Set(["customer_comes_to_groomer", "groomer_comes_to_customer"]),
  );
  assert.ok(plans.filter((plan) => plan.radius.boundary === "outside").every(
    (plan) => plan.expectation.targetShouldMatch === false,
  ));
});

test("WGS84 projection produces finite coordinates at the requested distance", () => {
  const origin = { latitude: 33.8703, longitude: -117.9242 };
  const projected = destinationCoordinateWGS84(origin, 12, 0);
  assert.ok(Number.isFinite(projected.latitude));
  assert.ok(Number.isFinite(projected.longitude));
  assert.ok(projected.latitude > origin.latitude);
  assert.ok(Math.abs(projected.longitude - origin.longitude) < 0.001);
});

test("matching seed parsing exposes pet and groomer fit metadata", () => {
  const customers = parseCustomerProfiles(customerResource);
  const groomers = parseGroomerProfiles(groomerResource);
  const firstDog = customers[0].pets.find((pet) => pet.species === "Dog");
  const firstGroomer = groomers[0];

  assert.deepEqual(
    {
      name: firstDog.name,
      breed: firstDog.breed,
      coatType: firstDog.coatType,
      size: firstDog.size,
    },
    {
      name: "Mochi",
      breed: "Toy Poodle",
      coatType: "curly_wavy",
      size: "XS",
    }
  );
  assert.deepEqual(firstGroomer.location.modes, [
    "groomer_comes_to_customer",
    "customer_comes_to_groomer",
  ]);
  assert.equal(firstGroomer.location.radiusMiles, 12);
  assert.ok(firstGroomer.sizeBands.includes("XL"));
  assert.ok(firstGroomer.services.some((service) => service.serviceType === "full_groom"));
  assert.ok(
    firstGroomer.fitClaims.some(
      (claim) => claim.traitType === "coat_type" && claim.traitValue === "curly_wavy"
    )
  );
});

test("local matching projection explains service, mode, and availability exclusions", () => {
  const groomers = parseGroomerProfiles(groomerResource);
  const plans = makeMatchingPlans({
    scenarioID: MATCHING_SCENARIO,
    matrix: "matching_baseline",
    runID: "TESTOPS-MATCH-PROJECT",
    customerProfiles: parseCustomerProfiles(customerResource),
    groomerProfiles: groomers,
  });

  const positive = projectMatchingCandidates(
    plans.find((plan) => plan.caseID === "TC-MATCH-001"),
    groomers
  );
  assert.equal(positive.target.eligible, true);
  assert.ok(positive.candidates.length >= 1);

  const serviceMismatch = projectMatchingCandidates(
    plans.find((plan) => plan.caseID === "TC-MATCH-006"),
    groomers
  );
  assert.equal(serviceMismatch.target.eligible, false);
  assert.ok(serviceMismatch.target.excludedReasons.includes("service_type_mismatch"));

  const modeMismatch = projectMatchingCandidates(
    plans.find((plan) => plan.caseID === "TC-MATCH-007"),
    groomers
  );
  assert.equal(modeMismatch.target.eligible, false);
  assert.ok(modeMismatch.target.excludedReasons.includes("location_mode_mismatch"));

  const unavailableDay = projectMatchingCandidates(
    plans.find((plan) => plan.caseID === "TC-MATCH-008"),
    groomers
  );
  assert.equal(unavailableDay.target.eligible, false);
  assert.ok(unavailableDay.target.excludedReasons.includes("request_day_unavailable"));
});

test("matching evaluation passes positive and negative target assertions", async () => {
  const [positivePlan, negativePlan] = makeMatchingPlans({
    scenarioID: MATCHING_SCENARIO,
    matrix: "matching_baseline",
    runID: "TESTOPS-MATCH-EVAL",
    customerProfiles: parseCustomerProfiles(customerResource),
    groomerProfiles: parseGroomerProfiles(groomerResource),
  });
  const positiveResult = await runMatchingEvaluation(fakeMatchingAPI({
    targetGroomerID: "groomer-positive",
    targetShouldAppear: true,
    matchReason: "Same state and service location. Preferred time fits. Groomer fit signals: self-claimed fit.",
  }), positivePlan);

  assert.equal(positiveResult.assertions.targetMatch, "passed");
  assert.equal(positiveResult.target.matched, true);
  assert.equal(positiveResult.matchCount, 3);

  const negativeResult = await runMatchingEvaluation(fakeMatchingAPI({
    targetGroomerID: "groomer-negative",
    targetShouldAppear: false,
    matchReason: "Same state and service location. Preferred time fits.",
  }), {
    ...negativePlan,
    expectation: {
      ...negativePlan.expectation,
      targetShouldMatch: false,
      reasonIncludes: [],
    },
  });

  assert.equal(negativeResult.assertions.targetMatch, "passed");
  assert.equal(negativeResult.target.matched, false);
});

test("radius evaluation reads the owner coordinate and publishes through request v2", async () => {
  const [plan] = makeMatchingPlans({
    scenarioID: MATCHING_SCENARIO,
    matrix: MATCHING_RADIUS_MATRIX,
    runID: "TESTOPS-RADIUS-EVAL",
    customerProfiles: parseCustomerProfiles(customerResource),
    groomerProfiles: parseGroomerProfiles(groomerResource),
  });
  const calls = [];
  const api = {
    requireServiceRole: () => "service-token",
    async signIn(email) {
      return email.includes("customer")
        ? { user: { id: "customer-user" }, accessToken: "customer-token" }
        : { user: { id: "groomer-user" }, accessToken: "groomer-token" };
    },
    async restSelect(table) {
      if (table === "pets") return [{ id: "pet-1", species: "Dog", name: "Mochi" }];
      if (table === "request_matches") {
        return [{
          groomer_id: "groomer-user",
          match_score: 70,
          match_reason: "5.0 miles away, within the customer's 10-mile travel range. Preferred time fits",
          status: "visible",
        }];
      }
      throw new Error(`unexpected table ${table}`);
    },
    async rpc(name, params) {
      calls.push({ name, params });
      if (name === "get_my_groomer_profile_address_v2") {
        return [{ latitude: 33.87, longitude: -117.92 }];
      }
      if (name === "create_grooming_request_v2") {
        return [{ request_id: "123e4567-e89b-12d3-a456-426614174000", match_count: 1 }];
      }
      throw new Error(`unexpected rpc ${name}`);
    },
  };

  const result = await runMatchingEvaluation(api, plan);
  const create = calls.find((call) => call.name === "create_grooming_request_v2");
  assert.ok(create);
  assert.equal(create.params.p_resolution_source, "manual_geocode");
  assert.equal(create.params.p_travel_radius_miles, 10);
  assert.ok(Number.isFinite(create.params.p_latitude));
  assert.ok(Number.isFinite(create.params.p_longitude));
  assert.equal(result.assertions.targetMatch, "passed");
});

test("matching report redacts sensitive actor and identifier data", () => {
  const report = renderMatchingReport({
    runID: "TESTOPS-MATCH-REPORT",
    scenarioID: MATCHING_SCENARIO,
    caseID: "TC-MATCH-001",
    startedAt: "2026-07-02T00:00:00.000Z",
    finishedAt: "2026-07-02T00:01:00.000Z",
    customer: {
      seedID: "BTC-001",
      userRef: "123E4567",
      email: "beckon.customer001@example.com",
      password: "BeckonTest!2026",
    },
    targetGroomer: {
      seedID: "BTG-001",
      userRef: "223E4567",
      email: "beckon.groomer001@example.com",
      password: "BeckonTest!2026",
    },
    ids: {
      requestID: "123e4567-e89b-12d3-a456-426614174000",
    },
    matchCount: 2,
    target: {
      matched: true,
      matchScore: 86,
      matchReason: "Preferred time fits.",
    },
    assertions: {
      targetMatch: "passed",
      matchCount: "passed",
      reason: "passed",
    },
    phases: [
      {
        phase: "customer.signIn",
        status: "failed",
        durationMs: 15,
        error: "password secret token abc beckon.customer001@example.com",
      },
    ],
  });

  assert.doesNotMatch(report, /BeckonTest!2026/);
  assert.doesNotMatch(report, /beckon\.customer001@example\.com/);
  assert.doesNotMatch(report, /123e4567-e89b-12d3-a456-426614174000/);
  assert.match(report, /123E4567/);
});

test("matching result and JSON artifact redact the request UUID", () => {
  const fullUUID = "123e4567-e89b-12d3-a456-426614174000";
  const result = {
    runID: "TESTOPS-MATCH-REDACT",
    scenarioID: MATCHING_SCENARIO,
    caseID: "TC-MATCH-001",
    startedAt: "2026-07-09T00:00:00Z",
    finishedAt: "2026-07-09T00:01:00Z",
    customer: { seedID: "BTC-001", userRef: "AAAAAAAA", emailDomain: "example.com" },
    targetGroomer: { seedID: "BTG-001", userRef: "BBBBBBBB", emailDomain: "example.com" },
    pet: { name: "Mochi", breed: "Toy Poodle", coatType: "curly_wavy", size: "XS" },
    ids: { requestID: fullUUID },
    matchCount: 1,
    target: { matched: true, matchScore: 3, matchReason: "Preferred time fits" },
    assertions: { targetMatch: "passed" },
    phases: [],
    cleanup: { requestCount: 1 },
  };
  const redacted = redactedMatchingResult(result);
  const artifactDir = fs.mkdtempSync(path.join(os.tmpdir(), "testops-matching-artifact-"));
  const { jsonPath } = writeMatchingArtifacts(result, artifactDir);
  const artifact = fs.readFileSync(jsonPath, "utf8");

  assert.equal(redacted.ids.requestID, "123E4567");
  assert.doesNotMatch(JSON.stringify(redacted), new RegExp(fullUUID, "i"));
  assert.doesNotMatch(artifact, new RegExp(fullUUID, "i"));
});

function fakeMatchingAPI({ targetGroomerID, targetShouldAppear, matchReason }) {
  return {
    requireServiceRole() {
      return "service-role-token";
    },
    async signIn(email) {
      if (email.includes("customer")) {
        return { user: { id: "customer-user" }, accessToken: "customer-token" };
      }
      return { user: { id: targetGroomerID }, accessToken: "groomer-token" };
    },
    async restSelect(table) {
      if (table === "pets") {
        return [{ id: "pet-1", species: "Dog", name: "Mochi" }];
      }
      if (table === "request_matches") {
        const rows = [
          {
            id: "match-1",
            groomer_id: "other-groomer",
            match_score: 76,
            match_reason: "Same state and service location.",
            status: "visible",
          },
        ];
        if (targetShouldAppear) {
          rows.push({
            id: "match-2",
            groomer_id: targetGroomerID,
            match_score: 88,
            match_reason: matchReason,
            status: "visible",
          });
        }
        return rows;
      }
      throw new Error(`unexpected table ${table}`);
    },
    async rpc(name) {
      if (name === "get_my_groomer_profile_address_v2") {
        return [{ latitude: 33.8703, longitude: -117.9242 }];
      }
      if (name === "create_grooming_request_v2") {
        return [{ request_id: "123e4567-e89b-12d3-a456-426614174000", match_count: 3 }];
      }
      throw new Error(`unexpected rpc ${name}`);
    },
  };
}
