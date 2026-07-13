# UI Code Governance

This is the executable governance contract for SwiftUI code under `ios/Beckon/Beckon/Features`. Visual direction and approved semantic roles live in `../01_product/DESIGN_SYSTEM.md`; this file defines what the source audit enforces.

## Gate

Run the repository-wide ratchet:

```bash
node scripts/ui-consistency-audit.mjs check
```

Run the zero-error gate for files being migrated:

```bash
node scripts/ui-consistency-audit.mjs strict ios/Beckon/Beckon/Features/Customer/ExampleView.swift
```

`scripts/preflight.sh` runs the repository-wide check. Output uses `path:line:column: severity rule message [replacement]`. Add `--format json` to `check` or `strict` for structured output.

## Findings

| Rule | Severity | Meaning | Preferred replacement |
|---|---|---|---|
| UI001 | error | Fixed `.font(.system(size:))` typography | `DesignTokens.Typography` semantic role |
| UI002 | error | Direct SwiftUI platform text style in Feature code | `DesignTokens.Typography` semantic role |
| UI003 | error | Raw color construction or platform color | `DesignTokens.Colors` semantic role |
| UI004 | error | Numeric feature spacing | Semantic spacing token or shared component |
| UI005 | error | Numeric feature radius or shape | Semantic shape role or shared surface |
| UI006 | error | Feature-owned shadow | Canonical `beckonShadow` elevation role |
| UI007 | error | Feature-local reusable presentation style | Shared `DesignSystem` style |
| UI008 | error | `minimumScaleFactor` below 0.85 | Reflow or content-sized layout |
| UI101 | warning | Fixed frame with Dynamic Type risk | Content-sized or adaptive layout |
| UI102 | warning | Offset or negative spacing repair | Alignment or layout container |
| UI201 | review | Repeated visual modifier stack | Review for a semantic component |

`error` is deterministic and blocks new or migrated code. `warning` marks a high-risk layout site for review. `review` is evidence of possible duplication, not proof that abstraction is correct.

The scanner lexes Swift comments and strings before matching, preserves UTF-16 source positions including content after emoji, and expands balanced modifier calls. It is intentionally narrower than a compiler: a clean audit proves compliance with these rules, not complete SwiftUI correctness or accessibility.

## Debt Ratchet

`scripts/ui-consistency-baseline.json` records legacy findings only. `check` succeeds when no new error exists and no recorded entry has silently disappeared. A stale entry must be removed explicitly so migrations produce a reviewed debt reduction.

Baseline entries use a path-bound fingerprint plus a path-independent expression hash and occurrence count. Do not hand-edit the file.

```bash
node scripts/ui-consistency-audit.mjs baseline initialize --reason Q-113
node scripts/ui-consistency-audit.mjs baseline prune --reason Q-116
node scripts/ui-consistency-audit.mjs baseline relocate \
  --from ios/Beckon/Beckon/Features/Old.swift \
  --to ios/Beckon/Beckon/Features/New.swift \
  --reason Q-116
```

`initialize` refuses overwrite. `prune` can only remove stale entries and refuses new errors. `relocate` supports whole-file moves and partial declaration splits: each prior source finding must either remain or appear exactly once at the destination with the same rule ID, expression hash, and occurrence. New, deleted, changed, or ambiguously duplicated findings exit with configuration status `2` without writing.

## Exceptions

Only UI101 supports a source exception, for a fixed square media crop whose text is outside the frame. Put this exact directive on the immediately preceding line:

```swift
// beckon-ui-audit: allow UI101 -- Fixed square media crop; text is outside this frame.
Image(uiImage: image).frame(width: 80, height: 80)
```

Wildcards, missing reasons, alternate wording, detached directives, and exceptions for other rules are invalid. If another justified pattern recurs, update the rule or introduce a semantic design definition through a dedicated task instead of silently bypassing the gate.

## Review Boundary

Feature views own data, business order, actions, and state. `DesignSystem` owns recurring typography, spacing, alignment, color, shape, elevation, control dimensions, and presentation feedback. The audit catches known source patterns; reviewers must still check component reuse, Dynamic Type, VoiceOver, contrast, localization, safe areas, focus, and native control behavior.

### Keyboard and Focus Review

For each changed scrolling form or editor, reviewers must verify the keyboard-aware form contract in `../01_product/DESIGN_SYSTEM.md`:

- focus scrolls the label/title and complete control as one stable target;
- an already visible target causes no programmatic scroll;
- an obscured target reveals only its nearest hidden edge plus semantic clearance and clamps naturally at content bounds;
- oversized semantic groups select one stable nearest edge instead of oscillating between top and bottom;
- measured keyboard overlap is used only as content clearance or as encapsulated compensation that preserves a page-level action's original coordinate;
- page-level actions do not float above the keyboard, while true input accessories such as chat send controls may track it;
- keyboard-aware scrolling forms expose both interactive drag dismissal and the shared explicit `Done` action, so no keyboard type requires leaving the page;
- UIKit representables report editing focus through the same callback contract as native SwiftUI fields;
- no fixed viewport-percentage anchor, guessed offset, negative spacing, fixed text-clipping height, or duplicate feature-local keyboard policy was added.

Feature code may declare stable focus IDs and call the shared keyboard/form modifiers. Keyboard-frame observation, viewport calculations, reveal anchors, animation timing, dismissal behavior, and stationary page-action behavior belong to DesignSystem; duplicating any of them in a feature is a review failure.

Simulator evidence for a migrated form must cover at least one low single-line field and one multiline field when the screen has both. Compare keyboard hidden and shown states, including Dynamic Type when the changed geometry could reflow. Source audit warnings remain review signals; a measured, shared keyboard compensation is not an invitation to suppress UI102 elsewhere.

## Migration Status

T-312/Q-120 completes the first reference slice: Customer Home, Requests, Request Wizard, and Account have zero strict errors and passed default/Accessibility 3 compact/large integration checks. Remaining repository debt, reviewed geometry, concentrations, and migration ordering live in `UI_CONSISTENCY_DEBT.md`.
