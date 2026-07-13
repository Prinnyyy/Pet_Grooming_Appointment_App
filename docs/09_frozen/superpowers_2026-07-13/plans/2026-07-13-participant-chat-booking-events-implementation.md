<!-- task-artifact
task: T-351
status: completed
type: plan
-->

# Participant Chat And Booking Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace booking-scoped conversations with one participant-pair conversation and append an ordered live booking card plus friendly text after acceptance or cancellation.

**Architecture:** PostgreSQL remains authoritative for conversation identity and lifecycle messages. Typed message rows reference live bookings, while Swift repositories decode the structure and existing role-specific Booking views own detail presentation.

**Tech Stack:** PostgreSQL/Supabase migrations and RLS, Supabase Swift, Swift 6, SwiftUI, Swift Testing, Node migration contract tests.

## Global Constraints

- The automatic booking card is inserted before its plain-text companion.
- Existing messages are preserved and duplicate pair conversations are merged.
- Booking cards show current booking state and navigate to existing Booking detail UI.
- Direct authenticated message writes remain text-only.
- No dependency, attachment, unrelated chat redesign, or legacy-project operation.
- Remote writes target only Beckon ref `lqmasbuqzvcvtawonjlb` under the user's T-351 authorization.

---

### Task 1: Migration Contract RED

**Files:**
- Create: `supabase/migrations/<generated>_t351_participant_conversations_booking_events.sql`
- Create: `tests/migrations/participant-chat-booking-events.test.mjs`

- [ ] Generate an empty migration with `supabase migration new t351_participant_conversations_booking_events`.
- [ ] Add static tests requiring pair uniqueness, historical merge, typed-message checks, direct text-only grants/policy, lifecycle RPC card-before-text inserts, and notification lookup compatibility.
- [ ] Run the focused Node test and confirm it fails because the migration is empty.

### Task 2: PostgreSQL GREEN

**Files:**
- Modify: generated T-351 migration.
- Modify: `docs/03_backend/SUPABASE_CONTRACT.md`
- Modify: `docs/03_backend/RLS_RPC_POLICY.md`

- [ ] Merge duplicate pair conversations into the earliest row, repoint messages, then remove booking/request ownership and add `unique (customer_id, groomer_id)`.
- [ ] Add `messages.kind`, nullable `body`, optional `booking_id`, integrity constraints, indexes, grants, and participant policies that prevent direct booking-card creation.
- [ ] Replace the current private acceptance/cancellation helpers so valid transitions atomically append card then text and wrappers retain their signatures.
- [ ] Update customer/groomer notification trigger helpers to derive request/booking context from the typed message when available.
- [ ] Run migration tests, preflight, diff check, and linked migration dry-run.

### Task 3: Swift Model And Repository RED/GREEN

**Files:**
- Modify: `ios/Beckon/Beckon/Core/Models/Chat.swift`
- Modify: `ios/Beckon/Beckon/Core/Repositories/ChatRepository.swift`
- Modify: `ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseChatRepository.swift`
- Modify: `ios/Beckon/Beckon/Features/Chat/ChatStore.swift`
- Modify: `ios/Beckon/BeckonTests/ChatFeatureTests.swift`

- [ ] Add failing tests for pair identity, booking-card decoding, live booking summaries, card-before-text ordering, and booking-to-pair lookup.
- [ ] Replace singular conversation booking fields with pair identity and current messaging-window data.
- [ ] Decode typed messages and batch-load referenced participant bookings without embedding snapshot data in messages.
- [ ] Keep text sending, pagination, Realtime, unread state, and stable `(created_at, id)` ordering intact.
- [ ] Run focused Chat tests to GREEN.

### Task 4: Existing Booking Detail Navigation

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Chat/ChatView.swift`
- Modify: Customer/Groomer tab composition files only where needed to pass existing Booking ownership into Chat.
- Modify: focused Chat/Booking presentation tests.

- [ ] Add failing presentation/navigation tests for text rows, live booking cards, and both role destinations.
- [ ] Render booking-card rows before their companion text and route taps through the existing role-specific Booking detail component.
- [ ] Change booking-origin Chat focus from booking ID matching to participant-pair resolution.
- [ ] Preserve TestOps identifiers or update their owned contract in the same change.
- [ ] Run focused Chat and Booking tests to GREEN.

### Task 5: Remote Apply And Completion

- [ ] Run `./scripts/preflight.sh`, focused iOS tests, `git diff --check`, and one `./scripts/ios-build.sh`.
- [ ] Sequentially verify linked migration history and dry-run, apply the single T-351 migration, then verify history, metadata, positive/negative authorization, advisors, and an up-to-date dry-run.
- [ ] Update Task Ledger, Worklog, Current State, backend facts, and Decision Log if the final architecture requires a durable decision entry.
- [ ] Mark both artifacts completed, run unified closeout and context hygiene, review the diff, commit, and push the task-scoped changes.
