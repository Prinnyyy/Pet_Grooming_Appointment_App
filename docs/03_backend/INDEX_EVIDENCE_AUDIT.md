# Supabase Index Evidence Audit

Last verified: 2026-07-09. Task: T-228 / Q-34. Project: `lqmasbuqzvcvtawonjlb`.

This is the current read-only disposition for the linked performance advisor. It authorizes no migration or index removal. Q-36 requires separate remote authorization.

## Evidence

- CLI `2.107.0`; current changelog and Supabase advisor/query-optimization guidance reviewed.
- Linked advisor: 12 unindexed-foreign-key INFO findings and 8 unused-index INFO findings.
- Statistics reset: 2026-05-22. Target tables currently hold 0-51 live rows, so zero scans are not removal evidence.
- Read-only catalog queries captured FK definitions, index definitions/size/scans, table activity, and redacted `pg_stat_statements` aggregates.
- `EXPLAIN` used no `ANALYZE`; `enable_seqscan=off` was transaction-local and rolled back.

## Foreign-Key Findings

| Constraint | Decision | Evidence |
|---|---|---|
| `bookings_offer_identity_fkey` | keep/no add | Unique `offer_id` plus participant indexes already narrow the equality lookup. |
| `bookings_request_customer_fkey` | keep/no add | Unique `request_id` covers the lookup. |
| `conversations_booking_identity_fkey` | keep/no add | Unique `booking_id` covers the lookup. |
| `customer_booking_handoff_acknowledgements_booking_id_fkey` | **add** | No `booking_id` index; forced plan remained a high-cost sequential scan. |
| `customer_booking_handoff_acknowledgements_request_fkey` | keep/no add | Reversed unique `(customer_id, request_id)` produced an index-only scan. |
| `groomer_offers_match_identity_fkey` | keep/no add | `groomer_offers_match_idx` produced an index scan. |
| `groomer_offers_request_customer_fkey` | keep/no add | Existing request/customer composites narrow the equality lookup. |
| `grooming_requests_pet_owner_fkey` | keep/no add | Partial `pet_id` index covers non-null FK rows. |
| `pet_photos_pet_owner_fkey` | keep/no add | `(customer_id, pet_id, ...)` covers both equality columns. |
| `request_matches_request_customer_fkey` | keep/no add | Existing request-prefixed indexes cover the lookup. |
| `request_photos_customer_id_fkey` | **add** | No `customer_id` index; forced plan remained a high-cost sequential scan. |
| `request_photos_request_customer_fkey` | keep/no add | Request-prefixed index produced a bitmap index scan. |

Q-36 should propose only:

- `customer_booking_handoff_acknowledgements_booking_id_idx (booking_id)`
- `request_photos_customer_id_idx (customer_id)`

## Unused-Index Findings

| Index | Decision | Evidence |
|---|---|---|
| `groomer_offers_match_idx` | keep | Supports the composite FK; forced plan used it. |
| `grooming_requests_location_mode_state_city_idx` | defer | No current direct list predicate; retain until representative production scale exists. |
| `groomer_profiles_location_mode_state_city_idx` | keep | Current matching predicate can use it. |
| `groomer_profiles_location_modes_gin_idx` | keep | Array containment plan used the GIN index. |
| `customer_notifications_related_booking_idx` | keep | Supports `ON DELETE SET NULL` FK maintenance. |
| `customer_notifications_related_offer_idx` | keep | Supports `ON DELETE SET NULL` FK maintenance. |
| `customer_notifications_push_pending_idx` | keep/excluded | Belongs to externally blocked APNs dispatch; outside remediation scope. |
| `account_deletion_requests_user_status_idx` | keep | Operational user/status plan used it; table has no live rows yet. |

No index removal is justified from current evidence.
