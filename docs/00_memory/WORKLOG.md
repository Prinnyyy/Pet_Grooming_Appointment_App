# Worklog

Recent closeouts only. Full historical worklog is archived at `docs/09_frozen/worklogs/WORKLOG_2026-06-19_to_2026-06-22.md`.

## Entries

```text
Date: 2026-07-06
Task: T-049 - Repair active Markdown information architecture.
Files changed: AGENTS.md, README.md, CLAUDE.md, docs indexes, workflow files, memory files, task ledger, design/archive indexes, context hygiene script, ignore rules, and frozen archive moves.
Checks: git diff --check; node scripts/context-hygiene-check.mjs.
Result: Active docs now use a layered L0-L4 access model. Stale task records, old workflow reports, old Fresh Brief, legacy Codex init plan, old Groomly prompt, Claude roadmap snapshot, Superpowers historical plans, and external agent drafts are archived under docs/09_frozen. Active task numbering advances to T-050.
Risks: This is docs/workflow only; no Swift, Supabase, Xcode, runtime, or UI behavior changed.
Next: Use the compact L0 startup and targeted L1/L2 indexes for future tasks.
```

```text
Date: 2026-06-22
Task: T-048 - Groomly customer new request wizard rework.
Result: Customer new request uses a five-step Pet/Service/Time/Details/Review wizard wired to existing persisted fields where supported. Location mode/address/range and photo tiles remain UI-only.
Checks: Targeted wizard presentation tests, ./scripts/ios-build.sh, git diff --check, simulator launch.
Next: Wait for explicit direction before adding persistent location/photo support.
```

```text
Date: 2026-06-22
Task: T-047 follow-ups - Customer request card/Home sync/global notices.
Result: Requests and Customer Home share visible quest card presentation, bottom success notices are global tab-shell state, and active/booked cards share polished compact presentation.
Checks: Targeted Store/feedback tests, ./scripts/ios-build.sh, git diff --check, simulator launches.
Next: Wait for explicit direction before more request persistence or visual tuning.
```

```text
Date: 2026-06-22
Task: T-046 - Groomly customer request handoff card fusion.
Result: Booked requests with matching confirmed bookings render through the quest action card and support same-device acknowledgement persistence.
Checks: Targeted Store tests, git diff --check, ./scripts/ios-build.sh, ./scripts/ios-test.sh, simulator launch.
Next: Cross-device handoff persistence requires a future backend/model task.
```

```text
Date: 2026-06-22
Task: T-045 - Groomly customer request booking handoff.
Result: Customer Requests shows open/has_offers cards plus booked -> confirmed booking handoff cards that open existing Booking detail.
Checks: Targeted Store tests, git diff --check, ./scripts/ios-build.sh, ./scripts/ios-test.sh, simulator launch.
Next: Do not add booking/request lifecycle backend changes without explicit scope.
```

```text
Date: 2026-06-22
Task: T-044 - Groomly customer request cancellation.
Result: Added controlled `cancel_grooming_request` RPC and iOS Store/repository/view wiring for cancelling open/has_offers requests.
Checks: Supabase MCP apply/rollback-only behavior checks/advisors, ./scripts/supabase-check.sh, git diff --check, ./scripts/ios-build.sh, ./scripts/ios-test.sh, simulator launch.
Next: Booking cancellation remains separate in `cancel_booking`.
```

```text
Date: 2026-06-22
Task: T-043 - Groomly customer Requests carousel edge refinement.
Result: Carousel bleeds to screen edges while keeping content aligned and shadows unclipped.
Checks: git diff --check, ./scripts/ios-build.sh, simulator launch.
Next: Further card content or lifecycle work requires explicit direction.
```

```text
Date: 2026-06-22
Task: T-042 - Groomly customer Requests carousel refinement.
Result: Requests page renders request progress as horizontally scrollable per-request cards.
Checks: git diff --check, ./scripts/ios-build.sh, simulator launch.
Next: Superseded request-edit/cancel placeholders were later handled by T-044.
```
