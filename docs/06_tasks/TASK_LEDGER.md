# Task Ledger

Track tasks here so Codex does not continue automatically.

| ID | Task | Status | Mode | Files/Docs | Checks | Notes |
|---|---|---|---|---|---|---|
| T-000 | Initialize Codex workspace docs | completed | Quick | docs/, .codex/, scripts/ | preflight | Completed in commit `0178430` |
| T-001 | Create SwiftUI baseline project | completed | Standard | ios/, scripts/, docs/ | build, 4 unit tests, 1 UI test, preflight | Closed from implementation and specification-review evidence |
| T-002 | Rebuild incremental implementation roadmap | completed | Standard | roadmap, task ledger, current state, worklog | preflight | Fresh Brief is canonical; future intake files are created just in time |
| T-003 | Align canonical product and engineering docs | completed | Quick | product, architecture, backend docs | preflight, stale-term scan | Canonical Request → Offer → Booking docs; no Supabase initialization |
| T-004 | Establish Supabase profile foundation | completed | Deep | new Supabase project, two MCP-applied/local-mirrored migrations, avatar Storage, RLS, backend contract | MCP metadata/RLS rollback tests/advisors, static Supabase check | Profile foundation deployed to fresh ref only; final security/performance advisors clean; legacy project forbidden |
| T-005 | Add iOS Supabase client and session boundary | completed | Deep | Xcode dependency, Core infrastructure, config docs | iOS build passed | Supabase 2.46.0 pinned; MCP-sourced local config; no Auth screens or session routing |
| T-006 | Implement email/password authentication | completed | Deep | Auth repository, AuthenticationStore, Auth views, focused tests | ios-test: 10 unit + 1 UI smoke passed | Default email confirmation; no profile query/creation or role routing |
| T-007 | Implement role onboarding and entry routing | completed | Deep | onboarding RPC/repository/Store/UI, Account, App routing | MCP rollback tests/advisors, supabase-check, 17 unit + 1 UI test | Corrective migration resolved `42702`; authoritative Customer/Groomer routing; no detailed role profile features |
| T-008 | Add pet data and photo Storage contract | planned | Deep | pets migration, Storage, RLS, backend docs | explicit backend validation | Backend only |
| T-009 | Implement customer pet management | planned | Standard | Customer pet feature | one iOS validation attempt | No grooming requests |
| T-010 | Add groomer profile and portfolio backend | planned | Deep | groomer services, portfolio Storage, RLS | explicit backend validation | Backend only |
| T-011 | Implement groomer profile management | planned | Standard | Groomer profile, services, portfolio UI | one iOS validation attempt | No request feed |
| T-012 | Add grooming request and match backend | planned | Deep | requests, matches, RPCs, RLS | explicit backend validation | Backend only |
| T-013 | Implement customer request wizard | planned | Standard | Customer request creation UI | one iOS validation attempt | No groomer feed |
| T-014 | Implement groomer matched-request feed | planned | Standard | Groomer request list/detail/dismiss | one iOS validation attempt | No offer creation |
| T-015 | Add groomer offer backend | planned | Deep | offers migration, create/withdraw RPCs, RLS | explicit backend validation | No offer UI or acceptance |
| T-016 | Implement groomer offer creation | planned | Standard | Groomer offer form, withdrawal, and state | one iOS validation attempt | No customer acceptance |
| T-017 | Implement customer offer review | planned | Standard | Customer offer list/detail | one iOS validation attempt | Read-only until T-018 |
| T-018 | Add atomic offer acceptance and booking | planned | Deep | bookings, conversations, acceptance/cancellation RPCs, conflict rules, RLS | explicit atomicity and backend validation | Backend only |
| T-019 | Implement booking acceptance and role UIs | planned | Standard | acceptance/cancellation UI, booking lists/details | one iOS validation attempt | No chat or reviews |
| T-020 | Implement booking-participant chat | planned | Deep | messages backend, RLS, basic chat UI | explicit backend and iOS validation | No realtime polish |
| T-021 | Implement completion and reviews | planned | Deep | completion/review RPCs, RLS, role UIs | explicit backend and iOS validation | No dispute flow |
| T-022 | Harden and validate the MVP | planned | Deep | states, Debug Panel, security and E2E checks | explicit full validation plan | No deferred features |
| WORKFLOW-SLIM-001 | Optimize Codex workflow budgets | completed | Quick | workflow docs only | diff stat, agent preflight | Superseded by `WORKFLOW-SIMPLIFY-001` |
| WORKFLOW-SIMPLIFY-001 | Replace agent-team workflow with single-agent workflow | completed | Quick | workflow docs and `.codex/` only | diff stat | Subagents disabled and old workflow archived |
