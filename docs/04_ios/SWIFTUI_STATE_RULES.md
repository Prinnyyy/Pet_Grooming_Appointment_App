# SwiftUI State Rules

## Principles

- Views render state.
- ViewModels coordinate UI state and actions.
- Repositories handle data boundaries.
- Business rules should not live in view layout code.

## State Checklist

For async actions:

- [ ] idle
- [ ] loading
- [ ] success
- [ ] error
- [ ] duplicate submit protection

## Rules

- Use `@State` for local view-only state.
- Use `@StateObject` for owned observable objects.
- Use `@ObservedObject` or environment injection for externally owned objects.
- Avoid global mutable state unless justified.

## Groomly UI Pass Rules

- Start Groomly UI work by extending shared `DesignSystem` tokens and primitives before restyling feature screens.
- Do not move repository calls, validation, duplicate-submit guards, or backend error mapping into SwiftUI layout code.
- Do not replace existing Stores or state owners just to match prototype screen structure.
- Preserve loading, empty, error, disabled, selected, and success states when restyling screens.
- Use semantic tokens instead of raw hex colors, hard-coded shadows, or magic spacing values in feature views.
- Keep role-specific state separate. Customer UI must not depend on groomer-only state, and groomer UI must not expose customer-private state before booking.
- If the Groomly prototype shows a state that current backend contracts do not support, document it as deferred instead of adding local fake success paths.
