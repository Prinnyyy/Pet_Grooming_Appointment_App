# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pet Groomer Marketplace is an iOS marketplace app where a pet owner publishes one open grooming request, matched independent groomers submit offers, and the owner confirms one offer to create a booking. The canonical product source is `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`.

## Commands

```bash
# Build (iPhone 16 Pro / iOS 18.4 Simulator)
./scripts/ios-build.sh

# Run all tests (Swift Testing + XCTest UI)
./scripts/ios-test.sh

# Static checks: git status, required docs, secret scan
./scripts/preflight.sh

# Supabase contract checks: migration presence, service-key exposure
./scripts/supabase-check.sh
```

Override build targets via env vars:
```bash
CODEX_IOS_PROJECT=... CODEX_IOS_SCHEME=... CODEX_IOS_DESTINATION=... ./scripts/ios-build.sh
```

The destination `platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro` may match both arm64 and x86_64 — select arm64 if prompted.

## Architecture

### iOS Layer (Swift 6, iOS 18+)

```
ios/PetGroomerMarketplace/PetGroomerMarketplace/
├── App/                    # AppComposition (DI root), AppRootView, entry point
├── Core/
│   ├── Configuration/      # SupabaseConfiguration (loads from Info.plist via xcconfig)
│   ├── Models/             # AppEntryRoute, UserRole, AuthSessionSnapshot
│   ├── Repositories/       # AuthSessionRepository protocol (and other repo protocols)
│   └── Infrastructure/
│       └── Supabase/       # SupabaseClientFactory, SupabaseAuthSessionRepository
├── Features/
│   ├── Auth/               # AuthenticationBootstrapView, AuthenticationBootstrapState
│   ├── Customer/           # CustomerTabView, CustomerTab
│   └── Groomer/            # GroomerTabView, GroomerTab
└── DesignSystem/           # DesignTokens, FeaturePlaceholderView
```

**Key invariant:** SwiftUI views never call Supabase directly. All backend access goes through repository/service protocol boundaries defined in `Core/Repositories/`. `AppComposition` is the single DI root that wires the concrete implementations.

**Entry routing:** `AppEntryRoute` has four cases (`.authentication`, `.roleOnboarding`, `.customer`, `.groomer`) and `AppRootView` switches on it, but since T-007 production launches only through `.authentication`. After sign-in, routing is owned by `AuthenticatedEntryView`'s Store-driven state machine (`AuthenticatedEntryStore`: loading → onboarding / customer / groomer / failure), not by the `AppEntryRoute` switch. The `.roleOnboarding`, `.customer`, and `.groomer` branches of `AppRootView` remain only as preview/test routes and are not reached on the production path.

**Supabase config:** Values flow through xcconfig → `AppInfo.plist` → `SupabaseConfiguration.load(from: bundle)`. The tracked `Supabase.xcconfig` has empty defaults; the Git-ignored `Supabase.local.xcconfig` carries real keys (populated by MCP). Only `sb_publishable_` prefix keys are accepted — missing or invalid config fails visibly with `AuthenticationBootstrapState.configurationError`.

**Supabase Swift** is pinned to exactly `2.46.0` with a checked-in `Package.resolved`.

### Backend (Supabase)

- **Authorized project:** `Pet Groomer Marketplace`, ref `lqmasbuqzvcvtawonjlb`, region `us-west-1`.
- **Legacy project** (`swdiiyypysyxbnfrxxsv`): do not inspect, branch, migrate, reset, or mutate it under any circumstances.
- All DDL must go through Supabase MCP (`apply_migration`) and be mirrored under `supabase/migrations/`. No Supabase CLI, `npx supabase`, or direct DB tools.
- Remote schema writes require explicit user authorization before `apply_migration` is called.
- The local `supabase_api_key` file is Git-ignored, must never be read by agents, and must never appear in code or documentation.

**Deployed tables (T-004):** `profiles`, `customer_profiles`, `groomer_profiles`, plus the private `avatars` Storage bucket with owner-scoped RLS and Storage policies. All other tables in `SUPABASE_CONTRACT.md` are planned only.

### Build Roadmap

Tasks T-001 through T-022 are documented in `docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md`. Current completed baseline: **T-007** (role onboarding and authenticated routing). Next planned: **T-008** (pets, pet photos, private Storage, and RLS). One task per run; do not start the next task automatically.

On-demand reference (build plans and longer context, not inlined here) lives in the root-level `CLAUDE_reference/` directory (kept out of `docs/`, which other agents own) — read it when relevant; start at its `CLAUDE_INDEX.md`. Files and folders Claude maintains are named with `CLAUDE` so other agents don't misread them.

## Claude's Role in This Project

Claude Code 在本项目中的职责是**评审（Review）**，不是实现。

**未经用户明确授权，Claude 不得修改任何项目文件**，包括但不限于：
- Swift 源代码、Xcode 项目文件、xcconfig
- Supabase 迁移文件、SQL、后端合约文档
- 脚本、配置文件、文档

允许的只读操作：阅读代码、分析问题、提出建议、生成评审意见。

如需对项目进行任何修改，必须先得到用户的明确指令，说明具体要改什么，再动手。

## Working Rules

- Read `docs/00_memory/CURRENT_STATE.md` for current build/backend/workflow state before starting any task.
- Keep SwiftUI views thin; business logic belongs outside views, behind repository protocols.
- Do not add dependencies, commit, push, or make remote writes without explicit user approval.
- `docs/03_backend/SUPABASE_CONTRACT.md` is the authoritative backend contract. Never claim a planned object is deployed.
- A new screen requires an entry in `docs/01_product/SCREEN_INVENTORY.md`; a new backend state requires an entry in `SUPABASE_CONTRACT.md` before implementation.
- If validation fails (build or backend), report the first real error and stop — do not enter a fix loop without approval.
- Preview and test fixtures are allowed only in preview and test processes; production paths must never return fake backend success.
