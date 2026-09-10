# Roadmap Execution Queue

Last verified: 2026-07-28.

Only unresolved packages appear here. This file does not assign `T-###` IDs or duplicate completed package history.

## Selection Rules

- Select a package only after an explicit user request.
- Use the next task ID from `TASK_LEDGER.md` when execution starts.
- Split remote writes, migrations, deploys, release actions, and independent UI/backend goals into separately authorized tasks.
- Deferred or blocked packages remain non-executable until their stated condition is satisfied.

## Executable Queue

No product package is currently executable. Adopt or design the next package before allocating `T-365`.

## Deferred Queue

| Order | Roadmap | Package | State |
|---|---|---|---|
| Q-104 | R-039 | Groomer Dynamic Type and Accessibility integration gate | User-deferred; no automatic task allocation. |

## Blocked Queue

| Order | Roadmap | Package | Blocker |
|---|---|---|---|
| Q-90 | R-030 | APNs dispatch deployment | T-157 requires paid Apple Developer access, APNs credentials, and deploy authorization. |
| Q-91 | R-030 | TestFlight/App Store submission | Paid Apple Developer setup and release/upload authorization. |
| Q-93 | R-033 | Leaked-password protection | Supabase Pro-or-higher plan plus Auth configuration authorization. |

R-042 and Q-121 through Q-125 are complete through T-363. Completed package evidence is preserved in task-ledger archives, worklogs, and durable decisions.
