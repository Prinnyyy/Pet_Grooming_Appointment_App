# Reviewed SQL Drafts

This folder stores reviewed SQL drafts that were originally attached to backend task records. They are preserved for review history and are separate from the authoritative migration mirrors under `supabase/migrations/`.

## Files

- `T-015_GROOMER_OFFER_BACKEND_REVIEWED_SQL.sql`: reviewed draft for the T-015 groomer offer backend migration.
- `T-018_OFFER_ACCEPTANCE_BOOKING_REVIEWED_SQL.sql`: reviewed draft for the T-018 offer acceptance and booking backend migration.
- `T-020_BOOKING_PARTICIPANT_CHAT_REVIEWED_SQL.sql`: reviewed draft for the T-020 participant chat backend migration.

## Lookup Rule

Current T-371 validation artifacts (not migration sources):

- [Availability acceptance](T-371_AVAILABILITY_ACCEPTANCE.md): implementation, actual SQL/HTTP/UI evidence, restoration and remaining release limits.

- [Atomic save rollback validation](T-371_ATOMIC_AVAILABILITY_ROLLBACK_VALIDATION.sql): three write-boundary failures, revision conflict, signed-out/anonymous checks; authenticated-role run completed 2026-09-07.
- [Availability authorization validation](T-371_AVAILABILITY_AUTHORIZATION_VALIDATION.sql): named cross-account fixtures, spoofed ownership payload, customer denial, and actual direct-write rejection; rollback run completed 2026-09-07.

For deployed backend state, prefer `../../03_backend/SUPABASE_CONTRACT.md` and `../../../supabase/migrations/`. Use these reviewed SQL drafts only when the review discussion or pre-migration draft history matters.
