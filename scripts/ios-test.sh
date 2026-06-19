#!/usr/bin/env bash
set -euo pipefail

echo "== iOS Test =="

if [[ -z "${CODEX_IOS_SCHEME:-}" ]]; then
  echo "CODEX_IOS_SCHEME is not set. Refusing to guess scheme."
  exit 1
fi

project_file="$(find . -maxdepth 3 -name "*.xcodeproj" | head -n 1 || true)"
workspace_file="$(find . -maxdepth 3 -name "*.xcworkspace" | head -n 1 || true)"
destination="${CODEX_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"

if [[ -n "$workspace_file" ]]; then
  xcodebuild -workspace "$workspace_file" -scheme "$CODEX_IOS_SCHEME" -destination "$destination" test
elif [[ -n "$project_file" ]]; then
  xcodebuild -project "$project_file" -scheme "$CODEX_IOS_SCHEME" -destination "$destination" test
else
  echo "No .xcodeproj or .xcworkspace found."
  exit 1
fi
