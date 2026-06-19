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
- [ ] Local demo mode preserved if applicable.

## Backend Check

- [ ] Supabase contract updated if needed.
- [ ] RLS/RPC assumptions documented if needed.
- [ ] No destructive operation performed.
- [ ] No secrets exposed.

## iOS Check

- [ ] Build script run if code changed.
- [ ] Tests run if relevant.
- [ ] Loading/error/empty states handled when relevant.
- [ ] Accessibility considered for UI changes.

## Memory Check

- [ ] `CURRENT_STATE.md` updated.
- [ ] `FEATURE_INDEX.md` updated if needed.
- [ ] `WORKLOG.md` appended.
- [ ] `DECISION_LOG.md` updated if needed.
