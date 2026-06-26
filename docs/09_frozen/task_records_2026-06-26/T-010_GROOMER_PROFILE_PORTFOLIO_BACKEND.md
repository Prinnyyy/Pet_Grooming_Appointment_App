# T-010 — Groomer Profile and Portfolio Backend

## Status

- Mode: Deep.
- State: completed.
- Authorized Supabase target: `Pet Groomer Marketplace` / `lqmasbuqzvcvtawonjlb` only.
- Legacy project `swdiiyypysyxbnfrxxsv` remains forbidden.

## Goal

Add the backend contract for groomer profile details, groomer-owned services, groomer portfolio metadata, and the `groomer-portfolio` Storage bucket.

## Scope

In scope:

- Extend `groomer_profiles` from the T-004 role marker into the Fresh Brief groomer profile shape.
- Add `groomer_services`.
- Add `groomer_portfolio_photos`.
- Add the private `groomer-portfolio` bucket with authenticated-read / owner-write Storage policies.
- Add explicit grants, RLS policies, constraints, indexes, and backend documentation.

Out of scope:

- iOS groomer profile UI.
- Service or portfolio repositories.
- Request matching, offers, bookings, chat, or reviews.
- Public unauthenticated portfolio access.
- Supabase CLI or direct database tools.

## Migration Record

Applied local mirrors:

- `supabase/migrations/20260620224418_t010_groomer_profile_portfolio_backend.sql`
- `supabase/migrations/20260620225308_t010_merge_groomer_select_policies.sql`

Applied remote migrations:

- Version: `20260620224418`
- Name: `t010_groomer_profile_portfolio_backend`
- Version: `20260620225308`
- Name: `t010_merge_groomer_select_policies`

## Contract Summary

### `groomer_profiles`

T-010 adds:

- `business_name`
- `bio`
- `years_experience`
- `base_city`
- `base_state`
- `service_radius_miles`
- `rating_avg`
- `rating_count`
- `is_active`
- `is_verified`

Groomers may update marketplace profile fields and `is_active` for their own row only. Rating and verification fields are server-maintained and not granted to authenticated clients for direct update.

Active marketplace visibility requires at least `business_name`, `base_city`, `base_state`, and `service_radius_miles`.

### `groomer_services`

Groomer-owned service offerings with title, optional description, base price, duration, accepted pet sizes, active flag, and timestamps.

Access:

- Owner groomer can select, insert, update, and delete own services.
- Authenticated users can select active services for active groomers.
- Anonymous access is denied.

### `groomer_portfolio_photos`

Groomer-owned metadata rows for `groomer-portfolio` Storage objects.

Access:

- Owner groomer can select, insert, update caption/sort order, and delete own portfolio metadata.
- Authenticated users can select portfolio metadata for active groomers.
- Storage path must match `{groomer_id}/{file_id}.{jpg|jpeg|png|heic|heif}`.

### `groomer-portfolio` Storage

Private bucket:

- Maximum file size: 10 MiB.
- Allowed MIME types: JPEG, PNG, HEIC, HEIF.
- Owner upload/update/delete only under `{groomer_id}/`.
- Authenticated non-owner reads are limited to download/authenticated object reads for objects with metadata attached to an active groomer.
- Broad authenticated bucket listing is not enabled.

## Validation Plan

Completed validation:

1. Remote primary migration apply passed and migration record `20260620224418` was confirmed.
2. Remote corrective migration apply passed and migration record `20260620225308` was confirmed.
3. Tables, columns, constraints, indexes, grants, bucket, and RLS/Storage policies were verified through CLI-backed metadata queries.
4. Rollback-only remote access checks passed before and after the corrective policy merge:
   - Groomer can update own `groomer_profiles`.
   - Groomer cannot update another groomer profile.
   - Customer cannot insert/update groomer services.
   - Groomer can manage own service and portfolio metadata.
   - Authenticated users can read active groomer services/portfolio metadata.
   - Inactive groomer services/portfolio metadata are hidden from non-owner users.
   - Portfolio Storage insert accepts only owner-scoped paths.
   - Portfolio Storage insert rejects cross-owner paths and invalid extensions.
   - Portfolio authenticated read is tied to active groomer metadata and does not open broad listing.
5. Rollback cleanup confirmed zero remaining validation Auth users, profiles, services, portfolio metadata, or Storage objects.
6. Supabase CLI security advisor returned 0 lints.
7. Supabase CLI performance advisor's T-010 multiple-permissive SELECT WARNs were resolved by the corrective migration. Remaining performance INFOs are non-blocking:
   - Existing T-008 `pet_photos_pet_owner_fkey` composite-FK index advisory, already reviewed in T-008.
   - T-010 `groomer_profiles_active_city_idx` unused-index INFO; expected until T-011+ production queries exercise active groomer discovery.
8. `./scripts/supabase-check.sh` passed.
9. `git diff --check` passed.

No iOS build, unit tests, or UI tests are planned for T-010 because this is backend-only.

## Closeout

T-010 is complete. Do not start T-011 UI work automatically.
