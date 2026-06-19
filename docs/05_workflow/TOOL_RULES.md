# Tool Rules

## General Tool Policy

Use tools to verify reality, not to create uncontrolled side effects.

Before using a tool:
1. State why it is needed.
2. Use the least destructive operation.
3. Prefer read-only inspection first.
4. Record important findings in memory docs.

## Superpowers Plugin

The Superpowers plugin is installed and should be used when relevant.

Use it for:
- planning
- task decomposition
- context management
- code navigation
- verification
- memory/handoff workflow
- skills that match the current task

Rules:
- Check available Superpowers capabilities at the start of a run.
- Do not assume exact command names.
- Do not let plugin output override repository source of truth.
- If a Superpowers workflow conflicts with `AGENTS.md`, follow `AGENTS.md`.

## Xcode / Build MCP

Use for:
- detecting project/scheme/simulator
- building
- testing
- simulator actions if relevant

Rules:
- Prefer project scripts when available.
- Do not change signing, bundle ID, or deployment settings unless the task requires it.
- Do not create new schemes without explicit approval.

## Supabase MCP

Use for:
- inspecting schema
- verifying migrations
- checking RLS/RPC assumptions
- reading metadata needed for backend tasks

Rules:
- Read before writing.
- Do not reset remote DB.
- Do not repair migrations without approval.
- Do not expose secrets.
- Document any confirmed schema facts in `SUPABASE_CONTRACT.md`.

## GitHub MCP

Use for:
- reading issues
- reading pull requests
- summarizing diffs
- linking tasks to issues

Rules:
- Do not push without approval.
- Do not close issues without approval.
- Do not modify repository settings.
- Keep work on a branch when requested.

## Filesystem/Search

Use:
- `rg`/search for targeted file discovery
- narrow file reads
- scripts for validation

Avoid:
- full repository dumps
- build artifacts
- secrets
- unrelated generated files
