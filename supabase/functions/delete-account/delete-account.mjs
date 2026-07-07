const deletionFailureMessage = "account_deletion_failed";

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
