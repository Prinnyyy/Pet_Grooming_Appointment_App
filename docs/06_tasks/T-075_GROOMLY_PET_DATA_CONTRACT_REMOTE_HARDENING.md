# T-075 Groomly Pet Data Contract Remote Hardening

## Status

- Status: Completed on 2026-06-25
- Mode: Deep
- Owner: Codex

## Goal

Repair and validate the local T-050 pet data contract migration before any remote deployment.

## Scope

In scope:

- Harden `supabase/migrations/20260623013113_t050_pet_fixed_taxonomy_derived_size.sql`.
- Keep fixed pet species, breed, temperament, weight range, and weight-derived size.
- Validate authenticated pet writes against the linked project inside rollback-only SQL.
- Confirm private helper permissions do not expose unrelated `app_private` helpers.

Out of scope:

- Remote migration apply, migration repair, or `db push`.
- Backend contract/RLS doc changes for deployed behavior.
- iOS pet UI, repository, model, or Store changes.
- Matching, offers, bookings, reviews, Storage policy changes, or public groomer directory behavior.

## Implementation Summary

- Replaced the T-050 workaround that granted `authenticated` execute on `app_private.pet_size_code_for_weight_lbs(numeric)`.
- Kept the size mapping helper private with execute granted to `service_role` only.
- Changed `app_private.set_pet_size_from_weight()` to `SECURITY DEFINER` with empty `search_path` so the trigger can derive size without client helper execute.
- Replaced `pets_size_derived_from_weight_check` helper usage with an inline `CASE` expression, avoiding authenticated CHECK-time access to `app_private`.
- Left the `pet-photos` bucket configuration, fixed taxonomy values, weight range, and trigger name unchanged.

## Validation

- Supabase changelog/docs review: checked current Supabase changelog and Data API/RLS docs. Relevant note: public schema object exposure now depends on explicit grants; T-075 does not add a new public table or remote object.
- Remote metadata check confirmed project `lqmasbuqzvcvtawonjlb` still has T-008 `pets` constraints and `pet-photos` bucket, and T-050 is not remotely deployed.
- RED/diagnostic rollback SQL against the linked project applied the previous local T-050 draft inside `BEGIN ... ROLLBACK` and confirmed `authenticated_can_execute_helper = true`.
- Corrected rollback metadata SQL applied the hardened local draft and confirmed:
  - `authenticated_can_execute_helper = false`
  - `service_role_can_execute_helper = true`
  - `trigger_function_security_definer = true`
  - `derived_check_has_no_private_helper = true`
- Rollback-only authenticated behavior SQL passed after one harness fix:
  - valid authenticated insert derived `size = 'S'` from `weight_lbs = 12` while ignoring user-supplied `size = 'Giant'`;
  - authenticated update to `weight_lbs = 45` derived `size = 'L'`;
  - authenticated size-only update stayed derived as `size = 'L'`;
  - invalid species, breed, temperament, and out-of-range weight were rejected;
  - authenticated direct helper execution was denied;
  - rollback left one valid pet row only inside the transaction.
- Independent residue check after rollback returned zero auth user, profile, customer profile, and pet rows for the T-075 validation identity.
- Supabase security advisor ran on the current remote baseline. It reported existing intentional authenticated `SECURITY DEFINER` RPC warnings and leaked-password protection; T-075 added no remote function.
- Supabase performance advisor ran on the current remote baseline. It reported existing INFO-level foreign-key/index findings; T-075 added no remote table/index.
- `./scripts/supabase-check.sh`: passed.
- `git diff --check`: passed.

## Notes

- This task itself performed no remote schema write. After this closeout, the user explicitly authorized T-050 deployment; `20260623013113_t050_pet_fixed_taxonomy_derived_size` was then applied to `lqmasbuqzvcvtawonjlb` and validated in the T-050 task doc.
- The first authenticated behavior batch failed because the validation harness attempted to insert into generated `auth.users.confirmed_at`; the batch was corrected to omit that generated column and rerun.

## Closeout

T-075 is complete as a local migration hardening and rollback-validation task. The hardened T-050 pet contract migration was later remotely applied after separate explicit authorization.

Next executable pet-fit task is T-076 only after explicit user authorization.
