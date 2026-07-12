# UI Consistency Governance Design

Approved direction: T-301, 2026-07-12. This is the design contract for R-041. It defines the architecture and migration boundary; the next planning task will assign execution packages and exact file-level steps.

## Goal

Make UI consistency primarily enforceable from code. Beckon should have one semantic visual language, reusable presentation components, an auditable exception path, and an automated ratchet that prevents new visual debt without requiring an immediate whole-app rewrite.

The first migration slice covers Customer Home, Requests, Request creation, Account, and the shared DesignSystem code those surfaces directly use. The entire app is audited from the start, but non-slice features initially retain recorded legacy debt and may not add new violations.

## Repository Findings

Beckon already has a design foundation and must evolve it rather than create a parallel theme:

- `DesignSystem/DesignTokens.swift` owns the active palette, spacing scale, shape values, shadows, and five platform-level typography values.
- Shared action, card, status, form, loading, empty, error, image, and feedback primitives are already used across multiple features.
- `docs/01_product/DESIGN_SYSTEM.md` already defines UI-R1 through UI-R8 and A11Y-R1 through A11Y-R10.
- `DesignTokenAccessibilityTests.swift` verifies only a subset of current color pairs.

The current implementation does not fully enforce that contract:

- Typography has platform categories, not the business semantics required by page titles, section titles, card titles, field labels, status copy, support copy, and actions.
- Documented `successText`, `warningText`, and `errorText` roles are missing from Swift tokens.
- `softCard`, `smallCard`, and `carouselCard` currently have identical values despite implying different elevation.
- Feature code contains at least 19 fixed `Font.system(size:)` calls, 34 `minimumScaleFactor` calls below 0.85, and 16 offset or negative-spacing layout patches.
- Request creation defines a feature-local `ButtonStyle`; repeated card, selection, settings-row, and form-group presentations remain feature-local.
- Customer Home, Requests, Request creation, and Account are useful references for product hierarchy and visual tone, but they also contain fixed typography, low text scale factors, local styles, raw geometry, and repeated surface implementations. They are reference inputs, not normative code.
- Groomer screens intentionally use denser grouped workspace surfaces. Customer card composition must not become a universal screen template.
- The repository has no SwiftLint or SwiftSyntax setup and no existing UI source-audit gate. Node-based repository checks and tests are already established in `scripts/` and `tests/`.

## Design Principles

1. Extend the existing `DesignTokens` and Beckon primitives in place.
2. Prefer semantic roles over aliases for numeric values.
3. Put repeatable presentation behavior in DesignSystem; keep data, ordering, navigation, and mutations in Features and Stores.
4. Extract a component when the same semantic pattern exists on at least two surfaces or when a single shared primitive must own a cross-app rule such as touch size or field error presentation.
5. Keep unique business compositions local when they do not repeat. Customer Home's request hero is one such composition, although it must consume shared typography, spacing, controls, and colors.
6. Preserve native SwiftUI controls, Dynamic Type, VoiceOver, safe areas, localization, Reduce Motion, and platform interaction behavior.
7. Treat screenshots as final rendering evidence, not the source of typography, spacing, card, or button rules.

## Semantic Foundation

`DesignTokens` remains the only token source. Its public feature-facing API should express stable meanings:

- Typography: page title, section title, card title, body, supporting copy, field label, status, and action.
- Layout: page inset, page top/trailing space, section gap, card content inset, row gap, field gap, and action-area inset.
- Metrics: minimum touch target, standard field height, standard action height, and repeated icon slots where an actual shared row contract needs them.
- Colors: app background, surfaces, borders/dividers, primary/secondary/tertiary text, role actions, disabled state, and distinct status fill/text roles.
- Shape and elevation: named surface/control roles only when their values or behavior differ.

The underlying 4-point spacing scale may remain available to DesignSystem and geometry-specific code. Migrated feature layouts should normally consume semantic containers or layout roles rather than assemble screens from scale values.

Existing token names needed by unmodified features remain transitional compatibility APIs. The audit baseline permits their existing occurrences outside the migration slice, but migrated files and new code may not reintroduce superseded APIs. Compatibility APIs are removed only after their recorded usage reaches zero.

## Component Boundaries

The implementation plan should evaluate and evolve these component families rather than build one universal component:

- Screen container: background, safe-area behavior, standard content insets, and optional scrolling.
- Section: semantic heading, optional trailing action, content spacing, and heading accessibility trait.
- Surface: standard card, grouped surface, and selectable surface with owned fill, border, radius, depth, and selected/error state.
- Actions: primary, secondary, destructive, and icon actions with role accent, loading/disabled behavior, minimum hit target, and native button semantics.
- Rows: settings/navigation row and factual information row with standard icon slot, text hierarchy, divider alignment, and full-row hit area.
- Forms: field label, supporting/error text, field surface, field group, and native-control integration.
- Wizard action area: Back/Continue/Publish layout, safe-area behavior, loading, and disabled presentation.
- Feedback: retain and refine the existing loading, empty, error, status, and global-feedback primitives.

Role-specific organisms remain valid. `GroomerGroupedSurface` can either become a role-neutral grouped-surface primitive when its semantics are truly shared or stay Groomer-owned. It must not be replaced merely to make names uniform.

The 1,429-line feedback primitive file is a maintainability concern, but splitting it is not a prerequisite unless a touched implementation needs ownership separation. File-size cleanup is not a substitute for visual governance.

## Customer Reference Slice

### Home

- Preserve the greeting, request hero, Pets, Active Request, and Next Booking order.
- Standardize section headings and shared surfaces.
- Keep the request hero as a feature composition while moving its text/action semantics to shared APIs.
- Review fixed pet-card dimensions as content/media geometry; remove text compression or offsets that compensate for inflexible text layout.

### Requests

- Standardize the root title, request progress surface, timeline information hierarchy, and action rows.
- Preserve the shared Customer Requests Store, request lifecycle, focused routing, cancellation, booking handoff, and pagination.
- Keep timeline-specific geometry local where it is not a cross-feature pattern.

### Request Creation

- Replace the local primary button style with the shared action contract.
- Standardize step heading, selectable surfaces, field groups, validation presentation, and bottom action area.
- Remove sub-0.85 text scaling in favor of reflow, flexible grids, or accessibility-size alternatives.
- Preserve the existing sheet ownership, Store state, address editor, validation, publication, and republish behavior.

### Account

- Standardize identity presentation, labeled groups, navigation rows, external-link rows, icon slots, and dividers.
- Preserve profile loading/editing, avatar behavior, account deletion, Privacy Policy, Support, and sign-out behavior.

This Customer accessibility work does not automatically reopen the user-deferred Groomer-wide Q-104 integration gate. The global audit may report Groomer debt, but Groomer migration remains separately scoped until the user restores it.

## Automated Audit

The first implementation should use the repository's existing Node test/tooling pattern and add no third-party dependency. The scanner must be more than a collection of unscoped regular expressions:

1. Lex Swift source while excluding comments and string literals.
2. Track balanced delimiters and modifier-call spans so findings point to complete expressions.
3. Apply deterministic rules to known syntax and classify ambiguous layout cases separately.
4. Normalize the matched expression for stable debt fingerprints.
5. Emit machine-readable results plus concise human output.

Each finding includes rule ID, severity, file, line, construct, reason, and recommended replacement.

Initial classifications:

- Error: unapproved feature typography, including fixed `Font.system(size:)` and direct platform text styles in migrated/new code; raw non-semantic colors; new numeric feature padding/spacing or card/control dimensions; feature-local `ButtonStyle` or presentation `ViewModifier`; raw card/control corner radius or shadow; unjustified `minimumScaleFactor` below 0.85; and invalid/stale exception directives.
- Warning: fixed image/icon/media geometry, text-containing fixed dimensions, line truncation, offsets, negative spacing/padding, and layout repair patterns whose correctness depends on surrounding structure.
- Review: repeated normalized modifier stacks, new feature-local visual components, new token proposals, and structures that resemble an existing semantic component.

Existing direct platform typography and numeric layout occurrences are baseline debt outside the first slice, not precedent. New or migrated text must use Beckon semantic roles. Warnings and review findings are not automatically promoted to errors because fixed image geometry, timeline drawing, progress bars, animation geometry, zero-spacing groups, one-pixel dividers, and badge positioning can be valid.

SwiftSyntax is a possible later upgrade only if measured false positives or required semantic rules justify a dependency proposal. It is not introduced speculatively.

## Debt Ratchet

The initial audit records existing findings outside the migrated slice. A baseline occurrence is identified by rule, file, normalized expression fingerprint, and occurrence index rather than line number alone.

- A normal audit passes with unchanged legacy debt and fails on new error-level debt.
- Migrated files have a zero-baseline expectation for rules addressed by their package.
- Removing a violation removes its baseline entry; it must not be regenerated during normal development.
- Baseline updates require an explicit command and reviewed diff.
- Counts by rule and feature are reported so later packages can reduce debt intentionally.
- A business change to a legacy file is not required to clear every unrelated warning, but it cannot add a new violation.

The audit command should be called by `scripts/preflight.sh` and covered by Node fixture tests. CI integration is deferred unless the repository gains an active CI workflow; local preflight is the current governed gate.

## Exceptions

Exceptions use a structured, single-site directive immediately before the affected expression. The final syntax will be fixed by the audit implementation, but it must include one rule ID and a non-empty reason.

Allowed examples include image/media geometry, one-pixel dividers, custom drawing, timeline markers, badge positioning, and motion geometry that respects Reduce Motion.

Not allowed:

- whole-file or wildcard suppression;
- suppressing typography, color, card, or button rules merely to preserve a local style;
- missing or generic reasons;
- silently keeping a suppression after the finding disappears.

Repeated exceptions for the same semantic need trigger a design-token or component review.

## Validation Strategy

Foundation and shared-component packages require:

- scanner fixture tests, including comments, strings, multiline modifiers, false-positive cases, baselines, and exceptions;
- expanded color contrast tests for status text/fill pairs;
- focused Swift tests where presentation state can be tested without rendering internals;
- complete iOS tests and one iOS build because DesignSystem is cross-feature;
- `git diff --check`, context hygiene, and preflight.

Each Customer migration package additionally verifies:

- default text and at least Accessibility 3 sizing;
- long/localized-style text reflow and no text overlap;
- 44-point interactive targets and full-row hit areas;
- VoiceOver labels, grouping, headings, and decorative-image hiding;
- Reduce Motion for any touched custom animation;
- one Simulator behavior/rendering pass.

Screenshots may identify clipping, missing content, or rendering failure. Code rules, component usage, test output, and audit findings determine consistency compliance.

## Delivery Sequence

The next planning task should split implementation into small reviewable packages in this dependency order:

1. UI audit tool, tests, all-app debt baseline, and preflight ratchet.
2. Semantic token evolution and accessibility contrast completion.
3. Shared screen, section, surface, action, row, form, and wizard-action primitives justified by the four-page audit.
4. Customer Home migration.
5. Customer Requests migration.
6. Customer Request creation migration.
7. Customer Account migration.
8. First-slice integration audit, remaining-debt report, and follow-up prioritization.

Exact package boundaries may combine or split foundation work after file-level planning, but each task must preserve the one-primary-task workflow and leave the app buildable. No package changes backend schema, Supabase policy, repository contracts, navigation/product flow, or dependencies without a separately approved scope change.

## Exit Criteria

R-041's first slice is complete when:

- the four Customer surfaces use the approved semantic typography and layout contracts;
- repeated cards, rows, forms, and actions in the slice use shared semantic components;
- the local Wizard button style and addressed feature-level visual stacks are removed;
- new error-level visual debt is blocked across all Feature code;
- legacy debt is visible, stable, and decreases as files migrate;
- exception use is explicit and audited;
- contrast, Dynamic Type, accessibility, build, test, audit, and preflight gates pass;
- screenshots are only supplementary rendering evidence;
- remaining non-slice debt and role-specific exceptions are documented for later prioritization.
