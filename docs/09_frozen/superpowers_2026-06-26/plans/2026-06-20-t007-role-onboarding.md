# T-007 Role Onboarding and Authenticated Routing Implementation Plan

> **For agentic workers:** Execute inline in this workspace. Subagents are disabled for this repository. Track the checkbox steps in order and do not commit or push without a separate user instruction.

**Goal:** Let a real authenticated user create or load one immutable marketplace role and enter the corresponding Customer or Groomer shell.

**Architecture:** A `security invoker` Postgres RPC performs the shared-profile and role-marker inserts atomically under existing grants and RLS. A dedicated profile repository and `AuthenticatedEntryStore` keep Supabase out of SwiftUI views and keep profile state separate from Auth session state. Production routing remains session- and backend-driven; explicit routes remain preview/test-only composition points.

**Tech Stack:** PostgreSQL 17, Supabase CLI, Supabase Swift 2.46.0, Swift 6, SwiftUI, Observation, Swift Testing.

---

## File Structure

Create:

- `supabase/migrations/<mcp-version>_t007_create_my_profile.sql` — exact CLI-applied RPC migration mirror.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/MarketplaceProfile.swift` — minimal profile domain value.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/ProfileRepository.swift` — profile lookup/onboarding contract and safe domain errors.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseProfileRepository.swift` — sole PostgREST/RPC adapter.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticatedEntryStore.swift` — profile loading, form validation, submission, and role route state.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticatedEntryView.swift` — authenticated profile state switch.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/RoleOnboardingView.swift` — display-name and explicit-role form.
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticatedAccountView.swift` — minimal identity and sign-out destination.

Modify:

- `Core/Models/UserRole.swift` — string/Codable/Sendable database representation and display title.
- `App/AppComposition.swift` — build Auth and profile repositories from one client.
- `App/AppRootView.swift` — inject the profile repository into production Auth routing and inject explicit preview onboarding content without runtime fixtures.
- `App/PetGroomerMarketplaceApp.swift` — pass the profile repository.
- `Features/Auth/AuthenticationGateView.swift` — replace the T-006 stop point with `AuthenticatedEntryView`.
- `Features/Customer/CustomerTabView.swift` and `Features/Groomer/GroomerTabView.swift` — render the authenticated Account destination only when injected.
- `PetGroomerMarketplaceTests/AppEntryModelsTests.swift` — focused profile-entry state tests and repository fake.
- Backend/product/architecture/memory documents listed in Task 7 after validation.

Delete:

- `Features/Auth/OnboardingRequiredView.swift`.
- `Features/Auth/RoleOnboardingPlaceholderView.swift`.

The Xcode project uses filesystem-synchronized groups, so no `project.pbxproj` edit is planned.

### Task 1: Apply the reviewed onboarding RPC

**Files:**

- Create with `supabase migration new <name>`: `supabase/migrations/<mcp-version>_t007_create_my_profile.sql`

- [x] **Step 1: Obtain explicit approval for this exact remote migration**

Target only Supabase project `lqmasbuqzvcvtawonjlb`. Use migration name `t007_create_my_profile` and this exact SQL:

```sql
create function public.create_my_profile(
  p_role public.user_role,
  p_display_name text
)
returns table (
  id uuid,
  role public.user_role,
  display_name text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_display_name text := btrim(p_display_name);
  v_existing_role public.user_role;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_role is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_role';
  end if;

  if v_display_name is null
    or char_length(v_display_name) not between 1 and 80
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_display_name';
  end if;

  select profile.role
  into v_existing_role
  from public.profiles as profile
  where profile.id = v_user_id;

  if found and v_existing_role <> p_role then
    raise exception using
      errcode = 'P0001',
      message = 'profile_role_immutable';
  end if;

  insert into public.profiles (id, role, display_name)
  values (v_user_id, p_role, v_display_name)
  on conflict (id) do nothing;

  select profile.role
  into v_existing_role
  from public.profiles as profile
  where profile.id = v_user_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'profile_creation_failed';
  end if;

  if v_existing_role <> p_role then
    raise exception using
      errcode = 'P0001',
      message = 'profile_role_immutable';
  end if;

  case p_role
    when 'customer'::public.user_role then
      insert into public.customer_profiles (user_id)
      values (v_user_id)
      on conflict (user_id) do nothing;
    when 'groomer'::public.user_role then
      insert into public.groomer_profiles (user_id)
      values (v_user_id)
      on conflict (user_id) do nothing;
  end case;

  return query
  select profile.id, profile.role, profile.display_name
  from public.profiles as profile
  where profile.id = v_user_id;
end;
$$;

comment on function public.create_my_profile(public.user_role, text) is
  'Atomically creates the authenticated non-anonymous user profile and matching immutable role marker.';

revoke all on function public.create_my_profile(public.user_role, text)
from public, anon, authenticated;

grant execute on function public.create_my_profile(public.user_role, text)
to authenticated, service_role;
```

- [x] **Step 2: Apply once with Supabase CLI**

Call Supabase CLI `db push --linked` with the approved SQL. Do not use `supabase db query --linked` for DDL, the legacy ref, or a second migration attempt.

- [x] **Step 3: Mirror the exact applied migration**

Use the CLI-created migration filename in the local filename. The file content must be byte-for-byte the approved/applied SQL above; do not retain “draft” comments.

#### Execution checkpoint: corrective migration applied

The first rollback-only behavior validation stopped with PostgreSQL `42702`: the
`RETURNS TABLE` output variable `id` makes `on conflict (id)` ambiguous inside
PL/pgSQL. The test transaction left zero test users. Do not edit the applied
`20260620172839_t007_create_my_profile.sql` history. Apply one corrective
migration named `t007_fix_create_my_profile_conflict_target` was explicitly
approved and applied as `20260620180607`; the only behavioral change is using
the named primary-key constraint as the conflict target.

```sql
create or replace function public.create_my_profile(
  p_role public.user_role,
  p_display_name text
)
returns table (
  id uuid,
  role public.user_role,
  display_name text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_is_anonymous boolean := coalesce(
    ((select auth.jwt()) ->> 'is_anonymous')::boolean,
    false
  );
  v_display_name text := btrim(p_display_name);
  v_existing_role public.user_role;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'authenticated_user_required';
  end if;

  if p_role is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_role';
  end if;

  if v_display_name is null
    or char_length(v_display_name) not between 1 and 80
  then
    raise exception using
      errcode = '22023',
      message = 'invalid_display_name';
  end if;

  select profile.role
  into v_existing_role
  from public.profiles as profile
  where profile.id = v_user_id;

  if found and v_existing_role <> p_role then
    raise exception using
      errcode = 'P0001',
      message = 'profile_role_immutable';
  end if;

  insert into public.profiles (id, role, display_name)
  values (v_user_id, p_role, v_display_name)
  on conflict on constraint profiles_pkey do nothing;

  select profile.role
  into v_existing_role
  from public.profiles as profile
  where profile.id = v_user_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'profile_creation_failed';
  end if;

  if v_existing_role <> p_role then
    raise exception using
      errcode = 'P0001',
      message = 'profile_role_immutable';
  end if;

  case p_role
    when 'customer'::public.user_role then
      insert into public.customer_profiles (user_id)
      values (v_user_id)
      on conflict (user_id) do nothing;
    when 'groomer'::public.user_role then
      insert into public.groomer_profiles (user_id)
      values (v_user_id)
      on conflict (user_id) do nothing;
  end case;

  return query
  select profile.id, profile.role, profile.display_name
  from public.profiles as profile
  where profile.id = v_user_id;
end;
$$;
```

### Task 2: Add the profile domain and Supabase adapter

**Files:**

- Create the four `Core` files listed above.
- Modify `Core/Models/UserRole.swift`.

- [x] **Step 1: Define exact domain contracts**

```swift
nonisolated enum UserRole: String, CaseIterable, Identifiable, Codable, Sendable {
    case customer
    case groomer

    var id: Self { self }
    var title: String { self == .customer ? "Customer" : "Groomer" }
    var entryRoute: AppEntryRoute { self == .customer ? .customer : .groomer }
}

struct MarketplaceProfile: Equatable, Sendable {
    let userID: UUID
    let role: UserRole
    let displayName: String
}

enum ProfileRepositoryError: Error, Equatable, Sendable {
    case roleImmutable
    case networkUnavailable
    case unavailable
}

@MainActor
protocol ProfileRepository: AnyObject {
    func profile(userID: UUID) async throws -> MarketplaceProfile?
    func createProfile(role: UserRole, displayName: String) async throws -> MarketplaceProfile
}
```

- [x] **Step 2: Implement the Supabase adapter**

Use `client.from("profiles")` with `select("id,role,display_name")`, an explicit `eq("id", value: userID.uuidString)`, and `limit(1)`. Decode an array and treat an empty array as a valid missing profile.

Call:

```swift
let rows: [ProfileRow] = try await client
    .rpc(
        "create_my_profile",
        params: CreateProfileParameters(
            pRole: role,
            pDisplayName: displayName
        )
    )
    .execute()
    .value
```

The DTO coding keys must be `p_role`, `p_display_name`, and `display_name`. Require exactly one returned row. Map only `PostgrestError(code: "P0001", message: "profile_role_immutable")` to `.roleImmutable`; map recognized offline `URLError` cases to `.networkUnavailable`; map every other error to `.unavailable`. Never surface raw backend text.

### Task 3: Implement authenticated-entry state

**Files:**

- Create `Features/Auth/AuthenticatedEntryStore.swift`.
- Test in `PetGroomerMarketplaceTests/AppEntryModelsTests.swift`.

- [x] **Step 1: Add focused tests without intermediate Xcode runs**

Cover these exact outcomes with a `ProfileRepositoryFake`:

1. `nil` lookup enters `.onboarding`.
2. Customer and Groomer lookup enter `.customer(profile)` and `.groomer(profile)`.
3. Lookup failure enters `.failure` and retry calls the repository again.
4. Blank/over-80-character display name and missing role do not call create.
5. Successful create routes from the returned profile role, even if it differs from local form assumptions.
6. Failed create preserves normalized form state and selected role, clears `isSubmitting`, and allows retry.
7. A suspended first create plus a second submit results in one repository call.

- [x] **Step 2: Implement the Store state and operations**

```swift
enum AuthenticatedEntryState: Equatable {
    case loading
    case onboarding
    case customer(MarketplaceProfile)
    case groomer(MarketplaceProfile)
    case failure(message: String)
}

@MainActor
@Observable
final class AuthenticatedEntryStore {
    private let repository: any ProfileRepository
    private(set) var userID: UUID?
    var state: AuthenticatedEntryState = .loading
    var displayName = ""
    var selectedRole: UserRole?
    var isSubmitting = false
    var errorMessage: String?

    func load(userID: UUID) async
    func retry() async
    func submit() async
}
```

`load` must distinguish `nil` from failure. `submit` trims whitespace/newlines, requires 1–80 characters and an explicit role, ignores duplicates, retains form input on failure, and calls a single route helper using only the repository-returned `MarketplaceProfile`.

Use these safe messages:

- invalid display name: `Enter a display name between 1 and 80 characters.`
- missing role: `Choose Customer or Groomer to continue.`
- immutable role: `Your account role is already set and cannot be changed here.`
- network: `Check your connection and try again.`
- generic create: `We could not create your profile. Please try again.`
- generic load: `We could not load your profile. Please try again.`

### Task 4: Replace the signed-in stop point with real onboarding and routing

**Files:**

- Create the four `Features/Auth` views listed above.
- Modify `AppComposition.swift`, `AppRootView.swift`, `PetGroomerMarketplaceApp.swift`, `AuthenticationGateView.swift`, and both role Tab views.
- Delete both placeholder views.

- [x] **Step 1: Wire dependencies**

`AppComposition` must construct `SupabaseAuthSessionRepository` and `SupabaseProfileRepository` from the same `SupabaseClient`. Configuration failure sets both optional repositories and `authenticationStore` to `nil`.

`AuthenticationGateView` must receive `profileRepository`; its `.signedIn(session)` branch creates `AuthenticatedEntryView(session:authenticationStore:profileRepository:)`. Its existing `.task { await store.start() }` remains the only Auth-session observer.

- [x] **Step 2: Render the exact entry states**

`AuthenticatedEntryView` owns one `AuthenticatedEntryStore` for its signed-in subtree and calls `load(userID:)` once per session user ID. It renders:

- loading progress with `profile.loading`;
- `RoleOnboardingView` with `profile.onboarding`;
- Customer/Groomer tab shells with the authoritative profile;
- retry and sign-out actions with `profile.load-error`.

Sign-out continues through `AuthenticationStore.signOut()`; profile code must not manipulate Auth directly.

- [x] **Step 3: Build the onboarding form**

Use a `NavigationStack`, display-name `TextField`, two explicit role buttons with no default selection, immutable-role explanation, inline safe error, submit progress/button, and sign-out. Disable all mutable controls while submitting. Accessibility identifiers:

- `profile.display-name`
- `profile.role.customer`
- `profile.role.groomer`
- `profile.submit`
- `profile.error`
- `auth.sign-out`

- [x] **Step 4: Preserve Account sign-out after routing**

`AuthenticatedAccountView` shows profile display name, `role.title`, optional lowercased session email, Auth error text, and a destructive current-device sign-out button. Customer/Groomer tab views accept an optional injected account destination; when present, the Account tab renders it, while explicit shell previews without authenticated context retain the generic placeholder.

`AppRootView` keeps `.authentication` as production default. `.customer` and `.groomer` remain shell-only explicit routes. `.roleOnboarding` accepts an explicitly injected preview/test view; when none is supplied it renders a blocking bootstrap message instead of creating a runtime fake repository.

### Task 5: Verify backend behavior

- [x] **Step 1: Verify migration metadata and grants through Supabase CLI**

Confirm one `t007_create_my_profile` migration and inspect `pg_proc` privileges/security mode with read-only Supabase CLI SQL.

- [x] **Step 2: Run one rollback-only Supabase CLI SQL validation batch**

Within one transaction that always rolls back, create isolated Auth test identities and set `request.jwt.claims` per caller. Prove Customer and Groomer marker exclusivity, same-role idempotency/name preservation, exact different-role error, cross-user invisibility, and anonymous rejection. Raise an exception from the validation block on any failed assertion.

- [x] **Step 3: Run Supabase CLI advisors**

Run security and performance advisors once. Stop and report any new T-007 finding rather than iterating remote DDL.

### Task 6: Run the fixed validation budget

- [x] **Step 1: Run the static backend check**

Run `./scripts/supabase-check.sh`. Expected: exit 0.

- [x] **Step 2: Run the only Xcode validation attempt**

Run `./scripts/ios-test.sh`. Expected: all existing and new Swift Testing tests plus the launch UI smoke test pass with `** TEST SUCCEEDED **`.

If it fails, capture the first real compiler/test error and stop. Do not modify code and rerun without explicit follow-up approval.

- [x] **Step 3: Run lightweight diff checks**

Run `git diff --check`, `git diff --stat`, and inspect only the T-007 diff. Confirm no key/token, runtime fixture, service-role client secret, T-008 code, legacy project operation, direct Supabase call from a View, or unintended `project.pbxproj` change.

### Task 7: Synchronize documentation and durable memory

**Files:**

- Modify `docs/03_backend/SUPABASE_CONTRACT.md` and `docs/03_backend/RLS_RPC_POLICY.md` with the deployed RPC and verification result.
- Modify `docs/01_product/SCREEN_INVENTORY.md` and `docs/01_product/NAVIGATION_AND_FLOWS.md` to mark real onboarding/routing implemented and placeholders removed.
- Modify `docs/02_architecture/DATA_FLOW.md` to mark the authenticated profile entry flow implemented.
- Modify `docs/00_memory/CURRENT_STATE.md`, `FEATURE_INDEX.md`, and `WORKLOG.md`.
- Modify `docs/06_tasks/TASK_LEDGER.md` and `T-007_ROLE_ONBOARDING_AND_ROUTING.md` to completed only after all checks pass.

- [x] **Step 1: Record only verified state**

List the actual Supabase CLI migration version, backend checks/advisors, exact iOS test result/count, implemented routes, and next task T-008. Do not claim build/test success from planned work.

- [x] **Step 2: Stop**

Do not commit, push, start T-008, add detailed profiles, or create pet schema/code.

## Self-Review

- Spec coverage: RPC order, immutable-role precheck, same-role name preservation, placeholder cleanup, repository separation, authoritative routing, Account sign-out, error states, backend negatives, one Xcode attempt, and memory updates all have owning steps.
- Placeholder scan: the plan contains no TBD/TODO or unspecified implementation step.
- Type consistency: `UserRole`, `MarketplaceProfile`, `ProfileRepository`, `AuthenticatedEntryState`, and the RPC parameter/result names are consistent across backend, adapter, Store, UI, and tests.
- Scope: one T-007 primary task; no T-008 pet/profile-detail work; no subagents; no commit/push.
