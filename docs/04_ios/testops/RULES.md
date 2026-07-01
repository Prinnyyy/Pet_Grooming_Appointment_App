# TestOps Rules

## Safety

- Do not record passwords, tokens, service-role keys, full emails, full UUIDs, raw headers, or raw Supabase request/response bodies.
- Use email domains only and 8-character support refs for UUIDs.
- Test data created by automation must include `TESTOPS:<run_id>` in a searchable field.
- Cleanup may delete only rows tagged with the current run id.
- Remote writes require explicit user authorization, `--execute`, and `TESTOPS_REMOTE_WRITE_APPROVED=1`.

## Assertion Rules

- Do not use screenshot matching as pass/fail logic.
- UI tests interact through stable `accessibilityIdentifier` values.
- Backend tests verify Auth, RPC, table state, and cleanup through Supabase APIs.
- Debug Console JSONL is diagnostic evidence, not a replacement for API assertions.

## Scope Rules

- TestOps must extend the existing Debug Console and `AppDebugEventRecorder`.
- Do not create a second toast, prompt, or logging stack.
- Do not add Supabase schema, RLS, RPC, or Storage changes inside TestOps unless a separate task explicitly authorizes that backend work.
- Do not create new test accounts inside TestOps; use the T-129 seeded customer/groomer pool.

