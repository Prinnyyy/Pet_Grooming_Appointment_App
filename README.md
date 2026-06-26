# Pet Groomer Marketplace

iOS SwiftUI marketplace app for pet grooming appointments.

Current product flow:

```text
Customer publishes an open grooming request
-> matched groomers make offers
-> customer accepts one offer
-> booking and chat are created
-> groomer completes the booking
-> customer leaves a review
```

## Active Phase

The MVP implementation is complete and the implemented Groomly UI phase is historical. Current task state and task numbering live in `docs/06_tasks/TASK_LEDGER.md`.

Detailed task records, including T-001 through T-088 and completed Groomly UI records, are archived under:

```text
docs/09_frozen/task_records_2026-06-26/
```

No active next Groomly UI, pet-fit, availability, backend, or screenshot task is currently defined. Start new work only from an explicit user request and the next available task ID in the ledger.

## Main References

- Agent rules: `AGENTS.md`
- Current state: `docs/00_memory/CURRENT_STATE.md`
- Project structure index: `docs/10_project_structure/README.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Task folder guide: `docs/06_tasks/README.md`
- Workflow rules: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
- Context/recovery tiers: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`
- Tooling policy: `docs/05_workflow/TOOLING_POLICY.md`
- Design screenshots: `docs/08_design/screenshots/`
- Frozen archives: `docs/09_frozen/README.md`
- Frozen task records: `docs/09_frozen/task_records_2026-06-26/`
- Groomly design prompt: `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`
- Groomly prototype: `docs/08_design/Groomly.html`
- Existing SwiftUI design tokens: `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/DesignTokens.swift`

## Validation Commands

```sh
./scripts/ios-build.sh
./scripts/ios-test.sh
./scripts/preflight.sh
./scripts/supabase-check.sh
```
