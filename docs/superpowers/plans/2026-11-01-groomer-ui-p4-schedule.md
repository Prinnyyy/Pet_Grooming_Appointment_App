<!-- task-artifact
task: T-432
status: completed
type: plan
-->

# Handoff 4 P4 — agenda and booking

Reads: section 3 items 7, 8, 14; D2 service-only gaps (explicitly approved), D4 existing booking snapshot visibility; appendix A P4. User-approved new UI/UX governs.

- [x] Agenda and shared booking details from named twins, customer branch preserved.
- [x] Store-owned weekly windows, role-aware cards/timeline and existing mutation/recovery guards.
- [x] Remove superseded sections, validate schedule rules and shared booking actions; report per section 10 and continue P5.

## Section 10 report

Timing SQL remains P7; final backend integration is not claimed before that package.

Ported file/twin map: five `Features/Groomer/Schedule/` files from the named P4 prototype twins; `BookingsView` delegates groomer agenda/detail while its customer composition and public entry points remain; shared `GroomingDetailParts` extracts appointment/partner blocks and the role-aware timeline; `GroomingDetailActions` adopts groomer labels/IDs. The ⚑ `GroomingDetailView` retains production loading, cancellation, typed routes, retry, and optional booking protections: only its booking timeline is shared. No fixture fallback enters runtime. Superseded fulfillment/reschedule section compositions are removed; the reschedule timing row remains for legacy callers. `GroomerTabView` now passes its retained booking Store and empty-day Requests action.

`BookingsStore` retains validated availability windows with its calendar. Agenda reads the continuous visible seven-day window with the existing bounded, fully paginated operation, then filters the selected day; partial general lists cannot undercount its day bars. Calendar arithmetic handles DST. Snapshot pet/service notes are already in the participant-authorized booking contract (D4); no grants broadened. The service-only gap is D2/D-069; timing SQL and remaining dialog wording are coordinated in P7. Shared status values preserve the prototype's labels and tones. User-owned prototype/signing/governance files were preserved.

Added `GroomerAgendaTests`: exact start/end clock phases, service-only gaps (including subminute overlap), bounded displayed days across DST, validated hours rejection. Adapted the old reschedule section render test to the shared times block and the retired-section source assertion to the shared destructive dialog. Debug generic Simulator build, Release generic Simulator build, **15/15** relevant Simulator tests (zero skips/failures), **29/29** Node source/boundary/audit tests, preflight, UI audit, document hygiene and whitespace passed. Evidence `/tmp/beckon-handoff4/p4-*`. Initial compile failures were removed-helper enums and a leftover result-builder annotation; corrected before passing validation. Seven resolved old baseline entries pruned; no error suppression. Visual sign-off remains the user's; final integrated tap-through belongs to P8.

Decisions: D1/D3/D5/D6/D7/D9 retained; D2 approved (P7 deployment still outstanding), D4 implemented without wider reads, D8 chat unchanged, D10 P6. Continue P5 without session stop.
