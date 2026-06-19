#!/usr/bin/env bash
set -euo pipefail

echo "== Repository Summary =="

echo "-- Git --"
git status --short || true

echo "-- Top-level files --"
find . -maxdepth 2 \
  -not -path "./.git/*" \
  -not -path "./DerivedData/*" \
  -print | sort | head -n 200

echo "-- Xcode projects --"
find . -maxdepth 4 \( -name "*.xcodeproj" -o -name "*.xcworkspace" \) -print

echo "-- Supabase --"
find supabase -maxdepth 3 -type f 2>/dev/null | sort | head -n 100 || true
