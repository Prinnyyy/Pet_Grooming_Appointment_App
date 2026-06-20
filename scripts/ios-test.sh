#!/usr/bin/env bash
set -euo pipefail

echo "== iOS Test =="

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode or run this on macOS with Xcode available."
  exit 1
fi

project="${CODEX_IOS_PROJECT:-ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj}"
scheme="${CODEX_IOS_SCHEME:-PetGroomerMarketplace}"
destination="${CODEX_IOS_DESTINATION:-platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro}"

if [[ ! -d "$project" ]]; then
  echo "Xcode project not found: $project"
  exit 1
fi

echo "Project: $project"
echo "Scheme: $scheme"
echo "Destination: $destination"

xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  test
