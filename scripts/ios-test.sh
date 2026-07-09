#!/usr/bin/env bash
set -euo pipefail

echo "== iOS Test =="

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/ios-destination.sh"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode or run this on macOS with Xcode available."
  exit 1
fi

project="${CODEX_IOS_PROJECT:-ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj}"
scheme="${CODEX_IOS_SCHEME:-PetGroomerMarketplace}"

if [[ ! -d "$project" ]]; then
  echo "Xcode project not found: $project"
  exit 1
fi

if [[ -n "${CODEX_IOS_DESTINATION:-}" ]]; then
  destination="$CODEX_IOS_DESTINATION"
else
  destination="$(ios_default_test_destination "$project" "$scheme")"
fi

echo "Project: $project"
echo "Scheme: $scheme"
echo "Destination: $destination"

log_file="$(mktemp -t ios-test)"
echo "Full log: $log_file"

if xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  test > "$log_file" 2>&1; then
  echo "TEST SUCCEEDED"
  grep -E "Test Suite|Executed .* tests" "$log_file" | tail -n 10 || true
else
  echo "TEST FAILED"
  grep -E "error:|✘|failed|FAILED" "$log_file" | sort -u | head -n 60 || true
  tail -n 40 "$log_file"
  exit 1
fi
