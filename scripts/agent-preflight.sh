#!/usr/bin/env bash
set -euo pipefail

echo "== Single-Agent Workflow Preflight =="

test -f AGENTS.md || { echo "Missing AGENTS.md"; exit 1; }
test -f docs/05_workflow/SINGLE_AGENT_WORKFLOW.md || { echo "Missing SINGLE_AGENT_WORKFLOW.md"; exit 1; }
test -f docs/06_tasks/LIGHTWEIGHT_TASK_PROMPT_TEMPLATE.md || { echo "Missing LIGHTWEIGHT_TASK_PROMPT_TEMPLATE.md"; exit 1; }

if [[ -d .codex/agents ]]; then
  echo "Active .codex/agents directory must remain disabled."
  exit 1
fi

if grep -q '^\[agents\]' .codex/config.toml; then
  echo "Active [agents] configuration is not allowed."
  exit 1
fi

echo "Single-agent workflow preflight passed."
