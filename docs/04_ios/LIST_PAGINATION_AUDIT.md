# List Pagination Audit

Last verified: 2026-07-09.

Purpose: record the V1.0 list-load contract for request, offer, booking, message, and notification surfaces.

## Contract

- Default first page: `ListPageRequest.first`.
- Default visible page size: 50 items.
- Repositories fetch `limit + 1` rows so `ListPage.hasMore` can be derived without a count query.
- Supabase-backed list reads apply `.range(from: page.offset, to: page.inclusiveRangeEnd)`.
- Debug repository wrappers must forward `ListPageRequest` instead of falling back to unpaged methods.

## Covered Lists

| Surface | Repository method | Supabase table | Ordering | Pagination status |
|---|---|---|---|---|
| Customer requests | `CustomerRequestRepository.requests(customerID:page:)` | `grooming_requests` | `created_at` desc | Store and shared Load More control complete T-230 |
| Customer offers | `CustomerRequestRepository.offers(customerID:requestID:page:)` | `groomer_offers` | `created_at` desc | Per-request Store and shared Load More control complete T-230 |
| Groomer matched requests | `GroomerRequestRepository.matchedRequests(groomerID:page:)` | `request_matches` | `created_at` desc | Store and shared Load More control complete T-230 |
| Groomer offers | `GroomerRequestRepository.offers(groomerID:page:)` | `groomer_offers` | `created_at` desc | Store and shared Load More control complete T-230 |
| Bookings | `BookingRepository.bookings(participantID:role:page:)` | `bookings` | `scheduled_start` desc | Customer/groomer Store and shared Load More control complete T-236 |
| Conversations | `ChatRepository.conversations(participantID:role:page:)` | `conversations` | `updated_at` desc | Store has next-page state |
| Messages | `ChatRepository.messages(conversationID:page:)` | `messages` | `created_at`, `id` asc | Store supports next page |
| Customer notifications | `CustomerNotificationRepository.notifications(customerID:page:)` | `customer_notifications` | `created_at` desc | Store and shared Load More control complete T-236 |
| Groomer notifications | `GroomerNotificationRepository.notifications(groomerID:page:)` | `groomer_notifications` | `created_at` desc | Store and shared Load More control complete T-236 |

## Deferred UI Work

- Conversation and message-history UI pagination remains Q-40 work.
- Customer/groomer request and offer lists use the same explicit Load More interaction. A failed next page preserves existing rows and the page cursor so the same action retries safely.
- Booking and notification lists follow the same retry-preserving interaction. Notification mark-all-read updates the loaded window without discarding its next-page cursor.

## Tests

- `ListPaginationFeatureTests` covers default page bounds, `limit + 1` trimming, `hasMore`, booking next-page append, and chat message next-page append.
- Customer/groomer request and offer Store suites cover first-page reset, failed-page retry, ordered unique append, and terminal-page state.
- Booking and customer/groomer notification Store suites cover failed-page retry, stable-ID dedupe, and terminal-page state.
