# T-001 iOS Code Map

Task ID: `T-001`

Agent: `ios_code_mapper`

Mode: `read-only investigation; this report is the only permitted write`

Date: `2026-06-19`

## Summary

- The repository has no existing Swift or Xcode project artifacts, so T-001 can create a genuinely fresh native baseline without importing old Swift code.
- Use one native project, one shared scheme, and three targets, all named from `PetGroomerMarketplace`.
- The production launch route must be authentication. Customer and groomer shells are reachable only through an explicitly injected `AppRoute`, including previews; normal UI must not expose role switching.
- No view model, repository, service, persistence, networking, runtime demo mode, or fake success path is needed for this baseline.

## 1. Entry Points

### Project and scheme

| Item | Exact mapping |
|---|---|
| Project | `ios/PetGroomerMarketplace.xcodeproj` |
| Shared scheme | `PetGroomerMarketplace` |
| Shared scheme file | `ios/PetGroomerMarketplace.xcodeproj/xcshareddata/xcschemes/PetGroomerMarketplace.xcscheme` |
| App target | `PetGroomerMarketplace` |
| Unit-test target | `PetGroomerMarketplaceTests` |
| UI-test target | `PetGroomerMarketplaceUITests` |
| Swift language mode | Swift 6 (`SWIFT_VERSION = 6.0`) |
| Minimum deployment | iOS 18.0 (`IPHONEOS_DEPLOYMENT_TARGET = 18.0`) |
| Dependencies | None |

The shared scheme should build the app target and include both test targets in its Test action. There should be no repository-level `.xcworkspace` in T-001.

### App entry and route model

Use these types and ownership rules:

```swift
enum AppRole: Equatable {
    case customer
    case groomer
}

enum AppRoute: Equatable {
    case authentication
    case main(role: AppRole)
}
```

`PetGroomerMarketplaceApp` is the sole production entry point and explicitly constructs:

```swift
AppRootView(route: .authentication)
```

`AppRootView` must require an `AppRoute` argument with no default. Its switch is exact:

| Route | Root content |
|---|---|
| `.authentication` | `AuthenticationBootstrapView` |
| `.main(role: .customer)` | `CustomerTabView` |
| `.main(role: .groomer)` | `GroomerTabView` |

Preview-only coverage should explicitly inject all three routes. Do not add launch-time role persistence, a debug role picker, launch-argument role overrides, a global mutable app model, or customer/groomer navigation buttons to the authentication screen.

## 2. Exact Directory and Target Map

```text
ios/
├── PetGroomerMarketplace.xcodeproj/
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/PetGroomerMarketplace.xcscheme
├── PetGroomerMarketplace/
│   ├── App/
│   │   ├── PetGroomerMarketplaceApp.swift
│   │   ├── AppRoute.swift
│   │   └── AppRootView.swift
│   ├── DesignSystem/
│   │   └── DesignTokens.swift
│   ├── Features/
│   │   ├── Auth/AuthenticationBootstrapView.swift
│   │   ├── Customer/CustomerTabView.swift
│   │   └── Groomer/GroomerTabView.swift
│   └── Resources/Assets.xcassets/
├── PetGroomerMarketplaceTests/
│   └── AppRouteTests.swift
└── PetGroomerMarketplaceUITests/
    └── PetGroomerMarketplaceUITests.swift
```

Target membership must be narrow:

| Files | Target membership |
|---|---|
| `ios/PetGroomerMarketplace/**` | App target only |
| `ios/PetGroomerMarketplaceTests/**` | Unit-test target only; test-host app target |
| `ios/PetGroomerMarketplaceUITests/**` | UI-test target only; target application is app target |

Use Xcode file-system-synchronized groups only if the generated `project.pbxproj` remains deterministic and all three target memberships are explicit. Otherwise use ordinary PBX groups and file references.

## 3. Tab and Route Mapping

Each role shell owns only its local selected-tab state with `@State`. Each tab gets its own `NavigationStack` so future feature navigation does not share a stack across tabs.

### Customer tabs

| Enum case | Label | SF Symbol | Initial |
|---|---|---|---|
| `.home` | Home | `house` | Yes |
| `.requests` | Requests | `list.bullet.clipboard` | No |
| `.bookings` | Bookings | `calendar` | No |
| `.messages` | Messages | `message` | No |
| `.account` | Account | `person.crop.circle` | No |

### Groomer tabs

| Enum case | Label | SF Symbol | Initial |
|---|---|---|---|
| `.requests` | Requests | `tray.full` | Yes |
| `.offers` | Offers | `tag` | No |
| `.bookings` | Bookings | `calendar` | No |
| `.messages` | Messages | `message` | No |
| `.account` | Account | `person.crop.circle` | No |

The five labels for each role come from the engineering brief's approved Main Tabs section. T-001 should render lightweight shell/placeholder content only; it must not implement request, offer, booking, message, account, or authentication behavior.

Recommended stable accessibility identifiers for smoke tests:

| Surface | Identifier |
|---|---|
| Authentication root | `auth.bootstrap` |
| Customer tab root | `customer.tabs` |
| Groomer tab root | `groomer.tabs` |

## 4. UI State Ownership

| State | Owner | T-001 behavior |
|---|---|---|
| Top-level `AppRoute` | App composition root | Immutable injected value; production value is `.authentication` |
| Selected customer tab | `CustomerTabView` | Local `@State`, initial `.home` |
| Selected groomer tab | `GroomerTabView` | Local `@State`, initial `.requests` |
| Authentication/session/profile state | None in T-001 | Deferred; do not simulate it |
| Feature/backend state | None in T-001 | Deferred; do not add view models or repositories |

This keeps SwiftUI views limited to rendering and local navigation state. Future authentication work can replace the composition-root input with a coordinator without changing the role shells.

## 5. Data Flow and Repository/Service Boundaries

T-001 has only a UI composition flow:

```text
PetGroomerMarketplaceApp
→ AppRootView(explicit AppRoute)
→ AuthenticationBootstrapView OR role TabView
→ selected placeholder tab content
```

There is no read or mutation flow, so creating empty repositories/services/view models adds no verified boundary. Do not create `AuthService`, API clients, Supabase adapters, persistence, production models, or a monolithic `AppModel` in this task. Those belong to later tasks when a real contract exists.

## 6. Design Token Boundary

`DesignTokens.swift` should contain only minimal semantic primitives used by the baseline, for example app background/surface colors, primary text color, standard spacing values, and a card corner radius. Keep them static and immutable. Do not introduce a theme manager, environment-wide mutable theme, custom font dependency, or broad component library.

## 7. Test Map

### Unit target: `PetGroomerMarketplaceTests`

`AppRouteTests.swift` should smoke-test the pure routing model without third-party view inspection:

1. Authentication is distinct from both role-main routes.
2. `.main(role: .customer)` retains the customer role.
3. `.main(role: .groomer)` retains the groomer role.

### UI target: `PetGroomerMarketplaceUITests`

Launch the app with no special arguments and assert:

1. `auth.bootstrap` exists.
2. `customer.tabs` does not exist.
3. `groomer.tabs` does not exist.

This validates the real launch state without adding a test backdoor into runtime route selection. Customer and groomer visual shells are verified by explicit SwiftUI previews and compilation in the app target.

## 8. Build/Test Verification Map

The scripts should stop discovering arbitrary projects/workspaces and use these safe defaults with environment overrides:

| Variable | Default |
|---|---|
| `CODEX_IOS_PROJECT` | `ios/PetGroomerMarketplace.xcodeproj` |
| `CODEX_IOS_SCHEME` | `PetGroomerMarketplace` |
| `CODEX_IOS_DESTINATION` | `platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro` |

Exact commands remain script-owned:

```text
./scripts/ios-build.sh
  → xcodebuild -project "$CODEX_IOS_PROJECT" -scheme "$CODEX_IOS_SCHEME" -destination "$CODEX_IOS_DESTINATION" build

./scripts/ios-test.sh
  → xcodebuild -project "$CODEX_IOS_PROJECT" -scheme "$CODEX_IOS_SCHEME" -destination "$CODEX_IOS_DESTINATION" test
```

Important script defect to fix during implementation: the current `find . -maxdepth 3 -name "*.xcworkspace"` matches the internal `PetGroomerMarketplace.xcodeproj/project.xcworkspace` and then incorrectly prefers it over the project. An explicit project path avoids that ambiguity.

Final T-001 validation order:

```text
./scripts/ios-build.sh
./scripts/ios-test.sh
./scripts/preflight.sh
git diff --check
```

## 9. Existing Workspace and Toolchain Findings

Read-only checks on 2026-06-19 found:

| Check | Result |
|---|---|
| Selected developer directory | `/Applications/Xcode.app/Contents/Developer` |
| Xcode | 26.5, build 17F42 |
| Swift | Apple Swift 6.3.2 |
| Installed iOS SDK | iOS / iOS Simulator 26.5 |
| Required baseline simulator | iPhone 16 Pro, iOS 18.4, available and shutdown |
| Additional available simulator runtime | iOS 26.5 |
| Existing `.swift` files | None |
| Existing `.xcodeproj` files | None |
| Existing `.xcworkspace` files | None |
| Existing `project.pbxproj` files | None |

The empty artifact search confirms there is no old Swift code, Xcode target, app entry point, test target, local `AppModel`, or migration-backed iOS implementation to preserve or import.

## 10. Files Likely to Edit in the Implementation Run

- Create only the `ios/` tree mapped above.
- Update `scripts/ios-build.sh` and `scripts/ios-test.sh` with the exact defaults above.
- After successful validation, update the T-001 task ledger and required durable memory files per `AGENTS.md`.

## 11. Files That Should Not Be Touched

- All Supabase/backend docs, migrations, schema, storage, policies, and remote resources.
- The uncommitted deletion of `Product_Architecture_Grooming_Request_Offers_Mode.md`.
- Existing user-authored `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`.
- Unrelated product and workflow docs.
- Any later feature implementation beyond the three root shells.

## 12. Likely Regression Risks

- Accidentally adding a role switcher or UI-test launch-argument router would make customer/groomer shells runtime-reachable outside the required explicit injection boundary.
- Letting project discovery select the internal `.xcodeproj/project.xcworkspace` can make script behavior differ across machines.
- Using an unqualified simulator name can select a newer runtime instead of exercising the iOS 18 baseline.
- Empty service/repository scaffolding can imply contracts that T-001 has not validated.
- The product and feature-index docs are still mostly TODO; tab names are supported by the engineering brief, but future tasks must promote approved product facts into durable memory.

## Recommendation to Main Agent

Implement exactly this isolated `ios/` baseline, keep production launch fixed to `.authentication`, configure the shared scheme and scripts before validation, and stop after T-001 checks and memory updates.

## Files Inspected

- `AGENTS.md`
- `docs/00_memory/PROJECT_MEMORY.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/06_tasks/T-001_SWIFTUI_BASELINE.md`
- `docs/02_architecture/ARCHITECTURE.md`
- `docs/02_architecture/MODULE_BOUNDARIES.md`
- `docs/02_architecture/DATA_FLOW.md`
- `docs/04_ios/SWIFT_STYLE_GUIDE.md`
- `docs/04_ios/SWIFTUI_STATE_RULES.md`
- `docs/04_ios/IOS_BUILD_AND_TESTING.md`
- `docs/01_product/PRODUCT_BRIEF.md`
- `docs/01_product/NAVIGATION_AND_FLOWS.md`
- `docs/01_product/SCREEN_INVENTORY.md`
- `docs/01_product/USER_ROLES.md`
- `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` (targeted relevant sections only)
- `scripts/ios-build.sh`
- `scripts/ios-test.sh`
- `scripts/preflight.sh`

## Files Changed

- `docs/05_workflow/agent_reports/T-001/02-ios-code-map.md` only.
