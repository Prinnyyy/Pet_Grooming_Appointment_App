#!/usr/bin/env bash
set -euo pipefail

TASK_ID="${1:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: scripts/task-start.sh <TASK_ID>"
  exit 1
fi

REPORT_DIR="docs/05_workflow/agent_reports/$TASK_ID"

mkdir -p "$REPORT_DIR"

if [[ ! -f "$REPORT_DIR/00-task-intake.md" ]]; then
  cat > "$REPORT_DIR/00-task-intake.md" <<EOF
# Task Intake

Task ID: \`$TASK_ID\`

Date: $(date +%Y-%m-%d)

---

## User Request

TBD

---

## Primary Task

TBD

---

## Out of Scope

- TBD

---

## Expected Output

- TBD

---

## Required Validation

- TBD

---

## Stop Condition

TBD
EOF
fi

echo "Task report folder ready: $REPORT_DIR"
