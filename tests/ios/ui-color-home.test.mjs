import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const root = new URL("../../ios/Beckon/Beckon/", import.meta.url);
const read = path => readFileSync(new URL(path, root), "utf8");

test("Home Grooming glance cards have a single action and explicit journey semantics", () => {
  const source = read("Features/Customer/Grooming/GroomingCard.swift");
  assert.match(source, /accessibilityLabel\(accessibilityLabel\)/);
  assert.match(source, /Opens this grooming in the Grooming tab/);
  assert.match(source, /style == \.full/);
  assert.match(source, /BeckonJourney/);
  assert.match(source, /Finished, leave a review/);
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

test("Groomer Home follows the approved coral scene, count tiles and exceptional availability alerts", () => {
  const home = read("Features/Groomer/Home/GroomerHomeView.swift");
  assert.match(home, /HomeHeader/);
  assert.match(home, /GroomerHomeTile/);
  assert.match(home, /BeckonLoadingHero\(isLoading: !isSettled/);
  assert.match(home, /case \.paused, \.needsSchedule/);
  assert.doesNotMatch(home, /let tint: Color|Colors\.groomerInk/);
});

test("both roles use the adopted message surfaces with a role-derived accent", () => {
  const row = read("Features/Chat/ChatView.swift").split("private struct ChatMessageRow: View {")[1].split("private struct ChatBookingDetailDestination:")[0];
  assert.match(row, /Colors\.customerFill/);
  assert.doesNotMatch(row, /customerDesign|groomerTextRow/);
  assert.match(read("DesignSystem/BeckonRole.swift"), /UITraitBridgedEnvironmentKey/);
});

test("Groomer Account reuses authenticated account actions with its existing sign-out identity", () => {
  const account = read("Features/Groomer/Profile/GroomerAccountView.swift");
  assert.match(account, /AccountDangerActions\(authenticationStore: authenticationStore/);
  assert.match(account, /signOutIdentifier: "groomer\.account\.sign-out"/);
  assert.match(read("Features/Auth/AuthenticatedEntryView.swift"), /authenticationStore: authenticationStore,\s*onSignOut: signOut/);
  assert.match(read("Features/Groomer/GroomerTabView.swift"), /authenticationStore: authenticationStore\)/);
});

test("groomer destructive entries retain their style and shared confirmations use destructive dialog actions", () => {
  const fulfillment = read("Features/Customer/Grooming/GroomingActionDialogs.swift");
  assert.match(fulfillment, /item\.isDestructive/);
  assert.match(fulfillment, /\.destructive\(title: item\.title/);
  const dialogs = read("Features/Bookings/BookingActionDialogs.swift");
  assert.match(dialogs, /if item\.isDestructive/);
  assert.match(dialogs, /\.destructive\(title: item\.title/);
  assert.match(dialogs, /confirmIdentifier: "booking\.fulfillment\.confirm"/);
});
