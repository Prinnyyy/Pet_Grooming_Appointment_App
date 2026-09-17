# Codex Agent Role Cards

These files define role-based Codex behavior for serial agent workflows.

They are not independent source-of-truth documents. They are role prompts.

Use them in this order:

1. `main-orchestrator.md`
2. `context-librarian.md`
3. One specialist role
4. `build-test-agent.md`
5. `documentation-scribe.md`

If native subagents are available, pass the relevant role card to the subagent. If not, follow the role card manually inside the current Codex session or ask the user to start a fresh Codex session with the role card.
