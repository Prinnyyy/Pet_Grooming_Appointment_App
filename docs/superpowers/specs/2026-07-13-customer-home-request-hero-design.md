# Customer Home Request Hero Design

## Scope

Refresh the existing Customer Home request CTA to follow the supplied Beckon reference while preserving its current action, disabled state, accessibility identifier, Store ownership, and Request Wizard presentation.

## Visual Contract

- Keep the existing light mint customer brand background.
- Match the supplied Display P3 `#93CEC2` to `#B0D8D9` light mint background and white title/supporting copy without converting the source into lower-saturation sRGB values.
- Let `Need grooming for your pet?` wrap naturally within the same content width as the action; do not embed a manual newline.
- Present `Start Grooming Request` as a compact white action with a scissors SF Symbol and sampled Display P3 `#518B7F` foreground, aligned to the copy's leading edge.
- Use the reference-calibrated rounded typography: 21pt bold title, 13pt regular supporting copy, and 15pt bold action.
- Keep the approximately 110pt top-right circle and diagonal bottom-right paw decoration inside the hero bounds and away from interactive content.
- Preserve the disabled requirement message and make disabled action styling visibly distinct.

## Shared Color Contract

- Keep `customerPrimary`, `customerPrimaryDark`, `groomerAccent`, and `groomerAccentDark` unchanged.
- Replace the single black primary-button foreground with separate customer and groomer semantic foreground tokens.
- Each role foreground remains a deep role color rather than black and is validated independently from the screenshot-specific Hero treatment.
- Existing primary button call sites inherit the role-specific foreground automatically through `BeckonPrimaryButtonStyle.Accent`.

## Behavior And Accessibility

- No navigation, Store, repository, persistence, Supabase, or backend behavior changes.
- Preserve a minimum 44pt action target and the existing `customer.home.start-request` identifier.
- Keep the hero content flexible through natural wrapping and no fixed height. Color-accessibility remediation for this screenshot-specific Hero is deferred by user direction.
- Human review owns visual approval; automated validation covers token contrast, copy contract, tests, and compilation.
