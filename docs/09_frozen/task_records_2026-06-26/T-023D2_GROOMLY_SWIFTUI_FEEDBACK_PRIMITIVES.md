# T-023D2 - Groomly SwiftUI Feedback Primitives

- State: blocked.
- Mode: Standard.
- Parent: `T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`.
- Depends on: completed T-023D1 and buildable Groomly action primitives.

## Goal

Add the second small set of reusable Groomly SwiftUI primitives for feedback, loading, empty states, and section structure. This task completes the T-023 foundation sequence but does not start feature-screen redesign.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
4. `docs/08_design/design_tokens.json`
5. `docs/01_product/DESIGN_SYSTEM.md`
6. `docs/04_ios/SWIFTUI_STATE_RULES.md`
7. `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/DesignTokens.swift`
8. the T-023D1 primitive file under `DesignSystem/`

## Scope

In scope:

- Create or extend one focused Swift file under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`, preferably `GroomlyFeedbackPrimitives.swift`.
- Add compile-ready primitives that are not yet wired into feature screens.
- Use existing filesystem-synchronized Xcode project behavior; do not manually edit `project.pbxproj` unless the build proves it is necessary.
- Update `docs/01_product/DESIGN_SYSTEM.md` with the primitive names and intended states.
- Update `docs/00_memory/CURRENT_STATE.md`, `docs/00_memory/WORKLOG.md`, and `docs/06_tasks/TASK_LEDGER.md` to mark T-023A through T-023D2 as the completed Groomly UI foundation sequence.
- Record that the next step is to create a new T-024 screen-specific Groomly task file before any feature screen is edited.

Out of scope:

- Button, card, or status-chip primitives already owned by T-023D1.
- Replacing existing feature-screen UI.
- Creating T-024 in the same run unless the user explicitly asks for task-planning only after T-023D2 is closed.
- Editing feature screens directly.
- Adding business logic to components.
- Adding assets.
- Editing Stores, repositories, models, Supabase adapters, backend docs, or scripts.
- Adding new product states that current Stores do not expose.

## Required Primitives

Add only:

- `GroomlyErrorBanner`
- `GroomlyLoadingView`
- `GroomlyEmptyState`
- `GroomlySectionHeader`

Implementation rules:

- Keep APIs simple and value-based.
- Use `DesignTokens` for all colors, spacing, radius, typography, and shadows.
- Do not embed repository calls, navigation, network work, or feature-specific copy.
- Prefer SF Symbols for icon slots and allow text-only fallback.
- Keep visible messages caller-provided so later screens can preserve existing error and empty-state copy.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Run only one build attempt by default. If the build fails, fix only errors clearly caused by this primitive addition and stop after the allowed targeted repair attempts from project rules.

## Acceptance

- The four feedback/structure primitives compile in the app target.
- The primitives use centralized `DesignTokens`.
- `docs/01_product/DESIGN_SYSTEM.md` lists these primitive contracts.
- No feature screen is restyled or rewired.
- No backend, repository, model, Store, Supabase, script, or asset file is changed.
- `./scripts/ios-build.sh` passes or the first real build error is reported under stop rules.
- `git diff --check` passes.
- T-023A through T-023D2 are recorded as the completed Groomly UI foundation sequence.
- Current state and task ledger say the next action is to create T-024 before editing any feature screen.

## Stop Conditions

Stop and report if:

- A primitive cannot compile without feature-screen rewrites.
- The component API would need current app state ownership changes.
- The prototype requirement depends on a deferred feature.
- The work begins to create or edit feature-screen UI.
- Build fails for reasons unrelated to this task.
