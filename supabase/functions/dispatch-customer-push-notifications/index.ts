import { createClient } from "npm:@supabase/supabase-js@2";
import {
  apnsEndpointForEnvironment,
  dispatchCustomerPushBatch,
} from "./dispatcher.mjs";

type ClaimedNotification = {
  notification_id: string;
  customer_id: string;
  kind: string;
  title: string;
  body: string;
  related_request_id: string | null;
  related_booking_id: string | null;
  related_offer_id: string | null;
};

type PushTokenRow = {
  customer_id: string;
  token: string;
  environment: "sandbox" | "production";
};

type APNSConfig = {
  keyID: string;
  teamID: string;
  topic: string;
  privateKey: string;
};

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const apnsConfig = readAPNSConfig();
  if (!apnsConfig) {
    return jsonResponse({ error: "apns_configuration_missing" }, 500);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceKey = readSupabaseServiceKey();
  if (!supabaseURL || !serviceKey) {
    return jsonResponse({ error: "supabase_configuration_missing" }, 500);
  }

  const body = await request.json().catch(() => ({}));
  const limit = Number.isInteger(body.limit) ? Math.max(1, Math.min(body.limit, 250)) : 50;
  const supabase = createClient(supabaseURL, serviceKey, {
    auth: {
      persistSession: false,
    },
  });

  const { data: claimed, error: claimError } = await supabase.rpc(
    "claim_customer_push_notifications",
    { p_limit: limit },
  );
  if (claimError) {
    return jsonResponse({ error: claimError.message }, 500);
  }

  const notifications = ((claimed ?? []) as ClaimedNotification[]).map((notification) => ({
    id: notification.notification_id,
    customer_id: notification.customer_id,
    kind: notification.kind,
    title: notification.title,
    body: notification.body,
    related_request_id: notification.related_request_id,
    related_booking_id: notification.related_booking_id,
    related_offer_id: notification.related_offer_id,
  }));

  const tokensByCustomerID = await activeTokensByCustomerID(
    supabase,
    notifications.map((notification) => notification.customer_id),
  );
  const jwt = await apnsAuthorizationJWT(apnsConfig);

  const result = await dispatchCustomerPushBatch({
    notifications,
    tokensByCustomerID,
    sendPush: ({ token, environment, payload }) =>
      sendAPNSPush({ apnsConfig, jwt, token, environment, payload }),
    recordDelivery: ({ notificationID, status, error }) =>
      recordDelivery(supabase, notificationID, status, error),
  });

  return jsonResponse(result);
});

async function activeTokensByCustomerID(
  supabase: ReturnType<typeof createClient>,
  customerIDs: string[],
) {
  const uniqueCustomerIDs = Array.from(new Set(customerIDs));
  const tokensByCustomerID = new Map<string, PushTokenRow[]>();
  if (uniqueCustomerIDs.length === 0) {
    return tokensByCustomerID;
  }

  const { data, error } = await supabase
    .from("customer_push_tokens")
    .select("customer_id,token,environment")
    .in("customer_id", uniqueCustomerIDs)
    .is("disabled_at", null);

  if (error) {
    throw new Error(error.message);
  }

  for (const token of (data ?? []) as PushTokenRow[]) {
    const tokens = tokensByCustomerID.get(token.customer_id) ?? [];
    tokens.push(token);
    tokensByCustomerID.set(token.customer_id, tokens);
  }

  return tokensByCustomerID;
}

async function recordDelivery(
  supabase: ReturnType<typeof createClient>,
  notificationID: string,
  status: string,
  error: string | null,
) {
  const { error: recordError } = await supabase.rpc("record_customer_push_delivery", {
    p_notification_id: notificationID,
    p_status: status,
    p_error: error,
  });

  if (recordError) {
    throw new Error(recordError.message);
  }
}

async function sendAPNSPush({
  apnsConfig,
  jwt,
  token,
  environment,
  payload,
}: {
  apnsConfig: APNSConfig;
  jwt: string;
  token: string;
  environment: "sandbox" | "production";
  payload: unknown;
}) {
  const response = await fetch(apnsEndpointForEnvironment(environment, token), {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": apnsConfig.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (response.ok) {
    return { ok: true };
  }

  const body = await response.json().catch(() => ({}));
  return {
    ok: false,
    status: response.status,
    error: typeof body.reason === "string" ? body.reason : `apns_http_${response.status}`,
  };
}

function readAPNSConfig(): APNSConfig | null {
  const keyID = Deno.env.get("APNS_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  const topic = Deno.env.get("APNS_TOPIC");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY")?.replaceAll("\\n", "\n");
  if (!keyID || !teamID || !topic || !privateKey) {
    return null;
  }

  return { keyID, teamID, topic, privateKey };
}

function readSupabaseServiceKey() {
  const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (secretKeys) {
    const parsed = JSON.parse(secretKeys);
    if (typeof parsed.default === "string") {
      return parsed.default;
    }
  }

  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
}

async function apnsAuthorizationJWT(config: APNSConfig) {
  const header = base64URLJSON({
    alg: "ES256",
    kid: config.keyID,
  });
  const claims = base64URLJSON({
    iss: config.teamID,
    iat: Math.floor(Date.now() / 1_000),
  });
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(config.privateKey),
    {
      name: "ECDSA",
      namedCurve: "P-256",
    },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    {
      name: "ECDSA",
      hash: "SHA-256",
    },
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64URL(signature)}`;
}

function pemToArrayBuffer(pem: string) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

function base64URLJSON(value: unknown) {
  return base64URL(new TextEncoder().encode(JSON.stringify(value)));
}

function base64URL(value: ArrayBuffer | Uint8Array) {
  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
    },
  });
}
