# Preview and Test Fixtures

## Policy

The application has no runtime demo mode. Preview and test fixtures exist only to render deterministic SwiftUI previews and to drive automated tests.

## Test Resource Documents

- `docs/02_architecture/test_resources/T-129_GROOMER_TEST_PROFILES.md` contains 50 local groomer seed profiles for review before any remote Supabase write; T-130 restricts all profile addresses to real public institution addresses in Los Angeles County or Orange County.
- `docs/02_architecture/test_resources/T-129_CUSTOMER_TEST_PROFILES.md` contains 50 local customer seed profiles, each with one dog and one cat, for review before any remote Supabase write; T-130 applies the same LA/OC public-address rule.
- These resources are documentation-only. They are not production fixtures, runtime fallback data, quick-login accounts, or evidence that remote users exist.
- TestOps usage, rules, scenarios, and run templates live under `docs/04_ios/testops/README.md`; use that index before running lifecycle automation with the seeded account pool.

## Allowed

- Inline or dedicated fixtures compiled for Xcode previews.
- Test doubles injected by unit or UI test targets.
- Deterministic role routes supplied explicitly to previews and tests.
- Fixture data that models loading, empty, content, validation, and error states without contacting a backend.

## Forbidden

- A production setting that switches repositories from Supabase to fixture data.
- Silent fallback to fixtures when configuration, Auth, network, RLS, RPC, or Storage fails.
- Launch arguments or persisted flags that grant a production user a fabricated role or successful backend result.
- Treating preview/test data as evidence that a backend feature is implemented.
- Shipping demo credentials or secret keys.

## Isolation Rules

- Fixture factories belong in preview-only or test-target code where practical.
- Product repository protocols may support test doubles, but production composition must construct only production implementations.
- Preview/test fixtures may reuse domain types; production code must not import test targets.
- UI text for an unimplemented production feature must state that it is unavailable rather than simulating completion.

## Review Checklist

- Can fixture code execute in a production launch path? It must not.
- Can a backend error select fixture data? It must not.
- Is every successful production mutation backed by a real repository/backend result? It must be.
- Are fixtures limited to data needed by the preview or test? They should be.
