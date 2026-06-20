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
secret_pattern='SUPABASE_SERVICE_''ROLE(_KEY)?[[:space:]]*[:=]|sb_''secret_[A-Za-z0-9_-]{16,}'
if rg --files-with-matches "$secret_pattern" . \
  --hidden \
  --glob '!*.md' \
  --glob '!.git/**' \
  --glob '!DerivedData/**' >/tmp/codex_supabase_secret_scan.txt 2>/dev/null; then
  echo "Potential service-role key value found outside ignored or markdown files. Inspect before continuing:"
  cat /tmp/codex_supabase_secret_scan.txt
  exit 1
fi

echo "-- Checking for backend contract doc --"
if [[ ! -f "docs/03_backend/SUPABASE_CONTRACT.md" ]]; then
  echo "Missing docs/03_backend/SUPABASE_CONTRACT.md"
  exit 1
fi

echo "Supabase contract check passed."
