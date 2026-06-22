# T-026 to T-035 - Groomly UI Completion Sequence

- State: completed.
- Mode: Sequence.
- Depends on: completed T-025 Groomly Customer Pets/Home UI.

## Goal

Finish the Groomly UI adaptation for all remaining implemented screens through a fixed sequence of small screen-specific tasks. This file is the queue contract only; each executable task lives in its own `T-026` through `T-035` task file.

## Execution Order

| Order | Task | Primary Area | Result |
|---|---|---|---|
| 1 | `T-026_GROOMLY_CUSTOMER_REQUESTS_LIST_STATUS_UI.md` | Customer request tab shell, request list, summary rows, loading/empty/error states | Customer Requests tab uses Groomly surfaces before form/detail work |
| 2 | `T-027_GROOMLY_CUSTOMER_REQUEST_WIZARD_UI.md` | Customer request creation wizard | Publish-request form uses Groomly form, card, and action styling |
| 3 | `T-028_GROOMLY_CUSTOMER_REQUEST_DETAIL_OFFERS_UI.md` | Customer request detail, offer review, offer acceptance entry | Owned request detail and offer comparison use Groomly cards/status/action styling |
| 4 | `T-029_GROOMLY_GROOMER_REQUESTS_FEED_DETAIL_UI.md` | Groomer matched-request feed and detail shell | Matched request browse/detail/dismiss flow uses Groomly styling |
| 5 | `T-030_GROOMLY_GROOMER_OFFER_FORM_STATUS_UI.md` | Groomer offer creation, pending/withdrawn status | Offer form and status blocks use Groomly form/action/feedback styling |
| 6 | `T-031_GROOMLY_GROOMER_PROFILE_SERVICES_UI.md` | Groomer profile and services management | Profile form, service list, and service sheet use Groomly styling |
| 7 | `T-032_GROOMLY_GROOMER_PORTFOLIO_UI.md` | Groomer portfolio metadata and upload/delete UI | Portfolio section uses Groomly cards/feedback/actions without image rendering changes |
| 8 | `T-033_GROOMLY_BOOKINGS_UI.md` | Shared customer/groomer bookings list, detail, cancellation, completion, review | Bookings and review surfaces use Groomly styling |
| 9 | `T-034_GROOMLY_CHAT_UI.md` | Conversation list, chat thread, composer | Participant text chat uses Groomly message and composer styling |
| 10 | `T-035_GROOMLY_ACCOUNT_TABS_DEBUG_FINAL_UI.md` | Account, customer/groomer tabs, debug panel, final inventory/docs audit | Remaining implemented baseline UI adapted; Admin Dashboard explicitly deferred |

## Global Rules

- Execute only one task from this sequence per Codex run unless the user explicitly changes the workflow.
- Do not skip ahead. If a task exposes a blocker, stop and update the queue instead of editing a later screen.
- Keep existing Store, repository, model, Supabase, RLS, RPC, Storage, routing, and product behavior unchanged.
- Use `docs/08_design/` only as a visual and interaction reference. Do not copy HTML, CSS, or React into SwiftUI.
- Preserve the current Open Request -> Groomer Offer -> Customer Confirmation -> Booking model.
- Do not implement deferred prototype features such as request cancellation, favorites, signed URL image rendering, realtime chat, attachments, payments, maps, calendars, availability, payouts, admin tools, or push notifications.
- New reusable UI helpers are allowed only when a task proves a small, pure DesignSystem gap. They must not carry business logic.

## Completion Definition

The Groomly UI phase is complete only when:

- T-026 through T-035 are completed.
- Every implemented screen in `docs/01_product/SCREEN_INVENTORY.md` is marked `groomly adapted`, except explicitly deferred Admin work.
- `docs/01_product/DESIGN_SYSTEM.md` records each completed screen slice.
- `docs/00_memory/CURRENT_STATE.md` and `docs/06_tasks/TASK_LEDGER.md` no longer point to a remaining Groomly UI screen task.
- The final task's validation passes or records the first unrelated blocker under project stop rules.

## Validation Policy

Each executable task in this sequence should run:

```sh
./scripts/ios-build.sh
git diff --check
```

Do not run backend checks for these UI slices. Run broader tests only if a task accidentally touches behavior-bearing code, in which case the task should usually stop and report instead.

## Stop Conditions

Stop and report if any task requires:

- backend/schema/RLS/RPC changes;
- repository, Store, or model rewrites;
- product-flow changes;
- asset licensing decisions;
- remote image rendering or signed URL support;
- changing more than the task's named UI surface.
