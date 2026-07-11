# Shared Content Fixtures

Every concept must use this exact content so evaluation compares composition rather than copy choices. Values derive from production model capabilities and the existing `BookingFeatureTests` pattern; long values are deliberate stress fixtures.

## Day

- Selected date: `Saturday, Aug 22`
- Visible day strip: `Thu 20`, `Fri 21`, `Sat 22`, `Sun 23`, `Mon 24`, `Tue 25`, `Wed 26`
- Summary: `3 appointments` · `Next 9:00 AM` · `4h 45m booked`

## Appointments

| Time | Pet | Breed / service | Status | Customer | Mode |
| --- | --- | --- | --- | --- | --- |
| 9:00–11:00 AM | Mochi | Poodle · Full Groom | Confirmed | Customer ref 123E4567 | Mobile |
| 12:00–1:15 PM | Princess Penelope Buttercup | Bernese Mountain Dog · Deshedding, Bath, Nail Trim & Coat Conditioning | Confirmed | Customer ref A11CE204 | Studio |
| 3:00–4:30 PM | Luna | Domestic Longhair · Bath & Brush | Completed | Customer ref C0FFEE12 | Mobile |

These provide three displayed state instances but only two distinct normal Schedule statuses (`Confirmed`, `Completed`). The third status required for contract coverage is `Cancelled by customer`; production Schedule filters cancellations out of the active timeline, so show it only in a labelled state-spec annotation, not as an active appointment row.

## Long address stress value

`1847 West Dravus Street, Apartment 12B, Seattle, Washington 98199`

Address exists in `Booking` and belongs in detail; it is included only to test detail handoff and prevent accidental list truncation.

## Travel Buffer

`Travel Buffer — 未发现实现`

Do not create a timed buffer row. If a concept needs to explain the gap from 11:00 AM to 12:00 PM, use an annotation outside the product UI stating that buffer semantics require product/data work.
