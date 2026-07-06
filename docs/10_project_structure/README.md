# Project Structure Index

Use this file to decide where a new document belongs.

| Directory | Responsibility | Default Read |
|---|---|---|
| `docs/00_memory/` | Current facts, feature routing, recent worklog | L0/L1 targeted |
| `docs/01_product/` | Product scope, roles, UX, screens, design rules | L2 by product/UI task |
| `docs/02_architecture/` | Client architecture and module boundaries | L2 by implementation task |
| `docs/03_backend/` | Supabase contract, RLS/RPC, Storage, migrations | L1/L2 by backend task |
| `docs/04_ios/` | iOS build/test/style/accessibility manuals | L1/L2 by iOS task |
| `docs/05_workflow/` | Active workflow and tooling rules | L1/L2 by workflow/task execution |
| `docs/06_tasks/` | Compact ledger and templates | L0 targeted |
| `docs/07_decisions/` | Durable decisions and ADRs | L3 targeted |
| `docs/08_design/` | Current design notes/assets | L2 by UI task |
| `docs/09_frozen/` | Historical archive | L4, default forbidden |
| `docs/10_project_structure/` | Structure index and reorganization log | L1 by docs cleanup task |

Historical records should be archived instead of left in active directories once they stop guiding current work.
