# Feature Index

This file maps features to docs and source files.

Codex should use this file to find relevant context without loading the full repository.

| Feature | Product Docs | Architecture Docs | Backend Docs | iOS Files | Status | Notes |
|---|---|---|---|---|---|---|
| App entry routing | `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` | `docs/02_architecture/ARCHITECTURE.md` | None | `ios/PetGroomerMarketplace/PetGroomerMarketplace/App/`, `Core/Models/` | baseline complete | Production defaults to authentication; customer/groomer routes are explicit |
| Authentication bootstrap | `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` | `docs/02_architecture/ARCHITECTURE.md` | Planned | `Features/Auth/` | placeholder complete | No real authentication or role onboarding yet |
| Customer tab shell | `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` | `docs/01_product/NAVIGATION_AND_FLOWS.md` | None | `Features/Customer/` | baseline complete | Home, Requests, Bookings, Messages, Account |
| Groomer tab shell | `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` | `docs/01_product/NAVIGATION_AND_FLOWS.md` | None | `Features/Groomer/` | baseline complete | Requests, Offers, Bookings, Messages, Account |
| Baseline design tokens | `docs/01_product/DESIGN_SYSTEM.md` | `docs/02_architecture/ARCHITECTURE.md` | None | `DesignSystem/` | baseline complete | Minimal semantic colors, spacing, and corner radius |
| iOS build/test harness | `docs/04_ios/IOS_BUILD_AND_TESTING.md` | None | None | `scripts/ios-build.sh`, `scripts/ios-test.sh`, unit/UI test targets | complete | Existing reports record build, 4 unit tests, 1 UI smoke test, and preflight passing |
