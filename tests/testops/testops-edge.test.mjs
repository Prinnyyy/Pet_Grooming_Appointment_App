import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import {
  DEFAULT_SCENARIO,
  SupabaseREST,
  buildCleanupPlan,
  cleanupRun,
  makeBackendPlans,
  parseCustomerProfiles,
  parseGroomerProfiles,
  requiredServerCredential,
  runMarketplaceLifecycle,
  safeErrorMessage,
} from "../../scripts/testops-core.mjs";

const jwtServiceRoleKey = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature";
const customerRow =
  "| GTC-001 | groomly.customer001@example.com | GroomlyTest!2026 | Amelia / amelia.customer001@example.com / 310-555-1001 | 3965 Cesar E Chavez Ave, Los Angeles, CA 90063 | Mochi; Toy Poodle | Juniper; Domestic Shorthair |";
const groomerRow =
  "| GTG-001 | groomly.groomer001@example.com | GroomlyTest!2026 | Ava Chen / South LA Curl & Calm | Bio | 150 E El Segundo Blvd, Los Angeles, CA 90061 | both / 12 mi | 5 | XS-XL | coat_type:curly_wavy | Mon-Fri | full_groom $105/135m |";

test("seed parsers reject empty resources and duplicate seed ids", () => {
  const emptyCustomerFile = writeTempMarkdown("# Empty customer resource\n");
  assert.throws(
    () => parseCustomerProfiles(emptyCustomerFile),
    /No customer seed profiles found/
  );

  const duplicateCustomerFile = writeTempMarkdown(`${customerRow}\n${customerRow}\n`);
  assert.throws(
    () => parseCustomerProfiles(duplicateCustomerFile),
    /Duplicate customer seed id GTC-001/
  );

  const duplicateGroomerFile = writeTempMarkdown(`${groomerRow}\n${groomerRow}\n`);
  assert.throws(
    () => parseGroomerProfiles(duplicateGroomerFile),
    /Duplicate groomer seed id GTG-001/
  );
});

test("seed parsers reject unsafe account fields without leaking credentials", () => {
  const badCustomerFile = writeTempMarkdown(
    customerRow
      .replace("groomly.customer001@example.com", "not-an-email")
      .replace("GroomlyTest!2026", "")
  );

  assert.throws(
    () => parseCustomerProfiles(badCustomerFile),
    (error) => {
      assert.match(error.message, /Invalid customer seed GTC-001/);
      assert.doesNotMatch(error.message, /GroomlyTest!2026/);
      assert.doesNotMatch(error.message, /not-an-email/);
      return true;
    }
  );
});

test("backend plan generation rejects unsafe run ids before building remote tags", () => {
  const customerProfiles = parseCustomerProfiles(writeTempMarkdown(customerRow));
  const groomerProfiles = parseGroomerProfiles(writeTempMarkdown(groomerRow));

  for (const runID of ["", "TESTOPS BAD", "TESTOPS/../../X", "TESTOPS:%"]) {
    assert.throws(
      () =>
        makeBackendPlans({
          scenarioID: DEFAULT_SCENARIO,
          runID,
          customerProfiles,
          groomerProfiles,
        }),
      /Invalid TestOps run id/
    );
  }

  const [plan] = makeBackendPlans({
    scenarioID: DEFAULT_SCENARIO,
    runID: "TESTOPS-EDGE-001",
    customerProfiles,
    groomerProfiles,
  });
  assert.match(plan.request.serviceNotes, /^TESTOPS:TESTOPS-EDGE-001 /);
  assert.ok(Date.parse(plan.request.preferredStart) > Date.now());
  assert.ok(Date.parse(plan.request.preferredStart) < Date.parse(plan.request.preferredEnd));
  assert.ok(Date.parse(plan.offer.proposedStart) < Date.parse(plan.offer.proposedEnd));
  assert.equal(plan.request.travelRadiusMiles, 15);
});

test("service credential validation supports modern secret keys and rejects unsafe public keys", () => {
  for (const badKey of ["sb_publishable_123", "anon-key"]) {
    assert.throws(
      () => new SupabaseREST("https://example.supabase.co", "sb_publishable_client", badKey),
      (error) => {
        assert.match(error.message, /service credential/);
        assert.doesNotMatch(error.message, /sb_publishable_123/);
        return true;
      }
    );
  }

  const api = new SupabaseREST(
    "https://example.supabase.co",
    "sb_publishable_client",
    jwtServiceRoleKey
  );
  assert.equal(api.requireServiceRole(), jwtServiceRoleKey);
  assert.equal(api.headers(jwtServiceRoleKey).apikey, jwtServiceRoleKey);
  assert.equal(api.headers(jwtServiceRoleKey).Authorization, `Bearer ${jwtServiceRoleKey}`);

  const secretAPI = new SupabaseREST(
    "https://example.supabase.co",
    "sb_publishable_client",
    "sb_secret_server"
  );
  assert.equal(secretAPI.requireServiceRole(), "sb_secret_server");
  assert.deepEqual(secretAPI.headers("sb_secret_server"), {
    apikey: "sb_secret_server",
    "Content-Type": "application/json",
  });
  assert.equal(secretAPI.headers("user.jwt.token").apikey, "sb_publishable_client");
  assert.equal(secretAPI.headers("user.jwt.token").Authorization, "Bearer user.jwt.token");
});

test("sign in normalizes Supabase snake-case access token", async () => {
  const api = new SupabaseREST(
    "https://example.supabase.co",
    "sb_publishable_client",
    "sb_secret_server"
  );
  api.request = async () => ({
    access_token: "user.jwt.token",
    token_type: "bearer",
    user: { id: "user-1" },
  });

  const session = await api.signIn("customer@example.com", "password");

  assert.equal(session.accessToken, "user.jwt.token");
  assert.equal(session.access_token, "user.jwt.token");
  assert.equal(session.user.id, "user-1");
});

test("server credential env falls back to modern Supabase secret key", () => {
  assert.equal(
    requiredServerCredential({
      SUPABASE_SERVICE_ROLE_KEY: jwtServiceRoleKey,
      SUPABASE_SECRET_KEY: "sb_secret_server",
    }),
    jwtServiceRoleKey
  );
  assert.equal(
    requiredServerCredential({
      SUPABASE_SECRET_KEY: "sb_secret_server",
    }),
    "sb_secret_server"
  );
  assert.throws(
    () => requiredServerCredential({}),
    /SUPABASE_SERVICE_ROLE_KEY or SUPABASE_SECRET_KEY is required/
  );
});

test("safe error messages redact modern keys, JWTs, emails, UUIDs, and signed URLs", () => {
  const message = safeErrorMessage(
    "auth failed for groomly.customer001@example.com with sb_secret_SUPERSECRET " +
      "and token eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.sig " +
      "at https://example.supabase.co/storage/v1/object/sign/pet/photo.png?token=abc123 " +
      "id 123e4567-e89b-12d3-a456-426614174000"
  );

  assert.doesNotMatch(message, /groomly\.customer001@example\.com/);
  assert.doesNotMatch(message, /sb_secret_SUPERSECRET/);
  assert.doesNotMatch(message, /eyJhbGciOiJIUzI1NiJ9/);
  assert.doesNotMatch(message, /token=abc123/);
  assert.doesNotMatch(message, /123e4567-e89b-12d3-a456-426614174000/);
  assert.match(message, /\[email-domain:example\.com\]/);
  assert.match(message, /123e4567/);
});

test("cleanup run with no tagged requests does not issue delete calls", async () => {
  const calls = [];
  const api = {
    requireServiceRole() {
      return jwtServiceRoleKey;
    },
    async restSelect(table, query, token) {
      calls.push({ kind: "select", table, query, token });
      return [];
    },
    async restDelete() {
      throw new Error("delete should not be called when no tagged requests exist");
    },
  };

  const summary = await cleanupRun(api, "TESTOPS-EDGE-NONE");

  assert.deepEqual(summary, {
    runID: "TESTOPS-EDGE-NONE",
    requestCount: 0,
    deleted: {},
  });
  assert.deepEqual(calls, [
    {
      kind: "select",
      table: "grooming_requests",
      query: "select=id&service_notes=ilike.*TESTOPS%3ATESTOPS-EDGE-NONE*",
      token: jwtServiceRoleKey,
    },
  ]);
});

test("cleanup plan rejects unsafe run ids before constructing filters", () => {
  assert.throws(() => buildCleanupPlan("TESTOPS)OR(true"), /Invalid TestOps run id/);
  assert.throws(() => buildCleanupPlan("TESTOPS SPACE"), /Invalid TestOps run id/);
});

test("lifecycle zero-match failure does not expose full identifiers or credentials", async () => {
  const customerProfiles = parseCustomerProfiles(writeTempMarkdown(customerRow));
  const groomerProfiles = parseGroomerProfiles(writeTempMarkdown(groomerRow));
  const [plan] = makeBackendPlans({
    scenarioID: DEFAULT_SCENARIO,
    runID: "TESTOPS-EDGE-ZERO",
    customerProfiles,
    groomerProfiles,
  });
  const requestID = "123e4567-e89b-12d3-a456-426614174000";
  const api = {
    async signIn(email) {
      assert.notEqual(email, undefined);
      return {
        user: { id: email.includes("customer") ? "customer-user" : "groomer-user" },
        accessToken: "access-token",
      };
    },
    async restSelect(table) {
      if (table === "pets") {
        return [{ id: "pet-1", species: "Dog", name: "Mochi" }];
      }
      throw new Error(`unexpected restSelect ${table}`);
    },
    async rpc(name) {
      if (name === "create_grooming_request") {
        return [{ request_id: requestID, match_count: 0 }];
      }
      throw new Error(`unexpected rpc ${name}`);
    },
  };

  await assert.rejects(
    () => runMarketplaceLifecycle(api, plan),
    (error) => {
      assert.match(error.message, /zero matches/);
      assert.match(error.message, /123E4567/);
      assert.doesNotMatch(error.message, /123e4567-e89b-12d3-a456-426614174000/);
      assert.doesNotMatch(error.message, /GroomlyTest!2026/);
      assert.doesNotMatch(error.message, /groomly\.customer001@example\.com/);
      return true;
    }
  );
});

function writeTempMarkdown(markdown) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "groomly-testops-"));
  const filePath = path.join(dir, "resource.md");
  fs.writeFileSync(filePath, `${markdown.trimEnd()}\n`);
  return filePath;
}
