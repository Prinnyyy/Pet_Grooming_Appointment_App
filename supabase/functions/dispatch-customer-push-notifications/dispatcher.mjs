export function normalizeAPNSToken(token) {
  return String(token ?? "")
    .replace(/[^0-9a-fA-F]/g, "")
    .toLowerCase();
}

export function apnsEndpointForEnvironment(environment, token) {
  const normalizedToken = normalizeAPNSToken(token);
  const host = environment === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
  return `${host}/3/device/${normalizedToken}`;
}

export function buildApnsPayload(notification) {
  return {
    aps: {
      alert: {
        title: notification.title,
        body: notification.body,
      },
      sound: "default",
    },
    beckon: {
      notification_id: notification.id ?? notification.notification_id,
      kind: notification.kind,
      related_request_id: notification.related_request_id ?? null,
      related_booking_id: notification.related_booking_id ?? null,
      related_offer_id: notification.related_offer_id ?? null,
    },
  };
}

export async function dispatchCustomerPushBatch({
  notifications,
  tokensByCustomerID,
  sendPush,
  recordDelivery,
}) {
  const result = {
    claimed: notifications.length,
    sent: 0,
    failed: 0,
    noActiveTokens: 0,
  };

  for (const notification of notifications) {
    const notificationID = notification.id ?? notification.notification_id;
    const tokens = tokensForCustomer(tokensByCustomerID, notification.customer_id)
      .map((token) => ({
        ...token,
        token: normalizeAPNSToken(token.token),
      }))
      .filter((token) => token.token.length > 0);

    if (tokens.length === 0) {
      result.noActiveTokens += 1;
      await recordDelivery({
        notificationID,
        status: "no_active_tokens",
        error: "no_active_customer_push_tokens",
      });
      continue;
    }

    const payload = buildApnsPayload(notification);
    const deliveryResults = [];

    for (const token of tokens) {
      try {
        deliveryResults.push(
          await sendPush({
            token: token.token,
            environment: token.environment,
            payload,
          }),
        );
      } catch (error) {
        deliveryResults.push({
          ok: false,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    const success = deliveryResults.some((deliveryResult) => deliveryResult.ok);
    if (success) {
      result.sent += 1;
      await recordDelivery({
        notificationID,
        status: "sent",
        error: null,
      });
    } else {
      result.failed += 1;
      await recordDelivery({
        notificationID,
        status: "failed",
        error: firstDeliveryError(deliveryResults),
      });
    }
  }

  return result;
}

function tokensForCustomer(tokensByCustomerID, customerID) {
  if (tokensByCustomerID instanceof Map) {
    return tokensByCustomerID.get(customerID) ?? [];
  }
  return tokensByCustomerID?.[customerID] ?? [];
}

function firstDeliveryError(deliveryResults) {
  const error = deliveryResults.find((deliveryResult) => deliveryResult.error)?.error;
  return error ? String(error).slice(0, 240) : "apns_delivery_failed";
}
