import assert from "node:assert/strict";
import { test } from "node:test";

import {
  handleDeleteAccount,
  removeAccountStorageObjects,
} from "../../supabase/functions/delete-account/delete-account.mjs";

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

test("delete-account removes user Storage objects between anonymization and Auth deletion", async () => {
  const calls = [];
  const storageListCalls = [];
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
    storage: {
      from: (bucketID) => ({
        list: async (path, options) => {
          storageListCalls.push([bucketID, path, options]);
          return { data: [], error: null };
        },
        remove: async () => {
          assert.fail("empty Storage folders must not call remove");
        },
      }),
    },
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
  assert.deepEqual(
    storageListCalls.map(([bucketID, path]) => [bucketID, path]),
    [
      ["avatars", userID],
      ["customer-avatars", userID],
      ["groomer-avatars", userID],
      ["pet-photos", userID],
      ["request-photos", userID],
      ["groomer-portfolio", userID],
    ],
  );
  assert.deepEqual(storageListCalls[0][2], {
    limit: 1000,
    offset: 0,
    sortBy: { column: "name", order: "asc" },
  });
});

test("delete-account recursively removes nested Storage objects", async () => {
  const requestID = "11111111-1111-4111-8111-111111111111";
  const userID = "22222222-2222-4222-8222-222222222222";
  const removed = [];
  const listed = [];

  const response = await handleDeleteAccount({
    request: new Request("https://example.test/delete-account", {
      method: "POST",
    }),
    userClient: {
      rpc: async () => ({
        data: [{ deletion_request_id: requestID, user_id: userID }],
        error: null,
      }),
    },
    adminClient: {
      storage: {
        from: (bucketID) => ({
          list: async (path) => {
            listed.push([bucketID, path]);

            if (bucketID === "customer-avatars" && path === userID) {
              return {
                data: [{ id: "avatar-object", name: "avatar.jpg" }],
                error: null,
              };
            }

            if (bucketID === "pet-photos" && path === userID) {
              return {
                data: [{ id: null, name: "pet-folder" }],
                error: null,
              };
            }

            if (bucketID === "pet-photos" && path === `${userID}/pet-folder`) {
              return {
                data: [
                  { id: "pet-object-a", name: "a.jpg" },
                  { id: "pet-object-b", name: "b.jpg" },
                ],
                error: null,
              };
            }

            return { data: [], error: null };
          },
          remove: async (paths) => {
            removed.push([bucketID, paths]);
            return { data: paths, error: null };
          },
        }),
      },
      auth: {
        admin: {
          deleteUser: async () => ({ error: null }),
        },
      },
      rpc: async () => ({ data: null, error: null }),
    },
  });

  assert.equal(response.status, 200);
  assert.ok(listed.some(([bucketID, path]) =>
    bucketID === "pet-photos" && path === `${userID}/pet-folder`
  ));
  assert.deepEqual(removed, [
    ["customer-avatars", [`${userID}/avatar.jpg`]],
    [
      "pet-photos",
      [
        `${userID}/pet-folder/a.jpg`,
        `${userID}/pet-folder/b.jpg`,
      ],
    ],
  ]);
});

test("account Storage cleanup paginates listing and removes at most 1000 paths per call", async () => {
  const userID = "22222222-2222-4222-8222-222222222222";
  const listOffsets = [];
  const removeBatchSizes = [];
  const firstPage = Array.from({ length: 1000 }, (_, index) => ({
    id: `object-${index}`,
    name: `${index}.jpg`,
  }));

  await removeAccountStorageObjects({
    userID,
    adminClient: {
      storage: {
        from: (bucketID) => ({
          list: async (_path, options) => {
            if (bucketID !== "avatars") {
              return { data: [], error: null };
            }

            listOffsets.push(options.offset);
            return options.offset === 0
              ? { data: firstPage, error: null }
              : {
                data: [{ id: "object-1000", name: "1000.jpg" }],
                error: null,
              };
          },
          remove: async (paths) => {
            removeBatchSizes.push(paths.length);
            return { data: paths, error: null };
          },
        }),
      },
    },
  });

  assert.deepEqual(listOffsets, [0, 1000]);
  assert.deepEqual(removeBatchSizes, [1000, 1]);
});

test("delete-account records Storage cleanup failures without deleting Auth user", async () => {
  const requestID = "11111111-1111-4111-8111-111111111111";
  const userID = "22222222-2222-4222-8222-222222222222";
  const recordedFailures = [];
  let authDeleteCalled = false;

  const response = await handleDeleteAccount({
    request: new Request("https://example.test/delete-account", {
      method: "POST",
    }),
    userClient: {
      rpc: async () => ({
        data: [{ deletion_request_id: requestID, user_id: userID }],
        error: null,
      }),
    },
    adminClient: {
      storage: {
        from: () => ({
          list: async () => ({
            data: null,
            error: { message: "storage unavailable" },
          }),
          remove: async () => ({ data: null, error: null }),
        }),
      },
      auth: {
        admin: {
          deleteUser: async () => {
            authDeleteCalled = true;
            return { error: null };
          },
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
  assert.equal(authDeleteCalled, false);
  assert.deepEqual(recordedFailures, [
    [
      "record_account_deletion_failure",
      {
        p_deletion_request_id: requestID,
        p_error: "storage unavailable",
      },
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
      storage: {
        from: () => ({
          list: async () => ({ data: [], error: null }),
          remove: async () => ({ data: [], error: null }),
        }),
      },
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
