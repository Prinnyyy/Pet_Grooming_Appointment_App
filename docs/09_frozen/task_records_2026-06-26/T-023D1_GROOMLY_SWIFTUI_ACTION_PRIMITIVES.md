# T-023D1 - Groomly SwiftUI Action Primitives

- State: blocked.
- Mode: Standard.
- Parent: `T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`.
- Depends on: completed T-023C and buildable Groomly token foundation.

## Goal

Add the first small set of reusable Groomly SwiftUI primitives for actions and compact content surfaces. This task does not wire primitives into feature screens.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
4. `docs/08_design/design_tokens.json`
5. `docs/01_product/DESIGN_SYSTEM.md`
6. `docs/04_ios/SWIFTUI_STATE_RULES.md`
7. `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/DesignTokens.swift`
8. `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/FeaturePlaceholderView.swift`

## Scope

In scope:

- Create or extend one focused Swift file under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`, preferably `GroomlyActionPrimitives.swift`.
- Add compile-ready primitives that are not yet wired into feature screens.
- Use existing filesystem-synchronized Xcode project behavior; do not manually edit `project.pbxproj` unless the build proves it is necessary.
- Update `docs/01_product/DESIGN_SYSTEM.md` with the primitive names and intended states.
- Update `docs/00_memory/CURRENT_STATE.md`, `docs/00_memory/WORKLOG.md`, and `docs/06_tasks/TASK_LEDGER.md` only enough to mark T-023D1 completion and T-023D2 as the next task.

Out of scope:

- Feedback, loading, empty-state, or section-header primitives.
- Replacing existing feature-screen UI.
- Adding business logic to components.
- Adding assets.
- Editing Stores, repositories, models, Supabase adapters, backend docs, or scripts.
- Adding new product states that current Stores do not expose.

## Required Primitives

Add only:

- `GroomlyPrimaryButtonStyle`
- `GroomlySecondaryButtonStyle`
- `GroomlyCard`
- `GroomlyStatusChip`

Implementation rules:

- Keep APIs simple and value-based.
- Use `DesignTokens` for all colors, spacing, radius, typography, and shadows.
- Include disabled visual states for button styles where SwiftUI button style APIs allow it.
- Ensure button styles can support 44 pt minimum tap targets when applied by later screens.
- Do not embed repository calls, navigation, network work, or feature-specific copy.
- Prefer SF Symbols for icon slots and allow text-only fallback.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Run only one build attempt by default. If the build fails, fix only errors clearly caused by this primitive addition and stop after the allowed targeted repair attempts from project rules.

## Acceptance

- The four action/surface primitives compile in the app target.
- The primitives use centralized `DesignTokens`.
- `docs/01_product/DESIGN_SYSTEM.md` lists these primitive contracts.
- No feature screen is restyled or rewired.
- No backend, repository, model, Store, Supabase, script, or asset file is changed.
- `./scripts/ios-build.sh` passes or the first real build error is reported under stop rules.
- `git diff --check` passes.
- Task ledger and current state point to T-023D2 as the next child task.

## Stop Conditions

Stop and report if:

- A primitive cannot compile without feature-screen rewrites.
- The component API would need current app state ownership changes.
- The prototype requirement depends on a deferred feature.
- Build fails for reasons unrelated to this task.
