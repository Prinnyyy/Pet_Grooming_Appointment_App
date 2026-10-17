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
- Home summaries are one whole-card button; Review is a visual cue included in its accessibility label. Offer counts use only complete, successfully loaded pages, not partial/stale/error caches; unknown counts use the specified fallback and never trigger a fetch.
- Chat has no verified customer-name field in its current contract. Keep a compact role plus participant code only in conversation titles so missing names cannot collapse distinct recipients; remove the technical `ref` wording. Do not add identity fetching or invent names.

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

### T-411

- Migrated Feature and SharedFeatures to opaque semantic surfaces and readable role colors; deleted all transitional color names and duplicate status mappings. Evaluated offer presentation preserves deadline, checking, changed-terms and capacity states through one typed result without changing acceptance logic. Inline errors now reuse the form error icon/container, and placeholders no longer encode species or role in their background.
- Eight Node contracts passed. Full serial regression: 767 Swift tests, 36 XCTest and 4 UI tests passed; 45 existing opt-in skips, zero failures (`/tmp/beckon-t411-final-tests.log`). An earlier snapshot test referenced an obsolete view name; it was corrected to the existing Requests workspace before the passing run. Final neutral-icon corrections were covered by the four snapshot tests and five status tests in `/tmp/beckon-t411-t412-focused.log`; that run also passed nine independent formatter tests prepared for T-412.
- Both-role Bookings, Offers and Requests captures were inspected (`artifacts/evidence/T-411/status-captures/manifest.json`; final captures in `artifacts/evidence/T-411/verified/manifest.json`). Status semantics agree; long dates, duplicate Offers heading and remaining Groomer-specific presentation are explicitly the following packages. Preflight, audit and hygiene passed. Baseline prune removed zero entries; no debt was added. Identifier strings and local signing changes are preserved.

### T-412

- Unified request/offer/booking/wizard/reschedule intervals, explicit unknown-zone handling, full zone identity in accessibility, human-readable empty values, independent singular/plural counts and sentence-case labels. Stored fields and transport values are unchanged. Visible-text TestOps selectors and their source oracle were updated together; 27 fixture tests passed.
- Nine formatter boundary tests cover same/different zones, noon, midnight, year boundaries, malformed intervals, DST gaps and repeated hours. The broad run passed 36 rendering tests and four UI smoke tests; it exposed a genuine chat-recipient distinction regression plus three outdated presentation expectations. The distinction was restored without new fields, the shared location labels aligned, and all affected suites passed in the follow-up (154 Swift tests including four T-413 tests, five snapshot tests; `/tmp/beckon-t412-t413-tests.log`). Generic Simulator build passed, hygiene passed. Final whole-suite integration remains T-414/T-415.
- Offers and Groomer Requests time captures inspected in `artifacts/evidence/T-413/captures/manifest.json`. No long IANA IDs appear in the list labels; unknown zones remain explicit rather than guessed.
