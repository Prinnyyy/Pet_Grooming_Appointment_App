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
