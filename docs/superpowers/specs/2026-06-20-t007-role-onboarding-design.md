# T-007 Role Onboarding and Authenticated Routing Design

## Status

Approved in conversation and revised after external review on 2026-06-20. The revised written spec awaits confirmation before implementation planning.

## Goal

Complete the authenticated entry path. A signed-in user with no marketplace profile must enter a display name, choose Customer or Groomer, create the shared and role-specific profile records safely, and enter the existing role Tab shell. A returning user must route from authoritative backend profile data without choosing a role again.

## Scope

In scope:

- Require a trimmed display name of 1–80 characters.
- Require an explicit Customer or Groomer selection; do not preselect a role.
- Load the signed-in user's profile through a repository boundary.
- Create `profiles` and the corresponding `customer_profiles` or `groomer_profiles` marker atomically.
- Make same-role retries idempotent and reject role changes.
- Route completed Customer and Groomer profiles to their existing Tab shells.
- Preserve a minimal authenticated Account destination with display name, role, email when available, and current-device sign-out.
- Provide loading, empty, validation, submission, retryable load/write error, and session-loss behavior.
- Add focused state tests and validate the deployed RPC and RLS boundary.

Out of scope:

- Avatar upload or profile editing.
- Customer details, pet creation, or grooming requests.
- Groomer business details, services, portfolio, or availability.
- Role switching, administrative correction UI, account deletion, or privileged repair tools.
- Runtime demo data, test launch shortcuts that fabricate a profile, or offline profile persistence.
- Changes to Auth provider settings or the legacy Supabase project.

## Selected Approach

Use one Postgres RPC named `create_my_profile`. A direct two-request client sequence was rejected because the shared profile could commit while the role marker fails. A trigger was rejected because it hides an important product transition behind a table side effect. The RPC keeps the operation explicit, transactional, testable, and callable through the existing repository boundary.

## Backend Contract

`create_my_profile` accepts:

- `p_role public.user_role`
- `p_display_name text`

It returns the authenticated user's `id`, immutable `role`, and normalized `display_name`.

The function must:

1. Run as `security invoker` with an empty `search_path`, using schema-qualified objects.
2. Require a non-null `auth.uid()` and reject anonymous identities.
3. Normalize with `btrim` and validate the normalized display name against the deployed 1–80 character contract before inserting it.
4. Explicitly read any existing profile role before attempting a role-marker insert. If it differs from `p_role`, raise the stable error contract `P0001` / `profile_role_immutable` without relying on an RLS failure.
5. Insert the caller's `profiles` row without allowing a caller-supplied user ID. A conflict-safe insert followed by an authoritative role recheck must also handle concurrent onboarding calls before continuing.
6. Insert the matching role marker only after the matching `profiles` row exists, using conflict-safe same-role retry behavior.
7. Return the authoritative profile after both records are valid.
8. On a same-role retry, retain and return the originally stored `display_name`; onboarding retry never acts as profile editing.

The shared `profiles` insert must occur before the role-marker insert, in the same function transaction. This order is not interchangeable: the deployed marker `WITH CHECK` policies require an already-visible matching `profiles.role` for `auth.uid()`. PostgreSQL makes the earlier uncommitted row visible to the later statement in the same transaction; a failed marker insert rolls the whole operation back.

Existing RLS and column grants remain active because the function uses invoker rights. Execute permission is revoked from `PUBLIC` and `anon`, then granted only to `authenticated` and `service_role`. No table RLS policy is weakened. The iOS repository maps only the exact `P0001` / `profile_role_immutable` pair to its immutable-role domain error; unrelated PostgREST and RLS errors remain generic safe failures.

This RPC is a T-007 contract addition. The migration is not deployed until its exact SQL is reviewed and explicitly authorized for MCP `apply_migration` against `lqmasbuqzvcvtawonjlb`.

## iOS Architecture

Add a profile boundary independent of Auth:

- `MarketplaceProfile`: user ID, `UserRole`, and display name only.
- `ProfileRepository`: load the current user's profile and complete onboarding.
- `SupabaseProfileRepository`: the only adapter that calls PostgREST tables or `create_my_profile`.
- `AuthenticatedEntryStore`: owns profile loading, onboarding form state, profile submission, and role routing.
- `RoleOnboardingView`: renders the form and delegates all operations to the Store.
- `AuthenticatedEntryView`: switches over Store state and composes onboarding, role shells, or retry UI.

`AuthenticationStore` remains responsible only for Auth session state and sign-out. `AppComposition` creates both repositories from the same configured `SupabaseClient`. SwiftUI views do not import or call Supabase directly.

The role Tab shells remain explicit routes for previews and tests. Production reaches them only through a real authenticated session plus a successfully loaded or created marketplace profile.

T-007 replaces the T-006 signed-in stop point rather than layering another screen on top of it:

- `AuthenticationGateView` changes its `.signedIn` branch from `OnboardingRequiredView` to `AuthenticatedEntryView`.
- `OnboardingRequiredView.swift` is removed because its sign-out and setup messaging move into the real authenticated entry/onboarding flow.
- `RoleOnboardingPlaceholderView.swift` is removed and its explicit `.roleOnboarding` composition is replaced by the real `RoleOnboardingView` with injected dependencies.
- `AppEntryRoute.roleOnboarding`, `.customer`, and `.groomer` remain explicit preview/test routes. Production launch continues through `.authentication` and Store-owned state only; preview/test fixtures never enter the production path.

## Authenticated Entry State

The Store exposes one explicit state:

- `loading`: profile status is unknown.
- `onboarding`: no profile exists and role setup is required.
- `customer(MarketplaceProfile)`: route to Customer tabs.
- `groomer(MarketplaceProfile)`: route to Groomer tabs.
- `failure(message)`: profile lookup failed and must not be treated as a missing profile.

At authenticated entry, load the profile using the session user ID as an additional narrow query filter. An empty successful result enters onboarding. A decoded Customer or Groomer profile routes immediately. A permission, decoding, network, or backend failure displays retry and sign-out actions.

Session expiry or sign-out remains authoritative: when `AuthenticationStore` returns to signed out, the authenticated entry subtree and its profile state are removed.

## Onboarding UI

The screen contains:

- a required display-name field;
- two explicit role choices: “I am a pet owner” and “I am a groomer”;
- a short statement that the role cannot be changed through the normal app;
- one submit button;
- inline validation and backend error text;
- current-device sign-out.

The role starts unselected. Submission trims the display name, validates 1–80 characters, requires a role, ignores duplicate taps, and disables mutable controls while the request is in flight. A failed write preserves both inputs and re-enables submission. A successful RPC result, not optimistic local state, selects the role route.

No avatar, pet, business, service, portfolio, or location field appears in T-007.

## Account and Sign-Out Continuity

Routing into a Tab shell must not remove the T-006 sign-out capability. The Account tab receives a minimal authenticated destination showing the loaded display name, role, optional session email, and a sign-out button. It does not edit profile data and does not become the later full Account feature.

The other role tabs remain the existing placeholders. T-007 does not implement their product features.

## Error Handling

- Profile lookup failure shows a generic safe message plus Retry and Sign Out. It never shows onboarding based on an unknown result.
- Invalid local input never calls the repository.
- Duplicate onboarding submissions are ignored.
- Network or backend failure preserves display name and selected role.
- A same-role retry after an uncertain client response succeeds idempotently and returns the stored profile.
- A same-role retry with a different submitted display name returns the original stored name and does not perform an update.
- A different-role retry is prechecked before marker insertion, returns `P0001` / `profile_role_immutable`, maps to a clear immutable-role message, and does not route optimistically.
- Raw PostgREST payloads, JWTs, keys, database internals, and unrestricted server error text never enter UI state or logs.

## Validation

Focused Store tests cover:

- missing profile enters onboarding;
- existing Customer and Groomer profiles enter their exact routes;
- profile lookup failure is retryable and is not treated as missing;
- local validation prevents repository calls;
- successful profile creation routes from the returned authoritative role;
- failed creation preserves form state and allows retry;
- duplicate submission protection.

Backend validation uses rollback-only MCP SQL to prove:

- Customer creation produces only the caller's shared and Customer marker rows;
- Groomer creation produces only the caller's shared and Groomer marker rows;
- same-role retry is idempotent;
- same-role retry does not update the stored display name;
- different-role retry returns the documented stable error and is rejected without mutation or an opaque RLS failure;
- another authenticated identity cannot read or mutate the created rows;
- anonymous execution is unavailable;
- security and performance advisors remain clean or report only reviewed unrelated notices.

After static `./scripts/supabase-check.sh`, use one Xcode validation attempt: `./scripts/ios-test.sh`. It compiles the app and runs the focused Store tests plus the existing launch smoke test. If it fails, report the first real error and stop without a build-fix loop. Lightweight `git diff --check` and scope review follow only after validation succeeds.

## Documentation and State Updates

After successful implementation, update the backend contract and RLS/RPC policy with the deployed function, update screen/navigation/data-flow documents to mark onboarding and real role routing implemented, and update `CURRENT_STATE`, `FEATURE_INDEX`, `WORKLOG`, and `TASK_LEDGER`.

## Stop Condition

Stop when the reviewed RPC is deployed and mirrored, profile onboarding and authenticated routing work through repositories, focused validation passes, and T-007 durable state is recorded. Do not implement T-008 pets or any detailed profile feature.
