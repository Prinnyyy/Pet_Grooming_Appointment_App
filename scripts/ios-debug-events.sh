#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.prinnyyy.PetGroomerMarketplace}"
DEVICE="${DEVICE:-booted}"
COMMAND="${1:-tail}"
LINES="${2:-300}"

APP_CONTAINER="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data 2>/dev/null || true)"
if [[ -z "$APP_CONTAINER" ]]; then
  echo "Could not locate app data container for $BUNDLE_ID on $DEVICE." >&2
  exit 1
fi

LOG_FILE="$APP_CONTAINER/Library/Application Support/GroomlyDebug/debug-events.jsonl"

case "$COMMAND" in
  path)
    echo "$LOG_FILE"
    ;;
  cat)
    if [[ -f "$LOG_FILE" ]]; then
      cat "$LOG_FILE"
    fi
    ;;
  tail)
    if [[ -f "$LOG_FILE" ]]; then
      tail -n "$LINES" "$LOG_FILE"
    else
      echo "No debug event log found at $LOG_FILE" >&2
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 [tail [lines]|cat|path]" >&2
    exit 2
    ;;
esac
