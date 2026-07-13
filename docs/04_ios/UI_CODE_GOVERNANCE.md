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
- form content keeps the native keyboard safe area and has no synthetic keyboard-height padding, inset, or `ignoresSafeArea(.keyboard)`;
- page-level actions do not float above the keyboard, while true input accessories such as chat send controls may track it;
- stationary page-action compensation applies only to a bottom-docked keyboard; floating, split, hidden, and hardware keyboards add no offset or blank space;
- keyboard-aware scrolling forms expose both interactive drag dismissal and the shared explicit `Done` action, so no keyboard type requires leaving the page;
- automatic reveal is non-animated, runs only for new focus or keyboard appearance, then yields immediately to user tracking/scrolling; geometry or keyboard-frame changes during that gesture must not restart programmatic scrolling;
- while a software keyboard is onscreen in a sheet, content scrolling/dismissal wins and sheet dismissal is suspended; after an interactive keyboard dismissal, the lock remains through deceleration and releases at idle so the same drag cannot dismiss the sheet;
- feature code passes only an additional business-lock Boolean and does not compose keyboard-driven `presentationContentInteraction` or `interactiveDismissDisabled` locally;
- UIKit representables report editing focus through the same callback contract as native SwiftUI fields;
- no fixed viewport-percentage anchor, guessed offset, negative spacing, fixed text-clipping height, or duplicate feature-local keyboard policy was added.

Feature code may declare stable focus IDs, focus order, semantic keyboard/content types, and an optional business-lock Boolean, then call the shared keyboard/form modifiers. Keyboard-frame observation, viewport calculations, reveal anchors, scroll-phase handoff, animation timing, keyboard/sheet gesture arbitration, synthetic content clearance, and stationary page-action behavior belong to DesignSystem; duplicating any of them in a feature is a review failure.

The UI audit enforces the deterministic boundary: `UI009` rejects feature-level keyboard safe-area bypass, `UI010` rejects keyboard-derived feature padding/offset, and `UI011` rejects feature-level keyboard notifications/frame reads. Shared geometry tests cover docked versus floating behavior that regex cannot determine.

Code review must account for at least one low single-line field and one multiline field when the screen has both, plus docked/floating/hardware keyboard outcomes in the shared contract tests. Runtime interaction remains user validation unless explicitly requested. Source audit warnings remain review signals; the one shared keyboard boundary is not an invitation to suppress UI102 elsewhere.

## Migration Status

T-312/Q-120 completes the first reference slice: Customer Home, Requests, Request Wizard, and Account have zero strict errors and passed default/Accessibility 3 compact/large integration checks. Remaining repository debt, reviewed geometry, concentrations, and migration ordering live in `UI_CONSISTENCY_DEBT.md`.
