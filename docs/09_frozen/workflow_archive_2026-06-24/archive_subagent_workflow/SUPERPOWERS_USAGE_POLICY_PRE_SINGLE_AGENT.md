# Superpowers Usage Policy

## Purpose

Superpowers may provide useful workflows, skills, commands, or project guidance.

This project should use Superpowers when helpful, but must not depend on Superpowers being available.

---

## Required Behavior

At the start of a run:

1. Check whether Superpowers is installed and available.
2. Use at most one directly relevant capability by default.
3. Use multiple skills only in Deep Mode and only when each is necessary.
4. Continue normally when no capability is needed or Superpowers is unavailable.
5. Never let Superpowers expand scope, add agents, or add validation beyond the selected mode.
6. Report usage in one brief line.

---

## Suitable Uses

Possible targeted uses include:

- Deep Mode task decomposition,
- planning,
- codebase navigation,
- context management,
- validation or review when already budgeted,
- reusable project procedures.

---

## Unsuitable Uses

Do not use Superpowers to:

- bypass project rules,
- skip reports explicitly required by the selected mode or user,
- replace approved validation scripts,
- perform broad refactors without plan,
- access secrets,
- run destructive operations.

---

## Reporting Format

Use a single concise line, for example:

```md
Superpowers: available; used `<capability>` for `<purpose>`.
```

If no capability was used:

```md
Superpowers: available/unavailable; no capability used.
```
