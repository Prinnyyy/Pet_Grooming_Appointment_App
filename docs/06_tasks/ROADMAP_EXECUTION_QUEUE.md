# Roadmap Execution Queue

Last verified: 2026-07-13.

Only unresolved packages appear here. This file does not assign `T-###` IDs or duplicate completed package history.

## Selection Rules

- Select a package only after an explicit user request.
- Use the next task ID from `TASK_LEDGER.md` when execution starts.
- Split remote writes, migrations, deploys, release actions, and independent UI/backend goals into separately authorized tasks.
- Deferred or blocked packages remain non-executable until their stated condition is satisfied.

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

No package is currently executable. Completed package evidence is preserved in `../09_frozen/roadmaps/T-346_2026-07-13/`, task-ledger archives, worklogs, and durable decisions.
