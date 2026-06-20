# T-008 Pet Data and Photo Storage Design

## Status

Approved and completed on 2026-06-20. Migration
`20260620192648_t008_pet_data_photo_storage` is deployed and mirrored, with
metadata inspection passed. The corrected rollback batch passed every assertion
before final Storage cleanup, where Supabase's `storage.protect_delete()`
correctly required the Storage API. The approved MCP-only closeout verified that
the authenticated DELETE policy exactly matches the behavior-tested owner-only
SELECT predicate. Advisors and static checks were reviewed and no validation
data persisted. Actual Storage API deletion is deferred to T-009 integration.

## Goal

Create the backend foundation for customer pet profiles and private pet photos.
Customers must be able to manage only their own pets and photo records. No
Groomer, other customer, anonymous user, or anonymous authenticated identity may
browse or mutate those resources.

## Scope

In scope:

- `public.pets` with the Fresh Brief fields and explicit validation.
- `public.pet_photos` with owner-consistent pet references and Storage paths.
- A private `pet-photos` Storage bucket with upload restrictions.
- Explicit grants, RLS policies, Storage policies, ownership indexes, and a
  single-primary-photo invariant.
- Backend contract documentation and rollback-only access validation.

Out of scope:

- iOS models, repositories, screens, uploads, signed URLs, or caching.
- Groomer access to live pet rows. Later request publication uses a frozen,
  separately authorized snapshot rather than widening pet-table access.
- Request-specific photos, image resizing, moderation, orphan cleanup jobs, or
  hard deletion of pet records.
- Any RPC or adjacent marketplace table.

## Selected Approach

Use normalized tables with direct owner-scoped Data API operations protected by
column grants and RLS. No RPC is needed because creating or editing one pet or
one photo metadata row is not a multi-row business transition. An RPC-only CRUD
surface would add repository and error-contract complexity without improving
atomicity between Postgres and Storage, which are separate services.

Using only `storage.objects` without `pet_photos` was rejected because the Fresh
Brief requires durable caption, ordering, primary-photo, pet, and customer
metadata. Broad authenticated reads were rejected because future Groomer access
must occur through an authorized request snapshot, not the customer's mutable
pet profile.

## Pet Table Contract

`public.pets` contains:

- `id uuid primary key default gen_random_uuid()`
- `customer_id uuid not null` referencing `customer_profiles(user_id)` with
  cascade on account/profile deletion
- required trimmed `name` and `species`
- optional trimmed `breed` and `size`
- optional positive `weight_lbs`
- optional `birthday`
- optional trimmed `temperament`, `medical_notes`, and `grooming_notes`
- `is_active boolean not null default true`
- `deleted_at timestamptz`
- `created_at` and trigger-maintained `updated_at`

The migration uses bounded text constraints. `size` remains bounded text rather
than introducing an enum whose values are not defined by the Fresh Brief. A
later product task may define canonical UI choices without requiring T-008 to
invent taxonomy.

`name` and `species` reject empty or surrounding-whitespace values. Optional
text is either null or non-empty, trimmed, and length bounded. Weight must be
positive and within a defensive upper bound. Birthday cannot be in the future.
The soft-delete state is consistent: active rows have no `deleted_at`; inactive
rows require one.

Authenticated clients receive no table-level hard-delete or ownership-column
update privilege. The supported delete operation is an update that sets
`is_active = false` and `deleted_at`. This preserves the pet relationship while
the client removes associated Storage objects through the Storage API.

## Pet Photo Metadata Contract

`public.pet_photos` contains:

- `id uuid primary key default gen_random_uuid()`
- `pet_id uuid not null`
- `customer_id uuid not null`
- `storage_bucket text not null default 'pet-photos'`
- `storage_path text not null`
- optional trimmed `caption`
- `sort_order integer not null default 0`
- `is_primary boolean not null default false`
- `created_at timestamptz not null default now()`

`pets` exposes a unique `(id, customer_id)` key, and `pet_photos` references that
pair with cascade deletion reserved for account-level or privileged cleanup.
This prevents a photo row from naming one customer's pet while carrying another
customer ID.

The bucket value is fixed to `pet-photos`. The path must contain exactly three
segments and match the row's customer and pet IDs:
`{customer_id}/{pet_id}/{file_id}.{extension}`. The file ID must be a UUID and
the extension must be `jpg`, `jpeg`, `png`, `heic`, or `heif`. Caption and sort
order are bounded. A partial unique index allows at most one primary photo per
pet.

The customer can insert metadata for an active owned pet, read and delete owned
metadata, and update only `caption`, `sort_order`, and `is_primary`. Pet,
customer, bucket, and path fields are immutable through client column grants.

## Storage Contract

Create a private bucket named `pet-photos` with a 10 MiB file limit and allowed
MIME types `image/jpeg`, `image/png`, `image/heic`, and `image/heif`.

Storage policies require all of the following:

- a non-null authenticated identity that is not anonymous;
- `owner_id` equal to `auth.uid()`;
- exactly two folder segments before the file name;
- the first folder equal to `auth.uid()`;
- the second folder equal to an active pet owned by that customer;
- an allowed file extension for insert and update destinations.

Select and delete remain owner-scoped even after a pet is soft-deleted so the
owner can view and clean up existing objects. Insert and update require an
active owned pet, preventing new uploads into deleted or foreign pet paths.
Upsert is supported because owner-scoped SELECT, INSERT, and UPDATE policies are
all present.

Storage objects are uploaded, replaced, and deleted only through the Storage
API. `pet_photos` stores bucket/path metadata and never stores a public or signed
URL. Database and Storage operations cannot share a transaction; T-009 must
surface partial failure and perform best-effort cleanup rather than claim false
atomicity.

## Grants and RLS

RLS is enabled on both public tables. Default access is revoked from `PUBLIC`,
`anon`, and `authenticated`, then only required authenticated column/table
privileges are granted explicitly. `service_role` retains administrative table
access but is never exposed to the iOS app.

Every authenticated policy requires a non-null `auth.uid()`, rejects
`is_anonymous`, confirms the Customer role marker, and checks row ownership.
Groomers receive no matching policy. Ownership reassignment is blocked twice:
by RLS `WITH CHECK` and by omission of ownership/path columns from UPDATE grants.

Ownership and pet foreign-key columns receive indexes suitable for RLS and
later list queries. No policy depends on user-editable Auth metadata.

## Error and Lifecycle Behavior

- Invalid fields, paths, formats, or soft-delete states fail at constraints.
- Cross-user, Groomer, and anonymous operations fail through grants/RLS without
  leaking another user's rows.
- A duplicate primary photo fails the unique invariant; T-009 must serialize or
  recover that user action rather than silently allowing two primary photos.
- Soft-deleted pets cannot receive new photo uploads or metadata.
- Existing photo objects remain owner-readable/deletable until client cleanup.
- Storage or metadata failure is reported as failure; no runtime fixture or
  local image is treated as remotely persisted.

## Validation

After explicit approval of the exact SQL, apply one migration through Supabase
MCP to fresh project `lqmasbuqzvcvtawonjlb` only. Then verify migration history,
metadata, grants, policies, bucket restrictions, and indexes.

One rollback-only SQL validation covers:

- Customer A can insert, read, update, and soft-delete an owned pet.
- Customer A can manage owned photo metadata and valid Storage-path rows.
- Customer B cannot read or mutate Customer A resources.
- a Groomer cannot read or mutate pet or photo resources.
- anonymous and anonymous-authenticated identities cannot access them.
- ownership/path reassignment, invalid paths, deleted-pet uploads, and a second
  primary photo are rejected.
- Storage policy predicates allow only the owner path and active owned pet for
  insert/update, while owner cleanup remains possible after soft deletion.

Run MCP security and performance advisors, `./scripts/supabase-check.sh`, and
`git diff --check`. Do not run Xcode build, unit tests, or UI tests because T-008
does not modify iOS code. On the first migration or validation failure, stop and
report the real error without an unapproved fix loop.

## Documentation and State Updates

After successful deployment, synchronize `SUPABASE_CONTRACT.md`,
`STORAGE_POLICY.md`, `RLS_RPC_POLICY.md`, the task ledger, current state, feature
index, and worklog with the verified deployed contract.

## Stop Condition

Stop when the approved migration is deployed and mirrored, owner and negative
access checks pass, advisors and repository checks are reviewed, and durable
state records T-008 as completed. Do not implement T-009.
