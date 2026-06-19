# Data Flow

## Read Flow

```text
View -> ViewModel -> Repository -> Backend/Local Adapter -> Repository -> ViewModel -> View
```

## Mutation Flow

```text
View action -> ViewModel validation -> Use Case/Repository -> Backend RPC or local equivalent -> state refresh -> UI result
```

## Rules

- Do not mutate production backend state directly from views.
- Prefer explicit refresh after important mutations.
- Do not fake success in production backend mode.
- Keep local demo data clearly marked.
