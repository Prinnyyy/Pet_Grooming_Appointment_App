# Context Management

## Goal

Prevent degraded decisions after long sessions, context compression, or interrupted runs.

## Durable Context Files

Use these instead of relying on conversation context:

- `PROJECT_MEMORY.md`: stable index
- `CURRENT_STATE.md`: latest known app state
- `FEATURE_INDEX.md`: feature-to-file map
- `DECISION_LOG.md`: architecture/product decisions
- `WORKLOG.md`: chronological task log
- `COMPRESSION_RECOVERY.md`: recovery procedure

## Context Pack Pattern

For each major feature, create a compact context pack when needed:

```text
docs/00_memory/context_packs/<feature-name>.md
```

A context pack should contain:
- Feature purpose
- Relevant source files
- Relevant backend objects
- Current known behavior
- Known bugs
- Open questions

## What Not To Store

Do not store:
- Full source files
- Huge diffs
- Generated build logs
- Secrets
- Temporary speculation
- Unverified assumptions

## When to Update Memory

Update memory after:
- New feature behavior
- New screen
- New backend contract
- New architecture decision
- Important bug fix
- Build/test status change
