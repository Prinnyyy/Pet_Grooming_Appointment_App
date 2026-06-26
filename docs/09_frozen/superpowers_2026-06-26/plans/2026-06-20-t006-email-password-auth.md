# T-006 Email and Password Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Subagents are disabled for this repository.

**Goal:** Add real email/password authentication and session-driven root UI while stopping before profile/role onboarding.

**Architecture:** A main-actor `AuthenticationStore` owns root and form state. It depends on a token-free `AuthSessionRepository`; only `SupabaseAuthSessionRepository` imports Supabase Auth types. Root composition injects the Store and sends every authenticated user to an onboarding-required view until T-007.

**Tech Stack:** Swift 6, SwiftUI/Observation, Swift Testing, XCTest UI tests, Supabase Swift 2.46.0.

---

## File Structure

- Modify `Core/Repositories/AuthSessionRepository.swift`: token-free session, sign-up outcome, safe Auth error, and command protocol.
- Modify `Core/Infrastructure/Supabase/SupabaseAuthSessionRepository.swift`: Supabase Auth adapter and error mapping.
- Create `Features/Auth/AuthenticationStore.swift`: root state, form state, validation, operations, and event observation.
- Create `Features/Auth/AuthenticationView.swift`: Sign In/Create Account form.
- Create `Features/Auth/AuthenticationGateView.swift`: loading/signed-out/signed-in switch.
- Create `Features/Auth/OnboardingRequiredView.swift`: explicit T-007 boundary and sign-out.
- Modify `App/AppComposition.swift`, `App/AppRootView.swift`, and `App/PetGroomerMarketplaceApp.swift`: Store composition and injection.
- Retain `AuthenticationBootstrapView.swift` for blocking configuration failure; remove its obsolete ready copy from production flow.
- Modify unit/UI test files for focused store behavior and launch smoke coverage.
- Update task, architecture/product status, and durable memory after validation.

### Task 1: Expand the Auth repository contract

**Files:**
- Modify: `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/AuthSessionRepository.swift`
- Modify: `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseAuthSessionRepository.swift`

- [ ] **Step 1: Define token-free domain types and operations**

Use this contract:

```swift
struct AuthSessionSnapshot: Equatable, Sendable {
    let userID: UUID
    let email: String?
}

enum AuthSignUpOutcome: Equatable, Sendable {
    case signedIn(AuthSessionSnapshot)
    case confirmationRequired(email: String)
}

enum AuthSessionError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailNotConfirmed
    case weakPassword
    case rateLimited
    case networkUnavailable
    case unavailable
}

@MainActor
protocol AuthSessionRepository: AnyObject {
    func currentSession() -> AuthSessionSnapshot?
    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?>
    func signUp(email: String, password: String) async throws -> AuthSignUpOutcome
    func signIn(email: String, password: String) async throws -> AuthSessionSnapshot
    func signOut() async throws
}
```

- [ ] **Step 2: Implement Supabase mapping**

Map `Session.user.id/email` without exposing tokens. Call:

```swift
let response = try await client.auth.signUp(email: email, password: password)
if let session = response.session {
    return .signedIn(Self.snapshot(from: session))
}
return .confirmationRequired(email: response.user.email ?? email)
```

Use `client.auth.signIn(email:password:)` for sign-in and `client.auth.signOut(scope: .local)` for current-device sign-out. Map `AuthError.errorCode` values `invalidCredentials`, `emailNotConfirmed`, `weakPassword`, request/email rate limits, and `requestTimeout`; map offline `URLError` cases to `networkUnavailable`; map everything else to `unavailable`.

### Task 2: Add Store state and focused tests

**Files:**
- Create: `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationStore.swift`
- Modify: `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/AppEntryModelsTests.swift`

- [ ] **Step 1: Add tests before implementation**

Add a main-actor fake repository with configurable current session, sign-up/sign-in results, sign-out result, call counts, and a finished default stream. Add async Swift Testing cases equivalent to:

```swift
@Test @MainActor
func restoresExistingSession() async {
    let session = AuthSessionSnapshot(userID: UUID(), email: "user@example.com")
    let repository = AuthSessionRepositoryFake(currentSession: session)
    let store = AuthenticationStore(repository: repository)
    await store.start()
    #expect(store.rootState == .signedIn(session))
}

@Test @MainActor
func signUpConfirmationRemainsSignedOut() async {
    let repository = AuthSessionRepositoryFake()
    repository.signUpResult = .success(.confirmationRequired(email: "new@example.com"))
    let store = AuthenticationStore(repository: repository)
    store.mode = .signUp
    store.email = " NEW@EXAMPLE.COM "
    store.password = "password"
    store.passwordConfirmation = "password"
    await store.submit()
    #expect(store.rootState == .signedOut)
    #expect(store.noticeMessage == "Check your email to confirm your account, then sign in.")
    #expect(repository.lastEmail == "new@example.com")
}
```

Also cover absent-session bootstrap, invalid-credential recovery, local validation preventing a repository call, and sign-out returning to signed-out.

- [ ] **Step 2: Implement Store types and behavior**

Define:

```swift
enum AuthenticationRootState: Equatable {
    case loading
    case signedOut
    case signedIn(AuthSessionSnapshot)
}

enum AuthenticationMode: String, CaseIterable, Identifiable {
    case signIn = "Sign In"
    case signUp = "Create Account"
    var id: Self { self }
}

@MainActor @Observable
final class AuthenticationStore {
    private let repository: any AuthSessionRepository
    private var didStart = false

    var rootState: AuthenticationRootState = .loading
    var mode: AuthenticationMode = .signIn
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var isSubmitting = false
    var errorMessage: String?
    var noticeMessage: String?
}
```

`start()` must set the cached session state, obtain the async stream, and apply every later session event. `submit()` must normalize email, validate email/password/confirmation, ignore duplicate calls, call the selected repository method, clear secret fields after success, and translate `AuthSessionError` into user-safe text. Require at least eight password characters. `signOut()` must use the same duplicate guard and return to signed-out only after the repository succeeds.

### Task 3: Build the Auth UI and root routing

**Files:**
- Create: `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationView.swift`
- Create: `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationGateView.swift`
- Create: `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/OnboardingRequiredView.swift`
- Modify: `ios/PetGroomerMarketplace/PetGroomerMarketplace/App/AppComposition.swift`
- Modify: `ios/PetGroomerMarketplace/PetGroomerMarketplace/App/AppRootView.swift`
- Modify: `ios/PetGroomerMarketplace/PetGroomerMarketplace/App/PetGroomerMarketplaceApp.swift`
- Modify: `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationBootstrapView.swift`

- [ ] **Step 1: Compose and inject the Store**

`AppComposition` creates one repository and one `AuthenticationStore` only when configuration is valid. `PetGroomerMarketplaceApp` passes the optional Store to `AppRootView`. `.authentication` renders the blocking configuration view when the Store is absent and otherwise renders `AuthenticationGateView`.

- [ ] **Step 2: Implement the gate and form**

`AuthenticationGateView` switches over Store root state:

```swift
switch store.rootState {
case .loading:
    ProgressView("Restoring session…")
case .signedOut:
    AuthenticationView(store: store)
case let .signedIn(session):
    OnboardingRequiredView(session: session, store: store)
}
```

Attach `.task { await store.start() }` once at the gate. The form uses a segmented Picker, email `TextField`, secure password fields, inline notice/error text, and one async submit button. Use accessibility identifiers `auth.form`, `auth.email`, `auth.password`, `auth.password-confirmation`, `auth.submit`, `auth.notice`, and `auth.error`.

- [ ] **Step 3: Implement the authenticated stop point**

`OnboardingRequiredView` states that role setup is required, may show the session email, and exposes a sign-out button with `auth.sign-out`. It must not query/create profiles or show Customer/Groomer tabs.

### Task 4: Update smoke coverage, validate once, and close T-006

**Files:**
- Modify: `ios/PetGroomerMarketplace/PetGroomerMarketplaceUITests/AppLaunchSmokeTests.swift`
- Modify: `docs/01_product/SCREEN_INVENTORY.md`
- Modify: `docs/01_product/NAVIGATION_AND_FLOWS.md`
- Modify: `docs/02_architecture/DATA_FLOW.md`
- Modify: `docs/00_memory/CURRENT_STATE.md`
- Modify: `docs/00_memory/FEATURE_INDEX.md`
- Modify: `docs/00_memory/WORKLOG.md`
- Modify: `docs/06_tasks/TASK_LEDGER.md`
- Modify: `docs/06_tasks/T-006_EMAIL_PASSWORD_AUTHENTICATION.md`

- [ ] **Step 1: Update launch smoke expectation**

Normal configured launch must wait for `auth.form`, while asserting `customer.tabs` and `groomer.tabs` do not exist. Configuration failure remains separately identifiable as `auth.bootstrap.configuration-error`.

- [ ] **Step 2: Run the single Xcode validation attempt**

Run:

```bash
./scripts/ios-test.sh
```

Expected: app/test targets compile; focused Auth store tests, existing route/tab tests, and UI launch smoke pass. If it fails, report the first real error and stop without editing or rerunning.

- [ ] **Step 3: Review and update memory**

Run `git diff --check`, review only the T-006 diff, scan for tokens/password logging and profile writes, mark T-006 completed only if validation passed, recommend T-007, and stop without commit or push.
