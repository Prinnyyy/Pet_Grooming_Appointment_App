import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const root = new URL("../../ios/Beckon/Beckon/", import.meta.url);
const read = path => readFileSync(new URL(path, root), "utf8");

test("Home request summaries use one action with explicit progress and review semantics", () => {
  const source = read("Features/Customer/Requests/CustomerRequestsDashboardView.swift");
  const summary = source.split("struct CustomerRequestActionCardSummary: View {")[1]
    .split("private struct CustomerRequestProgressCard:")[0];
  assert.match(summary, /CustomerRequestSummaryProgress/);
  assert.match(summary, /presentation\.accessibilityLabel/);
  assert.match(summary, /Text\("Review"\)/);
  assert.doesNotMatch(summary, /\bButton\s*[{(]/);
  assert.match(summary, /BeckonStatusChip\(presentation\.status\)/);
});

test("Home offer counts reuse loaded Store data without fetching", () => {
  const source = read("Features/Customer/Requests/CustomerRequestsStore.swift");
  const count = source.split("func loadedCurrentOfferCount(")[1]?.split("func canLoadMoreOffers")[0] ?? "";
  assert.match(count, /offerReviewsByRequestID/);
  assert.match(count, /offerListsNeedingRefresh/);
  assert.match(count, /nextCursor/);
  assert.match(count, /isCurrentProposal/);
  assert.doesNotMatch(count, /await|repository\./);
});

test("Groomer Home uses a role badge, shared count badges and non-color availability cues", () => {
  const home = read("Features/Groomer/Home/GroomerHomeView.swift");
  assert.match(home, /BeckonRoleBadge/);
  assert.match(home, /BeckonCountBadge/);
  assert.match(home, /checkmark\.circle\.fill/);
  assert.doesNotMatch(home, /let tint: Color|Colors\.groomerInk/);
});

test("shared message surfaces do not change color with the viewer role", () => {
  const chat = read("Features/Chat/ChatView.swift");
  assert.doesNotMatch(chat, /chatAccent|Colors\.(?:customer|groomer)(?:Tint|Fill|Ink)/);
  assert.match(chat, /isOutgoing \? DesignTokens\.Colors\.iconTileFill/);
});

test("Groomer sign out uses the shared destructive style", () => {
  const account = read("Features/Groomer/Profile/GroomerProfileAccountView.swift");
  assert.match(account, /BeckonDestructiveButtonStyle/);
});

test("destructive booking actions keep their style in both entry and confirmation", () => {
  const fulfillment = read("Features/Bookings/BookingFulfillmentSection.swift");
  assert.equal([...fulfillment.matchAll(/if action\.isDestructive/g)].length, 2);
  assert.equal([...fulfillment.matchAll(/BeckonDestructiveButtonStyle\(\)/g)].length, 2);
});
