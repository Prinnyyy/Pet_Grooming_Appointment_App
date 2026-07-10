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

- Launch harness: clear-session launch, seeded role sign-in/navigation, customer request-sheet open/dismiss, and relaunch reset.
- Full harness: customer publishes a tagged dog/full-groom request, groomer offers, customer accepts and sends chat, groomer verifies chat and completes, then customer reviews.
- `verify debug-log` requires publish/offer/accept/send/complete/review Store success events with zero error-level events in the run window. `verify ui-lifecycle` checks final backend state before tagged cleanup.
- UI assertions must use accessibility identifiers plus backend/Debug verification, not screenshots.

## `request_matching_eval`

Goal: prove request matching behavior, not full booking lifecycle.

Backend path:

1. Customer signs in with a T-129 seeded account.
2. Script loads the customer's active dog pet selected by the case.
3. Customer creates a tagged grooming request through `create_grooming_request`.
4. Script signs in the target groomer to resolve the target user id.
5. Service-role verification loads all `request_matches` rows for that request.
6. Script asserts target groomer inclusion or exclusion according to the case.
7. Positive target cases assert expected `match_reason` fragments, such as `Preferred time fits` or `Can suggest another time on your preferred day`.
8. Optional cleanup deletes only rows tagged with `TESTOPS:<run_id>`.

Baseline matrix:

- `matching_baseline` runs 8 fixed cases from `TEST_CASES.md`.
- Dry-run is the default and prints the redacted plan plus local candidate projection.
- Remote execution still requires `--execute` and `TESTOPS_REMOTE_WRITE_APPROVED=1`.
- This scenario creates grooming requests only. It does not create offers, bookings, chat rows, completion, reviews, image uploads, or Storage objects.

## Future Scenario Candidates

- `request_no_match_diagnostics`: create a request expected to produce zero matches and verify Debug Console event provenance.
- `image_upload_cleanup`: exercise request/pet/avatar image upload and explicit Storage cleanup.
- `chat_message_failure`: exercise send timeout/failure without success toast.
