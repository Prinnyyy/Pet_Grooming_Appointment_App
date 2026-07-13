# Beckon: Pet Grooming

iOS SwiftUI marketplace app for pet grooming appointments.

Pet groomers at your beck and call.

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

The MVP implementation is complete and the implemented Beckon UI phase is historical. Current task state and task numbering live in `docs/06_tasks/TASK_LEDGER.md`.

Detailed task records, including T-001 through T-088 and completed Beckon UI records, are archived under:

```text
docs/09_frozen/task_records_2026-06-26/
```

This README does not define active work. Start new work only from an explicit user request and the next available task ID in the ledger.

## Main References

- Agent rules: `AGENTS.md`
- Claude guide: `CLAUDE.md`
- Current state: `docs/00_memory/CURRENT_STATE.md`
- Canonical brand identity: `docs/01_product/BRAND_IDENTITY.md`
- Project structure index: `docs/10_project_structure/README.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Managed roadmap: `docs/06_tasks/ROADMAP.md`
- Durable decisions: `docs/07_decisions/DECISION_LOG.md`
- Task folder guide: `docs/06_tasks/README.md`
- Workflow rules: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
- Context/recovery tiers: `docs/05_workflow/CONTEXT_AND_RECOVERY.md`
- Tooling policy: `docs/05_workflow/TOOLING_POLICY.md`
- Git/GitHub rules: `docs/05_workflow/GITHUB_RULES.md`
- Search ignore rules: `.rgignore`
- Context hygiene check: `scripts/context-hygiene-check.mjs`
- Current Beckon UI notes: `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
- Design screenshots: `docs/08_design/screenshots/`
- Frozen archives: `docs/09_frozen/README.md`
- Frozen task records: `docs/09_frozen/task_records_2026-06-26/`
- Historical design prompts: `docs/09_frozen/design_prompts/`
- Historical product briefs: `docs/09_frozen/product_briefs/`
- Beckon prototype source: `docs/08_design/Beckon.html`
- Existing SwiftUI design tokens: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`

## Validation

Mode-specific validation and remote-operation authorization live only in `docs/05_workflow/TOOLING_POLICY.md`. Use its task-scoped commands rather than treating every repository script as a default gate.
