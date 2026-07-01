#!/usr/bin/env bash
set -euo pipefail

echo "== TestOps Unit Tests =="

node --test tests/testops/testops-core.test.mjs
