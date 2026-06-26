# T-023C - Groomly SwiftUI Token Foundation

- State: planned.
- Mode: Standard.
- Parent: `T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`.
- Depends on: completed T-023B and valid `docs/08_design/design_tokens.json`.

## Goal

Translate the Groomly JSON tokens into the existing SwiftUI `DesignTokens` foundation without creating reusable components or restyling feature screens.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
4. `docs/08_design/design_tokens.json`
5. `docs/01_product/DESIGN_SYSTEM.md`
6. `docs/04_ios/SWIFTUI_STATE_RULES.md`
7. `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/DesignTokens.swift`

## Scope

In scope:

- Modify `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/DesignTokens.swift`.
- Add Groomly semantic token namespaces for colors, spacing, radii, shadows, and typography direction.
- Preserve existing token names used by current screens, or provide aliases so existing code still compiles.
- Use SwiftUI `Color`, `CGFloat`, `Font`, and light wrapper values that fit existing project conventions.
- Update `docs/01_product/DESIGN_SYSTEM.md` if Swift token names differ from JSON token names.
- Update `docs/00_memory/CURRENT_STATE.md`, `docs/00_memory/WORKLOG.md`, and `docs/06_tasks/TASK_LEDGER.md` only enough to mark T-023C completion and T-023D1 as the next task.

Out of scope:

- Creating `GroomlyButton`, cards, chips, fields, banners, empty states, or loading views.
- Redesigning feature screens.
- Editing Stores, repositories, models, Supabase adapters, backend docs, scripts, or tests unless required by a compile error caused by this task.
- Adding app assets.

## Token Requirements

Keep the existing baseline API available:

- `DesignTokens.Colors.background`
- `DesignTokens.Colors.surface`
- `DesignTokens.Colors.primaryText`
- `DesignTokens.Colors.secondaryText`
- `DesignTokens.Spacing.standard`
- `DesignTokens.Spacing.large`
- `DesignTokens.CornerRadius.card`

Add Groomly-ready semantic tokens for:

- app background and raised surfaces;
- warm borders/dividers;
- primary, secondary, tertiary text;
- customer mint primary and pressed/dark variant;
- groomer coral accent and pressed/dark variant;
- success, warning, and error;
- spacing scale `xs`, `sm`, `md`, `lg`, `xl`;
- card, button, input, chip, and circular radii;
- soft card and primary-action shadows;
- dynamic-type-friendly font helpers or documented `Font` values for large title, title, headline, body, and caption.

Do not use `UIColor(named:)` or asset catalog color names in this task unless the asset already exists. Tokens may use fixed hex-derived SwiftUI colors for the initial Groomly foundation, centralized in `DesignTokens`.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Run only one build attempt by default. If the build fails, fix only errors clearly caused by this token change and stop after the allowed targeted repair attempts from project rules.

## Acceptance

- `DesignTokens.swift` exposes existing baseline names and new Groomly-ready semantic tokens.
- No feature screen is restyled.
- No backend, repository, model, Store, Supabase, script, or asset file is changed.
- `./scripts/ios-build.sh` passes or the first real build error is reported under stop rules.
- `git diff --check` passes.
- Task ledger and current state point to T-023D1 as the next child task.

## Stop Conditions

Stop and report if:

- Token naming would require broad feature-screen edits.
- Existing DesignSystem usage conflicts with the proposed token shape.
- Build fails for reasons unrelated to this task.
- Any product-flow, backend, or repository change appears necessary.
