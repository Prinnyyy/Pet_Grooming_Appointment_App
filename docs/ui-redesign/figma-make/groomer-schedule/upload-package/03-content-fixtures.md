# Groomer Schedule — Shared Content Fixtures

Use this exact data in Balanced Operations, Agenda First, and Compact Schedule. Default and Accessibility XL must also use identical content.

## Day

- Selected date: `Saturday, Aug 22`
- Date strip: `Thu 20`, `Fri 21`, `Sat 22`, `Sun 23`, `Mon 24`, `Tue 25`, `Wed 26`
- Active agenda total: `3 appointments`
- Summary: `Next 9:00 AM` · `4h 45m booked`

## Active appointments

| Time | Pet | Breed and service | Status | Customer | Location |
| --- | --- | --- | --- | --- | --- |
| 9:00–11:00 AM | Mochi | Poodle · Full Groom | Confirmed | Customer ref 123E4567 | Mobile |
| 12:00–1:15 PM | Princess Penelope Buttercup | Bernese Mountain Dog · Deshedding, Bath, Nail Trim & Coat Conditioning | Confirmed | Customer ref A11CE204 | Studio |
| 3:00–4:30 PM | Luna | Domestic Longhair · Bath & Brush | Completed | Customer ref C0FFEE12 | Mobile |

This set includes a normal pet name, a long pet name, short and long service names, and both location modes.

## Third real state sample

- Status: `Cancelled by customer`
- Usage: state-spec annotation only. Production excludes cancelled bookings from the active daily timeline, so do not add it as a fourth active agenda row.

## Long address stress fixture

`1847 West Dravus Street, Apartment 12B, Seattle, Washington 98199`

Address is detail-only. Use it to test handoff and long-text behavior, not as approved Schedule-row content.

## Travel Buffer fixture

`Travel Buffer — Not implemented; product decision required`

This is an external annotation, not a timed agenda row. Do not infer a buffer from the 11:00 AM–12:00 PM gap.
