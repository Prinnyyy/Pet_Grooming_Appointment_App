# Task Artifact Staging

This directory temporarily holds task-specific plans and specs. It is not a durable fact source. Current rules, status, and decisions belong in their active owner files.

Every Markdown file below `plans/` or `specs/` must start with:

```text
<!-- task-artifact
task: T-###
status: active
type: plan
-->
```

Use `type: plan` or `type: spec`. Change `status` to `completed` only after implementation and closeout facts are ready. The unified closeout command rejects missing/mismatched metadata and active backlinks, then moves completed files verbatim into the dated `docs/09_frozen/superpowers_*/` family.

Do not keep completed artifacts here, use these files as current product truth, or stage artifacts for more than one task at a time.
