# Project Memory

This is the highest-level durable memory file for Codex.

Keep this concise. It is an index, not a full project dump.

## Project Identity

- GitHub repository: `Prinnyyy/Pet_Grooming_Appointment_App`
- Repository URL: `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App`
- App type: iOS app.
- Platform: SwiftUI-first iOS project.
- Backend: Supabase if configured.
- Development model: Codex-first, lightweight single-agent runs.

## Product Summary

- Groomly is a request-first pet grooming marketplace for iOS.
- Customers maintain pet profiles, publish grooming requests, compare groomer offers, accept one offer, manage bookings, chat with the booked groomer, and review completed service.
- Groomers maintain profile, services, portfolio, availability, fit signals, and evidence dashboard; they receive eligible requests, make/withdraw offers, manage bookings, chat, and complete service.
- The product model remains Open Request -> Groomer Offer -> Customer Confirmation -> Booking.
- Pet-fit matching v1 improves request distribution with explainable evidence, not a public groomer directory or direct customer slot booking.

## Architecture Summary

- SwiftUI views remain thin and route business actions through Stores/ViewModels and repository protocols.
- Supabase Auth, Postgres, RPCs, RLS, and Storage are the production backend boundaries.
- Critical transitions such as request creation, offer creation, offer acceptance, booking completion, review creation, and request cancellation use controlled RPCs.
- Groomly UI adaptation is complete for implemented MVP screens; future UI work is screenshot-driven and must reuse existing Store/repository/model paths.
- Build and test scripts default to a generic simulator build destination and auto-discovered test simulator, with `CODEX_IOS_DESTINATION` overrides.

## Backend Summary

- Authorized Supabase project: `Pet Groomer Marketplace`, ref `lqmasbuqzvcvtawonjlb`.
- Legacy Supabase project `swdiiyypysyxbnfrxxsv` is out of scope and must not be mutated.
- Deployed tables cover profiles, pets/photos, groomer profiles/services/portfolio, availability, requests/matches/photos, offers, bookings, conversations/messages, reviews, structured pet-fit outcomes, groomer fit claims, and portfolio fit tags.
- Deployed RPCs include profile creation, request creation/cancellation, match dismissal, offer create/withdraw/accept, booking cancel/complete, review creation, and owner evidence summary.
- RLS and explicit grants are the security boundary; iOS must not use secret/service-role credentials.

## Active Development Priorities

1. Continue only from `codex/pet-fit-structure-cleanup` unless the user explicitly names another branch.
2. Use the next available task ID from `docs/06_tasks/TASK_LEDGER.md` for new bugfix or iteration work.
3. Do not start pet-fit, availability, backend, screenshot, or direct-booking work without an explicit user request/authorization.

## Permanent Constraints

- Single major task per Codex run.
- Preserve user work.
- Keep durable project memory updated.
- Do not rely on compressed conversation context.
- Use scripts for checks.
- Use Superpowers only when one directly relevant capability is clearly useful.

## Important Index Links

- Current state: `docs/00_memory/CURRENT_STATE.md`
- Feature index: `docs/00_memory/FEATURE_INDEX.md`
- Product flows: `docs/01_product/NAVIGATION_AND_FLOWS.md`
- Architecture: `docs/02_architecture/ARCHITECTURE.md`
- Backend contract: `docs/03_backend/SUPABASE_CONTRACT.md`
- Workflow: `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
