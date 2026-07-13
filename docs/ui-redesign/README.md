# Heavy UI Redesign Evidence Index

This directory contains a large, point-in-time SwiftUI inventory and Figma handoff package. It is retained because future redesign work may need its evidence, but it is not a current product, code, navigation, or task-status authority.

Only this README is visible to default `rg` searches. The body is L4 heavy context and requires a named design/inventory purpose.

## Open Conditions

Open a body file only when the task explicitly needs one of these:

- broad Figma redesign or inventory comparison;
- a named screen's historical functional/data mapping;
- existing component evidence for a focused design-system decision;
- the Groomer Schedule Figma Make package.

Before using a claim, verify it against current SwiftUI, Stores, repositories, models, `../01_product/SCREEN_INVENTORY.md`, or the relevant active domain contract. Counts, surface lists, navigation, and implementation notes can become stale as the app evolves.

Use targeted access:

```sh
rg --no-ignore -n "<screen-or-feature>" docs/ui-redesign
sed -n '<start>,<end>p' docs/ui-redesign/<target-file>.md
```

Do not read every file, use broad `rg --no-ignore --files`, or load images/export packages without a specific need.

## Routes

| Need | Target |
|---|---|
| Inventory scope and audit limits | `00-inventory-scope.md`, then targeted `06-inventory-audit.md` |
| Screen existence/ownership | `01-screen-inventory.md` |
| Navigation or one user flow | targeted section in `02-navigation-and-user-flows.md` |
| One screen's controls and states | targeted section in `03-screen-functional-specs.md` |
| Store/model/repository dependency | targeted section in `04-screen-data-and-state-map.md` |
| Existing component evidence | targeted section in `05-existing-component-inventory.md` |
| Broad Figma brief | `07-ui-redesign-brief.md`; use 01-06 only to verify a specific claim |
| Figma planning/system calibration | one named file from `08` through `12` |
| Groomer Schedule Figma Make input | `figma-make/groomer-schedule/00-readme.md`, then only its directed package files |

## Active Authority

- Core visual contract: `../01_product/DESIGN_SYSTEM.md`
- Accessibility and contrast: `../01_product/ACCESSIBILITY_RULES.md`
- Form/keyboard behavior: `../01_product/FORM_INTERACTION_RULES.md`
- Current design evidence routing: `../08_design/UI_IMPLEMENTATION_NOTES.md`
- Screenshot task boundary: `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md`

This package does not authorize product, backend, persistence, role, navigation, or remote changes.
