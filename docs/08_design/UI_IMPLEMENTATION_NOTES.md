# Beckon UI Implementation Notes

This is the active Beckon visual-reference index. Keep it short and current. The full pre-slim audit, including inspected design-source file lists, prototype screen catalog, SwiftUI mapping table, deferred prototype ideas, and asset notes, is archived at `../09_frozen/design_notes/UI_IMPLEMENTATION_NOTES_2026-07-02_PRE_SLIM.md`.

## Default Read Path

For current UI work, read in this order:

1. `../01_product/DESIGN_SYSTEM.md`
2. this file
3. `../01_product/SCREEN_INVENTORY.md`
4. `screenshots/README.md` when screenshot assets are involved
5. `../06_tasks/SCREENSHOT_UI_REWORK_TASK_TEMPLATE.md` for screenshot-driven tasks
6. `design_tokens.json` only when token details matter

Do not read Beckon HTML/export files by default. Use them only when a screenshot task explicitly needs design-source comparison. Do not copy HTML, CSS, React, generated JavaScript, or prototype runtime code into SwiftUI.

## Brand And Model

The prototype brand is `Beckon` with the tagline "Pet groomers at your beck and call."

The visual direction is compatible with the app only when it preserves the current marketplace model:

```text
Customer publishes one grooming request
-> matched groomers make offers
-> customer accepts one offer
-> booking and chat are created
```

Prototype-only ideas remain visual inspiration unless separately approved as product/backend work.

## Visual Summary

- Warm, soft mobile UI on cream/off-white backgrounds.
- High-radius white cards with thin warm-gray borders and low-opacity shadows.
- Mint/teal customer primary actions and progress states.
- Coral secondary/accent styling for groomer mode and groomer primary actions.
- Friendly pet-care cues through icons, rounded avatars, gentle status copy, and calm empty/error/loading states.
- iPhone-style navigation patterns: bottom tabs, sticky headers, sheets, toasts, and compact status feedback.

Core observed colors:

- Background: `#FAF7F2`, `#EFEAE1`, `#EBE4D9`
- Surface: `#FFFFFF`
- Border/divider: `#EFEAE1`, `#E8E2D8`
- Text: `#232323`, `#6F767E`
- Customer mint: `#7ECFC0`, `#5FBFAE`
- Groomer coral: `#FF9A8B`, `#F58575`
- State colors: success `#6CBF84`, warning `#F2B84B`, error `#E56B6F`

Use `design_tokens.json` and Swift `DesignTokens` as the implementation source. Do not import every observed prototype color.

## Typography And Layout

- Prefer native SF/SwiftUI semantic text styles with Dynamic Type.
- Page titles are bold and clear; body/supporting copy stays readable and restrained.
- Screen horizontal padding is typically around 20-24 pt.
- Primary buttons are tall, rounded, and visually dominant.
- Inputs use rounded rectangular fields with clear disabled/error states.
- Cards, sheets, chips, progress, timelines, and chat rows should use shared primitives where available.

## Preserve Existing App State

UI changes must preserve:

- Supabase configuration bootstrap and blocking invalid-config states.
- Auth session restore, signed-out auth UI, profile loading, and retryable failures.
- Immutable customer/groomer role separation.
- Customer pets, request publishing, request detail, frozen pet snapshot, matched-count feedback, offers, and offer acceptance.
- Groomer matched request feed/detail/dismiss, offer creation/withdrawal, and status states.
- Booking lists/details, cancellation, groomer completion, customer review, participant text chat, and authenticated account.
- Groomer profile, services, portfolio metadata, and safe developer Debug Console.
- Store/repository/service boundaries; SwiftUI views must not call Supabase directly.

## Deferred Prototype Concepts

Stop and ask before implementing any of these from a screenshot or prototype: direct public groomer discovery, direct slot booking, full schedule/calendar workflows beyond existing booking surfaces, payments/payouts/refunds, favorites, maps, chat attachments, read receipts, typing indicators, push behavior beyond the approved T-153/T-157 notification scope, admin tools, demo role switching, demo data, or any fake production success path.

## Asset Notes

The extracted prototype mostly contains HTML/CSS/JS, inline SVGs, emoji placeholders, screenshots, generated artifacts, and macOS metadata. No production-ready licensed logo, icon set, pet photos, groomer photos, or illustration package has been approved from it. Any future asset use needs explicit source/licensing review.
