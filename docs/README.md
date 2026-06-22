# Project Documentation Index

This folder is the durable project memory and coordination layer for Codex.

Use it to avoid relying on long conversation context.

## Sections

- `00_memory/`: compressed long-term project memory and recovery files
- `01_product/`: product definition, user roles, flows, design system
- `02_architecture/`: iOS/client architecture and module boundaries
- `03_backend/`: Supabase schema, RLS, RPC, storage, migrations
- `04_ios/`: Swift, SwiftUI, build, testing, accessibility rules
- `05_workflow/`: lightweight single-agent Codex workflow, context management, and tool policies
- `06_tasks/`: task ledger, task template, handoff notes, review template
- `07_decisions/`: ADRs and decision templates
- `08_design/`: Groomly prototype, design prompt, implementation notes, and extracted design tokens
- `09_frozen/`: frozen pre-phase snapshots used only for recovery or comparison

## Active Task

The completed Groomly foundation sequence is `06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`.

Completed screen slices:

- `06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md`
- `06_tasks/T-025_GROOMLY_CUSTOMER_PETS_UI.md`
- `06_tasks/T-026_GROOMLY_CUSTOMER_REQUESTS_LIST_STATUS_UI.md`
- `06_tasks/T-027_GROOMLY_CUSTOMER_REQUEST_WIZARD_UI.md`
- `06_tasks/T-028_GROOMLY_CUSTOMER_REQUEST_DETAIL_OFFERS_UI.md`
- `06_tasks/T-029_GROOMLY_GROOMER_REQUESTS_FEED_DETAIL_UI.md`
- `06_tasks/T-030_GROOMLY_GROOMER_OFFER_FORM_STATUS_UI.md`
- `06_tasks/T-031_GROOMLY_GROOMER_PROFILE_SERVICES_UI.md`
- `06_tasks/T-032_GROOMLY_GROOMER_PORTFOLIO_UI.md`

The planned remaining Groomly UI sequence is `06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`.

The active next executable task is `06_tasks/T-033_GROOMLY_BOOKINGS_UI.md`.

T-022 remains completed, but its post-MVP next-task suggestions are frozen and must not auto-start. Use `09_frozen/pre_groomly_ui_2026-06-21/` only to recover or compare pre-Groomly context.
