# Current State

Only dynamic task and recovery facts. Git owns branch, worktree and completion hashes.

```json
{
  "next_task_id": "T-421",
  "task": {
    "id": "T-420",
    "status": "active",
    "goal": "Adopt the approved customer prototype UI into production while preserving real data, navigation and accessibility contracts",
    "plan": "docs/superpowers/plans/2026-10-25-customer-ui-adoption.md",
    "next_action": "Foundations and kit committed; finish shell slice, then adopt Home/Requests and the remaining screen areas. Integrated runtime/accessibility/Release acceptance remains open; see plan execution record",
    "preserve": ["Pre-existing dirty contents and hashes: artifacts/evidence/T-420/pre-adoption/manifest.json", "Prototype and CLAUDE_sandbox are read-only except completion checkboxes; local signing stays uncommitted"],
    "authorization": ["User approved production adoption and scoped validated work-package commits; use current main branch"]
  },
  "pending_tasks": [
    {
      "id": "T-157",
      "status": "blocked",
      "goal": "APNs dispatch deployment outside the local Simulator scope",
      "plan": null,
      "next_action": "Do not resume unless the user adopts deployment scope and supplies its prerequisites",
      "blockers": [
        "External Apple membership/APNs credentials and deployment authorization; not a local app completion gate."
      ]
    }
  ],
  "last_completed": {
    "id": "T-419"
  }
}
```
