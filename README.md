# Pet Groomer Marketplace

iOS SwiftUI marketplace app for pet grooming appointments.

```text
Customer publishes an open grooming request
-> matched groomers make offers
-> customer accepts one offer
-> booking and chat are created
-> groomer completes the booking
-> customer leaves a review
```

## Current Status

The implemented MVP flow is complete through T-048. Historical task records, old roadmaps, external audits, and legacy prompts are archived under `docs/09_frozen/` and are not default startup context.

There is no active auto-start product task. Future work should start from the current facts in:

- `AGENTS.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/FEATURE_INDEX.md`

## Documentation Map

- Documentation index: `docs/README.md`
- Current facts: `docs/00_memory/CURRENT_STATE.md`
- Feature routing index: `docs/00_memory/FEATURE_INDEX.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Workflow rules: `docs/05_workflow/README.md`
- Product rules: `docs/01_product/`
- Architecture rules: `docs/02_architecture/`
- Supabase contract: `docs/03_backend/SUPABASE_CONTRACT.md`
- iOS runbooks: `docs/04_ios/`
- Frozen archive: `docs/09_frozen/README.md`

## Validation Commands

```sh
./scripts/ios-build.sh
./scripts/ios-test.sh
./scripts/preflight.sh
./scripts/supabase-check.sh
node scripts/context-hygiene-check.mjs
```
