# Product Directions

This file holds unadopted/deferred product directions, not current tasks. [Current State](../00_memory/CURRENT_STATE.md) owns IDs and pending work. Start only a user-adopted objective; external reports and old roadmap drafts are review input, not authorization.

## Local Product Directions

| Direction | Condition |
|---|---|
| R-039 / Q-104 Groomer Dynamic Type and Accessibility integration | User restores the deferred scope and adopts affected cross-screen validation. |
| R-033 / Q-93 leaked-password protection | Hosted capability/plan decision and explicit Auth configuration authorization. Not a prerequisite to unrelated local work. |

## Separate Distribution Scope

These are outside the adopted local Simulator target and must not be added to local completion gates.

| Direction | Condition |
|---|---|
| R-030 / Q-90 APNs dispatch deployment | Explicit deployment scope, Apple access and APNs credentials. Existing task recovery stays in Current State. |
| R-030 / Q-91 TestFlight/App Store submission | Explicit release/upload authorization and its external prerequisites. |

## Product Boundary

Customer Request -> Groomer Offer -> Customer Acceptance -> Booking/Chat -> Groomer Completion -> Customer Review remains the supported flow.

Payments, subscriptions, public directory/map-first discovery, AI recommendations, multi-pet requests, favorites, chat attachments/server read receipts, in-place request editing, moderation/admin tooling, social login and direct customer slot booking are not adopted by this roadmap. Current replacement/recovery behavior is owned by the domain contracts, not inferred from this exclusions list.

Keep account deletion/privacy/support accurate and select build, test, backend and cleanup evidence by risk. Record actual product/release decisions in [Decision Log](../07_decisions/DECISION_LOG.md).

R-042 / Q-121 through Q-125 completed through T-363; later functional reliability is covered by [T-385 local acceptance](sql_reviews/T-385_RELEASE_CHECKPOINT.md). Prior roadmap mappings remain in the historical archive, not a second execution queue.
