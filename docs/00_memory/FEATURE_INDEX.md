# Feature Index

Use this index to locate only the context needed for one active task. The Fresh Brief is canonical; active working summaries live under `docs/01_product`, architecture under `docs/02_architecture`, and planned backend contracts under `docs/03_backend`.

| Feature | Product Docs | Architecture Docs | Backend Docs | iOS Area | Status | Roadmap |
|---|---|---|---|---|---|---|
| App entry and role shells | `NAVIGATION_AND_FLOWS.md`, `USER_ROLES.md` | `ARCHITECTURE.md` | None | `App/`, `Core/Models/`, Customer/Groomer tab files | baseline complete | T-001 |
| Design tokens and placeholder component | `DESIGN_SYSTEM.md` | `ARCHITECTURE.md` | None | `DesignSystem/` | baseline complete | T-001 |
| Authentication and role onboarding | `PRODUCT_BRIEF.md`, `NAVIGATION_AND_FLOWS.md`, `SCREEN_INVENTORY.md` | `ARCHITECTURE.md`, `DATA_FLOW.md`, `ERROR_HANDLING.md` | `SUPABASE_CONTRACT.md`, `RLS_RPC_POLICY.md` | `App/AppComposition.swift`, `Core/Configuration/`, `Core/Infrastructure/Supabase/`, `Core/Repositories/AuthSessionRepository.swift`, `Features/Auth/` | profile/avatar backend and client/session infrastructure complete; Auth UI not implemented | T-004–T-007 |
| Customer pets and photos | `SCREEN_INVENTORY.md`, `UX_RULES.md` | `DATA_FLOW.md`, `MODULE_BOUNDARIES.md` | `SUPABASE_CONTRACT.md`, `STORAGE_POLICY.md`, `RLS_RPC_POLICY.md` | planned `Features/Pets/` | planned | T-008–T-009 |
| Groomer profile, services, and portfolio | `USER_ROLES.md`, `SCREEN_INVENTORY.md` | `MODULE_BOUNDARIES.md` | `SUPABASE_CONTRACT.md`, `STORAGE_POLICY.md`, `RLS_RPC_POLICY.md` | planned Groomer profile feature | planned | T-010–T-011 |
| Grooming requests and matching | `PRODUCT_BRIEF.md`, `NAVIGATION_AND_FLOWS.md`, `UX_RULES.md` | `DATA_FLOW.md`, `MODULE_BOUNDARIES.md` | `SUPABASE_CONTRACT.md`, `RLS_RPC_POLICY.md` | planned `Features/Requests/` | planned | T-012–T-014 |
| Groomer offers and customer review | `NAVIGATION_AND_FLOWS.md`, `SCREEN_INVENTORY.md`, `UX_RULES.md` | `DATA_FLOW.md`, `ERROR_HANDLING.md` | `SUPABASE_CONTRACT.md`, `RLS_RPC_POLICY.md` | planned `Features/Offers/` | planned | T-015–T-017 |
| Offer acceptance and bookings | `PRODUCT_BRIEF.md`, `NAVIGATION_AND_FLOWS.md`, `UX_RULES.md` | `DATA_FLOW.md`, `ERROR_HANDLING.md` | `SUPABASE_CONTRACT.md`, `RLS_RPC_POLICY.md` | planned `Features/Bookings/` | planned | T-018–T-019 |
| Participant chat | `SCREEN_INVENTORY.md`, `UX_RULES.md` | `DATA_FLOW.md`, `MODULE_BOUNDARIES.md` | `SUPABASE_CONTRACT.md`, `STORAGE_POLICY.md`, `RLS_RPC_POLICY.md` | planned `Features/Chat/` | planned | T-020 |
| Completion and reviews | `PRODUCT_BRIEF.md`, `SCREEN_INVENTORY.md` | `DATA_FLOW.md`, `ERROR_HANDLING.md` | `SUPABASE_CONTRACT.md`, `RLS_RPC_POLICY.md` | planned `Features/Reviews/` | planned | T-021 |
| Diagnostics and MVP hardening | `UX_RULES.md`, `SCREEN_INVENTORY.md`, `DESIGN_SYSTEM.md` | `ERROR_HANDLING.md`, `PREVIEW_AND_TEST_FIXTURES.md` | all backend policy docs | planned Debug feature and test targets | planned | T-022 |
| iOS build/test harness | None | None | None | `scripts/ios-build.sh`, `scripts/ios-test.sh`, unit/UI test targets | complete | T-001 |
