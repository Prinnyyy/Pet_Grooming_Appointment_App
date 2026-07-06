# T-003 — Canonical Documentation Alignment

## Status

Completed on 2026-06-19.

## Primary Task

Align the active product, architecture, and backend documentation with `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` and the implemented T-001 baseline.

## In Scope

- Replace placeholders and stale role/product terminology in `docs/01_product/`.
- Document the target SwiftUI, repository, Supabase, and source-of-truth boundaries in `docs/02_architecture/`.
- Replace runtime demo guidance with preview/test fixture rules.
- Document the planned schema, RPC, RLS, Storage, and migration contracts in `docs/03_backend/` without creating them.
- Update task and memory documents after validation.

## Out of Scope

- Swift or Xcode project changes.
- Supabase initialization, configuration, migrations, remote writes, or credentials.
- Dependencies, product implementation, build/test execution, commit, or push.

## Required Validation

- One documentation validation pass: `./scripts/preflight.sh` followed by a targeted stale-term/placeholder scan in active product, architecture, and backend docs.
- Brief current-diff review only.

## Risk Level

Low. Documentation-only, with backend contracts explicitly marked as planned rather than deployed.

## Stop Condition

Stop after active documents and durable memory agree, validation completes once, and T-003 is marked completed. Do not start T-004.
