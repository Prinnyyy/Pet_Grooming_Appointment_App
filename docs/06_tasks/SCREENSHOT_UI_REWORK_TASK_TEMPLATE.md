# Screenshot UI Rework Task Template

Task ID: `<NEXT_TASK_ID>`

Mode: `Quick / Standard / Deep`

Date: `<YYYY-MM-DD>`

## User Request

Paste or summarize the user request and attach/reference exactly one screenshot unless the user explicitly combines multiple screenshots.

Screenshot/source reference:

- `<path, attachment label, or design source>`

## Primary Task

Rework only the target screen represented by the screenshot.

Target screen and role:

- Screen: `<existing screen or new-feature candidate>`
- Role: `<Customer / Groomer / Shared / Developer only>`

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. targeted `docs/00_memory/CURRENT_STATE.md` sections when current state or risks matter
4. `docs/01_product/SCREEN_INVENTORY.md`
5. `docs/01_product/DESIGN_SYSTEM.md`
6. relevant SwiftUI view file(s)
7. relevant Store, repository protocol, and model files only when wiring existing behavior

## Screenshot Analysis

Map every visible module before editing SwiftUI.

Ignore rule:

- Ignore any long oval Customer/Groomer toggle located above the visible app screen frame. Treat it as an external prototype/control annotation, not as an app module to map, classify, or implement.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| `<module name>` | `visual-only / existing-feature rewire / reusable UI primitive / new feature` | `yes / partial / no` | `<SwiftUI view or DesignSystem file>` | `<existing path or none>` | `implement / stop for approval` |

Classification rules:

- `visual-only`: layout, spacing, color, typography, copy, icon, loading/empty/error/status presentation using existing state.
- `existing-feature rewire`: new UI presentation for behavior already supported by current Store/repository/model/backend contracts.
- `reusable UI primitive`: small pure DesignSystem helper with no business logic or data access.
- `new feature`: any new persistence, schema, RLS, RPC, Storage behavior, repository contract, navigation model, role capability, product flow, or deferred feature.

## Scope

In scope:

- Implement only modules classified as `visual-only`, `existing-feature rewire`, or approved `reusable UI primitive`.
- Reuse existing Stores, repository protocols/adapters, models, and backend contracts for existing behavior.
- Preserve loading, empty, error, disabled, duplicate-submit, and role-specific states.

Out of scope:

- New backend/schema/RLS/RPC/Storage changes unless separately approved.
- New repository/model contracts unless separately approved.
- New product flows, navigation models, role capabilities, or deferred features unless separately approved.
- Direct Supabase access from SwiftUI.
- Reopening or extending completed T-024 through T-035 task files.

## New Feature Stop Report

If any module is classified as `new feature`, stop before implementation and report:

```text
Stop reason:
Screenshot/module:
What the feature is:
Existing support:
Likely app files:
Likely backend/docs files:
Validation needed:
User decision needed:
```

## Implementation Rules

- Keep SwiftUI views thin and business logic outside views.
- Do not copy HTML/CSS/React directly into SwiftUI.
- Product correctness and accessibility take priority over visual matching.
- Preserve the Open Request -> Groomer Offer -> Customer Confirmation -> Booking model.
- Add reusable UI only under `DesignSystem` when it removes real duplication and carries no business logic.

## Validation

Default validation:

```sh
./scripts/ios-build.sh
git diff --check
```

If the task stops at screenshot analysis or only updates documentation, run only:

```sh
git diff --check
```

Completion launch for implemented UI changes:

- After validation, launch the app in the iOS Simulator for user inspection.
- Record simulator/device and visible root screen in this task file.

Run one validation attempt by mode. If required validation or required simulator launch fails, report the first real error and stop unless the user approves a follow-up. If no Swift/app UI changed, record simulator launch as skipped.

## Acceptance

- Screenshot modules are implemented only within the approved classification.
- Existing MVP behavior uses existing Store/repository/model/backend paths.
- No unapproved new feature, backend, schema, RLS, RPC, Storage, navigation, or role capability is introduced.
- Completed T-024 through T-035 files remain historical records, not active task files.
- Required validation passes or the first real error is reported under stop rules.

## Closeout

Status: `pending / completed / blocked`

Changed files:

- pending

Validation:

- pending

Simulator launch:

- pending

Risks:

- pending

Next:

- pending
