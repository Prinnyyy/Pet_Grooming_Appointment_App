# Data Flow

## App Entry Flow

```text
App launch
→ Configuration loader
→ Auth session observer
→ Profile repository
→ App entry state
→ Authentication / Role Onboarding / Customer Tabs / Groomer Tabs
```

Configuration, session, and profile are separate states. Missing configuration is not treated as signed-out, and a signed-in user without a profile is not treated as a Customer or Groomer.

## Read Flow

```text
View appears or refreshes
→ ViewModel starts loading
→ Repository performs authorized query
→ DTOs map to domain/display state
→ ViewModel publishes content, empty, or error state
→ View renders
```

Queries must be scoped by the feature contract even when RLS also enforces ownership. RLS remains the security boundary.

## Simple Mutation Flow

Use direct repository-backed inserts/updates only for user-owned, non-critical records explicitly permitted by the backend contract, such as profile fields or pet details.

```text
User submits
→ Client validation
→ ViewModel enters submitting state
→ Repository mutation
→ Backend constraints and RLS
→ Refresh authoritative row
→ Render success or recoverable error
```

## Critical Mutation Flow

Request publication, matching, offer creation/withdrawal, offer acceptance, booking completion, and review creation require server-side operations when they cross records or enforce a transition.

```text
User action
→ ViewModel duplicate-submit guard
→ Repository calls RPC
→ RPC verifies auth, role, ownership, current status, and constraints
→ RPC commits atomically or returns an error
→ Repository refreshes affected records
→ ViewModel renders authoritative result
```

The UI must not apply a durable optimistic result for these operations before the backend commits.

## Upload Flow

```text
User selects image
→ Local draft and validation
→ Repository obtains authorized path contract
→ Storage upload under owner-scoped path
→ Metadata row creation/update
→ Repository refresh
→ Local draft released
```

If metadata creation fails after upload, the feature task must define cleanup or retry behavior. Production must not claim success from a local image alone.

## Local State

Allowed local state:

- Auth library session cache.
- Form and request-wizard drafts.
- Temporary upload data.
- Last selection and disposable UI cache.
- Preview/test fixtures outside production execution.

Server-owned profiles, pets after synchronization, requests, offers, bookings, messages, and reviews must be refreshed from the backend rather than maintained as parallel local fact stores.
