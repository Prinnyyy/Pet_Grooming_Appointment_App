# Project Memory

This is the highest-level durable memory file. Keep it short; use it as an index, not a project dump.

## Project Identity

- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`
- App type: native iOS SwiftUI app.
- Backend: Supabase project `lqmasbuqzvcvtawonjlb`.
- Development model: indexed single-agent runs with one primary task per run.

## Product Summary

- Customers publish open grooming requests.
- Matched groomers submit offers.
- Customers accept one offer to create a booking and participant chat.
- Groomers complete bookings.
- Customers review completed bookings.
- Groomly visual styling is applied to implemented MVP screens.

## Architecture Summary

- SwiftUI views stay thin and route actions through Stores/repositories.
- Repository adapters own Supabase calls and Storage uploads.
- Product state is backend-authoritative; previews/tests may use fixtures, production runtime may not.
- Feature code is organized by Auth, Customer, Groomer, Bookings, Chat, Debug, DesignSystem, and Core.

## Backend Summary

- Supabase Auth owns identity; app tables own role/profile/product state.
- Deployed contract includes profiles, pets, groomer profiles/services/portfolio metadata, requests/matches/offers, bookings/conversations/messages, reviews, and controlled RPCs.
- Remote DDL and data writes require explicit user approval.

## Permanent Constraints

- One primary task per run.
- Preserve user work and inspect `git status --short` before edits.
- Do not use archived task records or old briefs as default startup context.
- Do not read, print, or commit local credential files.
- Use `node scripts/context-hygiene-check.mjs` after durable memory or ledger edits.

## Important Index Links

- Current state: `docs/00_memory/CURRENT_STATE.md`
- Feature index: `docs/00_memory/FEATURE_INDEX.md`
- Workflow: `docs/05_workflow/README.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Decision log: `docs/07_decisions/DECISION_LOG.md`
- Frozen archive: `docs/09_frozen/README.md`
