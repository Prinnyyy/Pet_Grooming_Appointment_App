# T-071 Groomly Availability Enforcement

## Status

Completed.

## Mode

Deep. This task changes deployed Supabase RPC behavior and adds a small iOS repository/store error mapping for the new groomer-side availability rejection.

## Goal

Enforce existing groomer weekly availability, booking preferences, and time off before a groomer can submit an offer or a customer can accept an old offer.

## Scope

In scope:

- Add a private SQL helper that evaluates a proposed booking range against:
  - enabled `groomer_availability_windows` in the groomer's configured timezone;
  - `groomer_time_off_windows`;
  - `groomer_booking_preferences.minimum_advance_notice_days`;
  - `groomer_booking_preferences.max_appointments_per_day`;
  - existing non-cancelled bookings for overlap and daily capacity.
- Replace `create_groomer_offer` internals without changing its signature or result shape.
- Replace `accept_groomer_offer` internals without changing its signature or result shape.
- Keep the customer acceptance error mapped to existing `booking_conflict`.
- Add iOS mapping for the new `P0001/groomer_unavailable` offer-submission error.

Out of scope:

- Request matching distribution.
- Customer-facing slot discovery or direct booking.
- Auto-accept behavior.
- Multiple availability windows per day.
- Public groomer directory, payments, notifications, Storage, or new tables.

## Implementation Summary

- Added migration `supabase/migrations/20260625073116_t071_availability_enforcement.sql`.
- Added private helper `app_private.groomer_is_available_for_range(uuid, timestamptz, timestamptz)`:
  - `SECURITY INVOKER`;
  - empty `search_path`;
  - no `anon` or `authenticated` execute privilege;
  - `service_role` execute privilege.
- Updated `create_groomer_offer` to reject unavailable proposed ranges with `P0001/groomer_unavailable`.
- Updated `accept_groomer_offer` to recheck availability at acceptance and reject stale unavailable offers with `P0001/booking_conflict`.
- Added transaction-scoped advisory locking per groomer around the availability check to serialize capacity-sensitive offer/acceptance decisions.
- Added `GroomerRequestRepositoryError.groomerUnavailable`, Supabase error mapping, and a groomer request store message.

## Supabase Migration

- Remote project: `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb`.
- Applied remote migration:
  - Version: `20260625073709`
  - Name: `t071_availability_enforcement`
- Local mirror:
  - `supabase/migrations/20260625073116_t071_availability_enforcement.sql`

## Validation

- RED rollback-only remote SQL failed before implementation because current RPCs allowed:
  - offer creation outside weekly hours;
  - offer creation during time off;
  - offer creation inside the minimum advance notice window;
  - offer creation after max daily appointment capacity;
  - accepting a stale offer during time off.
- RED targeted Swift test failed before implementation because `GroomerRequestRepositoryError.groomerUnavailable` did not exist.
- Supabase MCP migration application succeeded.
- GREEN rollback-only remote SQL passed for all availability cases and returned `auth_residue = 0`.
- Metadata/grant checks confirmed:
  - helper is not `SECURITY DEFINER`;
  - helper has empty `search_path`;
  - helper is not executable by `anon` or `authenticated`;
  - `create_groomer_offer` and `accept_groomer_offer` remain `SECURITY DEFINER` with empty `search_path`;
  - public RPCs remain executable by `authenticated`/`service_role`, not `anon`.
- Supabase security advisor returned only existing intentional `SECURITY DEFINER` RPC warnings plus leaked-password protection.
- Supabase performance advisor returned no issues.
- `./scripts/supabase-check.sh` passed.
- GREEN targeted Swift test passed:
  - `GroomerRequestsStoreTests/submitOfferUnavailableRangePreservesMatchAndShowsAvailabilityError`
- Final `git diff --check` passed.
- Final `./scripts/ios-build.sh` passed for `platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro`.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17 Pro` iOS 26.5 simulator (`45D452E8-DC6C-4CD4-A747-4D21671E68A6`) and launched `com.prinnyyy.PetGroomerMarketplace` with pid `70173`.

## Risks and Follow-ups

- Availability is enforced at offer creation and offer acceptance only. Request matching still does not filter by current availability, and customers still do not browse live slots.
- Groomers with no enabled weekly availability rows cannot submit offers until they save availability. This matches the current Availability UI default, where all days start disabled.
- `auto_accept_bookings` remains persisted but unused.
- Exact customer-facing slot discovery and direct booking remain deferred.
