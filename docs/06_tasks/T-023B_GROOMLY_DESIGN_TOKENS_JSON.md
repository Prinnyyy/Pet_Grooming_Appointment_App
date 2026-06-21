# T-023B - Groomly Design Tokens JSON

- State: planned.
- Mode: Quick.
- Parent: `T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`.
- Depends on: completed T-023A and `docs/08_design/UI_IMPLEMENTATION_NOTES.md`.

## Goal

Create the Groomly token source-of-truth JSON from the inspected design files and T-023A notes. This task produces documentation/data only and does not edit Swift files.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
4. `docs/08_design/Groomly.html`
5. `docs/08_design/Groomly/`
6. `docs/01_product/DESIGN_SYSTEM.md`

## Scope

In scope:

- Create `docs/08_design/design_tokens.json`.
- Extract exact values from HTML/CSS where practical.
- Infer conservative values only when exact tokens are not available.
- Label extracted versus inferred token values.
- Update `docs/01_product/DESIGN_SYSTEM.md` only if token interpretation changes.
- Update `docs/00_memory/CURRENT_STATE.md`, `docs/00_memory/WORKLOG.md`, and `docs/06_tasks/TASK_LEDGER.md` only enough to mark T-023B completion and T-023C as the next task.

Out of scope:

- Editing Swift, Xcode, Supabase, scripts, or backend docs.
- Creating reusable SwiftUI primitives.
- Redesigning feature screens.
- Adding image or icon assets to the app.

## Required JSON Shape

`docs/08_design/design_tokens.json` must be valid JSON with these top-level keys:

```json
{
  "metadata": {
    "brand": "Groomly",
    "source": [],
    "extractionStatus": "mixed-extracted-and-inferred"
  },
  "colors": {},
  "spacing": {},
  "radius": {},
  "shadow": {},
  "typography": {}
}
```

Each token group must make extraction status clear. Accept either per-token objects:

```json
"appBackground": {
  "value": "#FAF7F2",
  "status": "extracted"
}
```

or a `notes` block that clearly lists which values are inferred.

Minimum color tokens:

- `appBackground`
- `surface`
- `surfaceRaised`
- `border`
- `textPrimary`
- `textSecondary`
- `textTertiary`
- `customerPrimary`
- `customerPrimaryDark`
- `groomerAccent`
- `groomerAccentDark`
- `success`
- `warning`
- `error`

Minimum non-color tokens:

- spacing scale from `xs` through `xl`
- card, button, input, chip, and circular radius values
- soft card shadow and primary action shadow
- large title, title, headline, body, caption typography direction

## Validation

Run:

```sh
python3 -m json.tool docs/08_design/design_tokens.json >/tmp/groomly_design_tokens_lint.json
git diff --check
```

Do not run `./scripts/ios-build.sh` because this task must not change Swift or project files.

## Acceptance

- `design_tokens.json` exists and is valid JSON.
- Tokens are traceable to `Groomly.html`, `docs/08_design/Groomly/`, or clearly labeled inference.
- T-023A notes remain the design interpretation source; this task does not duplicate the full handoff summary.
- No Swift, backend, Supabase, script, or Xcode file is changed.
- JSON lint and `git diff --check` pass.
- Task ledger and current state point to T-023C as the next child task.

## Stop Conditions

Stop and report if:

- Token extraction would require unsafe generated-code edits.
- The prototype has conflicting values that cannot be resolved conservatively.
- Asset source or licensing is unclear enough to affect token or asset naming.
- Existing user changes conflict with this documentation/data-only task.
