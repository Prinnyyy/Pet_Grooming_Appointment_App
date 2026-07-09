# Private Image Rendering Audit

Last verified: 2026-07-09. Last implementation task: T-189. Roadmap source: R-005/Q-01-Q-02.

Purpose: bounded evidence for the next private-image rendering tasks. This is an audit, not an implementation spec.

## Contract

Supabase Storage images remain private. Current official contract allows private-object reads through authenticated downloads with the signed-in user's JWT, or time-limited signed URLs when explicitly designed. This app currently uses authenticated `.download(path:)`; production code does not use public Storage URLs or signed URLs.

Remote read-only verification on project `lqmasbuqzvcvtawonjlb` confirmed these buckets are private:

| Bucket | Limit | Read contract |
|---|---:|---|
| `customer-avatars` | 5 MB | customer owner only |
| `groomer-avatars` | 5 MB | groomer owner only |
| `avatars` | 5 MB | legacy owner-only fallback |
| `pet-photos` | 10 MB | customer owner only |
| `request-photos` | 10 MB | customer owner or visible matched groomer |
| `groomer-portfolio` | 10 MB | owner writes; authenticated reads for active groomer portfolio metadata |

All verified buckets allow only jpeg/png/heic/heif. Related metadata tables have RLS enabled and authenticated policies for the current role/ownership contracts.

## Current iOS State

- Shared display primitive exists: `GroomlyModuleImage` center-crops local `Data` into module frames.
- Customer and groomer profile avatars upload to dedicated avatar buckets, download with authenticated Storage reads, and persist a local `ProfileSnapshot` fallback.
- Customer pet card avatars upload to `pet-photos`, replace older pet avatar photos, render from local cache before network download, and use `CustomerPetPhotoSnapshot`.
- Request photos are uploaded/read from `request-photos` and rendered in customer and groomer request details.
- Groomer portfolio photos are uploaded/read from `groomer-portfolio` and rendered in portfolio cards.
- T-189 added `PrivateImageLoader`, `FilePrivateImageCache`, and `SupabasePrivateImageDataSource`. Supabase repositories now route avatar, pet, request, and portfolio image downloads through the shared authenticated loader. Cache file names are hashed and the shared cache is cleared during local account cleanup.

## Remaining Gaps for Q-03 to Q-04

1. Customer request wizard pet avatars still use breed emoji, not the existing private pet avatar data.
2. Request and portfolio surfaces now share the loader but still need UI-specific empty/error states and presentation checks.
3. Booking/chat/notification role avatars are placeholder-only because those flows do not fetch counterpart avatar paths/data.
4. Groomer avatar reads intentionally include legacy `avatars`; this compatibility is preserved unless a migration/removal task explicitly retires it.

## Next Implementation Boundary

Q-03 should focus on customer-facing image presentation: request wizard pet avatars, pet detail/photo states, request photo empty/error states, and simulator verification. Q-04 should focus on groomer avatar/portfolio presentation through the same loader. Any cross-user avatar display in chat/bookings needs a separate data-contract decision because current owner-only avatar buckets do not authorize counterpart reads.

Official references: [Storage buckets/private buckets](https://supabase.com/docs/guides/storage/buckets/fundamentals), [Storage access control](https://supabase.com/docs/guides/storage/security/access-control), and [serving private assets](https://supabase.com/docs/guides/storage/serving/downloads).
