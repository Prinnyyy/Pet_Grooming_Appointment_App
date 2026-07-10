# Beckon Brand Migration

Approved in T-243 on 2026-07-09. This is the scope contract for R-038 and queue packages Q-94 through Q-96.

## Identity Contract

- Brand: `Beckon`
- Domain: `hellobeckon.com`
- App Store name: `Beckon: Pet Grooming`
- Tagline: `Pet groomers at your beck and call.`
- Xcode project, app target, and module: `Beckon`
- Test targets: `BeckonTests` and `BeckonUITests`
- Planned iOS root: ios/Beckon/
- Bundle ID: `com.hellobeckon.beckon`
- URL scheme: `com.hellobeckon.beckon`
- Auth callback: `com.hellobeckon.beckon://auth/callback`

## Scope

The active product must use Beckon in UI copy, release metadata, Swift symbols, filenames, design primitives, diagnostics, cache paths, launch arguments, accessibility identifiers, scripts, tests, TestOps, seed resources, and active documentation. Rename `Groomly*` types/files to `Beckon*`; rename the Xcode project, targets, schemes, modules, source/test directories, and app entry point. The authentication screens display the approved tagline.

Test resources become `beckon.customer001@example.com` through `050` and `beckon.groomer001@example.com` through `050`, password `BeckonTest!2026`, IDs `BTC-###`/`BTG-###`, and metadata keys `beckon_seed`/`beckon_seed_id`.

## Sequencing

1. Q-94 completed the local application/source rename and prepared append-only backend changes in T-246. Its local iOS, TestOps, migration, privacy, and context gates passed.
2. Q-95 completed the standalone workflow-rule rename in T-247; active agent/workflow sources are now included in the Beckon identity audit.
3. Q-96 remote cutover completed in T-248: Supabase project display name, Auth sender/callback settings, append-only migration, and all 100 seeded Auth users now use Beckon in place. UUIDs remained stable; lifecycle 5/5, matching 8/8, Auth login, and zero-residue checks passed. The APNs dispatcher remains undeployed and excluded until its Apple prerequisites exist.

## Historical Boundary

Do not rewrite applied migration files, frozen records, or Git history. New append-only migration/runtime state replaces live `groomly` identifiers such as the request-expiry cron name and push payload namespace. Active code and documentation may retain an old string only when a validator identifies it as immutable historical evidence; such exceptions must be explicit and indexed.

The T-248 seed identity cutover core and its focused regression test are exact audit exceptions because they must recognize and explicitly roll back the retired seed identity. The public CLI, production app, TestOps plans, and all other active files remain audited.

Changing the Bundle ID creates a new app identity and local container. Existing sessions/caches are intentionally not migrated. Links using the old callback no longer work after Q-96. App Store Connect submission remains blocked by Apple prerequisites; repository metadata is prepared now.

## Gates

- Active-tree identifier audit has no unexplained `Groomly`, `groomly`, `PetGroomerMarketplace`, or old bundle/callback references.
- `xcodebuild -list`, full iOS tests/build, TestOps units/dry-runs, Supabase preflight/checks, privacy tests, `git diff --check`, and context hygiene pass.
- Simulator launch shows Beckon and the exact tagline with no old app name on customer/groomer/auth/account surfaces.
- Q-96 consumed fresh remote-write authorization and preserved all seed user UUID mappings; any future identity write requires new authorization.
