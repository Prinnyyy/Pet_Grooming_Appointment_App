# T-008 — Pet Data and Photo Storage Contract

## Status

Completed on 2026-06-20. Approved migration
`20260620192648_t008_pet_data_photo_storage` is
deployed to the authorized fresh project and mirrored locally. CLI-backed metadata
inspection confirmed the tables, constraints, indexes, grants, RLS policies,
trigger, private bucket, and Storage policies. The first rollback batch stopped
on an empty-row harness assertion. The separately approved corrected batch
passed owner, cross-customer, Groomer, anonymous-authenticated, constraint,
upload, and inactive-pet assertions, then stopped when
`storage.protect_delete()` rejected direct SQL deletion from `storage.objects`
and required the Storage API. Both transactions rolled back; the final
read-only safety check found zero validation users, profiles, pets, photo rows,
or Storage objects. Under the separately approved CLI-only closeout boundary,
metadata inspection confirmed that the authenticated DELETE policy exactly
matches the behavior-tested owner-only SELECT predicate. Security advisor
returned zero lints. The performance advisor's one composite-foreign-key INFO
was reviewed as non-blocking because the existing B-tree contains both equality
columns. Static Supabase and diff checks passed. Actual Storage API upload/delete
is an explicit T-009 integration acceptance item.

## Primary Task

Add the backend contract for customer-owned pets, pet-photo metadata, and a
private pet-photo Storage bucket. This task is backend-only.

## Dependencies

- T-004 profile tables, customer role marker, grants, and RLS are deployed.
- T-007 atomic role onboarding is deployed.
- The only authorized Supabase target is the fresh project
  `lqmasbuqzvcvtawonjlb`.

## Approved Design

- `docs/superpowers/specs/2026-06-20-t008-pet-data-photo-storage-design.md`
- Use direct owner-scoped CRUD rather than an RPC because T-008 has no
  multi-row business transition requiring atomic server orchestration.
- Pet deletion is a soft-delete transition through `is_active` and
  `deleted_at`; authenticated clients receive no hard-delete privilege on
  `pets`.
- Pet-photo metadata uses a composite pet/owner foreign key and immutable
  ownership/path columns.
- The `pet-photos` bucket is private and accepts only an authenticated Customer
  uploading to an active owned pet path.
- Groomers, other customers, anonymous users, and anonymous authenticated
  identities receive no pet or pet-photo access.

## In Scope

- One reviewed migration for `pets`, `pet_photos`, supporting constraints and
  indexes, explicit Data API grants, RLS policies, the private `pet-photos`
  bucket, and Storage policies.
- Exact path contract `{customer_id}/{pet_id}/{file_id}.{extension}`.
- JPEG, PNG, HEIC, and HEIF images up to 10 MiB.
- Rollback-only positive and negative RLS/Storage policy checks.
- Supabase security/performance advisors, static contract validation, backend
  documentation, and durable memory updates.

## Out of Scope

- Swift models, repositories, pet screens, photo upload UI, Xcode changes, or
  iOS build/test execution.
- Grooming requests, request snapshots, groomer access to pet records, signed
  URL UX, image processing, or orphan cleanup automation.
- New RPCs, service-role use from the app, runtime fixtures, or seeded product
  data.
- Any inspection or mutation of legacy project `swdiiyypysyxbnfrxxsv`.
- Commit or push without a separate explicit user instruction.

## Remote Boundary

All Supabase work uses Supabase CLI and targets only the linked
`lqmasbuqzvcvtawonjlb` project. The full migration SQL must be reviewed and
explicitly approved before `supabase db push --linked`. After successful
application, the exact CLI-created migration file and SQL are mirrored under
`supabase/migrations/`.

## Validation Plan

1. Apply the explicitly approved migration once through Supabase CLI.
2. Verify migration history, tables, constraints, indexes, grants, RLS
   policies, bucket configuration, and Storage policies through Supabase CLI.
3. Run one rollback-only SQL validation covering owner CRUD, soft deletion,
   cross-customer denial, Groomer denial, anonymous denial, ownership/path
   immutability, active-pet upload rules, and primary-photo uniqueness.
4. Run Supabase CLI security and performance advisors.
5. Run `./scripts/supabase-check.sh` and `git diff --check`.
6. Review only the T-008 diff. Do not run an Xcode build, unit tests, or UI
   tests because no iOS file changes.

If remote application or validation fails, report the first real error and stop
without applying a corrective migration unless the user explicitly approves it.

## Stop Condition

Stop when the approved backend migration is deployed and mirrored, the pet and
photo ownership boundary validates, backend documentation and durable memory
reflect the deployed state, and the current diff is reviewed. Do not begin
T-009.
