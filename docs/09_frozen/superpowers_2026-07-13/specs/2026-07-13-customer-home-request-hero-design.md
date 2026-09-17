# Customer Home Request Hero Design

## Scope

Refresh the existing Customer Home request CTA to follow the supplied Beckon reference while preserving its current action, disabled state, accessibility identifier, Store ownership, and Request Wizard presentation.

## Visual Contract

- Keep the existing light mint customer brand background.
- Match the supplied Display P3 `#93CEC2` to `#B0D8D9` light mint background without converting the source into lower-saturation sRGB values; render title/supporting copy with `#333333`.
- Let `Need grooming for your pet?` wrap naturally within the same content width as the action; do not embed a manual newline.
- Present `Start Grooming Request` as a compact white action with a scissors SF Symbol and shared `customerHeroText #333333` foreground, aligned to the copy's leading edge.
- Keep the action content-sized. Measure that intrinsic action width and apply it to the title/supporting-copy container; on narrower devices, both may contract to available width.
- Use the shared Beckon feature typography: `featureTitle` for the Hero heading, `body` for its description, and `prominentAction` for the button label.
- Keep the approximately 110pt top-right circle and diagonal bottom-right paw decoration inside the hero bounds and away from interactive content.
- Preserve the disabled requirement message and make disabled action styling visibly distinct.

## Global Customer Palette Contract

The approved Hero palette becomes the Customer semantic palette rather than remaining a one-off treatment:

| Role | Value | Usage |
|---|---|---|
| Primary text | sRGB `#333333` | Global primary text, including Customer and Groomer content. |
| Customer accent | Display P3 `#93CEC2` | Primary Customer fills and default accent surfaces. |
| Customer accent soft | Display P3 `#B0D8D9` | Customer gradients and quiet filled states. |
| Customer accent subtle | Display P3 `#B5DCD9` | Decorative or low-emphasis Customer surfaces. |
| Customer accent strong | Display P3 `#518B7F` | Customer tint, progress, selected borders, and meaningful icons. |
| Surface | sRGB `#FFFFFF` | Cards, controls, and raised surfaces. |
| App background | sRGB `#FAF7F2` | Existing warm off-white page background. |

- Customer primary buttons use the accent-to-soft gradient with `#333333` text. Pressed presentation may reverse or darken the gradient without introducing another raw color.
- Customer secondary actions, progress, selected outlines, and meaningful icons use the strong accent when they require more definition than the default fill.
- Low-emphasis fills derive opacity from accent or use the soft/subtle roles; feature code does not recreate raw P3 values.
- Existing `customerPrimary` and `customerPrimaryDark` names remain temporary compatibility aliases while shared primitives migrate to the new semantic roles.
- Groomer coral roles, success/warning/error roles, notification red, white surfaces, warm background, borders, and secondary/tertiary text remain unchanged.
- Hero-specific background names may alias the new Customer palette roles so the approved Hero does not duplicate values.

## Behavior And Accessibility

- No navigation, Store, repository, persistence, Supabase, or backend behavior changes.
- Preserve a minimum 44pt action target and the existing `customer.home.start-request` identifier.
- Keep the hero content flexible through natural wrapping and no fixed height.
- Validate every changed foreground/background pair. `#333333` on the darkest Hero mint is 7.06:1; meaningful strong-accent graphics on white must remain at least 3:1.
- Human review owns visual approval; automated validation covers token contrast, copy contract, tests, and compilation.
