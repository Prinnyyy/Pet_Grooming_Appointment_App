# TestOps Scenarios

## `marketplace_full_lifecycle`

Goal: prove the core marketplace flow can complete with seeded customer/groomer accounts.

Backend path:

1. Customer signs in with a T-129 seeded account.
2. Script loads the customer's active dog pet.
3. Customer creates a grooming request through `create_grooming_request`.
4. Groomer signs in with a T-129 seeded account.
5. Script verifies the groomer received a `request_matches` row.
6. Groomer creates an offer through `create_groomer_offer`.
7. Customer accepts through `accept_groomer_offer`.
8. Groomer completes through `complete_booking`.
9. Customer creates a review through `create_review`.
10. Script verifies final request/offer/booking/review state.
11. Optional cleanup deletes only rows tagged with `TESTOPS:<run_id>`.

Initial default pair:

- Customer: `GTC-001`
- Groomer: `GTG-001`
- Service: `full_groom`
- Location mode: `customer_comes_to_groomer`

Smoke matrix:

- `smoke5` runs five fixed LA/OC lifecycle pairs from `TEST_CASES.md`.
- Dry-run is the default and prints the planned case set only.
- Remote execution still requires `--execute` and `TESTOPS_REMOTE_WRITE_APPROVED=1`.

UI path:

- Current implementation: TestOps launch smoke with run/scenario arguments, clear-session, and disabled animations.
- Next expansion: sign in customer, publish request, sign out/sign in groomer, create offer, sign out/sign in customer, accept offer, sign out/sign in groomer, complete booking, sign out/sign in customer, create review.
- UI assertions must use accessibility identifiers plus backend/Debug verification, not screenshots.

## Future Scenario Candidates

- `request_no_match_diagnostics`: create a request expected to produce zero matches and verify Debug Console event provenance.
- `image_upload_cleanup`: exercise request/pet/avatar image upload and explicit Storage cleanup.
- `chat_message_failure`: exercise send timeout/failure without success toast.
