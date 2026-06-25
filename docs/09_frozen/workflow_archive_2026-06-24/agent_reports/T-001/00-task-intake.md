# Task Intake

Task ID: `T-001`

Date: 2026-06-19

## User Request

Create the fresh iOS 18 SwiftUI project baseline described in the approved T-001 plan, then stop for further instructions.

## Primary Task

Create a buildable and testable native Xcode project with explicit app-entry routing, customer and groomer tab shells, minimal design tokens, and preview/test-only fixtures.

## Out of Scope

- Supabase dependencies, configuration, schema, migrations, or remote operations.
- Authentication implementation or production data flows.
- Request, offer, booking, chat, review, or profile business logic.
- Runtime demo mode or fake backend success.
- Git commit, push, or pull request creation.

## Expected Output

- Native `PetGroomerMarketplace` Xcode project under `ios/`.
- App, unit-test, and UI-test targets for iOS 18.0.
- Build/test scripts configured with safe defaults and environment overrides.
- Durable project memory updated to describe the new baseline.

## Required Validation

- `./scripts/ios-build.sh`
- `./scripts/ios-test.sh`
- `./scripts/preflight.sh`
- `git diff --check`

## Stop Condition

Stop after T-001 validation, review, memory updates, and the final run report. Do not begin Supabase or authentication work.
