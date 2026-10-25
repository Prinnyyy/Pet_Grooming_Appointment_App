import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const root = new URL("../../ios/Beckon/Beckon/", import.meta.url);
const read = path => readFileSync(new URL(path, root), "utf8");

test("Home request summaries use one action with explicit progress and review semantics", () => {
  const source = read("Features/Customer/Requests/CustomerRequestsDashboardView.swift");
  const summary = source.split("struct CustomerRequestSummaryCard: View {")[1]
    .split("struct CustomerRequestCard:")[0];
  assert.match(summary, /BeckonJourney\(stage: step, offerCount: card\.loadedOfferCount\)/);
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

test("adopted customer message colors remain scoped away from groomer message surfaces", () => {
  const row = read("Features/Chat/ChatView.swift").split("private struct ChatMessageRow: View {")[1].split("private struct ChatBookingDetailDestination:")[0];
  assert.match(row, /if customerDesign \{ customerTextRow \} else \{ groomerTextRow \}/);
  const customer = row.split("private var customerTextRow:")[1]?.split("private var groomerTextRow:")[0] ?? row.split("private func groomerBody")[0];
  assert.match(customer, /Colors\.customerFill/);
  const groomer = row.split("private var groomerTextRow:")[1] ?? "";
  assert.match(groomer, /isOutgoing \? DesignTokens\.Colors\.iconTileFill/);
  assert.doesNotMatch(groomer, /Colors\.(?:customer|groomer)(?:Tint|Fill|Ink)/);
});

test("Groomer sign out uses the shared destructive style", () => {
  const account = read("Features/Groomer/Profile/GroomerProfileAccountView.swift");
  assert.match(account, /BeckonDestructiveButtonStyle/);
});

test("groomer destructive entries retain their style and shared confirmations use destructive dialog actions", () => {
  const fulfillment = read("Features/Bookings/BookingFulfillmentSection.swift");
  assert.match(fulfillment, /if action\.isDestructive/);
  assert.match(fulfillment, /BeckonDestructiveButtonStyle\(\)/);
  assert.match(fulfillment, /bookingFulfillmentDialog\(action: \$selectedAction\)/);
  const dialogs = read("Features/Bookings/BookingActionDialogs.swift");
  assert.match(dialogs, /if item\.isDestructive/);
  assert.match(dialogs, /\.destructive\(title: item\.title/);
  assert.match(dialogs, /confirmIdentifier: "booking\.fulfillment\.confirm"/);
});
