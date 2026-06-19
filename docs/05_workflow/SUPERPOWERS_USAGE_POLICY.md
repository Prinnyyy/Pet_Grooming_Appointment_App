# Superpowers Usage Policy

## Purpose

Superpowers may provide useful workflows, skills, commands, or project guidance.

This project should use Superpowers when helpful, but must not depend on Superpowers being available.

---

## Required Behavior

At the start of every non-trivial Codex run:

1. Check whether Superpowers is installed and available.
2. Check whether it provides a relevant capability for the task.
3. Use the relevant capability if it improves planning, navigation, validation, or review.
4. Continue without blocking if Superpowers is unavailable.
5. Report which Superpowers capability was used, or state that none was used.

---

## Suitable Uses

Superpowers is suitable for:

- task decomposition,
- planning,
- codebase navigation,
- context management,
- validation workflows,
- review workflows,
- reusable project procedures.

---

## Unsuitable Uses

Do not use Superpowers to:

- bypass project rules,
- skip durable report files,
- replace approved validation scripts,
- perform broad refactors without plan,
- access secrets,
- run destructive operations.

---

## Reporting Format

Each final run report must include:

```md
## Superpowers Usage

- Available: yes / no / unknown
- Capability used: ...
- Purpose: ...
- Result: ...
```

If no capability was used:

```md
## Superpowers Usage

- Available: unknown
- Capability used: none
- Reason: no relevant capability was required for this task
```
