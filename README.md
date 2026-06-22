# Pet Groomer Marketplace

iOS SwiftUI marketplace app for pet grooming appointments.

Current product flow:

```text
Customer publishes an open grooming request
-> matched groomers make offers
-> customer accepts one offer
-> booking and chat are created
-> groomer completes the booking
-> customer leaves a review
```

## Active Phase

The MVP implementation is complete through T-022. T-022 post-MVP next-task suggestions are frozen and recoverable from:

```text
docs/09_frozen/pre_groomly_ui_2026-06-21/
```

The completed Groomly foundation sequence is:

```text
docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md
```

The completed screen-specific Groomly slices are:

```text
docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md
docs/06_tasks/T-025_GROOMLY_CUSTOMER_PETS_UI.md
docs/06_tasks/T-026_GROOMLY_CUSTOMER_REQUESTS_LIST_STATUS_UI.md
docs/06_tasks/T-027_GROOMLY_CUSTOMER_REQUEST_WIZARD_UI.md
docs/06_tasks/T-028_GROOMLY_CUSTOMER_REQUEST_DETAIL_OFFERS_UI.md
docs/06_tasks/T-029_GROOMLY_GROOMER_REQUESTS_FEED_DETAIL_UI.md
docs/06_tasks/T-030_GROOMLY_GROOMER_OFFER_FORM_STATUS_UI.md
docs/06_tasks/T-031_GROOMLY_GROOMER_PROFILE_SERVICES_UI.md
docs/06_tasks/T-032_GROOMLY_GROOMER_PORTFOLIO_UI.md
docs/06_tasks/T-033_GROOMLY_BOOKINGS_UI.md
docs/06_tasks/T-034_GROOMLY_CHAT_UI.md
docs/06_tasks/T-035_GROOMLY_ACCOUNT_TABS_DEBUG_FINAL_UI.md
```

The Groomly UI completion sequence is completed:

```text
docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md
```

No active next Groomly UI task is currently defined. Do not start backend contracts, product-flow changes, Admin Dashboard, or deferred post-MVP features without an explicit task.

## Main References

- Agent rules: `AGENTS.md`
- Current state: `docs/00_memory/CURRENT_STATE.md`
- Task ledger: `docs/06_tasks/TASK_LEDGER.md`
- Groomly foundation sequence: `docs/06_tasks/T-023_GROOMLY_UI_FOUNDATION_SEQUENCE.md`
- Completed Auth/Onboarding slice: `docs/06_tasks/T-024_GROOMLY_AUTH_ONBOARDING_UI.md`
- Completed Customer Pets/Home slice: `docs/06_tasks/T-025_GROOMLY_CUSTOMER_PETS_UI.md`
- Completed Groomly UI sequence: `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`
- Completed Customer Requests List/Status slice: `docs/06_tasks/T-026_GROOMLY_CUSTOMER_REQUESTS_LIST_STATUS_UI.md`
- Completed Customer Request Wizard slice: `docs/06_tasks/T-027_GROOMLY_CUSTOMER_REQUEST_WIZARD_UI.md`
- Completed Customer Request Detail/Offers slice: `docs/06_tasks/T-028_GROOMLY_CUSTOMER_REQUEST_DETAIL_OFFERS_UI.md`
- Completed Groomer Requests Feed/Detail slice: `docs/06_tasks/T-029_GROOMLY_GROOMER_REQUESTS_FEED_DETAIL_UI.md`
- Completed Groomer Offer Form/Status slice: `docs/06_tasks/T-030_GROOMLY_GROOMER_OFFER_FORM_STATUS_UI.md`
- Completed Groomer Profile/Services slice: `docs/06_tasks/T-031_GROOMLY_GROOMER_PROFILE_SERVICES_UI.md`
- Completed Groomer Portfolio slice: `docs/06_tasks/T-032_GROOMLY_GROOMER_PORTFOLIO_UI.md`
- Completed Bookings slice: `docs/06_tasks/T-033_GROOMLY_BOOKINGS_UI.md`
- Completed Chat slice: `docs/06_tasks/T-034_GROOMLY_CHAT_UI.md`
- Completed Account/Tabs/Debug final slice: `docs/06_tasks/T-035_GROOMLY_ACCOUNT_TABS_DEBUG_FINAL_UI.md`
- Groomly design prompt: `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`
- Groomly prototype: `docs/08_design/Groomly.html`
- Existing SwiftUI design tokens: `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/DesignTokens.swift`

## Validation Commands

```sh
./scripts/ios-build.sh
./scripts/ios-test.sh
./scripts/preflight.sh
./scripts/supabase-check.sh
```
