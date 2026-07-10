import assert from "node:assert/strict";
import { test } from "node:test";

import {
  buildSeedIdentityCutoverPlan,
  executeSeedIdentityCutover,
  identityDigest,
  requireSeedCutoverApproval,
  verifyCompletedSeedCutover,
} from "../../scripts/seed-identity-cutover-core.mjs";

const customerProfile = {
  seedID: "BTC-001",
  email: "beckon.customer001@example.com",
  password: "BeckonTest!2026",
};
const groomerProfile = {
  seedID: "BTG-001",
  email: "beckon.groomer001@example.com",
  password: "BeckonTest!2026",
};

function legacyUser({
  id,
  seedID,
  email,
  role,
}) {
  return {
    id,
    email,
    app_metadata: {
      provider: "email",
      providers: ["email"],
      role,
      groomly_seed: "T-129",
      groomly_seed_id: seedID,
    },
    user_metadata: {
      display_name: role === "customer" ? "Amelia" : "Ava Chen",
      groomly_seed: "T-129",
      groomly_seed_id: seedID,
    },
  };
}

test("cutover plan maps legacy users to Beckon identities without changing UUIDs", () => {
  const users = [
    legacyUser({
      id: "11111111-1111-4111-8111-111111111111",
      seedID: "GTC-001",
      email: "groomly.customer001@example.com",
      role: "customer",
    }),
    legacyUser({
      id: "22222222-2222-4222-8222-222222222222",
      seedID: "GTG-001",
      email: "groomly.groomer001@example.com",
      role: "groomer",
    }),
  ];

  const plan = buildSeedIdentityCutoverPlan({
    users,
    customerProfiles: [customerProfile],
    groomerProfiles: [groomerProfile],
    expectedCount: 2,
  });

  assert.equal(plan.length, 2);
  assert.deepEqual(
    plan.map(({ userID, targetSeedID, targetEmail }) => ({
      userID,
      targetSeedID,
      targetEmail,
    })),
    [
      {
        userID: users[0].id,
        targetSeedID: "BTC-001",
        targetEmail: "beckon.customer001@example.com",
      },
      {
        userID: users[1].id,
        targetSeedID: "BTG-001",
        targetEmail: "beckon.groomer001@example.com",
      },
    ]
  );
  assert.equal(plan[0].updatePayload.app_metadata.groomly_seed_id, null);
  assert.equal(plan[0].updatePayload.user_metadata.groomly_seed, null);
  assert.equal(plan[0].updatePayload.app_metadata.beckon_seed_id, "BTC-001");
  assert.equal(plan[0].updatePayload.user_metadata.beckon_seed_id, "BTC-001");
  assert.equal(plan[0].rollbackPayload.email, users[0].email);
  assert.equal(plan[0].rollbackPayload.app_metadata.groomly_seed_id, "GTC-001");
  assert.equal(plan[0].rollbackPayload.app_metadata.beckon_seed_id, null);
  assert.equal(plan[0].legacyRollbackPayload.email, users[0].email);
  assert.equal(plan[0].legacyRollbackPayload.app_metadata.groomly_seed_id, "GTC-001");
  assert.equal(identityDigest(plan), identityDigest([...plan].reverse()));
  assert.throws(() => verifyCompletedSeedCutover(plan), /2 incomplete user/i);
});

test("cutover plan rejects target collisions and incomplete legacy sets", () => {
  const legacy = legacyUser({
    id: "11111111-1111-4111-8111-111111111111",
    seedID: "GTC-001",
    email: "groomly.customer001@example.com",
    role: "customer",
  });
  const collision = {
    ...legacy,
    id: "33333333-3333-4333-8333-333333333333",
    email: customerProfile.email,
    app_metadata: {},
    user_metadata: {},
  };

  assert.throws(
    () => buildSeedIdentityCutoverPlan({
      users: [legacy, collision],
      customerProfiles: [customerProfile],
      groomerProfiles: [groomerProfile],
      expectedCount: 2,
    }),
    /target email collision/i
  );
  assert.throws(
    () => buildSeedIdentityCutoverPlan({
      users: [legacy],
      customerProfiles: [customerProfile],
      groomerProfiles: [groomerProfile],
      expectedCount: 2,
    }),
    /missing legacy seed user for BTG-001/i
  );
});

test("cutover execution rolls back already updated users after a failure", async () => {
  const users = [
    legacyUser({
      id: "11111111-1111-4111-8111-111111111111",
      seedID: "GTC-001",
      email: "groomly.customer001@example.com",
      role: "customer",
    }),
    legacyUser({
      id: "22222222-2222-4222-8222-222222222222",
      seedID: "GTG-001",
      email: "groomly.groomer001@example.com",
      role: "groomer",
    }),
  ];
  const plan = buildSeedIdentityCutoverPlan({
    users,
    customerProfiles: [customerProfile],
    groomerProfiles: [groomerProfile],
    expectedCount: 2,
  });
  const calls = [];
  const api = {
    async updateUser(userID, payload) {
      calls.push({ userID, payload });
      if (userID === users[1].id) {
        throw new Error("injected update failure");
      }
      return { id: userID };
    },
  };

  await assert.rejects(
    executeSeedIdentityCutover(api, plan),
    /rolled back 1 updated user/i
  );
  assert.equal(calls.length, 3);
  assert.equal(calls[2].userID, users[0].id);
  assert.equal(calls[2].payload.email, users[0].email);
  assert.equal(calls[2].payload.password, "GroomlyTest!2026");
});

test("re-entered cleanup rolls back to the pre-run Beckon identity", async () => {
  const users = [
    legacyUser({
      id: "11111111-1111-4111-8111-111111111111",
      seedID: "GTC-001",
      email: "groomly.customer001@example.com",
      role: "customer",
    }),
    legacyUser({
      id: "22222222-2222-4222-8222-222222222222",
      seedID: "GTG-001",
      email: "groomly.groomer001@example.com",
      role: "groomer",
    }),
  ].map((user, index) => ({
    ...user,
    email: index === 0 ? customerProfile.email : groomerProfile.email,
    app_metadata: {
      ...user.app_metadata,
      beckon_seed: "T-129",
      beckon_seed_id: index === 0 ? "BTC-001" : "BTG-001",
    },
    user_metadata: {
      ...user.user_metadata,
      beckon_seed: "T-129",
      beckon_seed_id: index === 0 ? "BTC-001" : "BTG-001",
    },
  }));
  const plan = buildSeedIdentityCutoverPlan({
    users,
    customerProfiles: [customerProfile],
    groomerProfiles: [groomerProfile],
    expectedCount: 2,
  });
  const calls = [];
  const api = {
    async updateUser(userID, payload) {
      calls.push({ userID, payload });
      if (userID === users[1].id) throw new Error("injected cleanup failure");
      return { id: userID };
    },
  };

  await assert.rejects(executeSeedIdentityCutover(api, plan), /rolled back 1 updated user/i);
  assert.equal(calls[2].payload.email, customerProfile.email);
  assert.equal(calls[2].payload.password, customerProfile.password);
  assert.equal(calls[2].payload.app_metadata.beckon_seed_id, "BTC-001");
  assert.equal(calls[2].payload.app_metadata.groomly_seed_id, "GTC-001");
});

test("cutover requires the explicit environment approval gate", () => {
  assert.throws(() => requireSeedCutoverApproval({}), /BECKON_REMOTE_IDENTITY_APPROVED=1/);
  assert.doesNotThrow(() => requireSeedCutoverApproval({ BECKON_REMOTE_IDENTITY_APPROVED: "1" }));
});
