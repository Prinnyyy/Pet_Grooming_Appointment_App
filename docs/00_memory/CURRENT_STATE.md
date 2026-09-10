# Current State

Only dynamic task and recovery facts. Git owns branch, worktree and completion hashes.

```json
{
  "next_task_id": "T-390",
  "task": null,
  "pending_tasks": [
    {
      "id": "T-365",
      "status": "paused",
      "goal": "Preserve original functional findings documentation closure",
      "plan": null,
      "next_action": "Retain original drafting provenance; do not reopen functionality accepted in T-385",
      "preserve": [
        "docs/06_tasks/APP_FUNCTIONAL_DESIGN_FINDINGS.md was uncommitted at T-386 entry; no historical T-365 completion commit is claimed. Original document retained in the T-386 publication; separate authoring completion is not inferred."
      ]
    },
    {
      "id": "T-366",
      "status": "paused",
      "goal": "Preserve matching review addendum documentation closure",
      "plan": null,
      "next_action": "Retain original drafting provenance; separate it from completed functional remediation",
      "preserve": [
        "Original matching addendum is part of docs/06_tasks/APP_FUNCTIONAL_DESIGN_FINDINGS.md; no historical T-366 completion commit is claimed. Original document retained in the T-386 publication; separate authoring completion is not inferred."
      ]
    },
    {
      "id": "T-367",
      "status": "paused",
      "goal": "Preserve master plan authoring provenance",
      "plan": "docs/superpowers/plans/2026-09-07-functional-reliability-task-plan.md",
      "next_action": "Retain historical authoring closure separately from WP-00 through WP-14 accepted in T-385",
      "preserve": [
        "Master plan was uncommitted at T-386 entry; no historical T-367 completion commit is claimed. Original document retained in the T-386 publication; separate authoring completion is not inferred."
      ]
    },
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
    "id": "T-389"
  }
}
```
