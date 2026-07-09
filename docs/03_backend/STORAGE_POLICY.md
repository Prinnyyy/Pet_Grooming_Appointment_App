# Supabase Storage Policy

This is the active Storage access policy index. It records current bucket contracts, not deployment history.

Archived pre-trim version: `../09_frozen/backend_policies/STORAGE_POLICY_2026-07-02_PRE_INDEX_TRIM.md`.

Private image rendering audit and current client gaps: `../04_ios/PRIVATE_IMAGE_RENDERING_AUDIT.md`.

## Current Buckets

| Bucket | Purpose | Visibility | Owner Path |
|---|---|---|---|
| `avatars` | Legacy/shared profile avatar fallback | Private; owner access plus legacy presentation fallback where implemented | `{user_id}/{file_id}.{jpg,png,heic,heif}` |
| `groomer-avatars` | Groomer account avatar | Private; authenticated non-anonymous groomer owner-only access | `{groomer_id}/{file_id}.{jpg,png,heic,heif}` |
| `customer-avatars` | Customer account avatar | Private; authenticated non-anonymous customer owner-only access | `{customer_id}/{file_id}.{jpg,png,heic,heif}` |
| `pet-photos` | Customer pet images | Private; owning customer access | `{customer_id}/{pet_id}/{file_id}.{jpg,png,heic,heif}` |
| `groomer-portfolio` | Groomer work examples | Private bucket; authenticated reads only through active portfolio contract; owner writes | `{groomer_id}/{file_id}.jpg` |
| `request-photos` | Customer request images | Private; owning customer and matched groomer reads through request metadata/policies | `{customer_id}/{request_id}/{file_id}.{jpg,png,heic,heif}` |
| `chat-attachments` | Deferred booked-conversation attachments | Deferred; participants only when implemented | `{conversation_id}/{message_id}.jpg` |

Public buckets are not the default. Use signed URLs or authenticated object reads only when a task explicitly defines the access contract.

## Object Rules

- Generate file IDs; do not trust user-supplied ownership in object paths.
- Validate MIME type, extension, and size before upload and enforce compatible bucket limits.
- Bind object paths to the same owner/participant relationship used by metadata rows.
- Store bucket/path metadata, not secret or permanently trusted public URLs.
- Delete and replacement operations require the same ownership checks as upload.
- Avoid broad bucket listing. Scope reads to authorized prefixes or metadata-backed paths.
- Storage failure is a visible production failure; never substitute local fixture images as uploaded content.
- Account deletion lists only the deleting user's UUID prefix in the six active/legacy image buckets and removes objects through the service-role Storage API before Auth soft deletion. Never delete or mutate `storage.objects` directly with SQL.
- Logs and Debug Console output may show bucket/environment and sanitized path context, never signed tokens or credentials.

## Access Summary

| Operation | Rule |
|---|---|
| Upload | Owner or authorized participant only, according to bucket contract |
| Read | Owner, participant, or explicit marketplace presentation contract only |
| Replace/Delete | Same owner/participant predicate as upload |
| List | Avoid broad listing; query metadata or authorized prefix only |

## Update Rules

- Exact bucket creation, policy SQL, grants, limits, and path predicates belong in `../../supabase/migrations/`.
- Update this file only when the active Storage contract changes.
- Keep deployment narratives in task closeout or frozen archives.

Official reference: [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
