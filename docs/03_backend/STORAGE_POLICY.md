# Supabase Storage Policy

## Current Status

The private `avatars` bucket is deployed and validated by T-004, and T-059 reuses it for groomer owner-side avatar upload/download through `profiles.avatar_path`. T-008 deploys and validates the private `pet-photos` bucket with a 10 MiB limit, JPEG/PNG/HEIC/HEIF restrictions, UUID filenames, owner/customer/pet paths, and select/insert/update/delete policies; T-050 reuses this bucket for Add Pet form photos instead of adding a second pet container. T-010 deploys and validates the private `groomer-portfolio` bucket with the same 10 MiB image limits, owner-scoped upload/update/delete, authenticated object reads for active groomer portfolio metadata, and no broad authenticated listing. T-049 deploys and metadata-validates the private `request-photos` bucket with the same 10 MiB image limits, customer/request UUID paths, customer-owned upload/delete for open requests, and customer/matched-groomer reads through request-photo metadata. Supabase intentionally blocks direct SQL object deletion; MCP metadata confirmed owner-only DELETE policies match behavior-tested ownership predicates. The approved T-009 remote smoke verified actual authenticated Storage API upload/delete for pet photos and left zero persisted validation data. Later buckets remain planned.

## Bucket Roadmap

| Bucket | Purpose | Visibility | Owner Path | Owning Task |
|---|---|---|---|---|
| `avatars` | Customer/groomer profile avatar | Private by default; T-059 owner groomer profile flow uploads and downloads only its own avatar | `{user_id}/{file_id}.jpg` | T-004, T-059 |
| `pet-photos` | Customer pet images | Private | `{customer_id}/{pet_id}/{file_id}.{jpg,png,heic,heif}` | T-008; reused by T-050 |
| `groomer-portfolio` | Groomer work examples | Private bucket; authenticated object reads for active groomer portfolio metadata; owner-writable | `{groomer_id}/{file_id}.jpg` | T-010 |
| `request-photos` | Customer-added request images | Private bucket; customer and matched-groomer reads through metadata-backed policies; owner-writable for open requests | `{customer_id}/{request_id}/{file_id}.{jpg,png,heic,heif}` | T-049 |
| `chat-attachments` | Optional booked-conversation attachments | Private to conversation participants | `{conversation_id}/{message_id}.jpg` | T-020 |

Public buckets are not the default. A later task may choose signed URLs or authenticated object reads according to the repository contract; it must not broaden access implicitly.

## Object Rules

- Generate file IDs; do not trust user-supplied path ownership.
- Validate MIME type, extension, and maximum size before upload and enforce compatible bucket limits where supported.
- Bind Storage object paths to the same owner/participant relationship used by metadata rows.
- Metadata stores bucket/path, not a secret or permanently trusted public URL.
- Delete or replacement operations require the same ownership checks as upload.
- Upsert/replacement requires the necessary `INSERT`, `SELECT`, and `UPDATE` policies; do not grant broad access to make replacement work.
- Chat attachment policies must resolve conversation participation, not only sender ownership.

## Access Summary

| Operation | Avatars | Pet Photos | Groomer Portfolio | Request Photos | Chat Attachments |
|---|---|---|---|---|---|
| Upload | Owning user | Owning customer for owned pet | Owning groomer | Owning customer for owned open request | Conversation participant under authorized message flow |
| Read | Owner plus explicitly authorized profile presentation; T-059 uses owner-only groomer avatar rendering | Owning customer; request flow uses frozen authorized snapshot/metadata | Owner plus authenticated object reads for active groomer portfolio metadata; broad listing denied | Owning customer and matched groomers through `request_photos`/request-match policies | Conversation participants only |
| Replace/Delete | Owning user | Owning customer | Owning groomer | Owning customer; replacement not yet exposed in UI | Authorized participant/cleanup process defined in T-020 |
| List | Avoid broad bucket listing; scope to authorized prefix/query | Same | Same | Same | Same |

## Client Safety

- The iOS app never receives a service-role or secret key.
- Storage failure remains a visible failure; production does not substitute a local image as uploaded content.
- Signed URLs, when used, are short-lived and generated only for an authorized object.
- Logs and Debug Panel output show bucket/environment and sanitized path context, not signed tokens or credentials.

Official implementation reference: [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
