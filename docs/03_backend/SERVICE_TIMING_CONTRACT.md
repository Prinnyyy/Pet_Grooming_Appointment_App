# Service Timing Contract

Owner scope: T-374 / functional-reliability WP-03. Migration `20260908052312_t374_service_timing.sql` was deployed on 2026-09-08 and is append-only. Installed-definition SQL assertions and authenticated publication/offer/acceptance plus concurrent Save checks passed with exact restoration. Original WP-03 client flows and integration gates pass; evidence and release limitations are recorded in the timing acceptance files linked from the plan.

T-435 / D-069 adopts service-only occupancy; deployment and current acceptance are recorded in [P7](../superpowers/plans/2026-11-01-groomer-ui-p7-service-time.md). T-374 buffer settings below are superseded; its applied migration and historical commercial facts remain intact.

## Time Meaning

- Persist instants as UTC timestamps and retain an IANA timezone identifier with the intent/agreement. Never reconstruct historical timezone from the device or a subsequently edited profile. Unknown legacy zones remain unknown.
- The customer's preferred window is expressed in the confirmed request-address timezone. In the customer-travels direction the destination is not yet selected: preserve those absolute preference bounds, then show the quote in the chosen groomer location's timezone. Do not reinterpret the same wall-clock label as a different instant when a candidate is selected.
- The service-location timezone is the customer address for mobile service and the groomer base address for customer-travels service. Address resolution supplies location timezone; it must remain attached through confirmation and persistence. Missing timezone requires address/timezone confirmation before new timed commitments, not a device-timezone fallback.
- The groomer's schedule timezone is separate from the service-location timezone and is consistent across weekly hours. Notice and daily capacity use the schedule timezone. Changing it does not rewrite accepted agreement times or location timezone.
- A preferred window constrains the entire service, not its preparation, cleanup or travel. Clip its expired prefix to the existing five-minute earliest-start rule; reject only when no required service interval remains. Unknown duration permits an assessment request, not a confirmed-fit claim.
- Outside-window or outside-date alternatives are rejected until an explicit, versioned customer permission path exists. Editing the proposed duration never expands the customer's consent.

## Duration And Occupancy

- Reuse the existing service-duration range of 15 through 720 integer minutes. A configured active owned service supplies an editable duration and price, not a guarantee of availability. Custom, missing, inactive or ambiguous configuration requires explicit assessment and a groomer-entered duration/price before an offer.
- Duration is elapsed time, including across DST transitions. New offers/bookings use an explicit zero compatibility buffer snapshot and occupied start/end equal service start/end. Missing or previously saved positive buffer settings never downgrade matching or enlarge occupancy.
- Pet and groomer occupancy are `[service_start, service_end)`, subject to the existing authorized fulfillment release. Adjacent intervals may touch; actual overlap remains rejected by locked admission and the groomer/pet exclusion constraints.
- Availability and time-off checks cover the service interval, including on availability Save and reschedule. Keep the shared exact timezone/DST evaluator, daily capacity and minimum-notice checks. No page/cache truncation participates in admission. The service must still fit one service-location calendar day, allowing an exclusive end exactly at next midnight.
- The groomer judges travel and preparation when offering a time. The app does not promise route optimization or guaranteed arrival and never shifts confirmed appointments automatically.
- Existing immutable offers/booking snapshots retain their historical values. Old pending quotes whose padded timing differs from the new rule use existing `legacy_unverified` / replace-offer handling; they cannot silently create a booking with different frozen terms. Legacy booked facts remain readable; their operational resource interval uses service/release times. A verified reschedule preserves its prior agreement while applying service-only allocation to the new time.
- Availability Save normalizes the deprecated compatibility key to explicit zero. The removed four-field draft and inert Auto-ready control do not appear in the UI; `auto_accept_bookings` remains a stored compatibility field with no automatic booking promise.

## Notice And Capacity

- Preserve the existing configurable notice range 0...2 local calendar days and daily limit 1...12. Earliest service start is the later of `now + 5 minutes` and midnight of the schedule-local date plus configured notice days; one notice day is not 24 elapsed hours.
- Count a booking once on its service-start date in the current schedule timezone. Recheck service coverage on every touched date.
- Continue current confirmed/completed occupancy and count semantics until WP-06 defines actual fulfillment/release. Cancellation behavior is not broadened by this timing package. New admission, direct privileged writers and availability Save must use the same guarded allocation policy.

## DST And Interpretation

- Resolve user-entered wall time with the selected location timezone, not Calendar.current. A nonexistent wall time is rejected. Repeated wall time requires a choice of occurrence, shown with its offset; never silently choose one.
- Day boundaries are calendar operations in the declared zone. Do not add 86,400 seconds to mean tomorrow. Changing the device zone does not change existing selected instants, duration, consent or capacity date.
- A preference, quote or occupied interval with an invalid zone, invalid bounds or missing required provenance is not an exact-fit result.
- Recurring weekly hours apply to every occurrence of their local clock range. On a fall-back day, 01:15-01:45 covers each occurrence separately, not the closed real-time gap between them. Explicit appointment selection still requires an occurrence choice. The prepared coverage baseline splits UTC at integer-second boundaries and checks each complete local affine interval, including fractional endpoints; this uses the transition representation in [TZif section 2](https://www.rfc-editor.org/rfc/rfc8536.html#section-2), not point sampling. Benchmark and optimize bulk matching separately before using this exact-admission check per candidate.
- The prepared optimization converts each segment once and groups its bounds by local date. Because the schedule has one opening interval per weekday, every segment fits exactly when that date's minimum start and maximum exclusive end fit. It retains all UTC-second segments rather than assuming equal endpoint offsets imply no transition. Weekday arrays rely on the existing 1...7 and unique groomer/weekday constraints. Differential tests retain the original per-segment predicate as the oracle; measured single-interval improvement is not bulk-matching or Save latency acceptance.

## Compatibility And Integration

Prepared bulk Save validation reads and validates the shared seven-day schedule once per coverage check, then uses the same exact interval evaluator for every future confirmed/completed booking. Time-off overlap uses that validated schedule zone. No client page limit or persistent cache participates in admission. The optional `--bookings --scale` rollback fixture covers 54 additional bookings, conflicts on the final booking, rejected-Save atomicity and a valid weekly-hours change; measured fixture latency is not live-concurrency acceptance.

The shared typed/wire contract must carry preference start/end/reference timezone; service start/end/duration/location timezone; occupied start/end; applied preparation/cleanup/travel values; and schedule timezone used for admission. Settings ownership/versioning reuses WP-01's atomic availability boundary. WP-05 adds agreement revisions without replacing these timing facts.

Do not invent historical travel allowances or timezone evidence. Keep legacy accepted timestamps intact, label missing provenance, and preserve at least existing allocation protection during transition. Block unsafe new writes from unsupported clients with an explicit update/confirmation error only after the compatible client and recovery path exist. Append-only migrations and rollback tests must precede deployment; do not edit T-371/T-373 applied migrations.

Acceptance requires matching Swift/SQL vectors for clipping, unknown duration, 15/720-minute bounds, midnight, spring gaps, repeated fall times, device-zone changes, explicit zero snapshots and ignored historical buffers, adjacent/conflicting occupancy, notice days, quota and outside-window rejection. Verify the actual Wizard/offer interaction, then full regression, concurrent admission/Save, ownership and rollback gates. No package checkbox closes merely because this document exists.

References: [functional reliability plan](../superpowers/plans/2026-09-07-functional-reliability-task-plan.md), [Supabase contract](SUPABASE_CONTRACT.md), [Apple location timezone](https://developer.apple.com/documentation/mapkit/mkmapitem/timezone).
