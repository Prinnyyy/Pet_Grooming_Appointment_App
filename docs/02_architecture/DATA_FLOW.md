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

T-006 implements configuration plus Auth session restoration/observation. T-007 adds the separate profile repository and authenticated-entry Store: a successful empty lookup enters onboarding, a loaded or RPC-created profile selects its authoritative role shell, and a lookup failure remains a retryable failure rather than being mistaken for a missing profile.

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

## Address Confirmation Flow

This section, `../03_backend/RLS_RPC_POLICY.md`, and `../04_ios/ADDRESS_BACKFILL.md` are the current address and matching contract. Completed migration sequencing is historical evidence, not an active implementation source.

```text
Address Line 1 / Address Line 2 input
-> shared field-semantics parser
-> Apple Maps autocomplete or one manual geocode
-> entered-versus-suggested user confirmation
-> owner-checked persistence of display fields plus private coordinate metadata
-> PostGIS distance calculation
-> Customer travel radius or Groomer service radius eligibility
```

Localized address text is display data. After strict cutover, coordinates and the controlling radius are the only location-matching authority. Apple Maps confirmation must not be represented as postal deliverability validation.

Customer Profile, Groomer Profile, and Customer Request use this shared editor. Profiles save through owner-scoped v2 persistence; Requests require current confirmation before leaving Time & Location and publish display fields, Line 2, and private coordinate metadata atomically through `create_grooming_request_v2`. Profile autofill retains confirmation only when every address field still matches its metadata, while republished templates always return to address review. Groomer pre-booking Request models do not receive Line 2. Unchanged legacy profile addresses can still save unrelated fields until controlled backfill.

T-299's macOS-only controlled backfill resolves complete legacy snapshots without changing display fields, writes through service-only snapshot-checked atomic batches, and records only redacted support refs/fingerprints. All Groomers and active Requests are coordinate-backed; one Customer Profile ZIP conflict is a reviewed exception and cannot create a coordinate-null Request under the current publication contract.
