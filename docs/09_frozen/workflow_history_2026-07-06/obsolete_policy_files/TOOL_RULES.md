# Tool Rules

Use tools only when they reduce uncertainty or verify the requested result.

- Prefer targeted reads and existing scripts.
- Prefer read-only inspection before writes.
- Do not read or expose secrets.
- Do not make destructive or remote changes without explicit approval.
- Tool availability does not justify additional scope or validation.
- Quick Mode validates only when directly needed.
- Standard Mode makes one build attempt by default.
- Deep Mode states an explicit validation plan.
- Stop after the first real validation error unless the user approves a follow-up.

Superpowers is optional; see `SUPERPOWERS_USAGE_POLICY.md`.
