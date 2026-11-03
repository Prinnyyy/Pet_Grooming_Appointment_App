# UX Rules

## Interaction Basics

- Every async read has appropriate loading, content, empty, and visible error states. First/new-scope loading differs from background refresh: retain known content, confirmed empty results and count badges; do not add refresh-only rows or alter module height. Unknown values must not masquerade as zero.
- Every mutation has one progress owner, prevents duplicate submission, and never fabricates success. Do not duplicate button progress in a global sending overlay.
- Preserve recoverable form input after network, permission, conflict, or validation errors.
- Keep primary actions shallow and use user-facing language instead of backend terms.
- Respect Dynamic Type, VoiceOver labels, contrast, and minimum target sizes.

## Forms

- Validate required fields before submit and repeat critical checks on the backend.
- Explain invalid time windows, non-negative prices, missing images, and required profile fields next to the input.
- Disable submission only for an understandable reason and show that reason when it is not obvious.
- After success, refresh authoritative backend state before presenting the durable result.

## Marketplace Rules

- V1 is request-first: customers publish open requests; groomers receive matches and make concrete offers.
- Do not expose a public all-groomer directory or direct customer slot booking in pet-fit v1.
- Groomer dismissals are private and use neutral wording such as "Not a fit".
- A groomer has at most one active offer per request and may withdraw it only under backend rules.
- A customer can accept only one offer; the UI waits for the atomic backend result before showing a booking.
- Cancelled bookings remain cancelled; do not imply that the original request or accepted offer reopened.
- Hide completion/review actions until their backend transitions exist.
- Do not show actions invalid for the current request, match, offer, or booking status.
- Fit copy must distinguish claimed specialties from evidence such as completed similar bookings, relevant reviews, or repeat customers.

## Copy

Use sentence case for headings, field labels, status labels and explanatory copy. Preserve proper names and acronyms; command buttons may retain title case. Format appointment intervals through `BeckonDateTimeFormatter`, retain service-location time-zone calculations and validation. Technical Service time zone rows in offer/reschedule and the Schedule zone badge are intentionally hidden (T-448/T-450); do not restore them as refresh copy. Unknown service-zone data must retain validation/recovery rather than inventing a zone or raw timestamp. The remaining cross-zone disclosure question is recorded in `DESIGN_SYSTEM.md`. Counts must use correct singular/plural forms.

Preferred terms: Beckon, Find a groomer, Start a grooming request, Publish request, Open requests, Make offer, Review offers, Accept offer, Booking confirmed, Not a fit, Waiting for offers, No offers yet.

Avoid: Task card, Send task, Reject customer, Reject task, Recipient, Submission, Card exchange.

## Privacy and Errors

- Before booking, show groomers only pet/service/time/approximate-location context needed to decide whether to offer.
- Do not reveal unnecessary customer contact or private profile details before booking.
- Chat is available only after booking and only to booking participants.
- Diagnostic screens must not display passwords, full API keys, access tokens, or refresh tokens.
- Translate backend states into clear outcomes without exposing raw database or RLS wording.
- Unknown failures show a safe message and record sanitized diagnostic context.

## Fixtures

Preview/test fixtures may demonstrate states. Production builds must not switch to fixture-backed repositories, local success paths, or demo credentials.
