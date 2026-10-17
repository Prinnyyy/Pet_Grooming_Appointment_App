# Reviewed SQL Drafts

This folder stores reviewed SQL drafts that were originally attached to backend task records. They are preserved for review history and are separate from the authoritative migration mirrors under `supabase/migrations/`.

## Files

- `T-015_GROOMER_OFFER_BACKEND_REVIEWED_SQL.sql`: reviewed draft for the T-015 groomer offer backend migration.
- `T-018_OFFER_ACCEPTANCE_BOOKING_REVIEWED_SQL.sql`: reviewed draft for the T-018 offer acceptance and booking backend migration.
- `T-020_BOOKING_PARTICIPANT_CHAT_REVIEWED_SQL.sql`: reviewed draft for the T-020 participant chat backend migration.

## Lookup Rule

- [T-385 final local acceptance](T-385_RELEASE_CHECKPOINT.md): dual-Simulator lifecycle/recovery, compatibility/legacy/cost/security, Realtime/notification/readback fixes, full regression and exact cleanup. Physical devices, signing and store distribution are excluded.
- [T-384 core-first loading](T-384_CORE_LOADING_ACCEPTANCE.md): fixed measurements, optional failure isolation, stale-load protection and full client acceptance; no SQL migration.
- [T-383 password recovery](T-383_PASSWORD_RECOVERY_ACCEPTANCE.md): delivered email, isolated SDK recovery, account cleanup and UI/integration acceptance; no SQL migration.
- [T-379 scoped reads](T-379_SCOPED_READ_ACCEPTANCE.md) and [T-380 bounded chat summaries](T-380_CHAT_SUMMARY_ACCEPTANCE.md): complete date/exact reads and deployed one-summary-per-conversation acceptance. [Chat rollback vectors](T-380_CHAT_SUMMARY_ASSERTIONS.sql) require caller-owned rollback.
- [T-377 fulfillment acceptance](T-377_FULFILLMENT_ACCEPTANCE.md): deployed lifecycle, resource release and actual contention evidence. [Rollback lifecycle vectors](T-377_FULFILLMENT_ASSERTIONS.sql) require caller-owned rollback and the named T-376 fixture setup.
- [T-378 rescheduling acceptance](T-378_RESCHEDULING_ACCEPTANCE.md): deployed bilateral time changes, original-allocation retention and both real race orders. [Rollback vectors](T-378_RESCHEDULING_ASSERTIONS.sql) require the named T-376 setup and existing T-377 fixture helper.

- [T-376 agreement acceptance](T-376_AGREEMENT_ACCEPTANCE.md): immutable agreements, versioned replacement/acceptance, deployed SQL/HTTP and runtime evidence. [Installed rollback vectors](T-376_AGREEMENT_ASSERTIONS.sql) require the named isolated TestOps identities and a caller-owned rollback transaction.

- T-375/WP-04 deployed: [acceptance](T-375_MATCHING_ACCEPTANCE.md). Historical pre-deploy [core vectors](T-375_MATCHING_CORE_ASSERTIONS.sql), [matching/publication/reader/writer vectors](T-375_MATCHING_EVALUATOR_ASSERTIONS.sql), and [bounded cost probe](T-375_MATCHING_COST_PROBE.sql) assume a fresh migration/queue inside rollback; do not rerun wholesale against the installed active queue.

- [T-374 timing backend acceptance](T-374_TIMING_BACKEND_ACCEPTANCE.md): deployed state, real admission/Save lock contention in both orderings, exact restoration and open gates.
- [T-374 timing UI acceptance](T-374_TIMING_UI_ACCEPTANCE.md): scoped changed-flow evidence and remaining cases.

T-371 validation artifacts (historical acceptance, not migration sources or open tasks):

- [Availability acceptance](T-371_AVAILABILITY_ACCEPTANCE.md): implementation, actual SQL/HTTP/UI evidence, restoration and remaining release limits.

- [Atomic save rollback validation](T-371_ATOMIC_AVAILABILITY_ROLLBACK_VALIDATION.sql): three write-boundary failures, revision conflict, signed-out/anonymous checks; authenticated-role run completed 2026-09-07.
- [Availability authorization validation](T-371_AVAILABILITY_AUTHORIZATION_VALIDATION.sql): named cross-account fixtures, spoofed ownership payload, customer denial, and actual direct-write rejection; rollback run completed 2026-09-07.

For deployed backend state, prefer `../../03_backend/SUPABASE_CONTRACT.md` and `../../../supabase/migrations/`. Use these reviewed SQL drafts only when the review discussion or pre-migration draft history matters.
