# Supabase Storage Policy

## Current Status

The private `avatars` bucket is deployed and validated by T-004. T-008 deploys and validates the private `pet-photos` bucket with a 10 MiB limit, JPEG/PNG/HEIC/HEIF restrictions, UUID filenames, owner/customer/pet paths, and select/insert/update/delete policies. T-010 deploys and validates the private `groomer-portfolio` bucket with the same 10 MiB image limits, owner-scoped upload/update/delete, authenticated object reads for active groomer portfolio metadata, and no broad authenticated listing. Supabase intentionally blocks direct SQL object deletion; MCP metadata confirmed owner-only DELETE policies match behavior-tested ownership predicates. The approved T-009 remote smoke verified actual authenticated Storage API upload/delete for pet photos and left zero persisted validation data. Later buckets remain planned.

## Bucket Roadmap

| Bucket | Purpose | Visibility | Owner Path | Owning Task |
|---|---|---|---|---|
| `avatars` | Customer/groomer profile avatar | Private by default; authenticated reads only when the profile flow requires them | `{user_id}/{file_id}.jpg` | T-004 |
| `pet-photos` | Customer pet images | Private | `{customer_id}/{pet_id}/{file_id}.jpg` | T-008 |
| `groomer-portfolio` | Groomer work examples | Private bucket; authenticated object reads for active groomer portfolio metadata; owner-writable | `{groomer_id}/{file_id}.jpg` | T-010 |
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

| Operation | Avatars | Pet Photos | Groomer Portfolio | Chat Attachments |
|---|---|---|---|---|
| Upload | Owning user | Owning customer for owned pet | Owning groomer | Conversation participant under authorized message flow |
| Read | Owner plus explicitly authorized profile presentation | Owning customer; request flow uses frozen authorized snapshot/metadata | Owner plus authenticated object reads for active groomer portfolio metadata; broad listing denied | Conversation participants only |
| Replace/Delete | Owning user | Owning customer | Owning groomer | Authorized participant/cleanup process defined in T-020 |
| List | Avoid broad bucket listing; scope to authorized prefix/query | Same | Same | Same |

## Client Safety

- The iOS app never receives a service-role or secret key.
- Storage failure remains a visible failure; production does not substitute a local image as uploaded content.
- Signed URLs, when used, are short-lived and generated only for an authorized object.
- Logs and Debug Panel output show bucket/environment and sanitized path context, not signed tokens or credentials.

Official implementation reference: [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
