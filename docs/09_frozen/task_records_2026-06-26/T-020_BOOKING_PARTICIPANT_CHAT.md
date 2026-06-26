# T-020 — Booking Participant Chat

## Status

- Mode: Deep.
- State: completed.
- Depends on: T-018 booking/conversation backend and T-019 booking UI.
- Authorized Supabase target: `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb` only.
- Legacy project `swdiiyypysyxbnfrxxsv` remains forbidden.

## Goal

Add basic participant-only chat for accepted-booking conversations.

## Scope

In scope:

- Add a backend `messages` table for text-only conversation messages.
- Allow only the booking customer and groomer attached to a `conversation` to read and send messages.
- Keep writes direct and RLS-controlled; do not add a message RPC unless validation proves direct insert is insufficient.
- Add iOS chat models, repository boundary, Supabase adapter, conversation list, message list, and send form.
- Connect both role Messages tabs to the real participant conversation UI.
- Show booking schedule/price context on conversations and, where existing RLS allows it, the customer-side active groomer business name; otherwise fall back to short support references.
- Add focused store tests for loading conversations, loading messages, sending, trimming/validation, and safe error messages.

Out of scope:

- Realtime subscriptions, typing indicators, read receipts, push notifications, attachments, moderation tools, blocking/reporting, and message deletion/editing.
- Booking completion, reviews, dispute flow, payments, request cancellation, or rebooking.
- Supabase CLI, local Supabase stack, direct database tools, or legacy project inspection.

## SQL Review Draft

Reviewed SQL draft:

- `docs/06_tasks/sql_reviews/T-020_BOOKING_PARTICIPANT_CHAT_REVIEWED_SQL.sql`

The user approved this SQL and it was applied remotely as migration `20260621055915`.

## Backend Contract

### `messages`

Text-only messages under a T-018 `conversation`.

Columns:

- `id`
- `conversation_id`
- `sender_id`
- `body`
- `created_at`

Access:

- Authenticated, non-anonymous conversation participants can select messages for their conversations.
- Authenticated, non-anonymous conversation participants can insert messages only as themselves.
- Authenticated clients cannot update or delete messages.
- `service_role` has full table privileges.

Validation:

- `body` must already be trimmed and between 1 and 4000 characters.
- Client UI trims before send; the database constraint is the final authority.

## Validation Plan

After explicit SQL approval:

1. Apply the reviewed SQL with `supabase db push --linked` to the linked `lqmasbuqzvcvtawonjlb` project.
2. Verify with CLI-backed metadata/read-only SQL:
   - migration is listed,
   - `messages` exists with RLS enabled,
   - `authenticated` has `SELECT` and column-scoped `INSERT`,
   - exactly one `SELECT` and one `INSERT` policy exist,
   - no update/delete grants exist for `authenticated`.
3. Run rollback-only remote behavior checks:
   - booking customer can insert/read own conversation messages,
   - booking groomer can insert/read own conversation messages,
   - non-participant cannot read or insert,
   - anonymous/invalid sender insert is rejected,
   - blank/oversized body is rejected,
   - cleanup leaves zero validation rows.
4. Run Supabase CLI security/performance advisors and record findings.
5. Run `./scripts/supabase-check.sh`.
6. Run one iOS validation attempt: `./scripts/ios-test.sh`.
7. Run `git diff --check`.

If a validation fails, report the first real error and stop unless the user approves a targeted follow-up.

## Closeout

T-020 is complete. The backend text-message contract is deployed and mirrored, customer/groomer Messages tabs load participant conversations with booking context, and participants can load/send trimmed text-only messages through repository boundaries.

Validation completed:

- Supabase CLI migration apply passed as version `20260621055915`.
- CLI-backed metadata checks confirmed `messages` exists with RLS enabled, one SELECT policy, one INSERT policy, authenticated SELECT plus column-scoped INSERT, and no authenticated UPDATE/DELETE.
- Rollback-only behavior checks passed for customer/groomer participant reads/inserts, non-participant denial, anonymous-authenticated denial, body constraint rejection, and zero persisted validation rows. Two initial validation attempts failed due to test-harness setup only: `auth.users.instance_id` needed uuid casting and the temporary ID table needed authenticated SELECT during simulated RLS checks.
- Supabase CLI security advisor returned the existing six intentional SECURITY DEFINER WARNs from T-012/T-015/T-018; T-020 adds no definer functions.
- Supabase CLI performance advisor returned existing INFOs plus expected unused-index INFOs for `messages` indexes before production query traffic.
- `./scripts/supabase-check.sh` passed.
- `./scripts/ios-test.sh` passed with 62 Swift Testing tests and 1 XCTest UI smoke test after a targeted Swift 6 return/isolation fix in the post-review chat summary follow-up.
- `git diff --check` passed.

Review follow-up resolved the immediately actionable UX issue without adding SQL: chat conversations now include participant-readable booking schedule/price context, and customers see an active groomer's public business name when `groomer_profiles` RLS permits it. Groomer-side customer display names remain support references until a future customer-profile presentation contract exists.

Realtime subscriptions, attachments, read receipts, typing indicators, moderation, push notifications, completion, and reviews remain out of scope.
