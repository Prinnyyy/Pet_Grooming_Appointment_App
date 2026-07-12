# T-300 Strict Coordinate Cutover

Date: 2026-07-11

## Scope

Q-112 removes the temporary state/city matching fallback after Q-111 proved zero active Groomer and Request coordinate gaps. Coordinates plus the direction-correct radius are now the only active location-matching authority.

## Remote Migration

- Applied `20260712044858_t300_strict_coordinate_matching.sql` to Beckon project `lqmasbuqzvcvtawonjlb`.
- Migration preconditions rejected application if any active Groomer or non-expired open/has-offers Request lacked a valid owned private point.
- The private fit helper returns ineligible when either coordinate is absent, including identical city/state text.
- Customer travel radius controls `customer_comes_to_groomer`; Groomer service radius controls `groomer_comes_to_customer`.
- Authenticated execution of the retired pre-coordinate Request RPC was revoked.
- Linked history aligns through T-300 and repeat dry-run reports the database up to date.

## Runtime Evidence

| Run | Result | Cleanup |
|---|---|---|
| `TESTOPS-T300B-SMOKE5-*` | Lifecycle 5/5 passed | Each private Request point deleted; zero tagged Requests |
| `TESTOPS-T300-BASELINE-*` | Matching baseline 8/8 passed | Each private Request point deleted; zero tagged Requests |
| `TESTOPS-T300-RADIUS-*` | Radius near/edge/outside 6/6 passed | Each private Request point deleted; zero tagged Requests |

The first lifecycle attempt exposed a TestOps-only fixture defect: it copied a Profile `legacy_backfill` source into synthetic Request locations, outside the exact cleanup contract. The four resulting unreferenced rows were identified from the run time window, deleted, and reverified at zero. TestOps now always creates synthetic Request points as `manual_geocode` and anchors lifecycle cases at the selected target Groomer; matching accuracy remains independently covered by the baseline and radius matrices.

## Privacy And Integration

- Authenticated clients cannot query `app_private.address_locations` directly.
- Exact coordinates and Place IDs remain available only through current-owner Profile RPCs.
- Customer Profile, Groomer Profile, and Customer Request all use `BeckonAddressEditor`.
- `BeckonAddressSearch` is the only production MapKit address implementation.
- No production copy claims postal deliverability or USPS validation.
- Final active Groomer gaps, active Request gaps, private-location orphans, and T-300 tagged Requests are all zero.
