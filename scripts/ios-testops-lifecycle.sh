#!/usr/bin/env bash
set -euo pipefail

echo "== iOS TestOps Lifecycle =="

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
source "$script_dir/ios-destination.sh"

scenario="marketplace_full_lifecycle"
run_id="${TESTOPS_RUN_ID:-TESTOPS-UI-$(date -u +%Y%m%dT%H%M%SZ)}"
project="${CODEX_IOS_PROJECT:-ios/Beckon/Beckon.xcodeproj}"
scheme="${CODEX_IOS_SCHEME:-Beckon}"

required_environment=(
  SUPABASE_URL
  SUPABASE_PUBLISHABLE_KEY
  TESTOPS_UI_CUSTOMER_EMAIL
  TESTOPS_UI_CUSTOMER_PASSWORD
  TESTOPS_UI_GROOMER_EMAIL
  TESTOPS_UI_GROOMER_PASSWORD
)
for variable in "${required_environment[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing required environment variable: $variable" >&2
    exit 1
  fi
done
if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" && -z "${SUPABASE_SECRET_KEY:-}" ]]; then
  echo "Set SUPABASE_SERVICE_ROLE_KEY or SUPABASE_SECRET_KEY." >&2
  exit 1
fi
if [[ "${TESTOPS_REMOTE_WRITE_APPROVED:-}" != "1" ]]; then
  echo "TESTOPS_REMOTE_WRITE_APPROVED=1 is required." >&2
  exit 1
fi
if [[ ! "$run_id" =~ ^TESTOPS-[A-Z0-9-]{1,96}$ ]]; then
  echo "TESTOPS_RUN_ID must use TESTOPS- plus uppercase letters, numbers, and hyphens." >&2
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
echo "Scenario: $scenario"
echo "Run ID: $run_id"

cd "$project_root"

export "TEST_RUNNER_TESTOPS_RUN_ID=$run_id"
export "TEST_RUNNER_TESTOPS_SCENARIO_ID=$scenario"
export "TEST_RUNNER_TESTOPS_UI_LIFECYCLE_APPROVED=1"
redactions=()
for variable in \
  TESTOPS_UI_CUSTOMER_EMAIL \
  TESTOPS_UI_CUSTOMER_PASSWORD \
  TESTOPS_UI_GROOMER_EMAIL \
  TESTOPS_UI_GROOMER_PASSWORD; do
  export "TEST_RUNNER_${variable}=${!variable}"
  redactions+=("${!variable}")
done

log_file="$(mktemp -t ios-testops-lifecycle)"
result_bundle="$(mktemp -d -t ios-testops-lifecycle-result)/result.xcresult"
cleanup_done=0

redact() {
  local output="$1"
  for secret in "${redactions[@]}"; do
    output="${output//$secret/<redacted>}"
  done
  printf '%s\n' "$output"
}

cleanup_remote() {
  local output
  output="$(node scripts/testops.mjs cleanup --run-id "$run_id" --execute 2>&1)"
  redact "$output"
  grep -q '"remainingTaggedRequests": 0' <<<"$output"
  cleanup_done=1
}

on_exit() {
  local status=$?
  if [[ "$cleanup_done" != "1" ]]; then
    set +e
    cleanup_remote >/dev/null
  fi
  rm -f "$log_file"
  rm -rf "$(dirname "$result_bundle")"
  trap - EXIT
  exit "$status"
}
trap on_exit EXIT

set +e
debug_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  -resultBundlePath "$result_bundle" \
  test \
  -only-testing:BeckonUITests/TestOpsLifecycleTests/testSeededDualRoleMarketplaceLifecycle \
  >"$log_file" 2>&1
ui_status=$?
set -e

summary="$(grep -E 'Test Case|Executed .* tests|TEST SUCCEEDED|TEST FAILED|error:|failed|FAILED|skipped' "$log_file" | tail -n 100 || true)"
redact "$summary"

debug_status=0
if [[ "$ui_status" == "0" ]]; then
  echo "== Debug JSONL verification =="
  device_id="${TESTOPS_SIMULATOR_UDID:-$(sed -n 's/.*id=\([^,]*\).*/\1/p' <<<"$destination")}"
  if [[ -z "$device_id" ]]; then
    echo "Could not derive Simulator UDID for Debug JSONL verification." >&2
    debug_status=1
  else
    set +e
    xcrun simctl boot "$device_id" >/dev/null 2>&1
    xcrun simctl bootstatus "$device_id" -b >/dev/null 2>&1
    debug_log_path="$(DEVICE="$device_id" ./scripts/ios-debug-events.sh path 2>/dev/null)"
    if [[ -n "$debug_log_path" ]]; then
      debug_output="$(node scripts/testops.mjs verify debug-log \
        --run-id "$run_id" \
        --log-path "$debug_log_path" \
        --started-at "$debug_started_at" 2>&1)"
      debug_status=$?
      redact "$debug_output"
    else
      echo "Could not locate Debug JSONL after UI lifecycle." >&2
      debug_status=1
    fi
    set -e
  fi
else
  debug_status=1
fi

verification_status=0
if [[ "$ui_status" == "0" ]]; then
  echo "== Backend final-state verification =="
  set +e
  verification_output="$(node scripts/testops.mjs verify ui-lifecycle --run-id "$run_id" 2>&1)"
  verification_status=$?
  set -e
  redact "$verification_output"
else
  verification_status=1
fi

echo "== Tagged cleanup =="
set +e
cleanup_remote
cleanup_status=$?
set -e

if [[ "$ui_status" != "0" || "$debug_status" != "0" || "$verification_status" != "0" || "$cleanup_status" != "0" ]]; then
  exit 1
fi

echo "UI lifecycle, Debug/backend verification, and zero-residue cleanup passed."
