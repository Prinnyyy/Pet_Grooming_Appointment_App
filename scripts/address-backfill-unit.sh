#!/usr/bin/env bash
set -euo pipefail

node --test \
  tests/address-backfill/address-backfill-core.test.mjs \
  tests/migrations/address-backfill.test.mjs

xcrun swiftc -parse-as-library -typecheck scripts/address-backfill-geocoder.swift
node --check scripts/address-backfill-core.mjs
node --check scripts/address-backfill.mjs
node scripts/address-backfill.mjs --help >/dev/null
