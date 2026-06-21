# UX Rules

## General

- Every asynchronous read has loading, content, empty, and visible error states as applicable.
- Every mutation exposes progress, prevents duplicate submission, and reports failure without fabricating success.
- Preserve recoverable form input after network, permission, conflict, or validation errors.
- Keep primary actions shallow in navigation and use user-facing language instead of backend terminology.
- Respect Dynamic Type, VoiceOver labels, sufficient contrast, and minimum interactive target sizes.

## Forms

- Validate required fields before submission and repeat critical validation on the backend.
- Explain invalid time windows, non-negative price requirements, missing images, and required profile fields next to the relevant input.
- Disable submission only for an understandable reason; show that reason where it is not obvious.
- On successful mutations, refresh authoritative backend state before presenting the durable result.

## Marketplace Behavior

- A customer publishes one open request rather than selecting and repeatedly contacting individual groomers.
- A groomer may dismiss an assigned request privately. The customer remains in a neutral waiting state.
- A groomer has at most one active offer per request and may withdraw it according to backend rules.
- A customer can accept only one offer. The UI must wait for the atomic backend result before showing a booking.
- A cancelled booking remains a cancellation outcome for that booking; do not imply that the original request or accepted offer reopened.
- Hide completion and review actions until their backend transitions exist.
- Do not show actions that are invalid for the current request, match, offer, or booking status.

## Groomly UI Copy Rules

Use warm marketplace-oriented language during the Groomly UI phase.

Preferred terms:

- Groomly
- Find a groomer
- Start a grooming request
- Publish request
- Open requests
- Make offer
- Review offers
- Accept offer
- Booking confirmed
- Not a fit
- Waiting for offers
- No offers yet

Avoid old or misleading terms:

- Task card
- Send task
- Reject customer
- Reject task
- Recipient
- Submission
- Card exchange

For groomer dismissals, use private, neutral wording such as "Not a fit". Do not show customer-facing rejection language. Customers should stay in a neutral waiting or no-offers state.

## Privacy

- Before booking, show a groomer only the pet/service/time/approximate-location information needed to decide whether to offer.
- Do not reveal unnecessary customer contact or private profile details before booking.
- Chat is available only after booking and only to booking participants.
- Diagnostic screens must not display passwords, full API keys, access tokens, or refresh tokens.

## Status and Error Language

- Translate backend states into clear outcomes without exposing raw database or RLS wording.
- Permission failure: explain that the action is unavailable and preserve the screen state.
- Conflict: refresh current data and explain why the requested time or transition cannot proceed.
- Session expiry: return to authentication without silently losing an unsent recoverable draft where safe.
- Unknown failure: show a safe general message and record sanitized diagnostic context.

## Fixtures

Preview and test fixtures may demonstrate states in Xcode previews and automated tests. Production builds must not switch to fixture-backed repositories, local success paths, or demo credentials.
