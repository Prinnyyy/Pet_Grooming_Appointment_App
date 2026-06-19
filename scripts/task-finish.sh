#!/usr/bin/env bash
set -euo pipefail

TASK_ID="${1:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: scripts/task-finish.sh <TASK_ID>"
  exit 1
fi

REPORT_DIR="docs/05_workflow/agent_reports/$TASK_ID"

if [[ ! -d "$REPORT_DIR" ]]; then
  echo "Missing task report folder: $REPORT_DIR"
  exit 1
fi

echo "== Task Finish Check =="
echo "Task ID: $TASK_ID"

echo "-- Reports --"
find "$REPORT_DIR" -maxdepth 1 -type f -name "*.md" | sort

echo "-- Git status --"
git status --short || true

echo "-- Required final report --"
if [[ ! -f "$REPORT_DIR/09-final-run-report.md" ]]; then
  echo "Warning: missing $REPORT_DIR/09-final-run-report.md"
else
  echo "Final run report exists."
fi
