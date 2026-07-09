import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const manifestPath =
  "ios/PetGroomerMarketplace/PetGroomerMarketplace/PrivacyInfo.xcprivacy";
const privacyChecklistPath = "docs/04_ios/APP_STORE_PRIVACY.md";
const releaseLinksPath =
  "ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Configuration/AppReleaseLinks.swift";
const customerAccountPath =
  "ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Profile/CustomerProfileSettingsView.swift";
const groomerAccountPath =
  "ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift";
const genericAccountPath =
  "ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticatedAccountView.swift";
const privacyPolicyPath = "docs/04_ios/release/PRIVACY_POLICY.md";
const supportPagePath = "docs/04_ios/release/SUPPORT.md";
const releaseBaseURL =
  "https://github.com/Prinnyyy/Pet_Grooming_Appointment_App/blob/codex/pet-fit-structure-cleanup/docs/04_ios/release";
const privacyPolicyURL = `${releaseBaseURL}/PRIVACY_POLICY.md`;
const supportURL = `${releaseBaseURL}/SUPPORT.md`;

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

test("T-195 App Store privacy checklist records release URLs and nutrition label posture", () => {
  assert.equal(existsSync(privacyChecklistPath), true, "App Store privacy checklist is missing");

  const checklist = readFileSync(privacyChecklistPath, "utf8");
  assert.match(checklist, /Privacy Policy URL/);
  assert.match(checklist, /Support URL/);
  assert.doesNotMatch(checklist, /TBD/);
  assert.match(checklist, new RegExp(privacyPolicyURL.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(checklist, new RegExp(supportURL.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(checklist, /No tracking/);
  assert.match(checklist, /UserDefaults.*CA92\.1/s);
  assert.match(checklist, /File timestamp.*C617\.1/s);
  assert.match(checklist, /Photos or videos/);
  assert.match(checklist, /Other user content/);
});

test("T-195 release privacy and support pages are public-link ready", () => {
  assert.equal(existsSync(privacyPolicyPath), true, "Privacy policy page is missing");
  assert.equal(existsSync(supportPagePath), true, "Support page is missing");

  const privacyPolicy = readFileSync(privacyPolicyPath, "utf8");
  assert.match(privacyPolicy, /^# Groomly Privacy Policy/m);
  assert.match(privacyPolicy, /Data We Collect/);
  assert.match(privacyPolicy, /How We Use Data/);
  assert.match(privacyPolicy, /Data Retention and Deletion/);
  assert.match(privacyPolicy, /Support and Privacy Requests/);
  assert.doesNotMatch(privacyPolicy, /TBD|TODO|<[^>]+>/);

  const supportPage = readFileSync(supportPagePath, "utf8");
  assert.match(supportPage, /^# Groomly Support/m);
  assert.match(supportPage, /support requests/i);
  assert.match(supportPage, /general feedback/i);
  assert.match(supportPage, /feature requests/i);
  assert.match(supportPage, /https:\/\/github\.com\/Prinnyyy\/Pet_Grooming_Appointment_App\/issues/);
  assert.doesNotMatch(supportPage, /TBD|TODO|<[^>]+>/);
});

test("T-195 app exposes release links through a shared configuration and account surfaces", () => {
  assert.equal(existsSync(releaseLinksPath), true, "AppReleaseLinks.swift is missing");

  const releaseLinks = readFileSync(releaseLinksPath, "utf8");
  assert.match(releaseLinks, /enum AppReleaseLinks/);
  assert.match(releaseLinks, new RegExp(privacyPolicyURL.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.match(releaseLinks, new RegExp(supportURL.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));

  const genericAccount = readFileSync(genericAccountPath, "utf8");
  const customerAccount = readFileSync(customerAccountPath, "utf8");
  const groomerAccount = readFileSync(groomerAccountPath, "utf8");

  for (const source of [genericAccount, customerAccount, groomerAccount]) {
    assert.match(source, /AccountReleaseLinksSection/);
  }

  assert.match(genericAccount, /account\.privacy-policy/);
  assert.match(genericAccount, /account\.support/);
});
