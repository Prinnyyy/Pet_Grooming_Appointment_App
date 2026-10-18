# Beckon UI Reference Index

Compact route to current visual evidence. It does not define product behavior, backend facts, or task status.

Pre-routing source snapshot: `../09_frozen/design_notes/T-347_2026-07-13/UI_IMPLEMENTATION_NOTES.md`.

## Read By Task

| Task | Read first | Add only when needed |
|---|---|---|
| Screenshot-driven screen rework | `../01_product/DESIGN_SYSTEM.md`, `../01_product/ACCESSIBILITY_RULES.md`, `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` | `screenshots/README.md`, target SwiftUI/Store files |
| Form, editor, or sheet interaction | Above | `../01_product/FORM_INTERACTION_RULES.md` |
| Groomer Q-104/regression | Above | `GROOMER_UI_REDESIGN.md` and named approved captures |
| Broad Figma inventory/design handoff | `../ui-redesign/README.md` | Only the targeted heavy file(s) named by that index |
| Exact token comparison | `../01_product/DESIGN_SYSTEM.md` | Swift `DesignTokens` and `DesignTokenAccessibilityTests`; old JSON is frozen history |

Beckon HTML/export files and the heavy UI redesign body are not default context. Open them only for a named comparison or design task. Never copy HTML, CSS, React, generated JavaScript, or prototype runtime code into SwiftUI.

## Authority

- Production data, validation, navigation, accessibility, and behavior come from current SwiftUI, Stores, repositories, models, and active product/backend contracts.
- Screenshots define approved visual hierarchy only where the current task names them. Illustrative names, dates, images, counts, addresses, and copy are not fixtures or product facts.
- Swift `DesignTokens` is implementation authority; extracted JSON is reference evidence.
- New persistence, schema, RLS/RPC, Storage, role capability, navigation, or deferred feature requires separate approval.

## Asset Routes

- General screenshot index: `screenshots/README.md`
- Groomer current/approved evidence: `groomer_ui_redesign/current/` and `groomer_ui_redesign/approved/`
- Heavy Figma/inventory evidence: `../ui-redesign/README.md`
- Prototype export: `Beckon.html` and `Beckon/` (ignored heavy source)

No production-ready external logo, icon, photography, or illustration package is approved by these references. New asset use requires source and licensing review.

## T-416 Targeted Migration Review

2026-10-18: The T-409/T-411 color migration incorrectly treated authentication brand artwork as controls: the mint body became a pale Tint, the highlight became opaque white, the outline became Deep, surrounding bubbles lost translucency, and the shared card-shadow reduction removed the intended depth. The main icon also had only an entrance animation, not a continuing float. `BeckonBrandBubble` now owns the artwork/material and one motion timeline; small bubbles are preserved. Authentication navigation animations now also respect Reduce Motion.

The bounded source/history audit covered Customer Hero/request cards, discovery card elevation, pet/profile image borders and placeholders, onboarding/bootstrap, chat bubbles/composer, Groomer Home and portfolio/availability surfaces. Their opaque semantic fills, readable foregrounds and quiet card shadows match D-060; no additional defect of this migration pattern was confirmed, and those modules were not changed. This is not a new whole-app UX certification.

Acceptance: the actual landing-render test first failed with zero mint-body pixels and 247 dark-outline pixels, then passed after repair. Motion sampling isolates the main bubble from its satellites, checks changing frames, complete stillness when disabled and resumed motion. Default/AX3 renders were inspected, including the strengthened ground shadow; authentication launch/sign-in/recovery UI tests passed. This covers semantic accessibility structure and motion gating, not a fresh spoken VoiceOver walkthrough.

Validation: full Simulator regression produced 827 passes, one stale `Senior Care` copy expectation and 46 opt-in skips. Git history confirmed T-413 adopted `Senior care`; only that expectation was synchronized, then all 57 `GroomerProfileStoreTests` passed. Other passing results were reused, not falsely reported as a second full green run. `ios-build.sh`, 235 preflight tests, 30 focused color/audit tests and full context hygiene passed. Local evidence: `artifacts/evidence/T-416/auth-landing-default.jpg`, `landing-final/manifest.json` and `preflight.log`; XcodeBuildMCP result bundles end in `07-51-08-851Z_pid34241_da20aa51.xcresult` (full) and `07-55-12-328Z_pid34241_ca24e19f.xcresult` (retest).
