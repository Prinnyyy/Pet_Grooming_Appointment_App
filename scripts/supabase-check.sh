#!/usr/bin/env bash
set -euo pipefail

echo "== Supabase Contract Check =="

if [[ ! -d "supabase" ]]; then
  echo "No supabase directory found. Skipping Supabase checks."
  exit 0
fi

if [[ -d "supabase/migrations" ]]; then
  echo "Migrations directory found."
else
  echo "Warning: supabase directory exists but migrations directory is missing."
fi

echo "-- Checking for service-role key exposure patterns --"
if grep -R "service_role\|SUPABASE_SERVICE_ROLE" . \
  --exclude-dir=.git \
  --exclude-dir=DerivedData \
  --exclude="*.md" >/tmp/codex_supabase_secret_scan.txt 2>/dev/null; then
  echo "Potential service-role key reference found outside markdown. Inspect before continuing:"
  cat /tmp/codex_supabase_secret_scan.txt
  exit 1
fi

echo "-- Checking for backend contract doc --"
if [[ ! -f "docs/03_backend/SUPABASE_CONTRACT.md" ]]; then
  echo "Missing docs/03_backend/SUPABASE_CONTRACT.md"
  exit 1
fi

echo "Supabase contract check passed."
