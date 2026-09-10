# Beckon: Pet Grooming

iOS SwiftUI marketplace app for pet grooming appointments.

Pet groomers at your beck and call.

Customer Request -> Groomer Offer -> Customer Acceptance -> Booking/Chat -> Groomer Completion -> Customer Review.

Customers manage pets and requests, compare offers and review completed services. Groomers manage services, portfolio, availability and fit evidence. Pet-fit supports explainable request distribution, not a public groomer directory or direct customer slot booking. Production uses Supabase Auth, Postgres/RPC, RLS and private Storage behind repository boundaries.

## Navigation

- [Agent entry](AGENTS.md) and [on-demand development guide](docs/05_workflow/DEVELOPMENT_GUIDE.md)
- [Current task and recovery state](docs/00_memory/CURRENT_STATE.md)
- [Documentation and repository paths](docs/README.md)
- [Feature-to-code routing](docs/00_memory/FEATURE_INDEX.md)
- [Architecture](docs/02_architecture/ARCHITECTURE.md) and [backend contract](docs/03_backend/SUPABASE_CONTRACT.md)
- [Brand identity](docs/01_product/BRAND_IDENTITY.md) and [current UI notes](docs/08_design/UI_IMPLEMENTATION_NOTES.md)
- [Unadopted product directions](docs/06_tasks/ROADMAP.md) and [durable decisions](docs/07_decisions/DECISION_LOG.md)

## Validation

Choose checks by affected risk in the development guide. [iOS commands](docs/04_ios/IOS_BUILD_AND_TESTING.md) retain generic Simulator build and auto-discovered test destinations, with `CODEX_IOS_DESTINATION` overrides. [TestOps](docs/04_ios/testops/README.md) requires separate authorization for remote writes.

Original functional-reliability acceptance and its local-only limits remain in [T-385 evidence](docs/06_tasks/sql_reviews/T-385_RELEASE_CHECKPOINT.md). Historical records are not instructions to resume completed work.
