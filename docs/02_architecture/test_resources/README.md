# Test Resources

This directory contains reviewable seed-resource documents for local scripts and TestOps.

## Active Resources

- `T-129_GROOMER_TEST_PROFILES.md`: 50 machine-readable groomer seed profiles parsed by `scripts/seed-t129-groomers.mjs` and TestOps.
- `T-129_CUSTOMER_TEST_PROFILES.md`: 50 machine-readable customer seed profiles, each with one dog and one cat, parsed by `scripts/seed-t129-customers.mjs` and TestOps.

## Search Rule

These two profile documents are intentionally excluded from ordinary `rg` searches by `.rgignore` because they are large data tables, not daily context. Read them directly or use `rg --no-ignore` only when the task needs seed-resource content.

Do not trim, reformat, move, or archive these profile tables without updating the parsing scripts and TestOps tests that depend on their Markdown table shape.
