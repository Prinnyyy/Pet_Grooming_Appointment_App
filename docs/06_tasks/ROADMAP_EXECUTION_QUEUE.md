# Roadmap Execution Queue

Last verified: 2026-07-28.

Only unresolved packages appear here. This file does not assign `T-###` IDs or duplicate completed package history.

## Selection Rules

- Select a package only after an explicit user request.
- Use the next task ID from `TASK_LEDGER.md` when execution starts.
- Split remote writes, migrations, deploys, release actions, and independent UI/backend goals into separately authorized tasks.
- Deferred or blocked packages remain non-executable until their stated condition is satisfied.

## Executable Queue

R-042 remediates the reviewed Customer Request Journey in dependency order. Each package becomes one `T-###` task only when the user asks to execute it.

| Order | Roadmap | Package | State / Exit |
|---|---|---|---|
| Q-121 | R-042 | Request publish idempotency and recovery | Ready after explicit Supabase migration authorization. One customer publish operation creates at most one Request; photo upload and refresh failures cannot misreport Request creation as failed or invite a duplicate retry. |
| Q-122 | R-042 | Request Wizard input and time semantics | Ready after Q-121. Service choice is explicit, Custom Request requires useful detail, dates beyond the seven-day quick strip are reachable, and Continue has one truthful visual/interaction state with field-level validation. |
| Q-123 | R-042 | Request photo selection and retry | Ready after Q-122. Request-specific photos have preview, removal, review-summary, and post-create retry behavior while remaining distinct from the Pet avatar snapshot. |
| Q-124 | R-042 | Offer confirmation and Booking handoff | Ready after Q-123. Acceptance presents groomer/time/price/location/cancellation context, blocks duplicate submission, removes backend jargon, and routes directly to the resulting Booking. |
| Q-125 | R-042 | Request page state and visual consistency | Ready after Q-124. Requests exposes creation directly; Home and Requests distinguish loading/empty/error/loaded; horizontal cards expose position; reviewed copy, contrast, and strict UI-audit findings are corrected without resuming Q-104. |

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

Q-121 is the first selectable package but its remote migration remains unauthorized. Completed package evidence is preserved in `../09_frozen/roadmaps/T-346_2026-07-13/`, task-ledger archives, worklogs, and durable decisions.
