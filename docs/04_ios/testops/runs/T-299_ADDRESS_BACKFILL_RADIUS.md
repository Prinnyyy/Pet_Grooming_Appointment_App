# T-299 Address Backfill and Radius Matching

Date: 2026-07-11

Project: Beckon / `lqmasbuqzvcvtawonjlb`

Status: passed with one documented Customer-profile exception

## Backfill Result

- Dry-run targets: 103 complete unresolved addresses.
- Applied: 51 Groomer profiles, 50 Customer profiles, and 1 active Request.
- Documented exception: Customer support ref `6D8776F2`; database ZIP conflicts with the unique Apple Maps result, so no coordinate was written.
- Remaining gaps: Groomer 0, active Request 0, Customer 1 reviewed exception.
- Incomplete active targets: 0.
- Orphan `legacy_backfill` locations: 0.
- Authenticated/publishable access to list, summary, and write RPCs: denied.

## Radius Matrix

Run family: `TESTOPS-RADIUS299-TC-RADIUS-001...006`

| Case | Direction | Boundary | Result |
|---|---|---|---|
| `TC-RADIUS-001` | Customer travels | 5.0 / 10 miles | target included |
| `TC-RADIUS-002` | Customer travels | 9.999 / 10 miles | target included; reason rounded to 10.0 |
| `TC-RADIUS-003` | Customer travels | 10.25 / 10 miles | target excluded |
| `TC-RADIUS-004` | Groomer travels | 5.0 / 12 miles | target included |
| `TC-RADIUS-005` | Groomer travels | 11.999 / 12 miles | target included; reason rounded to 12.0 |
| `TC-RADIUS-006` | Groomer travels | 12.25 / 12 miles | target excluded |

Every case used Customer/Groomer password sign-in, the Groomer's owner-scoped coordinate RPC, WGS84 projected Request coordinates, `create_grooming_request_v2`, and live `request_matches` assertions. Cleanup removed six private Request locations, all tagged matches/Requests, and left zero tagged Requests and zero orphan `manual_geocode` locations.

## Remote Gates

- Migration history aligned through `20260712042846`.
- Repeat linked push dry-run: remote database up to date.
- Security advisor: only the existing hosted-plan leaked-password warning.
- Performance advisor: no issues.
- Private legacy location count after cleanup: 102.
