#!/usr/bin/env bash
set -euo pipefail

echo "== iOS TestOps E2E =="

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
source "$script_dir/ios-destination.sh"

scenario="${1:-marketplace_full_lifecycle}"
run_id="${TESTOPS_RUN_ID:-TESTOPS-$(date -u +%Y%m%dT%H%M%SZ)}"
project="${CODEX_IOS_PROJECT:-ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj}"
scheme="${CODEX_IOS_SCHEME:-PetGroomerMarketplace}"

if [[ -n "${CODEX_IOS_DESTINATION:-}" ]]; then
  destination="$CODEX_IOS_DESTINATION"
else
  destination="$(ios_default_test_destination "$project" "$scheme")"
fi

echo "Project: $project"
echo "Scheme: $scheme"
echo "Destination: $destination"
echo "Scenario: $scenario"
echo "Run ID: $run_id"

cd "$project_root"

xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  test \
  -only-testing:PetGroomerMarketplaceUITests/TestOpsLaunchSmokeTests/testLaunchWithTestOpsArgumentsShowsAuthenticationRoot \
  TESTOPS_RUN_ID="$run_id" \
  TESTOPS_SCENARIO_ID="$scenario"
