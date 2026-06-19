#!/usr/bin/env bash
set -euo pipefail

echo "== Preflight =="

echo "-- Git status --"
git status --short || true

echo "-- Required docs --"
required_files=(
  "AGENTS.md"
  "docs/00_memory/PROJECT_MEMORY.md"
  "docs/00_memory/CURRENT_STATE.md"
  "docs/00_memory/FEATURE_INDEX.md"
  "docs/06_tasks/TASK_LEDGER.md"
  "docs/05_workflow/CODEX_WORKFLOW.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file"
    exit 1
  fi
done

echo "-- Secret scan hints --"
if find . -maxdepth 3 -type f \( -name ".env" -o -name ".env.*" \) | grep -q .; then
  echo "Warning: .env files exist. Do not read or expose secrets."
fi

echo "Preflight passed."
