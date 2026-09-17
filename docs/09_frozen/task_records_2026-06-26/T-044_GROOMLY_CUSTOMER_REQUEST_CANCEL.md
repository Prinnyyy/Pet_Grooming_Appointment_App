# T-044 Groomly Customer Request Cancel

Task ID: `T-044`

Mode: `Deep`

Date: `2026-06-22`

## User Request

Change the Customer Requests page action row so the former `Edit` button is always a fixed `Detail` button, because the app does not support editing a published quest. Implement the `Cancel` button: confirmed quests cannot be cancelled, and unconfirmed quests can be cancelled.

The user also asked to re-check whether an existing cancel method already exists under another name before adding backend behavior. If none exists, the user authorized adding and deploying a controlled Supabase RPC, with detailed documentation in the relevant markdown task file.

## Existing Capability Audit

Local and remote checks found no customer request cancellation path.

- Swift `CustomerRequestRepository` exposed only `requests`, `offers`, and `createRequest`.
- `SupabaseCustomerRequestRepository` called only `create_grooming_request` for customer request writes.
- Existing cancel behavior was limited to `BookingRepository.cancelBooking` / Supabase RPC `cancel_booking`.
- Existing groomer-side close behavior was limited to `withdraw_groomer_offer`.
- `grooming_requests` includes a `cancelled` status value, but authenticated clients have no direct update grant.
- `SUPABASE_CONTRACT.md`, `RLS_RPC_POLICY.md`, `FEATURE_INDEX.md`, and earlier task docs record customer request cancellation as deferred.
- Remote `pg_proc` inspection on fresh project `lqmasbuqzvcvtawonjlb` listed `accept_groomer_offer`, `cancel_booking`, `complete_booking`, `create_groomer_offer`, `create_grooming_request`, `dismiss_request_match`, and `withdraw_groomer_offer`; no request-cancel function existed.

The migration filename is kept as the existing local timestamped file and is not regenerated.

## Primary Task

Add a real, controlled customer request cancellation flow and wire it to the Customer Requests action row.

Target screen and role:

- Screen: `CustomerRequestsView`
- Role: `Customer`

## Backend Contract

New RPC:

```sql
cancel_grooming_request(p_request_id uuid)
```

Returns:

- `request_id`
- `request_status`
- `cancelled_timestamp`

Allowed:

- Authenticated, non-anonymous customer.
- Customer must own the request.
- Request status must be `open` or `has_offers`.

Rejected:

- Anonymous or unauthenticated caller.
- Non-customer caller.
- Missing or unrelated request.
- `booked`, `cancelled`, or `expired` request.

Side effects:

- Updates `grooming_requests.status` to `cancelled`.
- Converts pending `groomer_offers` for that request to `declined_by_customer`.
- Hides visible/viewed/offered `request_matches` for that request.

Confirmed/booked requests remain final and cannot be cancelled through this request RPC. Booking cancellation remains owned by the existing `cancel_booking` flow.

## Implementation Plan

1. Create a T-044 migration with the controlled `cancel_grooming_request` RPC and narrow execute grants.
2. Deploy the migration to fresh project `lqmasbuqzvcvtawonjlb` through Supabase CLI.
3. Add iOS repository result types, protocol method, Supabase RPC adapter, and error mapping.
4. Add `CustomerRequestsStore.cancel(_:)` with busy state, local status replacement, and refresh fallback messaging.
5. Change Customer Requests action row from dynamic `Edit`/`Detail` to fixed `Detail`; wire `Cancel` to the store with confirmation and disabled state for confirmed/closed requests.
6. Update relevant docs and memory.
7. Validate backend and iOS, then launch the app in Simulator for inspection.

## Validation Plan

Backend:

```sh
./scripts/supabase-check.sh
```

Supabase CLI:

- Apply migration to `lqmasbuqzvcvtawonjlb`.
- Inspect function metadata/grants.
- Run rollback-only behavior checks for open request cancellation and booked request rejection when feasible.
- Run security and performance advisors.

iOS/basic:

```sh
git diff --check
./scripts/ios-build.sh
```

Completion launch:

- Launch the app in the iOS Simulator for user inspection.

## Closeout

Status: `completed`

Changed files:

- `docs/06_tasks/T-044_GROOMLY_CUSTOMER_REQUEST_CANCEL.md`
- `supabase/migrations/20260622142020_t044_cancel_grooming_request.sql`
- `docs/03_backend/SUPABASE_CONTRACT.md`
- `docs/03_backend/RLS_RPC_POLICY.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/WORKLOG.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Models/CustomerRequest.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Repositories/CustomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Core/Infrastructure/Supabase/SupabaseCustomerRequestRepository.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`

Implementation:

- Confirmed locally and remotely that no existing customer request cancellation method or RPC existed.
- Added and deployed `cancel_grooming_request(p_request_id uuid)` to fresh project `lqmasbuqzvcvtawonjlb`.
- Added `CancelGroomingRequestResult`, `CustomerRequestRepository.cancelRequest(requestID:)`, Supabase RPC adapter call, and stable repository error mapping for `request_not_found` / `request_not_cancellable`.
- Added `CustomerRequestsStore.cancel(_:)`, per-request cancellation busy state, local request status replacement, and pending-offer local state closure.
- Changed Customer Requests card actions so `Detail` is fixed for every request. `Cancel` is enabled only for `open` / `has_offers`, shows confirmation, and calls the real Store/repository/RPC path.
- Updated preview/test fakes and added Store tests for successful open-request cancellation and booked-request non-cancellation.

Backend validation:

- Remote migration application passed for `t044_cancel_grooming_request` on `lqmasbuqzvcvtawonjlb`.
- Remote metadata check confirmed `cancel_grooming_request(p_request_id uuid)` is `SECURITY DEFINER`, owned by `postgres`, and executable by `authenticated`, `service_role`, and owner `postgres`; no `anon` execute grant.
- Rollback-only behavior check passed:
  - `has_offers` request transitioned to `cancelled`.
  - Pending offer transitioned to `declined_by_customer`.
  - Offered match transitioned to `hidden`.
  - `booked` request raised `request_not_cancellable`.
  - Validation rows rolled back; follow-up count returned zero temporary auth users, requests, offers, and matches.
- Security advisor passed with expected controlled-RPC WARNs, including the new `cancel_grooming_request` authenticated SECURITY DEFINER WARN.
- Performance advisor returned existing INFOs only.
- `./scripts/supabase-check.sh` passed.

iOS validation:

- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- `./scripts/ios-test.sh` passed, including the Swift Testing suite and 1 UI smoke test.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- App launched successfully for inspection.
- Screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_297ba9f4-87b8-40b8-941d-a05341dc81bb.jpg`

Risks:

- The new RPC intentionally adds one authenticated SECURITY DEFINER advisor WARN, consistent with the existing controlled RPC pattern.
- `cancel_grooming_request` does not cancel confirmed bookings. Booked request/booking lifecycle remains owned by `accept_groomer_offer` and `cancel_booking`.
- Request editing and rebooking remain out of scope.

## Review Follow-Up

Date: `2026-06-22`

External review result: passed.

Immediate follow-up changes:

- Changed the local migration statement from `create function` to `create or replace function` so the migration body is safer to replay in a development database without changing the deployed RPC signature or behavior.
- Removed one extra blank line in `CustomerRequestsStore.applyCancellationResult`.
- Recorded the review follow-up in `WORKLOG.md`.

Follow-up validation:

- `git diff --check` passed.
- `./scripts/supabase-check.sh` passed.
- `./scripts/ios-build.sh` passed.
- `./scripts/ios-test.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- Screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_611f4550-f654-4653-a288-7436c6ff1f47.jpg`

Not changed:

- Did not add a separate `cancelled_at` column. That would be a schema and contract expansion beyond the immediate review follow-up; the current RPC continues to return the cancellation update timestamp.
