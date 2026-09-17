const deletionFailureMessage = "account_deletion_failed";
const storageListPageSize = 1000;
const storageRemoveBatchSize = 1000;
const accountStorageBucketIDs = [
  "avatars",
  "customer-avatars",
  "groomer-avatars",
  "pet-photos",
  "request-photos",
  "groomer-portfolio",
];

export async function handleDeleteAccount({
  request,
  userClient,
  adminClient,
}) {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const { data, error } = await userClient.rpc("request_account_deletion");
  if (error) {
    return jsonResponse({ error: deletionFailureMessage }, 500);
  }

  const deletionRequest = Array.isArray(data) ? data[0] : data;
  if (!isDeletionRequest(deletionRequest)) {
    return jsonResponse({ error: deletionFailureMessage }, 500);
  }

  try {
    await removeAccountStorageObjects({
      adminClient,
      userID: deletionRequest.user_id,
    });
  } catch (storageError) {
    await recordDeletionFailure({
      adminClient,
      deletionRequestID: deletionRequest.deletion_request_id,
      errorMessage: errorMessage(storageError),
    });
    return jsonResponse({ error: deletionFailureMessage }, 500);
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(
    deletionRequest.user_id,
    true,
  );

  if (deleteError) {
    await recordDeletionFailure({
      adminClient,
      deletionRequestID: deletionRequest.deletion_request_id,
      errorMessage: errorMessage(deleteError),
    });
    return jsonResponse({ error: deletionFailureMessage }, 500);
  }

  const { error: recordError } = await adminClient.rpc(
    "record_account_deletion_auth_soft_deleted",
    { p_deletion_request_id: deletionRequest.deletion_request_id },
  );
  if (recordError) {
    return jsonResponse({ error: deletionFailureMessage }, 500);
  }

  return jsonResponse({
    status: "completed",
    deletion_request_id: deletionRequest.deletion_request_id,
  });
}

export async function removeAccountStorageObjects({ adminClient, userID }) {
  for (const bucketID of accountStorageBucketIDs) {
    const bucket = adminClient.storage.from(bucketID);
    const paths = await listStorageObjectPaths({ bucket, rootPath: userID });

    for (let index = 0; index < paths.length; index += storageRemoveBatchSize) {
      const batch = paths.slice(index, index + storageRemoveBatchSize);
      const { error } = await bucket.remove(batch);

      if (error) {
        throw error;
      }
    }
  }
}

async function listStorageObjectPaths({ bucket, rootPath }) {
  const objectPaths = [];
  const pendingFolders = [rootPath];
  const visitedFolders = new Set();

  while (pendingFolders.length > 0) {
    const folderPath = pendingFolders.shift();
    if (visitedFolders.has(folderPath)) {
      continue;
    }
    visitedFolders.add(folderPath);

    let offset = 0;
    while (true) {
      const { data, error } = await bucket.list(folderPath, {
        limit: storageListPageSize,
        offset,
        sortBy: { column: "name", order: "asc" },
      });

      if (error) {
        throw error;
      }

      const entries = Array.isArray(data) ? data : [];
      for (const entry of entries) {
        if (typeof entry?.name !== "string" || !entry.name) {
          throw new Error("storage_list_invalid_entry");
        }

        const entryPath = `${folderPath}/${entry.name}`;
        if (entry.id === null) {
          pendingFolders.push(entryPath);
        } else {
          objectPaths.push(entryPath);
        }
      }

      if (entries.length < storageListPageSize) {
        break;
      }
      offset += entries.length;
    }
  }

  return objectPaths;
}

async function recordDeletionFailure({
  adminClient,
  deletionRequestID,
  errorMessage,
}) {
  await adminClient.rpc("record_account_deletion_failure", {
    p_deletion_request_id: deletionRequestID,
    p_error: errorMessage,
  });
}

function isDeletionRequest(value) {
  return value
    && typeof value.deletion_request_id === "string"
    && typeof value.user_id === "string";
}

function errorMessage(error) {
  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message.trim().slice(0, 500);
  }

  return deletionFailureMessage;
}

function jsonResponse(body, status = 200) {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
    },
  });
}
