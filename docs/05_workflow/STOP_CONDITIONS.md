# Stop Conditions

Codex must stop and report when any condition occurs.

## Scope Stop

- The task requires more than one major feature.
- The task begins to affect unrelated screens/modules.
- The task requires a product decision not documented.

## Safety Stop

- A destructive database operation appears necessary.
- Secrets are required.
- Remote state is uncertain.
- User changes would be overwritten.

## Technical Stop

- The first build or test attempt fails; report the first real error and stop unless the user approves a follow-up.
- Required scheme/simulator cannot be detected.
- Supabase schema cannot be verified.
- Tests fail for reasons unrelated to the current task.

## Groomly UI Stop

- The Groomly design source cannot be read.
- Design asset source, safety, or licensing is unclear.
- The prototype requires backend schema, RLS, RPC, Storage policy, or repository contract changes.
- The prototype requires a deferred feature such as request cancellation, favorites, attachments, read receipts, realtime chat, signed URL image rendering, payments, push notifications, maps, calendars, or admin tooling.
- The UI change would require direct Supabase access from SwiftUI.
- The implementation would reintroduce task-card flow, send-task wording, or customer-facing rejection language.
- The first T-023C, T-023D1, or T-023D2 build attempt fails outside a clearly task-caused compile issue; report the first real error and stop.

## Context Stop

- Conversation context conflicts with memory docs.
- Memory docs are missing critical project facts.
- Current code differs greatly from documented architecture.

## Required Stop Report

```text
Stop reason:
What was attempted:
What was found:
Files touched:
Safe next options:
User decision needed:
```
