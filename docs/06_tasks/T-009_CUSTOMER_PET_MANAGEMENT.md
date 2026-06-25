# T-009 — Customer Pet Management

## Status

Completed on 2026-06-20. iOS tests passed, and the approved remote Storage API
upload/delete smoke passed against the fresh Supabase project.

## Primary Task

Implement customer pet profile management in the iOS app using the T-008
`pets`, `pet_photos`, and private `pet-photos` Storage contract.

## Scope

- Add customer pet and pet-photo Swift models.
- Add a `CustomerPetRepository` boundary and Supabase-backed implementation.
- Add Customer Home pet list, add/edit form, soft-delete action, photo upload,
  and photo delete controls.
- Keep photo display metadata-only for now; signed URL/image download UX remains
  out of scope.
- Add focused unit tests for form validation, local state transitions, and
  Storage path contract.

## Out of Scope

- Supabase migrations or schema changes.
- Groomer profile/portfolio, grooming requests, offers, bookings, chat, reviews.
- Runtime mock success or seeded demo data.
- Commit or push.

## Validation Plan

- Run one iOS validation attempt.
- Do not run a build/test fix loop without user approval.
- Actual remote Storage API upload/delete smoke requires explicit approval if it
  needs temporary remote test data.

## Validation Result

- Initial `./scripts/ios-test.sh` attempt exposed a static-call compile error
  in `SupabaseCustomerPetRepository`.
- The first approved fix exposed a Swift 6 actor-isolation issue in the new
  path-contract test.
- The second approved fix passed `./scripts/ios-test.sh` with 24 Swift Testing
  tests and 1 XCTest UI smoke test.
- After explicit user approval, the remote smoke created a temporary
  authenticated customer, ran the real REST/RPC/Storage path, and passed:
  sign-in, `create_my_profile`, pet insert, private `pet-photos` object upload,
  `pet_photos` metadata insert, Storage API object delete, metadata delete, and
  pet soft-delete.
- Supabase cleanup deleted the temporary Auth user and confirmed zero remaining Auth
  user, profile, customer profile, pet, pet photo, or `pet-photos` object rows
  for the smoke user.
- No Supabase CLI command, migration, schema change, or persistent test data was
  created.

## Stop Condition

Stop when the customer pet management code is implemented, one validation
attempt has run or the first real blocking validation issue is reported, durable
memory is updated, and the current diff is reviewed.
