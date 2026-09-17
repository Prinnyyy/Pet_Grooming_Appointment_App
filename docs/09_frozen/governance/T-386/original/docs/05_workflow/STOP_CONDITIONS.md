# Stop Conditions

Owns: the stop-and-report matrix only.

Expected development RED states are governed by `TOOLING_POLICY.md` and are not stop conditions by themselves.

| Trigger | Required action | Owner for detail |
|---|---|---|
| Objective expands into another feature, rule task, broad refactor, or unrelated cleanup | Stop and split scope. | `SINGLE_AGENT_WORKFLOW.md` |
| Product/backend/navigation/role decision is missing or a screenshot cannot map to current ownership | Stop before implementation and request the decision. | Active product/backend docs |
| Target files contain unexplained user work or the branch/task facts conflict | Stop before edits; report the conflict. | `CONTEXT_AND_RECOVERY.md` |
| Secret, destructive operation, dependency/signing change, or unauthorized remote operation is required | Stop before the operation and request explicit authorization. | `TOOLING_POLICY.md` |
| Current docs conflict with code/scripts/migrations/verified tools, or safe continuation needs an unclear/broad L4 read | Stop and report the smallest conflicting evidence. | `CONTEXT_AND_RECOVERY.md` |
| Completion validation fails outside the one allowed narrow task-caused correction | Report the first real error and stop. | `TOOLING_POLICY.md` |
| Required Simulator/runtime evidence is unavailable and the user has not deferred it | Report the first blocker and stop. | `TOOLING_POLICY.md` |
| Completion push fails or is rejected | Report and stop without reconciliation. | `GITHUB_RULES.md` |
| Context pressure makes the next edit or validation unreliable | Write the minimum checkpoint and end/compact; do not start another task. | `CONTEXT_AND_RECOVERY.md` |
| Hygiene cannot repair a malformed/insufficient rotation window in one scoped batch | Report the structural blocker and stop. | `CONTEXT_AND_RECOVERY.md` |

## Stop Report

```text
Stop reason:
What was attempted:
What was found:
Files touched:
Safe next options:
User decision needed:
```

For screenshot/UI stops, also identify the screenshot module, existing ownership, likely files, and required validation.
