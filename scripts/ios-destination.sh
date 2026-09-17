#!/usr/bin/env bash

ios_default_build_destination() {
  printf '%s\n' 'generic/platform=iOS Simulator'
}

ios_default_test_destination() {
  local project="$1"
  local scheme="$2"
  local destinations

  if ! destinations="$(xcodebuild -project "$project" -scheme "$scheme" -showdestinations 2>/dev/null)"; then
    echo "Unable to discover iOS Simulator destinations for scheme: $scheme" >&2
    return 1
  fi

  local preferred_name
  for preferred_name in \
    "iPhone 17 Pro" \
    "iPhone 17" \
    "iPhone 16 Pro" \
    "iPhone 16" \
    "iPhone 15 Pro" \
    "iPhone 15"
  do
    local preferred_line
    preferred_line="$(
      printf '%s\n' "$destinations" |
        awk -v name="$preferred_name" \
          '$0 ~ /platform:iOS Simulator/ && $0 !~ /placeholder/ && $0 ~ "name:" name "([, }]|$)" { print; exit }'
    )"

    if [[ -n "$preferred_line" ]] && ios_destination_from_line "$preferred_line"; then
      return 0
    fi
  done

  local iphone_line
  iphone_line="$(
    printf '%s\n' "$destinations" |
      awk '$0 ~ /platform:iOS Simulator/ && $0 !~ /placeholder/ && $0 ~ /name:iPhone/ { print; exit }'
  )"

  if [[ -n "$iphone_line" ]] && ios_destination_from_line "$iphone_line"; then
    return 0
  fi

  local simulator_line
  simulator_line="$(
    printf '%s\n' "$destinations" |
      awk '$0 ~ /platform:iOS Simulator/ && $0 !~ /placeholder/ { print; exit }'
  )"

  if [[ -n "$simulator_line" ]] && ios_destination_from_line "$simulator_line"; then
    return 0
  fi

  echo "No concrete iOS Simulator destination is available. Set CODEX_IOS_DESTINATION explicitly." >&2
  return 1
}

ios_destination_from_line() {
  local line="$1"
  local id

  id="$(printf '%s\n' "$line" | sed -E 's/.*id:([^,}[:space:]]+).*/\1/')"
  if [[ -n "$id" && "$id" != "$line" ]]; then
    printf 'platform=iOS Simulator,id=%s\n' "$id"
    return 0
  fi

  return 1
}
