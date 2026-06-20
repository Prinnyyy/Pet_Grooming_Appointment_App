# Architecture

## Current Baseline

T-001 provides a SwiftUI application with explicit `AppEntryRoute`, Customer/Groomer tab shells, feature-first folders, semantic design tokens, and test targets. Production always enters the authentication bootstrap. There is no backend client, persistence, repository, view model, or product workflow yet.

## Target Architecture

```text
SwiftUI View
→ Feature ViewModel / State Coordinator
→ Repository Protocol
→ Supabase-backed Repository
→ Supabase Auth / Postgres RPC or Data API / Storage
```

Cross-record business transitions terminate in backend RPCs:

```text
View action
→ ViewModel validation and submission state
→ Repository RPC call
→ Backend authorization, constraints, and transaction
→ Typed result
→ Repository refresh
→ Updated UI state
```

## Responsibilities

### Views

- Layout, user input, accessibility, navigation, and rendering state.
- No Supabase calls, authorization decisions, persistence, or booking/offer rules.

### ViewModels / State Coordinators

- Screen state, input validation, cancellation, duplicate-submit protection, repository calls, and user-safe error mapping.
- No direct database policies or client-side recreation of atomic backend transitions.

### Repositories

- Typed feature-facing data operations, RPC invocation, DTO/domain mapping, and refresh behavior.
- Hide Supabase query and Storage details from views and view models.

### Infrastructure

- Supabase client composition, safe environment configuration, Auth session observation, API/Storage adapters, and sanitized diagnostics.
- No product decisions or UI state.

### Backend

- Identity, RLS, grants, constraints, server validation, request matching, offer limits, booking uniqueness/conflict protection, review eligibility, and Storage access control.

## Feature Organization

New product code belongs in focused feature folders such as Auth, Onboarding, Pets, Requests, Offers, Bookings, Chat, Reviews, and Account. Shared infrastructure belongs under Core/Services/Repositories only when two or more features need the same boundary.

Avoid:

- A monolithic global application model that stores server data as local truth.
- One repository containing unrelated feature operations.
- Domain types shaped only for one screen.
- Runtime fixture adapters or silent fallback from Supabase to local data.

## Source of Truth

- Supabase Auth is authoritative for session identity.
- Postgres is authoritative for profiles, pets after sync, requests, matches, offers, bookings, conversations, messages, and reviews.
- Storage metadata and object policies are authoritative for uploaded media.
- Local state is limited to session cache provided by the Auth client, unsent form drafts, temporary image data, selection, and disposable UI cache.

## Security Boundary

The iOS app uses a publishable client key and never a service-role or secret key. RLS and explicit grants protect exposed data. Critical state transitions use narrowly granted RPCs and backend constraints; hiding a UI control is not authorization.

## Update Policy

Update this file when a new layer, shared service, repository boundary, source-of-truth rule, or major navigation/data flow is introduced.
