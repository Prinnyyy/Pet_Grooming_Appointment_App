<!-- task-artifact
task: T-409
status: active
type: plan
-->
# UI Color Implementation

The user adopted [the handoff](../../../UI_COLOR_IMPLEMENTATION_HANDOFF.md) on 2026-10-17. Its sections 1-5 own the complete visual scope and acceptance; the [external audit](../../../UI_UX_AUDIT_AND_OPTIMIZATION_PLAN.md) is supporting evidence, not additional backlog. Baseline: `e8c2d2b5`. Dynamic task state belongs only to [Current State](../../00_memory/CURRENT_STATE.md).

## Execution Decisions

- Execute continuously on the user-selected branch. The external draft's one-session-per-package rule is superseded by the repository workflow and the user's continuous-execution request.
- Use the handoff's final sRGB values when the earlier audit differs. Keep old symbols only until their last consumers migrate; do not delete symbols in the primitive package while Feature consumers still require them.
- Preserve business behavior, navigation, accessibility identifiers, signing and backend state. Use local fixtures/Simulator for visual coverage rather than creating remote data.
- Semantic domain chips share one presentation mapping outside DesignSystem. Non-domain chips also use named shared presentations; do not force arbitrary account or validation labels into domain enums.
- Verify per package; full regression at shared-component/integration boundaries as specified, reuse unchanged evidence. Keep only acceptance summaries and significant corrections here.
- Visual reference is available: both Tuned PNGs in `artifacts/evidence/UI-COLOR-HANDOFF/` were inspected, and the user opened the authenticated sidebar prototype. Its Customer/Groomer pages and diagnosis agree with the handoff. Use their color/hierarchy, not HTML geometry; retain native layout and Dynamic Type.

## Packages

| Package | Scope | Acceptance |
|---|---|---|
| T-409 | sRGB tokens, transitional aliases, root tints, contrast tests, design routing/decision | Focused tests, build, audit, hygiene, both Home baseline/updated captures |
| T-410 | Buttons, semantic chips, domain presentation, feedback, selection, placeholders, badges, catalog | Mapping/component tests, full regression, catalog/default+AX3 and Home/Wizard captures |
| T-411 | Feature color/status migration and alias removal | Zero prohibited color/tint uses, full regression, audit pruning, both-role status captures |
| T-412 | Unified date intervals, timezone/unknown handling, display fallbacks, plurals, sentence case | DST/midnight/cross-zone tests, build, affected UI selectors, time captures |
| T-413 | Customer Home hero/pet/request presentation and progress | All request states, loaded/unknown offer counts, single action target, AX3/accessibility, strict audit |
| T-414 | Groomer Home, Requests/Offers and Account component use | Current-state recheck, full regression, three screens/default+AX3, accessible targets |
| T-415 | UI012-014 rules/tests, debt pruning, external draft archival | Zero new-rule baseline debt, preflight, full regression, full hygiene, final source/visual review |

## Evidence

Evidence images and long logs belong in ignored `artifacts/evidence/<task>/`. No backend, account, data-model, signing, dark-mode or product capability work is included.

### T-409

- Implemented sRGB palette, semantic roles/temporary compatibility names, warm text hierarchy, root Deep tint, AccentColor and single card elevation; original JSON moved unchanged to frozen design history. D-060 records the adopted usage contract.
- RED reproduced old hex values and inverted secondary/tertiary luminance. Final focused run: 18 Swift tests plus one four-capture XCTest passed (`/tmp/beckon-t409-final-tests.log`). Core Graphics converts the old P3 mint within 2/255 of the new sRGB fill. Alpha comparison uses floating-point tolerance after observing UIColor's 0.0599999987 representation of 0.06; contrast thresholds were unchanged.
- Build passed (`/tmp/beckon-t409-build.log`); only the existing no-AppIntents metadata warning. UI check: 142 existing findings, no new violations. Hygiene: 84 documents, zero errors/warnings. Both Home default/AX3 images inspected in `artifacts/evidence/T-409/manifest.json`; old gradients, emoji, badge and verbose date presentation remain assigned to later packages, not claimed fixed here.

### T-410

- Solid Fill/Ink primary actions, opaque disabled surfaces, Deep secondary/tertiary actions and shared destructive style; semantic chips and exhaustive request/match/offer/booking mappings; neutral SF Symbol placeholders, semantic feedback/selection and scoped native tab badges (capped at 99+). Existing tap-availability behavior and all accessibility identifiers are preserved.
- Four Node contracts passed after RED. Full serial scheme regression passed: 767 Swift tests, 35 XCTest rendering/interaction tests and 4 UI tests; 45 existing opt-in tests skipped, zero failures (`/tmp/beckon-t410-serial.log`). The script's default parallel run stalled during simulator startup after its UI tests passed; it was terminated and rerun with `-parallel-testing-enabled NO`, without changing test selection. Two compile-time role-chip callers were migrated before the passing run.
- Preflight and UI audit passed (142 existing findings); hygiene passed. Home and Wizard default/AX3 captures show solid buttons, neutral pet placeholders and role-tinted native badges. Expanded catalog scroll captures passed in a focused three-test run and were visually checked (`artifacts/evidence/T-410/catalog-expanded/manifest.json`, `/tmp/beckon-t410-captures.log`). Legacy Feature status mappings and long date labels remain T-411/T-412 work.
