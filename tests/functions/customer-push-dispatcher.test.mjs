import assert from "node:assert/strict";
import { test } from "node:test";

import {
  apnsEndpointForEnvironment,
  buildApnsPayload,
  dispatchCustomerPushBatch,
  normalizeAPNSToken,
} from "../../supabase/functions/dispatch-customer-push-notifications/dispatcher.mjs";

test("normalizes APNs tokens to lowercase compact hex", () => {
  assert.equal(normalizeAPNSToken(" 0A FF 10 "), "0aff10");
  assert.equal(normalizeAPNSToken("0a-ff-10"), "0aff10");
});

test("builds APNs alert payload from system notification copy only", () => {
  const payload = buildApnsPayload({
    id: "notification-1",
    kind: "new_message",
    title: "New message",
    body: "Your groomer sent you a message.",
    related_request_id: "request-1",
    related_booking_id: "booking-1",
    related_offer_id: null,
  });

  assert.deepEqual(payload.aps.alert, {
    title: "New message",
    body: "Your groomer sent you a message.",
  });
  assert.equal(payload.beckon.kind, "new_message");
  assert.equal(payload.beckon.notification_id, "notification-1");
  assert.equal(payload.beckon.related_request_id, "request-1");
  assert.equal(payload.beckon.related_booking_id, "booking-1");
  assert.ok(!JSON.stringify(payload).includes("street_address"));
});

test("chooses sandbox and production APNs endpoints", () => {
  assert.equal(
    apnsEndpointForEnvironment("sandbox", "abc123"),
    "https://api.sandbox.push.apple.com/3/device/abc123",
  );
  assert.equal(
    apnsEndpointForEnvironment("production", "abc123"),
    "https://api.push.apple.com/3/device/abc123",
  );
});

test("dispatches to active customer tokens and records delivery outcome", async () => {
  const deliveries = [];
  const notifications = [
    {
      id: "notification-1",
      customer_id: "customer-1",
      kind: "new_offer",
      title: "New offer received",
      body: "A groomer sent a new offer for your request.",
      related_request_id: "request-1",
      related_booking_id: null,
      related_offer_id: "offer-1",
    },
    {
      id: "notification-2",
      customer_id: "customer-2",
      kind: "new_message",
      title: "New message",
      body: "Your groomer sent you a message.",
      related_request_id: null,
      related_booking_id: "booking-1",
      related_offer_id: null,
    },
  ];
  const tokensByCustomerID = new Map([
    [
      "customer-1",
      [
        {
          token: "ABC123",
          environment: "sandbox",
        },
      ],
    ],
  ]);

  const result = await dispatchCustomerPushBatch({
    notifications,
    tokensByCustomerID,
    sendPush: async ({ token, payload }) => {
      deliveries.push({ token, payload });
      return { ok: true };
    },
    recordDelivery: async (delivery) => {
      deliveries.push(delivery);
    },
  });

  assert.equal(result.sent, 1);
  assert.equal(result.noActiveTokens, 1);
  assert.equal(deliveries[0].token, "abc123");
  assert.equal(deliveries[0].payload.beckon.kind, "new_offer");
  assert.deepEqual(deliveries.slice(1), [
    {
      notificationID: "notification-1",
      status: "sent",
      error: null,
    },
    {
      notificationID: "notification-2",
      status: "no_active_tokens",
      error: "no_active_customer_push_tokens",
    },
  ]);
});
