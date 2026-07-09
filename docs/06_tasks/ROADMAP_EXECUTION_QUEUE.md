# Roadmap Execution Queue

Last verified: 2026-07-09.

Purpose: convert `ROADMAP.md` candidates into adoptable packages. This file does not assign `T-###` IDs. Each adopted package uses the next ID from `TASK_LEDGER.md`, one primary package per run.

Source: T-202 adopted root review input `../../V1.0_RELEASE_TASK_PLAN.md`; that root file is not an active task source.

## Selection Rules

- There are no remaining unblocked V1.0 ideal-operation packages after T-222/Q-33.
- Do not start a new package from this file unless a new queue row is added or the user names a blocked package and provides the required credentials/authorization.
- Split any package that combines Supabase writes with visible SwiftUI or grows beyond one reviewable task.
- Get explicit authorization before migrations, Auth config writes, remote TestOps, seeds, deploys, release uploads, or other non-Git remote writes.
- Do not start Q-90...Q-92 until credentials and authorization are recorded.
- Q-01...Q-33 are complete and mapped in `ROADMAP.md`.

## Queue

| Order | Roadmap | Package | Mode | Scope | Validation |
|---|---|---|---|---|---|
| _none_ | _none_ | _none_ | _none_ | No unblocked local/read-only ideal-operation packages remain. | Add a new row before executing another roadmap package. |

## Blocked External Queue

| Order | Roadmap | Package | Blocker |
|---|---|---|---|
| Q-90 | R-030 | APNs dispatch deployment | Paid Apple Developer, APNs secrets, deploy authorization. |
| Q-91 | R-030 | TestFlight / App Store submission | Paid Apple Developer and release/upload authorization. |
| Q-92 | R-030 | Production email domain and SMTP | Production domain, SMTP secrets, Auth config authorization. |
