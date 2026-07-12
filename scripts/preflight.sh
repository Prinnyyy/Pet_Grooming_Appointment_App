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
  "docs/06_tasks/ROADMAP.md"
  "docs/05_workflow/SINGLE_AGENT_WORKFLOW.md"
  "docs/05_workflow/CONTEXT_AND_RECOVERY.md"
  "docs/05_workflow/TOOLING_POLICY.md"
  "docs/05_workflow/GITHUB_RULES.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file"
    exit 1
  fi
done

run_node_test_dir() {
  local label="$1"
  local dir="$2"

  if [[ ! -d "$dir" ]]; then
    return
  fi

  local tests=()
  while IFS= read -r -d '' test_file; do
    tests+=("$test_file")
  done < <(find "$dir" -maxdepth 1 -type f -name "*.test.mjs" -print0 | sort -z)

  if (( ${#tests[@]} == 0 )); then
    return
  fi

  echo "-- ${label} --"
  node --test "${tests[@]}"
}

echo "-- Beckon identity --"
./scripts/beckon-identity-check.sh
echo "-- UI consistency --"
node scripts/ui-consistency-audit.mjs check
run_node_test_dir "Brand identity tests" "tests/brand"
run_node_test_dir "Migration tests" "tests/migrations"
run_node_test_dir "Edge Function tests" "tests/functions"

echo "-- Secret scan hints --"
if find . -maxdepth 3 -type f \( -name ".env" -o -name ".env.*" \) | grep -q .; then
  echo "Warning: .env files exist. Do not read or expose secrets."
fi

echo "Preflight passed."
