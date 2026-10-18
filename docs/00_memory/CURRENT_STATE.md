# Current State

Only dynamic task and recovery facts. Git owns branch, worktree and completion hashes.

```json
{
  "next_task_id": "T-417",
  "task": null,
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
    "id": "T-416"
  }
}
```
