# Stop Conditions

Stop and report when any condition occurs.

## Scope

- The task becomes more than one primary task.
- The change begins touching unrelated screens/modules.
- A required product decision is undocumented.
- A screenshot implies a new feature beyond visual-only or existing-feature rewire scope.

## Safety

- User changes would be overwritten.
- A secret, local credential, or remote environment value is needed.
- Destructive database or filesystem action appears necessary.
- Supabase remote writes, migration apply, seed, cleanup, reset, or repair would be needed without explicit approval.
- Commit, push, PR, branch reset, rebase, or merge would be needed without explicit approval.

## Context

- Active docs conflict with code facts.
- Required facts only appear in L4 archive and the recovery reason is unclear.
- The task would require full-reading frozen archives, seed tables, full design exports, or large unrelated Swift files.

## Validation

- The first required validation attempt fails.
- A required simulator launch fails for a UI/app task.
- Required scheme/simulator cannot be detected for an app validation task.
- Tests fail for reasons unrelated to the current task.

## Stop Report

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
