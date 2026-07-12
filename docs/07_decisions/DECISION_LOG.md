# Decision Log

Use this for durable architecture/product/workflow decisions. Keep active entries compact; full historical text lives in frozen snapshots.

Full pre-T-174 snapshot: `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

## Format

```text
Decision ID:
Date:
Decision:
Context:
Consequences:
Linked files:
```

## Active Decisions

```text
Decision ID: D-031
Date: 2026-07-12
Decision: Govern Beckon UI consistency through the existing DesignSystem, semantic components, and an all-app source-audit debt ratchet, with the first migration slice limited to Customer Home, Requests, Request creation, and Account.
Context: Existing tokens and shared primitives are real but incomplete; feature code still mixes platform fonts, fixed sizes, local styles, repeated modifier stacks, and layout repairs. Screenshot review catches rendering failures but cannot reliably enforce fine-grained consistency. Customer reference pages establish useful hierarchy and tone but also contain debt, while Groomer intentionally uses denser workspace patterns.
Consequences: R-041 evolves DesignTokens in place, adds only reuse-backed semantic components, establishes a tested dependency-free source audit with explicit exceptions, baselines non-slice debt, and blocks new violations. The four Customer surfaces migrate first. Business logic, repositories, navigation, Supabase, dependencies, and deferred Groomer Q-104 scope are unchanged unless separately approved.
Linked files: docs/superpowers/specs/2026-07-12-ui-consistency-governance-design.md, docs/01_product/DESIGN_SYSTEM.md, docs/06_tasks/ROADMAP.md, docs/00_memory/FEATURE_INDEX.md
```

```text
Decision ID: D-030
Date: 2026-07-11
Decision: Adopt one shared Apple Maps service-address confirmation system and make private PostGIS coordinates plus the controlling radius the long-term location-matching authority.
Context: Device-localized city strings can differ across Customer and Groomer records, current city/state matching ignores ZIP and configured radii, and the Request address dropdown performed expensive per-candidate language normalization. The product needs shopping-style field semantics and address confirmation, but grooming service locations do not require a USPS-deliverability claim or a Google dependency.
Consequences: Address Line 1 excludes Unit/Apt data and Address Line 2 owns it; complete misplaced suffixes auto-move unless a conflict requires user choice. MapKit suggestions display directly, only selections/manual continuation resolve, Place ID is optional, and complete coordinates are mandatory. Exact geo metadata is private; PostGIS applies Customer travel radius for shop visits and Groomer service radius for mobile service. Legacy city/state fallback exists only through controlled backfill and is removed after a zero-gap gate. Remote migration/backfill/TestOps remain separately authorized.
Linked files: docs/06_tasks/APPLE_MAPS_ADDRESS_SYSTEM_PLAN.md, docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md, docs/02_architecture/DATA_FLOW.md
```

```text
Decision ID: D-029
Date: 2026-07-11
Decision: Automatically chain an immediately due periodic meta-review after the triggering task, then require a conversation-compaction boundary.
Context: The previous reservation rule prevented a two-task commit deadlock but still required another user turn before the reserved review ran. The user now requires due reviews to execute automatically and every completed meta-review to be followed by context compaction.
Consequences: The triggering task and meta-review retain separate task IDs, validation, closeouts, commits, and pushes; this is the only automatic exception to one task per session. After meta-review closeout, Codex invokes host compaction when callable. If the host provides no compaction API, Codex emits an explicit /compact handoff, states that compaction is pending, and stops before any implementation task.
Linked files: AGENTS.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/06_tasks/META_REVIEW_TEMPLATE.md
```

```text
Decision ID: D-028
Date: 2026-07-10
Decision: Use one T-### task per session, with session end as the default context reset and manual compaction as fallback for one oversized task.
Context: Per-turn cost scales with conversation size. The T-249 through T-257 mega-session and its unattributed modified files drove context and quota growth, while build scripts were already summary-mode and active Markdown was already minimal.
Consequences: Standard slices use focused tests plus one build; full ios-test.sh is reserved for package/integration gates, Deep tasks, shared-layer changes, and pre-release. Visual evidence stays under artifacts/evidence/<task-id>/ and is referenced by path rather than re-ingested. Full logs are read only in filtered slices. Session boundaries require a task commit or a WORKLOG-linked checkpoint(<id>) commit; stash is not a boundary mechanism. The 65%/80% thresholds govern only a single oversized in-flight task.
Linked files: AGENTS.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/05_workflow/GITHUB_RULES.md, docs/05_workflow/TOOLING_POLICY.md, .gitignore, .rgignore
```

```text
Decision ID: D-027
Date: 2026-07-10
Decision: Permit an exactly due documentation meta-review to be explicitly reserved as the immediate next task without blocking the preceding task's closeout.
Context: T-250 became the tenth completed task after T-240. The cadence check correctly required T-251, but it also prevented T-250 from passing its own Git completion gate even though CURRENT_STATE explicitly reserved T-251, creating a two-task commit deadlock.
Consequences: At a delta of exactly ten, context hygiene passes only when CURRENT_STATE names the numerically immediate next task and explicitly calls it the required periodic meta-review. Missing reservations and deltas above ten still fail. The reserved meta-review must execute next and update the marker.
Linked files: scripts/context-hygiene-check.mjs, tests/docs/context-hygiene-check.test.mjs, docs/06_tasks/META_REVIEW_TEMPLATE.md, docs/00_memory/CURRENT_STATE.md
```

```text
Decision ID: D-026
Date: 2026-07-10
Decision: Use one Beckon visual foundation with a schedule/action-oriented Groomer workspace and exactly five direct Groomer tabs.
Context: Live Simulator inspection showed the Groomer side using six equal tabs, a system-generated More screen, nested Account navigation, duplicate back buttons in Edit Profile, and card-heavy pages without a stable operational priority. The user approved the first T-249 visual direction and its Requests, Account, and Edit Profile extensions.
Consequences: R-039 targets Home, Requests, Schedule, Messages, and Account. Offers moves into a Requests Matches/Offers segment; Notifications opens from Home; Account is direct; feature editors hide the tab bar. Grouped surfaces and row separators replace per-row floating cards. Existing marketplace/backend contracts remain unchanged, and implementation is split into Q-97 through Q-104.
Linked files: docs/08_design/GROOMER_UI_REDESIGN.md, docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md, docs/01_product/DESIGN_SYSTEM.md
```

```text
Decision ID: D-025
Date: 2026-07-09
Decision: Treat Beckon as the only active product and workflow vocabulary while preserving legacy names solely in immutable history and explicit migration evidence.
Context: Q-94 renamed the local application and source, but the separately governed agent/workflow rules still used the prior product name and old Xcode credential path. Their temporary identity-audit exclusion also allowed future drift.
Consequences: AGENTS.md, CLAUDE.md, and docs/05_workflow use Beckon terminology and current ios/Beckon paths. The active identity audit now checks those files; only frozen records, applied migrations, the migration contract, and audit fixtures may retain legacy literals. Product behavior and remote state are unchanged.
Linked files: AGENTS.md, CLAUDE.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/05_workflow/STOP_CONDITIONS.md, docs/05_workflow/TOOLING_POLICY.md, scripts/beckon-identity-check.mjs
```

```text
Decision ID: D-024
Date: 2026-07-09
Decision: Maintain active Markdown with buffered entry-count windows and treat all word counts as informational telemetry.
Context: The old trigger and retained counts were identical, so every new closeout rotated one item and left the window full. Separate word limits then caused repeated trimming even when document structure was healthy, while manual compaction guidance started at only 30% of the 353,000-token context.
Consequences: Ledger uses trigger/retain 18/12; Worklog and active decisions use 14/8; decision archive pointers use 12/6 with one pointer per archive batch. Each completed rotation restores six entries. Word references never warn, fail, stop, compress, or rotate content. Manual compaction uses 65%/80% task-boundary thresholds, and completed task-specific plans/specs move to dated frozen Superpowers archives. This supersedes D-016 and the Markdown-budget parts of D-017; D-017's failed-push rule remains active.
Linked files: AGENTS.md, docs/05_workflow/CONTEXT_AND_RECOVERY.md, docs/05_workflow/SINGLE_AGENT_WORKFLOW.md, docs/05_workflow/STOP_CONDITIONS.md, scripts/context-hygiene-policy.mjs, scripts/context-hygiene-check.mjs, scripts/context-rotate.mjs
```

```text
Decision ID: D-023
Date: 2026-07-09
Decision: Replace the complete active legacy brand/project identity with Beckon through a dependency-ordered local, workflow, and remote cutover.
Context: The user finalized the brand, domain, App Store name, and tagline and explicitly required technical identifiers, files, UI, TestOps seeds, and remote state to follow the same identity.
Consequences: The canonical identity is Beckon, `com.hellobeckon.beckon`, and `com.hellobeckon.beckon://auth/callback`. R-038 uses Q-94 through Q-96 so product/source work, standalone workflow-rule changes, and authorized remote Supabase/seed-user changes remain separately reviewable. Applied migrations, frozen records, and Git history remain immutable; append-only changes replace live old identifiers.
Linked files: docs/06_tasks/BECKON_BRAND_MIGRATION.md, docs/06_tasks/ROADMAP.md, docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md
```


## Archived Decision Index

Full text for the entries below is preserved in `../09_frozen/decisions/DECISION_LOG_2026-07-08_PRE_T174_TRIM.md`.

| Date | Decision | Current entry point |
|---|---|---|
| 2026-07-12 | Archived decisions D-016 to D-022. | `../09_frozen/decisions/DECISION_LOG_D-016_TO_D-022_2026-07-12.md` |
| 2026-07-09 | Replace the active Markdown 85% cleanup trigger with structural context-budget tooling. | `../09_frozen/decisions/DECISION_LOG_D-015_2026-07-10.md` |
| 2026-07-09 | Superseded by D-016/D-017: treat the active Markdown 85% waterline as a cleanup trigger. | `../09_frozen/decisions/DECISION_LOG_D-014_2026-07-09.md` |
| 2026-07-08 | Treat task-completion commit and push as standing user-authorized Git actions. | `../09_frozen/decisions/DECISION_LOG_D-013_2026-07-09.md` |
| 2026-07-08 | Reduce active Markdown before raising the 32k total budget. | `../09_frozen/decisions/DECISION_LOG_D-012_2026-07-09.md` |
| 2026-07-08 | Keep branch baseline as a single active fact in CURRENT_STATE. | `../09_frozen/decisions/DECISION_LOG_D-011_2026-07-09.md` |
| 2026-07-08 | Track meta-review cadence by completed-task distance, not wall-clock age. | `../09_frozen/decisions/DECISION_LOG_D-010_2026-07-09.md` |
