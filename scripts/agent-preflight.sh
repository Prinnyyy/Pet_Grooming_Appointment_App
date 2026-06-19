#!/usr/bin/env bash
set -euo pipefail

echo "== Agent Preflight =="

echo "-- Required files --"
test -f AGENTS.md || { echo "Missing AGENTS.md"; exit 1; }
test -f docs/00_memory/AGENT_TEAM_INDEX.md || { echo "Missing AGENT_TEAM_INDEX.md"; exit 1; }
test -f docs/05_workflow/AGENT_TEAM_WORKFLOW.md || { echo "Missing AGENT_TEAM_WORKFLOW.md"; exit 1; }
test -f docs/05_workflow/SUBAGENT_DISPATCH_PROTOCOL.md || { echo "Missing SUBAGENT_DISPATCH_PROTOCOL.md"; exit 1; }
test -f docs/05_workflow/PLAN_FIRST_PROTOCOL.md || { echo "Missing PLAN_FIRST_PROTOCOL.md"; exit 1; }

echo "-- Codex agent definitions --"
test -d .codex/agents || { echo "Missing .codex/agents"; exit 1; }
ls .codex/agents/*.toml >/dev/null 2>&1 || { echo "No .codex/agents/*.toml files found"; exit 1; }

echo "-- Report folder --"
mkdir -p docs/05_workflow/agent_reports

echo "-- Git status --"
git status --short || true

echo "Agent preflight passed."
