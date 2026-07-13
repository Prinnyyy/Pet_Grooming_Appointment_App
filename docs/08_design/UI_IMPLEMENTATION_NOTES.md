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
| Exact token comparison | `../01_product/DESIGN_SYSTEM.md` | `design_tokens.json` and Swift `DesignTokens` |

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
