# Architecture

## Target Architecture

TODO: Fill with actual architecture after project inspection.

Recommended default:

```text
SwiftUI Views
↓
View Models / UI State Coordinators
↓
Use Cases / Domain Services
↓
Repositories
↓
Backend Adapters / Local Demo Adapters
↓
Supabase or local data
```

## Rules

- Views should not own business rules.
- Views should not directly call Supabase.
- Repositories should hide backend implementation details.
- Domain models should not be shaped only by UI convenience.
- Local demo mode must remain intentionally separate from production backend behavior.

## Update Policy

Update this file whenever:
- A new module is added.
- A new data boundary is introduced.
- A major flow changes.
- Backend/client responsibilities change.
