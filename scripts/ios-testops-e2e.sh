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

export "TEST_RUNNER_TESTOPS_RUN_ID=$run_id"
export "TEST_RUNNER_TESTOPS_SCENARIO_ID=$scenario"
redactions=()
for variable in \
  TESTOPS_UI_CUSTOMER_EMAIL \
  TESTOPS_UI_CUSTOMER_PASSWORD \
  TESTOPS_UI_GROOMER_EMAIL \
  TESTOPS_UI_GROOMER_PASSWORD; do
  if [[ -n "${!variable:-}" ]]; then
    export "TEST_RUNNER_${variable}=${!variable}"
    redactions+=("${!variable}")
  fi
done

log_file="$(mktemp -t ios-testops-e2e)"
result_bundle="$(mktemp -d -t ios-testops-result)/result.xcresult"
trap 'rm -f "$log_file"; rm -rf "$(dirname "$result_bundle")"' EXIT

redacted_summary() {
  local pattern='Test Case|Executed .* tests|TEST SUCCEEDED|TEST FAILED|error:|failed|FAILED|skipped'
  local output
  output="$(grep -E "$pattern" "$log_file" | tail -n 80 || true)"
  for secret in "${redactions[@]}"; do
    output="${output//$secret/<redacted>}"
  done
  printf '%s\n' "$output"
}

if xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  -resultBundlePath "$result_bundle" \
  test \
  -only-testing:PetGroomerMarketplaceUITests/TestOpsLaunchSmokeTests \
  >"$log_file" 2>&1; then
  echo "TEST SUCCEEDED"
  redacted_summary
else
  echo "TEST FAILED"
  redacted_summary
  exit 1
fi
