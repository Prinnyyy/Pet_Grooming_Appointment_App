# Documentation And Paths

Read one domain entry when needed, then targeted contracts/code. [Current State](00_memory/CURRENT_STATE.md) alone owns task IDs and recovery. [Development Guide](05_workflow/DEVELOPMENT_GUIDE.md) owns workflow and safety; this index does not define active work.

## Domain Entries

| Need | Entry |
|---|---|
| Find feature ownership | [Feature Index](00_memory/FEATURE_INDEX.md) |
| Product, roles and flows | [Product brief](01_product/PRODUCT_BRIEF.md), [navigation](01_product/NAVIGATION_AND_FLOWS.md) |
| UI contract | [Design System](01_product/DESIGN_SYSTEM.md), [brand](01_product/BRAND_IDENTITY.md) |
| Client architecture | [Architecture](02_architecture/ARCHITECTURE.md) |
| Backend definitions and safety | [Supabase Contract](03_backend/SUPABASE_CONTRACT.md) |
| Build and tests | [iOS commands](04_ios/IOS_BUILD_AND_TESTING.md), [TestOps](04_ios/testops/README.md) |
| Future product directions | [Roadmap](06_tasks/ROADMAP.md) |
| Durable decisions | [Decision Log](07_decisions/DECISION_LOG.md) |
| Plans and acceptance evidence | [Task artifacts](superpowers/README.md), [reviewed SQL/evidence index](06_tasks/sql_reviews/README.md) |
| Design assets | [UI notes](08_design/UI_IMPLEMENTATION_NOTES.md), [screenshots](08_design/screenshots/README.md) |
| Named heavy design inspection | [UI redesign entry](ui-redesign/README.md) |
| Named fixture/account lookup | [Test resources](02_architecture/test_resources/README.md) |

## Repository Paths

| Path | Ownership |
|---|---|
| [ios](../ios/) | SwiftUI app, Xcode project and tests; moves need Xcode-reference validation. |
| [migrations](../supabase/migrations/) | Append-only migration mirrors; do not rename, rewrite or reorder applied versions. |
| [functions](../supabase/functions/) | Backend functions; deployment needs scoped authorization. |
| [scripts](../scripts/) and [tests](../tests/) | Existing validation and operational tools. |
| [project config](../.codex/config.toml) | Local Codex configuration; not changed by repository governance. |
| [search exclusions](../.rgignore) | Historical and heavy material hidden from ordinary searches. |
| [frozen archives](09_frozen/README.md) | Historical evidence, read only for a named purpose. |
| [reorganization history](10_project_structure/REORGANIZATION_LOG.md) | Prior moves, not another live path index. |

Credentials and generated artifacts remain ignored and outside ordinary reads. Search hiding is not a security permission. Current plans and changed task documents remain eligible for targeted hygiene checks even when excluded from broad search.

The [functional findings](06_tasks/APP_FUNCTIONAL_DESIGN_FINDINGS.md) and [original reliability plan](superpowers/plans/2026-09-07-functional-reliability-task-plan.md) are historical inputs to [T-385 local acceptance](06_tasks/sql_reviews/T-385_RELEASE_CHECKPOINT.md), not an unadopted remediation queue.
