# Groomer UI Redesign

- Decision: D-026 / R-039
- Approved: 2026-07-10
- Implemented packages: Q-97 through Q-103
- Remaining package: Q-104, user-deferred

This active file retains only the current Groomer visual contract and deferred regression scope. The complete T-249 execution contract is frozen at `../09_frozen/design_notes/T-347_2026-07-13/GROOMER_UI_REDESIGN.md`.

## Read Condition

Read this file only for Q-104, a focused R-039 visual regression, or a Groomer screen task that needs the role-specific layout contract. Use `../01_product/DESIGN_SYSTEM.md` and `../01_product/ACCESSIBILITY_RULES.md` as the shared authority.

## Current Contract

- Groomer is a calm, schedule/action-oriented workspace; Customer remains pet/decision oriented.
- The five direct Groomer tabs are Home, Requests, Schedule, Messages, and Account. There is no system More tab.
- Requests owns Matches and Offers segments. Notifications open from Home. Account is direct; feature editors hide the tab bar and expose one back action.
- Operational queues use one grouped surface with separators. Cards are reserved for standalone or genuinely raised objects.
- Coral is limited to Groomer actions, selection, unread/current emphasis, and small role accents.
- Current request, offer, booking, chat, notification, profile, repository, and backend behavior remains authoritative.
- Do not add revenue, payments, ranking, maps, attachments, read receipts, typing state, new push behavior, schema, RLS/RPC, Storage, dependencies, or public assets through visual work.

## Q-104 Deferred Gate

Q-104 resumes only on explicit user direction. It must cover:

- loading, populated, empty, partial-error, retry, disabled, and busy states;
- long names and AX3 Dynamic Type without overlap or clipping;
- VoiceOver labels, grouping, headings, actions, and 44pt targets;
- approved color pairs and non-color status cues;
- image success, cache-first display, missing-image fallback, and remote failure;
- no More tab, duplicate back controls, or unstable selectors;
- preserved TestOps identifiers and updated selector-based automation where semantics change.

Simulator captures are visual evidence, not pixel pass/fail assertions. Behavioral automation remains selector and state based.

## Evidence

Approved targets:

- [Home](groomer_ui_redesign/approved/groomer-home-approved.png)
- [Requests](groomer_ui_redesign/approved/groomer-requests-approved.png)
- [Account](groomer_ui_redesign/approved/groomer-account-approved.png)
- [Edit Profile](groomer_ui_redesign/approved/groomer-edit-profile-approved.png)

Pre-change captures remain under `groomer_ui_redesign/current/` and are read only for a named comparison.

## Architecture Boundary

Views do not call Supabase. Existing feature Stores remain mutation owners; the root tab owns navigation/deep-link coordination. A read-only Home aggregator may use existing repositories. No backend or remote write is part of this visual contract.
