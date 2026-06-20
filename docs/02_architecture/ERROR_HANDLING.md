# Error Handling

## Principles

- Fail visibly and preserve recoverable user input.
- Separate configuration, authentication, validation, permission, conflict, transport, Storage, and unknown failures.
- Map infrastructure errors to user-safe messages without discarding diagnostic cause.
- Refresh authoritative state after conflicts or ambiguous mutation outcomes.
- Never convert backend failure into local success.

## Error Categories

| Category | Example | UI Handling | Diagnostic Handling |
|---|---|---|---|
| Configuration | Missing Supabase URL or publishable key | Blocking configuration state | Environment name and missing field only |
| Authentication | Invalid credentials or expired session | Inline Auth error or return to Auth | Sanitized Auth operation and code |
| Validation | Required field missing or invalid time range | Inline field message | Usually no remote log required |
| Permission | RLS denies cross-user access | Safe unavailable/permission message | Table/operation and correlation context, no tokens |
| Conflict | Offer/request changed or booking overlaps | Explain conflict and refresh | Transition name and safe record IDs |
| Network | Timeout or offline request | Visible retry path | Underlying transport category |
| Storage | Invalid file, denied path, or upload failure | Keep image draft and offer retry/remove | Bucket, safe path prefix, and operation |
| Decoding | Unexpected response shape | General data error and retry | Expected type and sanitized response metadata |
| Unknown | Unclassified failure | General error with recovery action | Full local error in development-safe logging |

## Async State Contract

Each async feature state distinguishes:

```text
idle
loading or submitting
content or success
empty when applicable
recoverable failure
```

Submission controls remain disabled only while that specific operation is in flight. Cancellation and task replacement must not let stale responses overwrite newer state.

## Critical Mutation Rules

- On RPC failure, keep the previous authoritative state and show the backend result.
- On timeout after a possibly committed mutation, refresh before allowing a retry that could duplicate work.
- Map uniqueness and booking-overlap failures to specific conflict messages.
- Do not retry non-idempotent transitions automatically unless the backend contract defines an idempotency mechanism.

## Logging and Debug Panel

Allowed diagnostics include environment label, current user ID, profile role, sanitized operation name, safe record ID, and last API error category. Never log or display passwords, refresh tokens, full access tokens, secret keys, or full sensitive payloads.
