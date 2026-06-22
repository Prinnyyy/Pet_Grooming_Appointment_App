# T-035 - Groomly Account, Tabs, Debug, and Final UI Completion Audit

- State: planned.
- Mode: Standard.
- Depends on: completed T-034.

## Goal

Apply Groomly styling to the remaining lightweight shared surfaces and close the Groomly UI phase by auditing docs/inventory for complete screen coverage.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`
4. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
5. `docs/08_design/design_tokens.json`
6. `docs/01_product/DESIGN_SYSTEM.md`
7. `docs/01_product/SCREEN_INVENTORY.md`
8. `docs/04_ios/SWIFTUI_STATE_RULES.md`
9. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticatedAccountView.swift`
10. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/CustomerTabView.swift`
11. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/GroomerTabView.swift`
12. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Debug/DebugPanelView.swift`
13. `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/FeaturePlaceholderView.swift`
14. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle `AuthenticatedAccountView`, `CustomerTabView`, `GroomerTabView`, `FeaturePlaceholderView`, and `DebugPanelView` only as needed to align lightweight shared surfaces with Groomly.
- Keep Debug Panel sanitized and development-only.
- Audit `SCREEN_INVENTORY.md` and mark all implemented screens adapted after the final UI pass; keep Admin Dashboard deferred.
- Update `DESIGN_SYSTEM.md`, `CURRENT_STATE.md`, `TASK_LEDGER.md`, entry docs, and worklog to record Groomly UI phase completion.
- Run one final build and `git diff --check`.

Out of scope:

- Backend, repository, Store, model, Supabase, scripts, assets, new tab routing, new account features, admin tools, debug secrets, or post-MVP features.
- Adding new screens to replace placeholder/unsupported prototype concepts.

## Implementation Rules

- Do not expose tokens, API keys, passwords, raw secrets, or full user identifiers in Debug or Account surfaces.
- Do not change sign-out behavior, role routing, tab ownership, or debug diagnostic data sources.
- Keep visual changes small and consistent with already completed Groomly slices.
- Treat this as a completion audit, not a new feature pass.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Run broader tests only if the task changes behavior-bearing code, which should generally be avoided.

## Acceptance

- Remaining Account, tab shell, and Debug surfaces use Groomly styling without changing behavior.
- `SCREEN_INVENTORY.md` shows implemented screens as `groomly adapted`, with Admin Dashboard still `deferred`.
- `DESIGN_SYSTEM.md`, `CURRENT_STATE.md`, `TASK_LEDGER.md`, entry docs, and worklog record the Groomly UI phase as complete.
- No backend, repository, Store, model, Supabase, script, asset, product-flow, or deferred feature work is introduced.

## Stop Conditions

Stop and report if final polish requires changing role routing, sign-out, debug data, secrets handling, backend contracts, or unsupported prototype features.
