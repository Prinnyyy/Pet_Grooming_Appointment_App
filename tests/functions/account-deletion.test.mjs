import assert from "node:assert/strict";
import { test } from "node:test";

import { handleDeleteAccount } from "../../supabase/functions/delete-account/delete-account.mjs";

test("delete-account rejects non-POST requests", async () => {
  const response = await handleDeleteAccount({
    request: new Request("https://example.test/delete-account", {
      method: "GET",
    }),
    userClient: {},
    adminClient: {},
  });

  assert.equal(response.status, 405);
  assert.deepEqual(await response.json(), { error: "method_not_allowed" });
});

test("delete-account anonymizes through RPC before soft-deleting the Auth user", async () => {
  const calls = [];
  const requestID = "11111111-1111-4111-8111-111111111111";
  const userID = "22222222-2222-4222-8222-222222222222";
  const userClient = {
    rpc: async (name) => {
      calls.push(["user-rpc", name]);
      assert.equal(name, "request_account_deletion");
      return {
        data: [{
          deletion_request_id: requestID,
          user_id: userID,
          role: "customer",
          status: "pending_auth_soft_delete",
          requested_at: "2026-07-07T12:00:00Z",
        }],
        error: null,
      };
    },
  };
  const adminClient = {
    auth: {
      admin: {
        deleteUser: async (deletedUserID, shouldSoftDelete) => {
          calls.push(["delete-user", deletedUserID, shouldSoftDelete]);
          assert.equal(deletedUserID, userID);
          assert.equal(shouldSoftDelete, true);
          return { error: null };
        },
      },
    },
    rpc: async (name, params) => {
      calls.push(["admin-rpc", name, params]);
      assert.equal(name, "record_account_deletion_auth_soft_deleted");
      assert.deepEqual(params, { p_deletion_request_id: requestID });
      return { data: null, error: null };
    },
  };

  const response = await handleDeleteAccount({
    request: new Request("https://example.test/delete-account", {
      method: "POST",
    }),
    userClient,
    adminClient,
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: "completed",
    deletion_request_id: requestID,
  });
  assert.deepEqual(calls, [
    ["user-rpc", "request_account_deletion"],
    ["delete-user", userID, true],
    [
      "admin-rpc",
      "record_account_deletion_auth_soft_deleted",
      { p_deletion_request_id: requestID },
    ],
  ]);
});

test("delete-account records auth soft-delete failures", async () => {
  const requestID = "11111111-1111-4111-8111-111111111111";
  const userID = "22222222-2222-4222-8222-222222222222";
  const recordedFailures = [];
  const response = await handleDeleteAccount({
    request: new Request("https://example.test/delete-account", {
      method: "POST",
    }),
    userClient: {
      rpc: async () => ({
        data: [{
          deletion_request_id: requestID,
          user_id: userID,
          role: "groomer",
          status: "pending_auth_soft_delete",
          requested_at: "2026-07-07T12:00:00Z",
        }],
        error: null,
      }),
    },
    adminClient: {
      auth: {
        admin: {
          deleteUser: async () => ({
            error: { message: "auth service unavailable" },
          }),
        },
      },
      rpc: async (name, params) => {
        recordedFailures.push([name, params]);
        return { data: null, error: null };
      },
    },
  });

  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: "account_deletion_failed" });
  assert.deepEqual(recordedFailures, [
    [
      "record_account_deletion_failure",
      {
        p_deletion_request_id: requestID,
        p_error: "auth service unavailable",
      },
    ],
  ]);
});
