# T-001 — SwiftUI Baseline

## Status

Completed on 2026-06-19 from existing implementation and specification-review evidence.

## Objective

Create a fresh, buildable, and testable iOS 18 SwiftUI project with explicit role routing and customer/groomer tab shells.

## In Scope

- Native Xcode project named `PetGroomerMarketplace`.
- Swift 6 and minimum iOS 18.0.
- Authentication bootstrap as the real launch state.
- Customer and groomer tab shells reachable only by explicit route injection and previews.
- Minimal semantic design tokens.
- Unit and UI smoke tests.
- Build/test script and project-memory updates.

## Out of Scope

- Supabase and all third-party dependencies.
- Real authentication, persistence, networking, and business features.
- Runtime demo data or fake success paths.
- Commit, push, or pull request creation.

## Validation

```bash
./scripts/ios-build.sh
./scripts/ios-test.sh
./scripts/preflight.sh
git diff --check
```

## Stop Condition

After validation and memory updates, report results and wait for the next user instruction.
