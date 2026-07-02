#!/usr/bin/env bash
set -euo pipefail

echo "== iOS Build =="

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

destination="${CODEX_IOS_DESTINATION:-$(ios_default_build_destination)}"

echo "Project: $project"
echo "Scheme: $scheme"
echo "Destination: $destination"

xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  build
