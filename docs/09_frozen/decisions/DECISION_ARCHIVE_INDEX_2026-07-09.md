# Archived Decision Index Rows

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-07-09

| Date | Decision | Current entry point |
|---|---|---|
| 2026-07-08 | Record the T-163 through T-173 batch commits as a one-time historical exception. | `../09_frozen/decisions/DECISION_LOG_D-009_2026-07-09.md` |
| 2026-07-08 | Treat `main` commit `2fddf7b` as reviewed and superseded by this branch's governance architecture. | `../09_frozen/decisions/DECISION_LOG_D-008_2026-07-09.md` |
| 2026-07-08 | Workflow-rule file changes must be standalone governed tasks. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-08 | Treat context hygiene as the machine check for active-doc fact drift. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Make preflight the local gate for migration and Edge Function static tests. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Use `docs/06_tasks/ROADMAP.md` as the only managed roadmap index. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Require task-prefixed Git/GitHub operations for new commits and release actions. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Treat root governance plans as external review input, not active project fact. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-07 | Promote customer notification work from deferred concept to approved scoped product behavior through T-153 and T-157. | `../09_frozen/decisions/DECISION_LOG_D-001_TO_D-007_2026-07-09.md` |
| 2026-07-02 | Support modern Supabase `sb_secret_...` keys in TestOps as `apikey`-only server credentials. | `../04_ios/testops/RUNBOOK.md`, `../05_workflow/TOOLING_POLICY.md` |
| 2026-07-01 | Separate Supabase CLI credentials from project API keys in local runbooks. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/MIGRATION_RULES.md` |
| 2026-07-01 | Run linked Supabase CLI commands single-flight and inspect ignored credential files only under explicit authorization. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-07-01 | Treat repository-local migration filenames as canonical and use `supabase db push --linked` as the normal deployment path. | `../03_backend/MIGRATION_RULES.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-06-25 | Use Supabase CLI for every current and future Supabase task in this repository. | `../05_workflow/TOOLING_POLICY.md`, `../03_backend/MIGRATION_RULES.md` |
| 2026-06-20 | Pin Supabase Swift to 2.46.0 and inject publishable configuration through ignored local xcconfig. | `../03_backend/SUPABASE_CONTRACT.md`, `../../ios/PetGroomerMarketplace/` |
| 2026-06-19 | Treat the existing non-Groomly Supabase project as legacy and use the isolated `Pet Groomer Marketplace` project. | `../00_memory/CURRENT_STATE.md`, `../03_backend/SUPABASE_CONTRACT.md` |
| 2026-06-19 | Use the Fresh Brief open-request marketplace as the product model; fixtures are preview/test-only. | `../01_product/PRODUCT_BRIEF.md`, `../02_architecture/` |
