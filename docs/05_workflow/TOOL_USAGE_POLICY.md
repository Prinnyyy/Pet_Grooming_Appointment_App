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

---

## Xcode / iOS Rules

Prefer scripts:

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

Implementation worker may edit only files listed in the approved patch plan.

If a new file must be added, the implementation worker must state why.

If a file outside the approved list must be edited, stop and update the plan first.
