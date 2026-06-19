# Module Boundaries

## Layers

| Layer | Allowed Responsibilities | Forbidden Responsibilities |
|---|---|---|
| View | Layout, user interaction, simple UI state | Backend calls, business rules |
| ViewModel/Coordinator | UI state, input validation, calling use cases | Direct database policy decisions |
| Use Case/Service | Business operations | UI layout |
| Repository | Data access boundary | UI state |
| Backend Adapter | Supabase/local implementation | Product decisions |

## Dependency Direction

Higher layers may depend on lower abstractions.

Lower layers must not import UI-specific logic.
