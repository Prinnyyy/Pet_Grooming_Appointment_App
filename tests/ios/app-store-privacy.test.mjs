import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const manifestPath =
  "ios/PetGroomerMarketplace/PetGroomerMarketplace/PrivacyInfo.xcprivacy";
const privacyChecklistPath = "docs/04_ios/APP_STORE_PRIVACY.md";

function readPlist(path) {
  const json = execFileSync("plutil", [
    "-convert",
    "json",
    "-o",
    "-",
    path,
  ], { encoding: "utf8" });
  return JSON.parse(json);
}

test("T-161 app privacy manifest declares Groomly 1.0 data and required reason APIs", () => {
  assert.equal(existsSync(manifestPath), true, "PrivacyInfo.xcprivacy is missing");

  const manifest = readPlist(manifestPath);
  assert.equal(manifest.NSPrivacyTracking, false);
  assert.deepEqual(manifest.NSPrivacyTrackingDomains, []);

  const collectedTypes = new Map(
    manifest.NSPrivacyCollectedDataTypes.map((entry) => [
      entry.NSPrivacyCollectedDataType,
      entry,
    ])
  );
  const expectedCollectedTypes = [
    "NSPrivacyCollectedDataTypeName",
    "NSPrivacyCollectedDataTypeEmailAddress",
    "NSPrivacyCollectedDataTypePhoneNumber",
    "NSPrivacyCollectedDataTypePhysicalAddress",
    "NSPrivacyCollectedDataTypeCoarseLocation",
    "NSPrivacyCollectedDataTypeUserID",
    "NSPrivacyCollectedDataTypeDeviceID",
    "NSPrivacyCollectedDataTypePhotosorVideos",
    "NSPrivacyCollectedDataTypeOtherUserContent",
  ];

  for (const type of expectedCollectedTypes) {
    assert.equal(collectedTypes.has(type), true, `${type} is missing`);
    const entry = collectedTypes.get(type);
    assert.equal(entry.NSPrivacyCollectedDataTypeLinked, true, `${type} should be linked to the signed-in account`);
    assert.equal(entry.NSPrivacyCollectedDataTypeTracking, false, `${type} must not be used for tracking`);
    assert.deepEqual(
      entry.NSPrivacyCollectedDataTypePurposes,
      ["NSPrivacyCollectedDataTypePurposeAppFunctionality"],
      `${type} should be declared only for app functionality`
    );
  }

  const accessedAPIReasons = new Map(
    manifest.NSPrivacyAccessedAPITypes.map((entry) => [
      entry.NSPrivacyAccessedAPIType,
      entry.NSPrivacyAccessedAPITypeReasons,
    ])
  );
  assert.deepEqual(
    accessedAPIReasons.get("NSPrivacyAccessedAPICategoryUserDefaults"),
    ["CA92.1"]
  );
  assert.deepEqual(
    accessedAPIReasons.get("NSPrivacyAccessedAPICategoryFileTimestamp"),
    ["C617.1"]
  );
});

test("T-161 App Store privacy checklist records URL blockers and nutrition label posture", () => {
  assert.equal(existsSync(privacyChecklistPath), true, "App Store privacy checklist is missing");

  const checklist = readFileSync(privacyChecklistPath, "utf8");
  assert.match(checklist, /Privacy Policy URL/);
  assert.match(checklist, /Support URL/);
  assert.match(checklist, /TBD/);
  assert.match(checklist, /No tracking/);
  assert.match(checklist, /UserDefaults.*CA92\.1/s);
  assert.match(checklist, /File timestamp.*C617\.1/s);
  assert.match(checklist, /Photos or videos/);
  assert.match(checklist, /Other user content/);
});
