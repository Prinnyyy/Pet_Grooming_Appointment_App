# Archived Decision Log Entries

Source: docs/07_decisions/DECISION_LOG.md
Date archived: 2026-09-08

```text
Decision ID: D-036
Date: 2026-07-28
Decision: Remediate the Customer Request Journey through five dependency-ordered packages, with publish correctness and idempotency preceding form, media, offer, and presentation changes.
Context: The journey audit found a duplicate-Request risk when post-create work fails, implicit service selection, a seven-day date ceiling, incomplete Request-photo review, an under-informed Offer acceptance handoff, misleading loading/empty states, and focused UI consistency debt. Combining backend correctness and all visible refinements in one task would be difficult to validate and reverse.
Consequences: R-042 uses Q-121 through Q-125. Q-121 owns the separately authorized Deep publish contract; later packages own Wizard semantics, Request media, Offer-to-Booking handoff, and page-state/visual corrections. Matching rules, Groomer offer creation, booking lifecycle semantics, dependencies, direct booking, and deferred Groomer Q-104 scope remain unchanged.
Linked files: docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md, docs/01_product/DESIGN_SYSTEM.md, docs/01_product/FORM_INTERACTION_RULES.md
```
```text
Decision ID: D-035
Date: 2026-07-13
Decision: Give each Customer/Groomer pair one durable conversation and represent acceptance/cancellation as ordered typed booking events.
Context: Booking-scoped conversations split the same participants across multiple threads and static chat context could not represent more than one booking or remain current after a status transition.
Consequences: Existing duplicate threads merge into the earliest participant-pair conversation with messages preserved. Controlled acceptance and first cancellation atomically append a live booking card followed by friendly text from the acting user. Authenticated clients may still insert only self-authored text and cannot forge cards. iOS resolves cards through the Booking repository and routes to the existing role-specific Booking detail with shared state.
Linked files: supabase/migrations/20260713223400_t351_participant_conversations_booking_events.sql, ios/Beckon/Beckon/Features/Chat/, docs/03_backend/RLS_RPC_POLICY.md, docs/06_tasks/sql_reviews/T-351_PARTICIPANT_CHAT_ROLLBACK_VALIDATION.sql
```
```text
Decision ID: D-034
Date: 2026-07-13
Decision: Use one guarded task-closeout command for numbered durable closeouts and a metadata-based lifecycle for temporary plans/specs.
Context: Closeout required several manual steps, so completed artifacts, active backlinks, and rolling windows could drift independently. The unused agent-preflight script also referenced a deleted template and always failed.
Consequences: task-closeout dry-runs by default. Apply mode first requires aligned completed ledger/current-state/worklog facts, completed task/type metadata, clear active backlinks, a safe rotation preview, and a hygiene precheck; it then moves artifacts verbatim into a dated frozen Superpowers family, applies one rotation batch, and reruns hygiene. Default output is concise and --verbose exposes diagnostics. The broken agent-preflight entrypoint is removed rather than maintained beside the canonical gates.
Linked files: docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/superpowers/README.md, scripts/task-closeout.mjs, scripts/context-rotate.mjs, tests/scripts/task-closeout.test.mjs
```
```text
Decision ID: D-033
Date: 2026-07-13
Decision: Assign each workflow concern to one owner file, enforce compact AGENTS/Claude adapters, and keep one T-### task per session without automatic meta-review chaining.
Context: Validation, context, Git, stop, Simulator, checkpoint, skill, and meta-review rules had been copied across active files and had drifted into contradictions. The repository also assumed a fixed host context capacity it cannot observe.
Consequences: SINGLE_AGENT_WORKFLOW owns lifecycle; CONTEXT_AND_RECOVERY owns reads/recovery/compaction/hygiene; TOOLING_POLICY owns validation/tools/credentials/remote authorization; GITHUB_RULES owns Git conventions; STOP_CONDITIONS is a short matrix. AGENTS and CLAUDE have enforced 600/250-word interface ceilings. Development RED is distinct from completion failure; user-deferred Simulator review is valid; host-required skills are not repository-capped; incomplete checkpoint Git needs explicit approval. A due meta-review is reserved and runs only in a fresh user-continued session. Host telemetry replaces fixed token thresholds. This supersedes D-029, the fixed-capacity/checkpoint parts of D-028, and creates an entry-adapter exception to D-024's generic informational word telemetry.
Linked files: AGENTS.md, CLAUDE.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/05_workflow/TOOLING_POLICY.md, docs/05_workflow/GITHUB_RULES.md, docs/05_workflow/STOP_CONDITIONS.md, docs/06_tasks/META_REVIEW_TEMPLATE.md, scripts/context-hygiene-check.mjs
```
```text
Decision ID: D-032
Date: 2026-07-12
Decision: Use layered Xcode/Simulator runtime-log sampling for app behavior validation.
Context: Full Debug Area output is noisy and expensive to inspect, but ignoring it can miss SwiftUI faults and runtime warnings that are not visible in screenshots or test assertions.
Consequences: Runtime validation samples recent interaction output and severity/task keywords first, then expands only relevant messages and narrow time windows. Actionable Beckon diagnostics are recorded; Apple/Simulator noise is classified before any code change. Build-only, test-only, docs-only, and static checks do not require runtime-log inspection.
Linked files: docs/05_workflow/TOOLING_POLICY.md, docs/04_ios/IOS_BUILD_AND_TESTING.md
```
```text
Decision ID: D-031
Date: 2026-07-12
Decision: Govern Beckon UI consistency through the existing DesignSystem, semantic components, and an all-app source-audit debt ratchet, with the first migration slice limited to Customer Home, Requests, Request creation, and Account.
Context: Existing tokens and shared primitives are real but incomplete; feature code still mixes platform fonts, fixed sizes, local styles, repeated modifier stacks, and layout repairs. Screenshot review catches rendering failures but cannot reliably enforce fine-grained consistency. Customer reference pages establish useful hierarchy and tone but also contain debt, while Groomer intentionally uses denser workspace patterns.
Consequences: R-041 evolves DesignTokens in place, adds only reuse-backed semantic components, establishes a tested dependency-free source audit with explicit exceptions, baselines non-slice debt, and blocks new violations. The four Customer surfaces migrate first. Business logic, repositories, navigation, Supabase, dependencies, and deferred Groomer Q-104 scope are unchanged unless separately approved.
Linked files: docs/01_product/DESIGN_SYSTEM.md, docs/01_product/ACCESSIBILITY_RULES.md, docs/01_product/FORM_INTERACTION_RULES.md, docs/04_ios/UI_CODE_GOVERNANCE.md, docs/04_ios/UI_CONSISTENCY_DEBT.md, docs/06_tasks/ROADMAP.md, docs/00_memory/FEATURE_INDEX.md
```
```text
Decision ID: D-030
Date: 2026-07-11
Decision: Adopt one shared Apple Maps service-address confirmation system and make private PostGIS coordinates plus the controlling radius the long-term location-matching authority.
Context: Device-localized city strings can differ across Customer and Groomer records, current city/state matching ignores ZIP and configured radii, and the Request address dropdown performed expensive per-candidate language normalization. The product needs shopping-style field semantics and address confirmation, but grooming service locations do not require a USPS-deliverability claim or a Google dependency.
Consequences: Address Line 1 excludes Unit/Apt data and Address Line 2 owns it; complete misplaced suffixes auto-move unless a conflict requires user choice. MapKit suggestions display directly, only selections/manual continuation resolve, Place ID is optional, and complete coordinates are mandatory. Exact geo metadata is private; PostGIS applies Customer travel radius for shop visits and Groomer service radius for mobile service. Legacy city/state fallback exists only through controlled backfill and is removed after a zero-gap gate. Remote migration/backfill/TestOps remain separately authorized.
Linked files: docs/02_architecture/DATA_FLOW.md, docs/03_backend/RLS_RPC_POLICY.md, docs/04_ios/ADDRESS_BACKFILL.md, docs/06_tasks/ROADMAP.md
```
