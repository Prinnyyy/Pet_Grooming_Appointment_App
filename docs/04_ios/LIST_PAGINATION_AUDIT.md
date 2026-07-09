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
| Customer requests | `CustomerRequestRepository.requests(customerID:page:)` | `grooming_requests` | `created_at` desc | First-page range applied |
| Customer offers | `CustomerRequestRepository.offers(customerID:requestID:page:)` | `groomer_offers` | `created_at` desc | First-page range applied |
| Groomer matched requests | `GroomerRequestRepository.matchedRequests(groomerID:page:)` | `request_matches` | `created_at` desc | First-page range applied |
| Groomer offers | `GroomerRequestRepository.offers(groomerID:page:)` | `groomer_offers` | `created_at` desc | First-page range applied |
| Bookings | `BookingRepository.bookings(participantID:role:page:)` | `bookings` | `scheduled_start` desc | Store supports next page |
| Conversations | `ChatRepository.conversations(participantID:role:page:)` | `conversations` | `updated_at` desc | Store has next-page state |
| Messages | `ChatRepository.messages(conversationID:page:)` | `messages` | `created_at`, `id` asc | Store supports next page |
| Customer notifications | `CustomerNotificationRepository.notifications(customerID:page:)` | `customer_notifications` | `created_at` desc | First-page range applied |
| Groomer notifications | `GroomerNotificationRepository.notifications(groomerID:page:)` | `groomer_notifications` | `created_at` desc | First-page range applied |

## Deferred UI Work

- Current V1.0 screens still call first-page load for most lists.
- `BookingsStore` and `ChatStore` expose next-page methods/state for future "Load more" controls or scroll-triggered pagination.
- Customer request, groomer request, offer, and notification UI controls remain deferred until product design requests visible pagination.

## Tests

- `ListPaginationFeatureTests` covers default page bounds, `limit + 1` trimming, `hasMore`, booking next-page append, and chat message next-page append.
