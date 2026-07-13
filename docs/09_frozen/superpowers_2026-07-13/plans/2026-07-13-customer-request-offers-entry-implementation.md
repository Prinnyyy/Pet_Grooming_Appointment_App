# Customer Request Offers Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a direct, status-aware Offers route to active Customer Request cards and remove Offers from Request Details.

**Architecture:** Keep `CustomerRequestsStore` as the sole data owner. Introduce `CustomerOffersView.swift` as the dedicated destination, reuse the existing Offer list/detail presentation there, make that destination load on entry, and keep Request Details focused on immutable request information.

**Tech Stack:** SwiftUI, Swift Testing, existing Beckon DesignSystem and Customer Request Store.

## Global Constraints

- Do not change Store, repository, Supabase, persistence, or matching contracts.
- Use request status as the Offers-button authority; do not eagerly load every card's offers.
- Preserve booking handoff and closed-request behavior.
- Reuse existing Offer list, detail, refresh, pagination, acceptance, and accessibility behavior.
- Human review owns visual approval.

---

### Task 1: Lock navigation and availability contracts

**Files:**
- Modify: `ios/Beckon/BeckonTests/CustomerRequestFeatureTests+RequestsAndBookings.swift`

**Interfaces:**
- Consumes: `GroomingRequestStatus`
- Produces: `CustomerRequestCardActionsPresentation` and an Offers-free `CustomerRequestDetailPresentation`

- [x] Add tests requiring `.open` to disable Offers and `.hasOffers` to enable Offers.
- [x] Update the Request Detail contract to require only cancelled-request republish behavior.
- [x] Run focused Customer Request tests and confirm RED because the new action presentation is missing and Request Details still owns Offers.

### Task 2: Recompose Request card actions

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsDashboardView.swift`

**Interfaces:**
- Consumes: `CustomerRequestCardActionsPresentation`
- Produces: equal Detail/Offers first row and full-width destructive Cancel second row

- [x] Add the status-backed action presentation.
- [x] Add the direct Offers `NavigationLink`, preserving existing TestOps request references.
- [x] Extend the local action-label tone with enabled Customer green and filled destructive styling.
- [x] Run focused tests and confirm the action contract is GREEN.

### Task 3: Move Offers into a dedicated destination

**Files:**
- Create: `ios/Beckon/Beckon/Features/Customer/Requests/CustomerOffersView.swift`
- Modify: `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestDetailView.swift`

**Interfaces:**
- Consumes: request ID and `CustomerRequestsStore`
- Produces: `CustomerRequestOffersView`, Offer list, and Offer detail destination

- [x] Reuse the current Offer list, summary, fit evidence, and detail views without changing their Store calls or identifiers.
- [x] Make the Offers destination load via `.task(id:)` and retain manual refresh/pagination/error states.
- [x] Remove Offer rendering and `.task` loading from Request Details.
- [x] Run focused Customer Request tests and confirm GREEN.

### Task 4: Validate and close out T-344

**Files:**
- Modify: `docs/06_tasks/TASK_LEDGER.md`
- Modify: `docs/00_memory/WORKLOG.md`
- Modify: `docs/00_memory/CURRENT_STATE.md`

**Interfaces:**
- Consumes: validated source and tests
- Produces: durable task closeout, commit, and push

- [x] Run focused Customer Request tests, `./scripts/ios-build.sh`, and `git diff --check`.
- [x] Review the diff and run context hygiene after durable-memory updates.
- [x] Record T-344 as completed, preserve T-340 as planned, and set T-345 as next unallocated.
