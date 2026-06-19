#!/usr/bin/env bash
set -euo pipefail

echo "== iOS Build =="

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode or run this on macOS with Xcode available."
  exit 1
fi

project_file="$(find . -maxdepth 3 -name "*.xcodeproj" | head -n 1 || true)"
workspace_file="$(find . -maxdepth 3 -name "*.xcworkspace" | head -n 1 || true)"

if [[ -z "$project_file" && -z "$workspace_file" ]]; then
  echo "No .xcodeproj or .xcworkspace found within maxdepth 3."
  exit 1
fi

echo "Detected project: ${project_file:-none}"
echo "Detected workspace: ${workspace_file:-none}"

echo "This script needs project-specific scheme configuration."
echo "Update docs/04_ios/IOS_BUILD_AND_TESTING.md and this script after inspecting schemes."

if [[ -n "${CODEX_IOS_SCHEME:-}" ]]; then
  scheme="$CODEX_IOS_SCHEME"
else
  echo "CODEX_IOS_SCHEME is not set. Refusing to guess scheme."
  exit 1
fi

destination="${CODEX_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"

if [[ -n "$workspace_file" ]]; then
  xcodebuild -workspace "$workspace_file" -scheme "$scheme" -destination "$destination" build
else
  xcodebuild -project "$project_file" -scheme "$scheme" -destination "$destination" build
fi
