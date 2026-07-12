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
export const MATCHING_SCENARIO = "request_matching_eval";
export const MATCHING_BASELINE_MATRIX = "matching_baseline";
export const MATCHING_RADIUS_MATRIX = "matching_radius";
export const REMOTE_WRITE_ENV = "TESTOPS_REMOTE_WRITE_APPROVED";
export const SERVICE_ROLE_KEY_ENV = ["SUPABASE", "SERVICE", "ROLE", "KEY"].join("_");
const SIZE_ORDER = ["XS", "S", "M", "L", "XL", "XXL", "Giant"];
const LOCATION_MODES = {
  mobile: ["groomer_comes_to_customer"],
  studio: ["customer_comes_to_groomer"],
  both: ["groomer_comes_to_customer", "customer_comes_to_groomer"],
};
const WEEKDAYS = new Map([
  ["Mon", 1],
  ["Tue", 2],
  ["Wed", 3],
  ["Thu", 4],
  ["Fri", 5],
  ["Sat", 6],
  ["Sun", 7],
]);

export const SMOKE5_CASES = [
  {
    caseID: "TC-MKT-001",
    customerSeedID: "BTC-001",
    groomerSeedID: "BTG-001",
    purpose: "default LA curly coat full lifecycle",
    preferredWeekdays: [1, 2, 3, 4, 5],
  },
  {
    caseID: "TC-MKT-002",
    customerSeedID: "BTC-003",
    groomerSeedID: "BTG-003",
    purpose: "wire terrier studio full lifecycle",
    preferredWeekdays: [3, 4, 5, 6, 0],
  },
  {
    caseID: "TC-MKT-003",
    customerSeedID: "BTC-004",
    groomerSeedID: "BTG-004",
    purpose: "small drop-coat full lifecycle",
    preferredWeekdays: [1, 2, 3, 4, 6],
  },
  {
    caseID: "TC-MKT-004",
    customerSeedID: "BTC-016",
    groomerSeedID: "BTG-006",
    purpose: "larger double-coat full lifecycle",
    preferredWeekdays: [1, 2, 3, 4, 5],
  },
  {
    caseID: "TC-MKT-005",
    customerSeedID: "BTC-049",
    groomerSeedID: "BTG-041",
    purpose: "Orange County curly full lifecycle",
    preferredWeekdays: [2, 3, 4, 5, 6],
  },
];

export const MATCHING_BASELINE_CASES = [
  {
    caseID: "TC-MATCH-001",
    customerSeedID: "BTC-001",
    targetGroomerSeedID: "BTG-001",
    purpose: "curly Toy Poodle exact preferred window should reach a curly/full-groom groomer",
    serviceType: "full_groom",
    locationMode: "customer_comes_to_groomer",
    timing: "exact_daytime",
    preferredWeekdays: [1, 2, 3, 4, 5],
    targetShouldMatch: true,
    reasonIncludes: ["Preferred time fits"],
  },
  {
    caseID: "TC-MATCH-002",
    customerSeedID: "BTC-001",
    targetGroomerSeedID: "BTG-001",
    purpose: "curly Toy Poodle late preferred window should still reach same-day-capacity groomer",
    serviceType: "full_groom",
    locationMode: "customer_comes_to_groomer",
    timing: "same_day_late",
    preferredWeekdays: [1, 2, 3, 4, 5],
    targetShouldMatch: true,
    reasonIncludes: ["Can suggest another time on your preferred day"],
  },
  {
    caseID: "TC-MATCH-003",
    customerSeedID: "BTC-003",
    targetGroomerSeedID: "BTG-003",
    purpose: "wire Miniature Schnauzer should reach a wire/terrier studio groomer",
    serviceType: "full_groom",
    locationMode: "customer_comes_to_groomer",
    timing: "exact_daytime",
    preferredWeekdays: [3, 4, 5, 6, 0],
    targetShouldMatch: true,
    reasonIncludes: ["Preferred time fits"],
  },
  {
    caseID: "TC-MATCH-004",
    customerSeedID: "BTC-016",
    targetGroomerSeedID: "BTG-006",
    purpose: "large double-coat German Shepherd should reach a large-dog coat-care groomer",
    serviceType: "full_groom",
    locationMode: "customer_comes_to_groomer",
    timing: "exact_daytime",
    preferredWeekdays: [1, 2, 3, 4, 5],
    targetShouldMatch: true,
    reasonIncludes: ["Preferred time fits"],
  },
  {
    caseID: "TC-MATCH-005",
    customerSeedID: "BTC-049",
    targetGroomerSeedID: "BTG-041",
    purpose: "Orange County Standard Poodle should reach an OC curly/full-groom groomer",
    serviceType: "full_groom",
    locationMode: "customer_comes_to_groomer",
    timing: "exact_daytime",
    preferredWeekdays: [2, 3, 4, 5, 6],
    targetShouldMatch: true,
    reasonIncludes: ["Preferred time fits"],
  },
  {
    caseID: "TC-MATCH-006",
    customerSeedID: "BTC-002",
    targetGroomerSeedID: "BTG-002",
    purpose: "service hard filter should exclude a groomer without full_groom service",
    serviceType: "full_groom",
    locationMode: "groomer_comes_to_customer",
    timing: "exact_daytime",
    preferredWeekdays: [2, 3, 4, 5, 6],
    targetShouldMatch: false,
    excludedBy: "service_type_mismatch",
  },
  {
    caseID: "TC-MATCH-007",
    customerSeedID: "BTC-001",
    targetGroomerSeedID: "BTG-005",
    purpose: "location-mode hard filter should exclude mobile-only groomer for studio request",
    serviceType: "full_groom",
    locationMode: "customer_comes_to_groomer",
    timing: "exact_daytime",
    preferredWeekdays: [1, 2, 3, 4, 5],
    targetShouldMatch: false,
    excludedBy: "location_mode_mismatch",
  },
  {
    caseID: "TC-MATCH-008",
    customerSeedID: "BTC-001",
    targetGroomerSeedID: "BTG-001",
    purpose: "request-day hard filter should exclude a groomer without enabled availability that day",
    serviceType: "full_groom",
    locationMode: "customer_comes_to_groomer",
    timing: "exact_daytime",
    preferredWeekdays: [0],
    targetShouldMatch: false,
    excludedBy: "request_day_unavailable",
  },
];

export const MATCHING_RADIUS_CASES = [
  radiusCase("TC-RADIUS-001", "customer_comes_to_groomer", "near", 5, 10, true),
  radiusCase("TC-RADIUS-002", "customer_comes_to_groomer", "edge", 9.999, 10, true),
  radiusCase("TC-RADIUS-003", "customer_comes_to_groomer", "outside", 10.25, 10, false),
  radiusCase("TC-RADIUS-004", "groomer_comes_to_customer", "near", 5, null, true),
  radiusCase("TC-RADIUS-005", "groomer_comes_to_customer", "edge", 11.999, null, true),
  radiusCase("TC-RADIUS-006", "groomer_comes_to_customer", "outside", 12.25, null, false),
];

function radiusCase(caseID, locationMode, boundary, distanceMiles, travelRadiusMiles, targetShouldMatch) {
  const controllingRadius = locationMode === "customer_comes_to_groomer" ? 10 : 12;
  const reasonLabel = locationMode === "customer_comes_to_groomer"
    ? "customer's 10-mile travel range"
    : "groomer's 12-mile service range";
  return {
    caseID,
    customerSeedID: "BTC-001",
    targetGroomerSeedID: "BTG-001",
    purpose: `${boundary} ${locationMode} PostGIS radius boundary`,
    serviceType: "full_groom",
    locationMode,
    timing: "exact_daytime",
    preferredWeekdays: [1, 2, 3, 4, 5],
    targetShouldMatch,
    reasonIncludes: targetShouldMatch ? ["miles away", reasonLabel] : [],
    radius: { boundary, distanceMiles, controllingRadius, travelRadiusMiles },
  };
}

export function parseCustomerProfiles(filePath = CUSTOMER_RESOURCE) {
  const markdown = fs.readFileSync(filePath, "utf8");
  const profiles = markdown
    .split(/\r?\n/)
    .filter((line) => line.startsWith("| BTC-"))
    .map((line) => {
      const cells = cellsFromRow(line, 7);
      const [seedID, email, password, nicknameContact, addressValue, dogValue, catValue] = cells;
      const [nickname] = nicknameContact.split(" / ").map((value) => value.trim());
      return {
        seedID,
        email,
        password,
        displayName: nickname,
        address: parseAddress(addressValue),
        pets: [parsePet(dogValue, "Dog"), parsePet(catValue, "Cat")],
      };
    });
  validateSeedProfiles(profiles, "customer");
  return profiles;
}

export function parseGroomerProfiles(filePath = GROOMER_RESOURCE) {
  const markdown = fs.readFileSync(filePath, "utf8");
  const profiles = markdown
    .split(/\r?\n/)
    .filter((line) => line.startsWith("| BTG-"))
    .map((line) => {
      const cells = cellsFromRow(line, 12);
      const [
        seedID,
        email,
        password,
        displayBusiness,
        ,
        addressValue,
        modesRadius,
        ,
        sizeExperience,
        fitSignals,
        availability,
        services,
      ] = cells;
      const [displayName, businessName] = displayBusiness
        .split(" / ")
        .map((value) => value.trim());
      const sizeBands = expandSizeExperience(sizeExperience);
      const fitClaims = uniqueClaims([
        ...fitSignals.split(";").map((entry) => parseFitSignal(entry.trim())),
        ...sizeBands.map((size) => ({ traitType: "size_band", traitValue: size })),
      ]);
      const availabilityPlan = parseAvailabilitySafe(availability);
      return {
        seedID,
        email,
        password,
        displayName,
        businessName,
        address: parseAddress(addressValue),
        location: parseModesRadius(modesRadius),
        sizeExperience,
        sizeBands,
        fitClaims,
        availabilityWindows: availabilityPlan.windows,
        bookingPreferences: availabilityPlan.preferences,
        services: services.split(";").map((entry) => parseService(entry.trim())),
      };
    });
  validateSeedProfiles(profiles, "groomer");
  return profiles;
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

export function requiredServerCredential(env = process.env) {
  const value = env[SERVICE_ROLE_KEY_ENV]?.trim() || env.SUPABASE_SECRET_KEY?.trim();
  if (!value) {
    throw new Error(`${SERVICE_ROLE_KEY_ENV} or SUPABASE_SECRET_KEY is required.`);
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

export function serverCredentialStatus(env = process.env) {
  return envStatus(SERVICE_ROLE_KEY_ENV, env) === "set"
      || envStatus("SUPABASE_SECRET_KEY", env) === "set"
    ? "set"
    : "not set";
}

export function makeBackendPlans({
  scenarioID = DEFAULT_SCENARIO,
  matrix,
  runID,
  customerSeedID = "BTC-001",
  groomerSeedID = "BTG-001",
  customerProfiles = parseCustomerProfiles(),
  groomerProfiles = parseGroomerProfiles(),
} = {}) {
  assertSupportedScenario(scenarioID);

  if (matrix) {
    if (matrix !== "smoke5") {
      throw new Error(`Unsupported matrix: ${matrix}`);
    }

    const baseRunID = validateRunID(runID ?? makeRunID());
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
      runID: validateRunID(runID ?? makeRunID()),
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
  validateRunID(runID);
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

export function makeMatchingPlans({
  scenarioID = MATCHING_SCENARIO,
  matrix = MATCHING_BASELINE_MATRIX,
  runID,
  customerProfiles = parseCustomerProfiles(),
  groomerProfiles = parseGroomerProfiles(),
} = {}) {
  assertSupportedMatchingScenario(scenarioID);
  if (![MATCHING_BASELINE_MATRIX, MATCHING_RADIUS_MATRIX].includes(matrix)) {
    throw new Error(`Unsupported matching matrix: ${matrix}`);
  }

  const baseRunID = validateRunID(runID ?? makeRunID());
  const cases = matrix === MATCHING_RADIUS_MATRIX
    ? MATCHING_RADIUS_CASES
    : MATCHING_BASELINE_CASES;
  return cases.map((entry) =>
    makeMatchingPlan({
      runID: `${baseRunID}-${entry.caseID}`,
      scenarioID,
      entry,
      customer: requireSeed(customerProfiles, entry.customerSeedID),
      targetGroomer: requireSeed(groomerProfiles, entry.targetGroomerSeedID),
    })
  );
}

export function makeMatchingPlan({
  runID,
  scenarioID = MATCHING_SCENARIO,
  entry,
  customer,
  targetGroomer,
}) {
  assertSupportedMatchingScenario(scenarioID);
  validateRunID(runID);
  const pet = selectDogPet(customer, entry.petName);
  const slot = matchingSlot(entry.preferredWeekdays, entry.timing);
  const travelRadiusMiles = entry.radius?.travelRadiusMiles
    ?? (entry.locationMode === "customer_comes_to_groomer" ? 15 : null);

  return {
    runID,
    scenarioID,
    caseID: entry.caseID,
    purpose: entry.purpose,
    customer,
    pet,
    targetGroomer,
    request: {
      serviceType: entry.serviceType,
      serviceNotes: `TESTOPS:${runID} ${scenarioID} ${entry.caseID} matching evaluation request.`,
      preferredStart: slot.preferredStart,
      preferredEnd: slot.preferredEnd,
      locationMode: entry.locationMode,
      streetAddress: customer.address.street,
      city: customer.address.city,
      state: customer.address.state,
      zipCode: customer.address.zip,
      travelRadiusMiles,
    },
    timing: {
      kind: entry.timing,
      localISOWeekday: slot.localISOWeekday,
      localStartTime: slot.localStartTime,
      localEndTime: slot.localEndTime,
    },
    radius: entry.radius ?? null,
    expectation: {
      targetGroomerSeedID: entry.targetGroomerSeedID,
      targetShouldMatch: entry.targetShouldMatch,
      minimumMatchCount: entry.targetShouldMatch ? 1 : 0,
      reasonIncludes: entry.reasonIncludes ?? [],
      excludedBy: entry.excludedBy ?? null,
    },
  };
}

export function projectMatchingCandidates(plan, groomerProfiles = parseGroomerProfiles()) {
  const evaluated = groomerProfiles.map((groomer) => evaluateGroomerForPlan(plan, groomer));
  const candidates = evaluated.filter((entry) => entry.eligible);
  const excluded = evaluated.filter((entry) => !entry.eligible);
  const target =
    evaluated.find((entry) => entry.seedID === plan.expectation.targetGroomerSeedID)
      ?? {
        seedID: plan.expectation.targetGroomerSeedID,
        eligible: false,
        excludedReasons: ["target_not_found"],
        overlapTraits: [],
      };

  return {
    runID: plan.runID,
    caseID: plan.caseID,
    candidateCount: candidates.length,
    candidates,
    excluded,
    target,
  };
}

export async function runMatchingEvaluation(api, plan) {
  const startedAt = new Date().toISOString();
  const phases = [];
  const serviceToken = api.requireServiceRole();

  const customerSession = await timed(phases, "customer.signIn", () =>
    api.signIn(plan.customer.email, plan.customer.password)
  );
  const customerID = customerSession.user.id;

  const groomerSession = await timed(phases, "targetGroomer.signIn", () =>
    api.signIn(plan.targetGroomer.email, plan.targetGroomer.password)
  );
  const targetGroomerID = groomerSession.user.id;

  const pets = await timed(phases, "customer.loadPets", () =>
    api.restSelect(
      "pets",
      `select=id,name,species,breed,coat_type,weight_lbs&customer_id=eq.${customerID}&is_active=eq.true&order=created_at.asc`,
      customerSession.accessToken
    )
  );
  const dog =
    pets.find((candidate) => candidate.species === "Dog" && candidate.name === plan.pet.name)
      ?? pets.find((candidate) => candidate.species === "Dog")
      ?? pets[0];
  if (!dog) {
    throw new Error(`No active pet found for ${plan.customer.seedID}.`);
  }

  let requestRPC = "create_grooming_request";
  let requestParameters = {
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
  };
  if (plan.radius) {
    const rows = await timed(phases, "targetGroomer.loadAddress", () =>
      api.rpc("get_my_groomer_profile_address_v2", {}, groomerSession.accessToken)
    );
    const address = rows[0];
    if (!Number.isFinite(address?.latitude) || !Number.isFinite(address?.longitude)) {
      throw new Error(`${plan.targetGroomer.seedID} has no coordinate-backed profile.`);
    }
    const coordinate = destinationCoordinateWGS84(
      { latitude: address.latitude, longitude: address.longitude },
      plan.radius.distanceMiles,
      0,
    );
    requestRPC = "create_grooming_request_v2";
    requestParameters = {
      ...requestParameters,
      p_address_line_2: null,
      p_provider: "apple_maps",
      p_place_id: null,
      p_country_code: "US",
      p_latitude: coordinate.latitude,
      p_longitude: coordinate.longitude,
      p_resolution_source: "manual_geocode",
      p_user_confirmed_at: new Date().toISOString(),
    };
  }

  const requestRows = await timed(phases, "customer.createRequest", () =>
    api.rpc(
      requestRPC,
      requestParameters,
      customerSession.accessToken
    )
  );
  const requestID = firstValue(requestRows, "request_id");
  const matchCount = Number(firstValue(requestRows, "match_count") ?? 0);
  if (!requestID) {
    throw new Error(`${requestRPC} did not return request_id.`);
  }

  const matches = await timed(phases, "service.loadRequestMatches", () =>
    api.restSelect(
      "request_matches",
      `select=id,groomer_id,match_score,match_reason,status&request_id=eq.${requestID}&order=match_score.desc`,
      serviceToken
    )
  );
  const targetMatch =
    matches.find((match) => match.groomer_id === targetGroomerID) ?? null;
  const assertions = assertMatchingResult(plan, {
    requestID,
    matchCount,
    targetMatch,
  });

  return {
    runID: plan.runID,
    scenarioID: plan.scenarioID,
    caseID: plan.caseID,
    startedAt,
    finishedAt: new Date().toISOString(),
    customer: safeActor(plan.customer, customerID),
    targetGroomer: safeActor(plan.targetGroomer, targetGroomerID),
    pet: {
      name: plan.pet.name,
      breed: plan.pet.breed,
      coatType: plan.pet.coatType,
      size: plan.pet.size,
    },
    ids: { requestID },
    matchCount,
    target: {
      matched: Boolean(targetMatch),
      matchScore: targetMatch?.match_score ?? null,
      matchReason: targetMatch?.match_reason ?? null,
    },
    assertions,
    phases,
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
    throw new Error(`Request ${shortRef(requestID)} produced zero matches.`);
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
      `Selected groomer ${plan.groomer.seedID} did not receive request ${shortRef(requestID)}.`
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
  const summary = {
    runID,
    requestCount: requestIDs.length,
    deleted: {},
    remainingTaggedRequests: 0,
  };
  if (requestIDs.length === 0) {
    return summary;
  }

  summary.deleted.request_address_locations = 0;
  for (const requestID of requestIDs) {
    const deleted = await api.rpc(
      "cleanup_testops_request_address_location",
      { p_request_id: requestID, p_run_id: runID },
      serviceToken,
    );
    if (deleted === true) summary.deleted.request_address_locations += 1;
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

  const remainingRequests = await api.restSelect(
    "grooming_requests",
    `select=id&service_notes=ilike.*${encodeURIComponent(cleanupPlan.tag)}*`,
    serviceToken
  );
  summary.remainingTaggedRequests = remainingRequests.length;

  return summary;
}

export function buildCleanupPlan(runID) {
  validateRunID(runID);
  return {
    runID,
    tag: `TESTOPS:${runID}`,
    deleteOrder: [
      "request_address_locations",
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

export async function verifyUILifecycleRun(api, runID) {
  validateRunID(runID);
  const serviceToken = api.requireServiceRole();
  const tag = `TESTOPS:${runID}`;
  const requests = await api.restSelect(
    "grooming_requests",
    `select=id,status&service_notes=ilike.*${encodeURIComponent(tag)}*`,
    serviceToken
  );
  if (requests.length !== 1) {
    throw new Error(
      `Expected one tagged UI lifecycle request, found ${requests.length}.`
    );
  }

  const request = requests[0];
  if (request.status !== "booked") {
    throw new Error(`Expected booked request ${shortRef(request.id)}.`);
  }

  const matches = await api.restSelect(
    "request_matches",
    `select=id&request_id=eq.${request.id}`,
    serviceToken
  );
  if (matches.length < 1) {
    throw new Error(`Expected at least one match for request ${shortRef(request.id)}.`);
  }

  const offers = await api.restSelect(
    "groomer_offers",
    `select=id,status&request_id=eq.${request.id}&status=eq.accepted_by_customer`,
    serviceToken
  );
  if (offers.length !== 1 || offers[0].status !== "accepted_by_customer") {
    throw new Error(`Expected one accepted offer for request ${shortRef(request.id)}.`);
  }

  const bookings = await api.restSelect(
    "bookings",
    `select=id,status&request_id=eq.${request.id}`,
    serviceToken
  );
  if (bookings.length !== 1 || bookings[0].status !== "completed") {
    throw new Error(`Expected completed booking for request ${shortRef(request.id)}.`);
  }

  const booking = bookings[0];
  const conversations = await api.restSelect(
    "conversations",
    `select=id&request_id=eq.${request.id}&booking_id=eq.${booking.id}`,
    serviceToken
  );
  if (conversations.length !== 1) {
    throw new Error(`Expected one booking conversation for request ${shortRef(request.id)}.`);
  }

  const conversation = conversations[0];
  const messages = await api.restSelect(
    "messages",
    `select=id,body&conversation_id=eq.${conversation.id}&body=ilike.*${encodeURIComponent(tag)}*`,
    serviceToken
  );
  if (messages.length < 1) {
    throw new Error(`Expected tagged chat message for request ${shortRef(request.id)}.`);
  }

  const reviews = await api.restSelect(
    "reviews",
    `select=id,rating,content&booking_id=eq.${booking.id}&content=ilike.*${encodeURIComponent(tag)}*`,
    serviceToken
  );
  if (reviews.length !== 1 || reviews[0].rating !== 5) {
    throw new Error(`Expected one five-star review for request ${shortRef(request.id)}.`);
  }

  return {
    runID,
    requestRef: shortRef(request.id),
    offerRef: shortRef(offers[0].id),
    bookingRef: shortRef(booking.id),
    conversationRef: shortRef(conversation.id),
    requestStatus: request.status,
    offerStatus: offers[0].status,
    bookingStatus: booking.status,
    matchCount: matches.length,
    messageCount: messages.length,
    reviewCount: reviews.length,
  };
}

export function verifyUIDebugEvents(events, { runID, startedAt }) {
  validateRunID(runID);
  const startTime = Date.parse(startedAt);
  if (!Number.isFinite(startTime)) {
    throw new Error("Invalid UI debug verification start timestamp.");
  }

  const runRef = String(runID).slice(0, 12);
  const windowEvents = events.filter((event) => {
    const timestamp = Date.parse(event?.timestamp);
    return Number.isFinite(timestamp) && timestamp >= startTime;
  });
  const hasLaunchContext = windowEvents.some(
    (event) =>
      event.source === "AppDebugEventRecorder.configureTestOps"
      && event.message === "TestOps launch context configured"
      && event.metadata?.automationRunID === runRef
  );
  if (!hasLaunchContext) {
    throw new Error(`Missing TestOps debug launch context for ${runRef}.`);
  }

  const expectedSources = [
    "CustomerRequestsStore.publish",
    "GroomerRequestsStore.submitOffer",
    "CustomerRequestsStore.accept",
    "ChatStore.sendMessage",
    "BookingsStore.complete",
    "BookingsStore.createReview",
  ];
  const successSources = expectedSources.filter((source) =>
    windowEvents.some((event) => event.source === source && event.message === "success")
  );
  const missingSources = expectedSources.filter(
    (source) => !successSources.includes(source)
  );
  if (missingSources.length > 0) {
    throw new Error(`Missing UI debug success events: ${missingSources.join(", ")}.`);
  }

  const errors = windowEvents.filter((event) => event.level === "error");
  if (errors.length > 0) {
    const sources = [...new Set(errors.map((event) => event.source).filter(Boolean))];
    throw new Error(`UI debug log recorded ${errors.length} errors from ${sources.join(", ")}.`);
  }

  return {
    runRef,
    successSources,
    errorCount: errors.length,
  };
}

export class SupabaseREST {
  constructor(url, publishableKey, serviceRoleKey) {
    this.url = url.replace(/\/$/, "");
    this.publishableKey = publishableKey;
    this.serviceRoleKey = serviceRoleKey;
    this.serviceCredentialKind = serviceCredentialKind(serviceRoleKey);
    if (serviceRoleKey && this.serviceCredentialKind === "unsupported") {
      throw new Error(
        `${SERVICE_ROLE_KEY_ENV} must be a JWT-shaped legacy service-role key ` +
          "or a modern sb_secret service credential; public keys are not supported here."
      );
    }
  }

  async signIn(email, password) {
    const payload = await this.request(
      "/auth/v1/token?grant_type=password",
      {
        method: "POST",
        headers: this.headers(this.publishableKey),
        body: JSON.stringify({ email, password }),
      },
      "auth"
    );
    return {
      ...payload,
      accessToken: payload?.accessToken ?? payload?.access_token,
    };
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
    if (this.serviceCredentialKind === "unsupported") {
      throw new Error(
        `${SERVICE_ROLE_KEY_ENV} must be a JWT-shaped legacy service-role key ` +
          "or a modern sb_secret service credential; public keys are not supported here."
      );
    }
    return this.serviceRoleKey;
  }

  headers(accessToken, extra = {}) {
    const isServiceCredential =
      accessToken === this.serviceRoleKey && this.serviceCredentialKind !== "none";
    const headers = {
      apikey:
        isServiceCredential
          ? this.serviceRoleKey
          : this.publishableKey,
      "Content-Type": "application/json",
      ...extra,
    };
    if (!(isServiceCredential && this.serviceCredentialKind === "modern-secret")) {
      headers.Authorization = `Bearer ${accessToken}`;
    }
    return headers;
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

export function redactedMatchingPlan(plan) {
  const projection = projectMatchingCandidates(plan);
  return {
    runID: plan.runID,
    scenarioID: plan.scenarioID,
    caseID: plan.caseID,
    purpose: plan.purpose,
    customer: {
      seedID: plan.customer.seedID,
      emailDomain: emailDomain(plan.customer.email),
    },
    pet: {
      name: plan.pet.name,
      species: plan.pet.species,
      breed: plan.pet.breed,
      coatType: plan.pet.coatType,
      size: plan.pet.size,
    },
    targetGroomer: {
      seedID: plan.targetGroomer.seedID,
      emailDomain: emailDomain(plan.targetGroomer.email),
    },
    request: plan.request,
    timing: plan.timing,
    radius: plan.radius,
    expectation: plan.expectation,
    localProjection: {
      candidateCount: projection.candidateCount,
      target: projection.target,
    },
  };
}

export function destinationCoordinateWGS84(origin, distanceMiles, bearingDegrees = 0) {
  const a = 6_378_137;
  const flattening = 1 / 298.257223563;
  const b = (1 - flattening) * a;
  const distance = distanceMiles * 1_609.344;
  const alpha1 = bearingDegrees * Math.PI / 180;
  const phi1 = origin.latitude * Math.PI / 180;
  const lambda1 = origin.longitude * Math.PI / 180;
  const tanU1 = (1 - flattening) * Math.tan(phi1);
  const cosU1 = 1 / Math.sqrt(1 + tanU1 * tanU1);
  const sinU1 = tanU1 * cosU1;
  const sigma1 = Math.atan2(tanU1, Math.cos(alpha1));
  const sinAlpha = cosU1 * Math.sin(alpha1);
  const cosSqAlpha = 1 - sinAlpha * sinAlpha;
  const uSq = cosSqAlpha * (a * a - b * b) / (b * b);
  const A = 1 + uSq / 16_384 * (4_096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
  const B = uSq / 1_024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));
  let sigma = distance / (b * A);
  let previous;
  do {
    const twoSigmaM = 2 * sigma1 + sigma;
    const sinSigma = Math.sin(sigma);
    const cosSigma = Math.cos(sigma);
    const cosTwoSigmaM = Math.cos(twoSigmaM);
    const deltaSigma = B * sinSigma * (
      cosTwoSigmaM + B / 4 * (
        cosSigma * (-1 + 2 * cosTwoSigmaM ** 2)
          - B / 6 * cosTwoSigmaM * (-3 + 4 * sinSigma ** 2) * (-3 + 4 * cosTwoSigmaM ** 2)
      )
    );
    previous = sigma;
    sigma = distance / (b * A) + deltaSigma;
  } while (Math.abs(sigma - previous) > 1e-12);

  const sinSigma = Math.sin(sigma);
  const cosSigma = Math.cos(sigma);
  const twoSigmaM = 2 * sigma1 + sigma;
  const phi2 = Math.atan2(
    sinU1 * cosSigma + cosU1 * sinSigma * Math.cos(alpha1),
    (1 - flattening) * Math.sqrt(
      sinAlpha ** 2
        + (sinU1 * sinSigma - cosU1 * cosSigma * Math.cos(alpha1)) ** 2
    )
  );
  const lambda = Math.atan2(
    sinSigma * Math.sin(alpha1),
    cosU1 * cosSigma - sinU1 * sinSigma * Math.cos(alpha1)
  );
  const C = flattening / 16 * cosSqAlpha * (4 + flattening * (4 - 3 * cosSqAlpha));
  const L = lambda - (1 - C) * flattening * sinAlpha * (
    sigma + C * sinSigma * (
      Math.cos(twoSigmaM) + C * cosSigma * (-1 + 2 * Math.cos(twoSigmaM) ** 2)
    )
  );
  return {
    latitude: phi2 * 180 / Math.PI,
    longitude: (lambda1 + L) * 180 / Math.PI,
  };
}

export function redactedResult(result) {
  return {
    runID: result.runID,
    scenarioID: result.scenarioID,
    caseID: result.caseID,
    startedAt: result.startedAt,
    finishedAt: result.finishedAt,
    customer: result.customer,
    groomer: result.groomer,
    ids: redactedIDs(result.ids),
    matchCount: result.matchCount,
    phases: result.phases,
    verification: result.verification,
    cleanup: result.cleanup,
  };
}

export function redactedMatchingResult(result) {
  return {
    runID: result.runID,
    scenarioID: result.scenarioID,
    caseID: result.caseID,
    startedAt: result.startedAt,
    finishedAt: result.finishedAt,
    customer: result.customer,
    targetGroomer: result.targetGroomer,
    pet: result.pet,
    ids: redactedIDs(result.ids),
    matchCount: result.matchCount,
    target: result.target,
    assertions: result.assertions,
    phases: result.phases,
    cleanup: result.cleanup,
  };
}

export function writeArtifacts(result, artifactDir = ARTIFACT_DIR) {
  fs.mkdirSync(artifactDir, { recursive: true });
  const jsonPath = path.join(artifactDir, `${result.runID}.json`);
  const markdownPath = path.join(artifactDir, `${result.runID}.md`);
  const safeResult = redactedResult(result);
  fs.writeFileSync(jsonPath, `${JSON.stringify(safeResult, null, 2)}\n`);
  fs.writeFileSync(markdownPath, renderReport(safeResult));
  return { jsonPath, markdownPath };
}

export function writeMatchingArtifacts(result, artifactDir = ARTIFACT_DIR) {
  fs.mkdirSync(artifactDir, { recursive: true });
  const jsonPath = path.join(artifactDir, `${result.runID}.json`);
  const markdownPath = path.join(artifactDir, `${result.runID}.md`);
  const safeResult = redactedMatchingResult(result);
  fs.writeFileSync(jsonPath, `${JSON.stringify(safeResult, null, 2)}\n`);
  fs.writeFileSync(markdownPath, renderMatchingReport(safeResult));
  return { jsonPath, markdownPath };
}

function redactedIDs(ids = {}) {
  return Object.fromEntries(
    Object.entries(ids).map(([key, value]) => [key, shortRef(value)]),
  );
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

export function renderMatchingReport(result) {
  const phaseRows = result.phases
    .map((phase) =>
      `| ${phase.phase} | ${phase.status} | ${phase.durationMs} | ${safeErrorMessage(phase.error ?? "")} |`
    )
    .join("\n");
  return `# TestOps Matching Run ${result.runID}

| Field | Value |
|---|---|
| Scenario | ${result.scenarioID} |
| Case | ${result.caseID ?? ""} |
| Started | ${result.startedAt} |
| Finished | ${result.finishedAt} |
| Customer | ${result.customer.seedID} / ${result.customer.userRef} |
| Target Groomer | ${result.targetGroomer.seedID} / ${result.targetGroomer.userRef} |
| Pet | ${result.pet?.name ?? ""} / ${result.pet?.breed ?? ""} / ${result.pet?.coatType ?? ""} / ${result.pet?.size ?? ""} |
| Request | ${shortRef(result.ids.requestID)} |
| Match count | ${result.matchCount} |
| Target matched | ${result.target.matched ? "yes" : "no"} |
| Target score | ${result.target.matchScore ?? ""} |

## Assertions

\`\`\`json
${JSON.stringify(result.assertions, null, 2)}
\`\`\`

## Target Reason

${safeErrorMessage(result.target.matchReason ?? "")}

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
    .replace(/https:\/\/[^\s]+\/storage\/v1\/object\/sign\/[^\s]+/gi, "[signed-url]")
    .replace(/\bsb_secret_[A-Za-z0-9._+=/-]+/g, "[supabase-secret]")
    .replace(/\bsb_publishable_[A-Za-z0-9._+=/-]+/g, "[supabase-publishable]")
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, "[jwt]")
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

function matchingSlot(weekdays, kind) {
  const allowed = new Set(weekdays);
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + 4);
  while (!allowed.has(date.getUTCDay())) {
    date.setUTCDate(date.getUTCDate() + 1);
  }

  const year = date.getUTCFullYear();
  const month = date.getUTCMonth();
  const day = date.getUTCDate();
  const localISOWeekday = date.getUTCDay() === 0 ? 7 : date.getUTCDay();
  if (kind === "same_day_late") {
    return {
      preferredStart: new Date(Date.UTC(year, month, day, 23, 0, 0)).toISOString(),
      preferredEnd: new Date(Date.UTC(year, month, day + 1, 2, 0, 0)).toISOString(),
      localISOWeekday,
      localStartTime: "16:00",
      localEndTime: "19:00",
    };
  }
  if (kind !== "exact_daytime") {
    throw new Error(`Unsupported matching timing: ${kind}`);
  }
  return {
    preferredStart: new Date(Date.UTC(year, month, day, 17, 0, 0)).toISOString(),
    preferredEnd: new Date(Date.UTC(year, month, day, 19, 0, 0)).toISOString(),
    localISOWeekday,
    localStartTime: "10:00",
    localEndTime: "12:00",
  };
}

function assertSupportedScenario(scenarioID) {
  if (scenarioID !== DEFAULT_SCENARIO) {
    throw new Error(`Unsupported scenario: ${scenarioID}`);
  }
}

function assertSupportedMatchingScenario(scenarioID) {
  if (scenarioID !== MATCHING_SCENARIO) {
    throw new Error(`Unsupported matching scenario: ${scenarioID}`);
  }
}

function assertMatchingResult(plan, { requestID, matchCount, targetMatch }) {
  const assertions = {};
  if (matchCount < plan.expectation.minimumMatchCount) {
    throw new Error(
      `Request ${shortRef(requestID)} produced ${matchCount} matches; expected at least ${plan.expectation.minimumMatchCount}.`
    );
  }
  assertions.matchCount = "passed";

  if (plan.expectation.targetShouldMatch && !targetMatch) {
    throw new Error(
      `Expected ${plan.expectation.targetGroomerSeedID} to receive request ${shortRef(requestID)}.`
    );
  }
  if (!plan.expectation.targetShouldMatch && targetMatch) {
    throw new Error(
      `Expected ${plan.expectation.targetGroomerSeedID} to be excluded from request ${shortRef(requestID)}.`
    );
  }
  assertions.targetMatch = "passed";

  const reason = String(targetMatch?.match_reason ?? "");
  for (const required of plan.expectation.reasonIncludes) {
    if (!reason.includes(required)) {
      throw new Error(
        `Expected ${plan.expectation.targetGroomerSeedID} match reason to include "${required}".`
      );
    }
  }
  assertions.reason = "passed";
  return assertions;
}

function evaluateGroomerForPlan(plan, groomer) {
  const excludedReasons = [];
  if (!groomer.location?.modes?.includes(plan.request.locationMode)) {
    excludedReasons.push("location_mode_mismatch");
  }
  if (
    groomer.address?.state !== plan.request.state
      && groomer.address?.city?.toLowerCase() !== plan.request.city.toLowerCase()
  ) {
    excludedReasons.push("location_mismatch");
  }
  if (!groomer.services?.some((service) => service.serviceType === plan.request.serviceType)) {
    excludedReasons.push("service_type_mismatch");
  }
  if (
    !groomer.availabilityWindows?.some(
      (window) => window.isEnabled && window.weekday === plan.timing.localISOWeekday
    )
  ) {
    excludedReasons.push("request_day_unavailable");
  }

  const requestTraits = traitsForMatchingPet(plan.pet, plan.request.serviceType);
  const groomerClaims = new Set(
    (groomer.fitClaims ?? []).map((claim) => `${claim.traitType}:${claim.traitValue}`)
  );
  const overlapTraits = requestTraits.filter((trait) =>
    groomerClaims.has(`${trait.traitType}:${trait.traitValue}`)
  );

  return {
    seedID: groomer.seedID,
    eligible: excludedReasons.length === 0,
    excludedReasons,
    overlapTraits,
  };
}

function traitsForMatchingPet(pet, serviceType) {
  const traits = [
    { traitType: "coat_type", traitValue: pet.coatType },
    { traitType: "size_band", traitValue: pet.size },
  ];
  const serviceTrait = serviceFitTrait(serviceType);
  if (serviceTrait) {
    traits.push({ traitType: "service_fit", traitValue: serviceTrait });
  }
  return uniqueClaims(traits);
}

function serviceFitTrait(serviceType) {
  switch (serviceType) {
    case "full_groom":
    case "haircut_only":
      return "full_haircut_styling";
    case "de_shedding":
      return "de_shedding_treatment";
    case "nail_trim":
      return "nail_paw_care";
    default:
      return null;
  }
}

function selectDogPet(customer, petName) {
  const dog =
    customer.pets?.find((pet) => pet.species === "Dog" && (!petName || pet.name === petName))
      ?? customer.pets?.find((pet) => pet.species === "Dog");
  if (!dog) {
    throw new Error(`No dog pet found for ${customer.seedID}.`);
  }
  return dog;
}

function validateSeedProfiles(profiles, kind) {
  if (profiles.length === 0) {
    throw new Error(`No ${kind} seed profiles found.`);
  }

  const seen = new Set();
  for (const profile of profiles) {
    if (seen.has(profile.seedID)) {
      throw new Error(`Duplicate ${kind} seed id ${profile.seedID}.`);
    }
    seen.add(profile.seedID);

    const invalidFields = [];
    if (!/^[A-Z]{3}-\d{3}$/.test(profile.seedID)) {
      invalidFields.push("seedID");
    }
    if (!isEmail(profile.email)) {
      invalidFields.push("email");
    }
    if (!profile.password) {
      invalidFields.push("password");
    }
    if (!profile.displayName) {
      invalidFields.push("displayName");
    }
    if (kind === "groomer" && !profile.businessName) {
      invalidFields.push("businessName");
    }
    if (!profile.address?.street || !profile.address?.city || !profile.address?.zip) {
      invalidFields.push("address");
    }

    if (invalidFields.length > 0) {
      throw new Error(`Invalid ${kind} seed ${profile.seedID}: ${invalidFields.join(", ")}.`);
    }
  }
}

function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function validateRunID(runID) {
  if (!/^TESTOPS-[A-Z0-9-]{1,96}$/.test(String(runID ?? ""))) {
    throw new Error("Invalid TestOps run id. Use TESTOPS- plus uppercase letters, numbers, and hyphens only.");
  }
  return runID;
}

function isLegacyJWTKey(value) {
  return /^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value);
}

function serviceCredentialKind(value) {
  if (!value) {
    return "none";
  }
  if (isLegacyJWTKey(value)) {
    return "legacy-jwt";
  }
  if (/^sb_secret_[A-Za-z0-9._+=/-]+$/.test(value)) {
    return "modern-secret";
  }
  return "unsupported";
}

function cellsFromRow(line, expectedCount) {
  const cells = line
    .split("|")
    .slice(1, -1)
    .map((cell) => cell.trim());
  if (cells.length !== expectedCount) {
    throw new Error(`Expected ${expectedCount} columns in seed row.`);
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

function parsePet(value, species) {
  const parts = value.split(";").map((part) => part.trim());
  if (parts.length !== 7) {
    return partialPet(parts, species);
  }
  const [name, breed, coatType, weightValue, birthday, temperament, notesValue] = parts;
  const weightMatch = weightValue.match(/^(\d+(?:\.\d+)?)\s*lb$/);
  const notesMatch = notesValue.match(/^notes:\s*(.+)$/i);
  if (!weightMatch || !notesMatch) {
    throw new Error(`Invalid pet details.`);
  }
  const weightLbs = Number.parseFloat(weightMatch[1]);
  return {
    name,
    species,
    breed,
    coatType,
    weightLbs,
    birthday,
    temperament,
    groomingNotes: notesMatch[1],
    size: sizeCodeForWeight(weightLbs),
  };
}

function partialPet(parts, species) {
  return {
    name: parts[0] || `${species} pet`,
    species,
    breed: parts[1] || "Unspecified",
    coatType: "not_sure",
    weightLbs: null,
    birthday: null,
    temperament: "Not Sure",
    groomingNotes: "",
    size: "M",
  };
}

function sizeCodeForWeight(weightLbs) {
  if (weightLbs < 10) {
    return "XS";
  }
  if (weightLbs < 20) {
    return "S";
  }
  if (weightLbs < 40) {
    return "M";
  }
  if (weightLbs < 60) {
    return "L";
  }
  if (weightLbs < 80) {
    return "XL";
  }
  if (weightLbs <= 100) {
    return "XXL";
  }
  return "Giant";
}

function parseModesRadius(value) {
  const match = value.match(/^(mobile|studio|both)\s*\/\s*(\d+)\s*mi$/);
  if (!match) {
    throw new Error(`Invalid modes/radius value.`);
  }
  return {
    modes: LOCATION_MODES[match[1]],
    radiusMiles: Number.parseInt(match[2], 10),
  };
}

function parseAvailabilitySafe(value) {
  try {
    return parseAvailability(value);
  } catch {
    return {
      windows: [],
      preferences: {
        maxAppointmentsPerDay: null,
        minimumAdvanceNoticeDays: null,
      },
    };
  }
}

function parseAvailability(value) {
  const [windowPart, maxPart, advancePart] = value.split(";").map((part) => part.trim());
  const maxMatch = maxPart?.match(/^max\/day\s+(\d+)$/);
  const advanceMatch = advancePart?.match(/^advance\s+(\d+)d$/);
  if (!maxMatch || !advanceMatch) {
    throw new Error(`Invalid availability preferences.`);
  }

  return {
    windows: windowPart.split(",").flatMap((part) => parseAvailabilityWindow(part.trim())),
    preferences: {
      maxAppointmentsPerDay: Number.parseInt(maxMatch[1], 10),
      minimumAdvanceNoticeDays: Number.parseInt(advanceMatch[1], 10),
    },
  };
}

function parseAvailabilityWindow(value) {
  const match = value.match(/^([A-Za-z]{3})(?:-([A-Za-z]{3}))?\s+(\d{2}:\d{2})-(\d{2}:\d{2})$/);
  if (!match) {
    throw new Error(`Invalid availability window.`);
  }
  const startDay = weekdayNumber(match[1]);
  const endDay = match[2] ? weekdayNumber(match[2]) : startDay;
  if (endDay < startDay) {
    throw new Error(`Availability ranges must not wrap weeks.`);
  }
  return range(startDay, endDay).map((weekday) => ({
    weekday,
    startTime: match[3],
    endTime: match[4],
    isEnabled: true,
    timezone: "America/Los_Angeles",
  }));
}

function weekdayNumber(value) {
  const weekday = WEEKDAYS.get(value);
  if (!weekday) {
    throw new Error(`Unknown weekday.`);
  }
  return weekday;
}

function parseFitSignal(value) {
  const [traitType, traitValue] = value.split(":").map((part) => part.trim());
  if (!traitType || !traitValue) {
    throw new Error(`Invalid fit signal.`);
  }
  return { traitType, traitValue };
}

function expandSizeExperience(value) {
  const [start, end] = value.split("-");
  const startIndex = SIZE_ORDER.indexOf(start);
  const endIndex = SIZE_ORDER.indexOf(end);
  if (startIndex === -1 || endIndex === -1 || endIndex < startIndex) {
    throw new Error(`Invalid size experience.`);
  }
  return SIZE_ORDER.slice(startIndex, endIndex + 1);
}

function uniqueClaims(claims) {
  const seen = new Set();
  return claims.filter((claim) => {
    const key = `${claim.traitType}:${claim.traitValue}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

function parseService(value) {
  const match = value.match(/^([a-z_]+)\s+\$(\d+)\/(\d+)m$/);
  if (!match) {
    throw new Error(`Invalid service value.`);
  }
  return {
    serviceType: match[1],
    basePrice: Number.parseInt(match[2], 10),
    durationMinutes: Number.parseInt(match[3], 10),
    isActive: true,
  };
}

function requireSeed(profiles, seedID) {
  const profile = profiles.find((candidate) => candidate.seedID === seedID);
  if (!profile) {
    throw new Error(`Could not find seed ${seedID}.`);
  }
  return profile;
}

function range(start, end) {
  return Array.from({ length: end - start + 1 }, (_, index) => start + index);
}

function firstValue(rows, key) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return null;
  }
  return rows[0]?.[key] ?? null;
}
