import assert from "node:assert/strict";
import test from "node:test";

import {
  ADDRESS_BACKFILL_REMOTE_WRITE_ENV,
  addressFingerprint,
  baseAddressLine1,
  classifyResolution,
  makeBackfillReport,
  requireBackfillRemoteWriteApproval,
  validateDecisionArtifact,
  validateExceptionArtifact,
} from "../../scripts/address-backfill-core.mjs";

const target = {
  sourceKind: "customer_profile",
  sourceID: "11111111-2222-3333-4444-555555555555",
  ownerID: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  line1: "770 S Harbor Blvd",
  line2: "Unit 2410",
  city: "Fullerton",
  state: "CA",
  zipCode: "92832",
};

const exactCandidate = {
  provider: "apple_maps",
  placeID: null,
  line1: "770 South Harbor Boulevard",
  city: "Fullerton",
  state: "CA",
  zipCode: "92832",
  countryCode: "US",
  latitude: 33.8703,
  longitude: -117.9242,
};

test("exact normalized US components produce one auto-approved decision", () => {
  const decision = classifyResolution(target, [exactCandidate]);
  assert.equal(decision.status, "approved_exact");
  assert.equal(decision.candidateCount, 1);
  assert.equal(decision.exactCandidateCount, 1);
  assert.match(decision.addressFingerprint, /^[a-f0-9]{64}$/);
  assert.equal(decision.supportRef, "customer_profile:11111111");
  assert.equal("line1" in decision, false);
  assert.equal("latitude" in decision, false);
});

test("multilingual city and optional direction are display variants when street, state, and ZIP agree", () => {
  const decision = classifyResolution(
    { ...target, line1: "1900 E Firestone Blvd", city: "洛杉矶" },
    [{ ...exactCandidate, line1: "1900 Firestone Blvd", city: "Los Angeles", zipCode: "92832" }],
  );
  assert.equal(decision.status, "approved_exact");
  assert.deepEqual(decision.displayVariantFields, ["city"]);
  assert.equal(baseAddressLine1("20540 E Arrow Highway Suite K"), "20540 E Arrow Highway");
  assert.equal(
    classifyResolution(
      { ...target, line1: "17635 Los Alamos" },
      [{ ...exactCandidate, line1: "17635 Los Alamos St" }],
    ).status,
    "approved_exact",
  );
});

test("zero, multiple exact, incomplete, and non-US results require review", () => {
  assert.equal(classifyResolution(target, []).status, "review_missing");
  assert.equal(
    classifyResolution(target, [exactCandidate, { ...exactCandidate, placeID: "other" }]).status,
    "review_ambiguous",
  );
  assert.equal(
    classifyResolution(target, [{ ...exactCandidate, latitude: null }]).status,
    "review_incomplete",
  );
  assert.equal(
    classifyResolution(target, [{ ...exactCandidate, countryCode: "CA" }]).status,
    "review_non_us",
  );
  assert.equal(
    classifyResolution(target, [{ ...exactCandidate, zipCode: "90720" }]).status,
    "review_component_mismatch",
  );
});

test("fingerprint includes line two but never exposes address text", () => {
  const first = addressFingerprint(target);
  const second = addressFingerprint({ ...target, line2: "Unit 2411" });
  assert.notEqual(first, second);
  assert.doesNotMatch(first, /Harbor|2410|Fullerton/i);
});

test("remote writes require --execute and the dedicated approval env", () => {
  assert.throws(
    () => requireBackfillRemoteWriteApproval({ execute: false, env: {} }),
    /--execute/,
  );
  assert.throws(
    () => requireBackfillRemoteWriteApproval({ execute: true, env: {} }),
    new RegExp(ADDRESS_BACKFILL_REMOTE_WRITE_ENV),
  );
  assert.doesNotThrow(() => requireBackfillRemoteWriteApproval({
    execute: true,
    env: { [ADDRESS_BACKFILL_REMOTE_WRITE_ENV]: "1" },
  }));
});

test("decision artifact is bound to current target fingerprints", () => {
  const decision = classifyResolution(target, [exactCandidate]);
  assert.deepEqual(validateDecisionArtifact([target], [decision]), [decision]);
  assert.throws(
    () => validateDecisionArtifact([{ ...target, city: "Anaheim" }], [decision]),
    /stale/i,
  );
});

test("documented exceptions require a current fingerprint and safe reason code", () => {
  const exception = {
    supportRef: "customer_profile:11111111",
    addressFingerprint: addressFingerprint(target),
    reasonCode: "zip_conflicts_with_apple_result",
  };
  assert.deepEqual(validateExceptionArtifact([target], [exception]), [exception]);
  assert.throws(
    () => validateExceptionArtifact([target], [{ ...exception, reasonCode: "full address text" }]),
    /reason code/i,
  );
  assert.throws(
    () => validateExceptionArtifact([{ ...target, zipCode: "90720" }], [exception]),
    /stale/i,
  );
});

test("report contains counts and redacted refs without addresses or coordinates", () => {
  const decisions = [classifyResolution(target, [exactCandidate])];
  const report = makeBackfillReport({ runID: "T-299-DRY", decisions });
  const serialized = JSON.stringify(report);
  assert.equal(report.counts.approved_exact, 1);
  assert.match(serialized, /customer_profile:11111111/);
  assert.doesNotMatch(serialized, /770 S Harbor|Fullerton|92832|33\.8703|-117\.9242/);
});
