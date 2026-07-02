# Stop Conditions

Codex must stop and report when any condition occurs.

## Scope Stop

- The task requires more than one major feature.
- The task begins to affect unrelated screens/modules.
- The task requires a product decision not documented.
- The task cannot be completed without turning one requested task into multiple independent tasks.

## Safety Stop

- A destructive database operation appears necessary.
- Secrets are required.
- Remote state is uncertain.
- User changes would be overwritten.
- Commit, push, PR, remote write, seed, cleanup, migration apply, or dependency changes are needed without explicit user approval.

## Technical Stop

- The first required build or test attempt fails; report the first real error and stop unless the user approves a follow-up.
- A required completion `git diff --check` attempt fails.
- The app cannot be launched in the iOS Simulator when simulator launch is required for the task.
- Required scheme/simulator cannot be detected when app build or simulator launch is required.
- Supabase schema cannot be verified.
- Tests fail for reasons unrelated to the current task.

## Groomly UI Stop

- The uploaded screenshot or Groomly design source cannot be read.
- Design asset source, safety, or licensing is unclear.
- A screenshot module cannot be mapped to an existing SwiftUI surface, Store/repository/model path, or clearly identified new feature.
- The screenshot or prototype requires backend schema, RLS, RPC, Storage policy, repository contract, or new persistence changes.
- The screenshot or prototype requires a deferred feature such as request cancellation, favorites, attachments, read receipts, realtime chat, signed URL image rendering, payments, push notifications, maps, calendars, or admin tooling.
- The screenshot or prototype implies a new navigation model, role capability, or product flow not already documented.
- The UI change would require direct Supabase access from SwiftUI.
- The implementation would reintroduce task-card flow, send-task wording, or customer-facing rejection language.
- The first T-023C, T-023D1, or T-023D2 build attempt fails outside a clearly task-caused compile issue; report the first real error and stop.

## Context Stop

- Conversation context conflicts with memory docs.
- Memory docs are missing critical project facts.
- Current code differs greatly from documented architecture.
- Current docs conflict with source code, scripts, migrations, or verified tool behavior.
- L4 frozen/heavy context is needed but the reason is not specific.
- The next step would require broad full-file reads of archives, Groomly HTML/export, T-129 seed tables, large migrations, or large Swift files.
- Default search would need to bypass `.rgignore` without a targeted reason.
- `rg --files -g '*.md'` or another broad inventory would re-include ignored heavy Markdown as routine context.

## Required Stop Report

```text
Stop reason:
What was attempted:
What was found:
Files touched:
Safe next options:
User decision needed:
```

For screenshot-driven Groomly UI stops, also include:

```text
Screenshot/module:
Existing support:
Likely files:
Validation needed:
```
