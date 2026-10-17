import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../../ios/Beckon/Beckon/DesignSystem/BeckonActionPrimitives.swift", import.meta.url), "utf8");
const primary = source.slice(source.indexOf("struct BeckonPrimaryButtonStyle"), source.indexOf("struct BeckonSecondaryButtonStyle"));
const tones = source.slice(source.indexOf("struct BeckonStatusChip"), source.indexOf("private let title", source.indexOf("struct BeckonStatusChip")));

test("primary actions use solid role fill without colored shadows or disabled opacity", () => {
  assert.doesNotMatch(primary, /LinearGradient|gradientColors|beckonShadow|\.opacity\(/);
  assert.match(primary, /fillPressed/);
  assert.match(primary, /iconTileFill/);
});

test("status chip tones are semantic and use opaque semantic surfaces", () => {
  assert.doesNotMatch(tones, /case customer|case groomer|\.opacity\(/);
  for (const tone of ["neutral", "success", "warning", "error", "info"]) {
    assert.match(tones, new RegExp(`case ${tone}`));
  }
});

test("shared text and destructive actions own their minimum hit areas", () => {
  for (const name of ["BeckonTertiaryButtonStyle", "BeckonDestructiveButtonStyle"]) {
    assert.match(source, new RegExp(`struct ${name}: ButtonStyle`));
  }
  const textAction = source.slice(source.indexOf("struct BeckonTertiaryButtonStyle"), source.indexOf("struct BeckonDestructiveButtonStyle"));
  assert.match(textAction, /minimumTouchTarget/);
});

test("domain status presentation has a single shared owner", () => {
  const shared = readFileSync(new URL("../../ios/Beckon/Beckon/SharedFeatures/Status/BeckonStatusPresentation.swift", import.meta.url), "utf8");
  for (const name of ["GroomingRequestStatus", "RequestMatchStatus", "GroomerOfferStatus", "BookingStatus"]) {
    assert.match(shared, new RegExp("extension " + name));
  }
  assert.doesNotMatch(shared, /role ==|switch role/);
});
