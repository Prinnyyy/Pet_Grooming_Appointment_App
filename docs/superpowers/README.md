# Task Plans And Specs

Use a plan for a complex adopted objective, not every small change. [Current State](../00_memory/CURRENT_STATE.md) owns dynamic status and the current plan pointer; plans own scope, decisions and acceptance requirements.

Preserve the existing metadata convention for provenance:

```text
<!-- task-artifact
task: T-###
status: active
type: plan
-->
```

Use type plan/spec and artifact status active/completed. Artifact status is not the full task lifecycle: planned/paused/blocked are recorded in Current State. Mark an artifact completed when its described work is accepted; its authoring task may retain a distinct historical documentation-closure record.

Completed plans remain at their original paths as evidence, not current rules. No automatic archive, one-plan limit, backlink rewrite or fixed review cadence applies. Broad search hides plan bodies; hygiene explicitly checks the current plan and changed/untracked task artifacts. Pending plan pointers remain available for recovery without loading all pending bodies.

Scope and safety come from [Development Guide](../05_workflow/DEVELOPMENT_GUIDE.md), never from a historical unchecked box or old authorization.
