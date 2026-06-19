# Error Handling

## Principles

- Fail visibly.
- Preserve recoverable user input.
- Do not silently swallow backend errors.
- Log enough information for debugging.
- Show user-safe messages in UI.

## Error Categories

| Category | Example | Handling |
|---|---|---|
| Validation | Missing required field | Inline message |
| Network | Timeout | Retry option or visible error |
| Permission | RLS denied | User-safe permission message |
| Conflict | Duplicate action | Refresh state and show explanation |
| Unknown | Unexpected response | Generic error + log |

## Rules for Codex

When adding async behavior, include:
- loading state
- success state
- error state
- duplicate submission protection
