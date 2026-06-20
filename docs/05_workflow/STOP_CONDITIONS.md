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
