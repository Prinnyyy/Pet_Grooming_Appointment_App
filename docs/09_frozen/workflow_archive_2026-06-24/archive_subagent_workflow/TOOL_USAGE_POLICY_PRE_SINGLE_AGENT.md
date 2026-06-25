# Tool Usage Policy

## Purpose

This policy defines how Codex should use local tools, scripts, Xcode, Supabase, GitHub, and MCP tools.

---

## General Tool Rules

1. Prefer existing project scripts over invented shell commands.
2. Prefer read-only commands during planning.
3. Use write commands only during implementation.
4. Avoid destructive commands.
5. Do not use network access unless the task explicitly requires it and the user approves.
6. Do not read secrets.
7. Do not log secrets.
8. Document any command failure in the agent report.

Apply the validation budget from `LIGHTWEIGHT_EXECUTION_POLICY.md`; tool availability does not justify extra checks.

---

## Xcode / iOS Rules

Use project scripts only when the selected mode requires validation:

```text
scripts/ios-build.sh
scripts/ios-test.sh
scripts/agent-preflight.sh
```

If Xcode MCP is available, it may be used for:

- listing schemes,
- selecting simulator,
- building,
- testing,
- reading structured build errors.

Rules:

- Do not manually invent new build commands if scripts exist.
- Do not change project signing settings unless explicitly requested.
- Do not modify Xcode project files casually.
- If build fails due to environment or simulator availability, report it as environment failure, not code failure.
- Quick Mode does not build/test unless the edited file requires it.
- Standard Mode makes one build attempt by default.
- Deep Mode states its build/test plan before execution.
- UI tests run only for directly changed launch, navigation, or interaction behavior.
- Initialization tasks do not require unit tests or TDD RED/GREEN loops, and make at most one build attempt.
- On validation failure, report the first real error and stop unless the user approves a fix loop.

---

## Supabase Rules

During planning:

- read local docs,
- read local migrations,
- inspect repository code paths,
- avoid remote commands.

During implementation:

- do not create migrations unless explicitly planned,
- do not weaken RLS,
- do not bypass RPC for protected mutations,
- do not fake Supabase success in app code.

Allowed by default:

```text
read local files
inspect migration SQL
inspect repository code
run local non-destructive validation scripts
```

Not allowed by default:

```text
supabase db reset
supabase migration repair
remote production writes
manual production schema edits
weakening RLS
logging service role keys
```

---

## Git / GitHub Rules

Allowed by default:

```text
git status
git diff
git log --oneline
git branch --show-current
```

Requires explicit user approval:

```text
git commit
git push
git reset
git rebase
gh pr create
gh pr merge
```

If GitHub MCP is available, it may be used for:

- reading issues,
- reading pull requests,
- summarizing diffs,
- checking CI status.

Do not create PRs or push branches unless the user explicitly requests it.

---

## File Editing Rules

Implementation worker may edit only files listed in the active task scope or plan.

If a new file must be added, the implementation worker must state why.

If a file outside that list must be edited, stop and update the scope first.
