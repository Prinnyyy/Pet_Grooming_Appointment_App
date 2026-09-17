# T-032 - Groomly Groomer Portfolio UI

- State: completed.
- Mode: Standard.
- Depends on: completed T-031.

## Goal

Apply Groomly styling to groomer portfolio metadata, upload, and delete UI while preserving existing Storage metadata behavior and avoiding remote image rendering changes.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`
4. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
5. `docs/08_design/design_tokens.json`
6. `docs/01_product/DESIGN_SYSTEM.md`
7. `docs/04_ios/SWIFTUI_STATE_RULES.md`
8. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
9. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle only `GroomerPortfolioSection` and directly related local portfolio row/content inside `GroomerProfileManagementView.swift`.
- Use Groomly cards, empty/loading/error feedback, section headers, status/meta rows, and groomer-accent buttons.
- Preserve portfolio metadata display, upload action, delete action, busy/disabled states, notices, and errors.
- Keep current metadata/file-name style display. Do not implement remote thumbnails or signed URL rendering.

Out of scope:

- Profile and services UI already covered by T-031.
- Storage policy changes, repository changes, models, backend, signed URLs, image caching, image transforms, customer screens, requests, bookings, chat, debug, scripts, assets, or routing changes.

## Implementation Rules

- Do not read or display remote image content unless an existing local picker result is already present in the current view flow.
- Do not change upload/delete semantics or Storage paths.
- Do not add asset licensing assumptions.
- Keep business behavior in `GroomerProfileStore`.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

Status:

- `./scripts/ios-build.sh` passed on 2026-06-22.
- Post-review `./scripts/ios-test.sh` passed on 2026-06-22.
- `git diff --check` passed on 2026-06-22.

## Acceptance

- Groomer portfolio section uses Groomly cards, feedback, metadata rows, and action styling.
- Existing portfolio upload/delete metadata behavior, disabled states, notices, and errors are preserved.
- No Store, repository, model, backend, Supabase, script, asset, request, booking, chat, debug, or tab-routing file is changed.
- Next planned task remains T-033.

Completion notes:

- `GroomerPortfolioSection` now uses `GroomlySectionHeader`, `GroomlyEmptyState`, `GroomlyCard`, token-based metadata rows, an inline upload progress card, and groomer-accent upload styling.
- Existing `PhotosPicker` selection, local data loading, content-type detection, `store.uploadPortfolioPhoto(data:contentType:)`, `store.deletePortfolioPhoto(_:)`, busy/disabled states, notices, and errors remain owned by the existing view/Store flow.
- Remote image rendering, signed URLs, Storage policies, repositories, models, backend, scripts, assets, request screens, bookings, chat, debug, and tab routing were not changed.

## Stop Conditions

Stop and report if the restyle requires signed URLs, remote thumbnail rendering, Storage policy changes, repository changes, or new asset decisions.
