# Review Template

Use this for internal Codex review before reporting completion.

## Scope Check

- [ ] Only one major task was completed.
- [ ] No unrelated refactor was introduced.
- [ ] Existing user changes were preserved.

## Architecture Check

- [ ] Module boundaries preserved.
- [ ] Views remain thin.
- [ ] Backend access remains behind repositories/services.
- [ ] Preview/test fixtures remain isolated from production composition and success paths.

## Backend Check

- [ ] Supabase contract updated if needed.
- [ ] RLS/RPC assumptions documented if needed.
- [ ] No destructive operation performed.
- [ ] No secrets exposed.

## iOS Check

- [ ] The selected Quick/Standard/Deep validation rule was followed.
- [ ] No repeated build/test fix loop was started without approval.
- [ ] Loading/error/empty states handled when relevant.
- [ ] Accessibility considered for UI changes.

## Memory Check

- [ ] `CURRENT_STATE.md` updated only if project state changed.
- [ ] `FEATURE_INDEX.md` updated if needed.
- [ ] `WORKLOG.md` appended only after meaningful implementation.
- [ ] `DECISION_LOG.md` updated if needed.
