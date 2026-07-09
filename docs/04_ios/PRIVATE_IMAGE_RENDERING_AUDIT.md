# Private Image Rendering Audit

Last verified: 2026-07-09. Closing task: T-188. Roadmap source: R-005/Q-01.

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

## Gaps for Q-02 to Q-04

1. There is no shared authorized image loader/service. Each repository/store owns its own download loop and cache choice.
2. Cache coverage is uneven: profile avatars and pet avatars have local snapshot fallback; request photos and portfolio photos do not.
3. Customer request wizard pet avatars still use breed emoji, not the existing private pet avatar data.
4. Booking/chat/notification role avatars are placeholder-only because those flows do not fetch counterpart avatar paths/data.
5. Groomer avatar reads intentionally include legacy `avatars`; the next implementation should keep this compatibility unless a migration/removal task explicitly retires it.

## Next Implementation Boundary

Q-02 should add the shared private-image loading/cache contract first, without changing Storage policy. Q-03 should move customer pet/request surfaces onto it. Q-04 should move groomer avatar/portfolio surfaces onto it. Any cross-user avatar display in chat/bookings needs a separate data-contract decision because current owner-only avatar buckets do not authorize counterpart reads.

Official references: [Storage buckets/private buckets](https://supabase.com/docs/guides/storage/buckets/fundamentals), [Storage access control](https://supabase.com/docs/guides/storage/security/access-control), and [serving private assets](https://supabase.com/docs/guides/storage/serving/downloads).
