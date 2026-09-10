# Feature Index

Choose the relevant row, then inspect targeted code. These are ownership routes, not a status ledger or a mandatory reading chain.

| Feature | Code Entry | Relevant Contract |
|---|---|---|
| Authentication and role routing | [Auth](../../ios/Beckon/Beckon/Features/Auth/) | [Roles](../01_product/USER_ROLES.md) |
| Design System and forms | [DesignSystem](../../ios/Beckon/Beckon/DesignSystem/) | [Design System](../01_product/DESIGN_SYSTEM.md), [form interaction](../01_product/FORM_INTERACTION_RULES.md) |
| Customer account and address | [Profile](../../ios/Beckon/Beckon/Features/Customer/Profile/) | [Data flow](../02_architecture/DATA_FLOW.md) |
| Pets and private photos | [Pets](../../ios/Beckon/Beckon/Features/Customer/Pets/) | [Storage](../03_backend/STORAGE_POLICY.md) |
| Notifications | [Customer](../../ios/Beckon/Beckon/Features/Customer/Notifications/), [Groomer](../../ios/Beckon/Beckon/Features/Groomer/Notifications/) | [RLS/RPC](../03_backend/RLS_RPC_POLICY.md) |
| Groomer profile, services and schedule | [Profile](../../ios/Beckon/Beckon/Features/Groomer/Profile/) | [Backend](../03_backend/SUPABASE_CONTRACT.md) |
| Requests and matching | [Customer](../../ios/Beckon/Beckon/Features/Customer/Requests/), [Groomer](../../ios/Beckon/Beckon/Features/Groomer/Requests/) | [Data flow](../02_architecture/DATA_FLOW.md) |
| Coordinate confirmation and radius | [Repositories](../../ios/Beckon/Beckon/Core/Repositories/) | [Address backfill](../04_ios/ADDRESS_BACKFILL.md) |
| Pet-fit evidence | [Models](../../ios/Beckon/Beckon/Core/Models/), [Groomer profile](../../ios/Beckon/Beckon/Features/Groomer/Profile/) | [UX](../01_product/UX_RULES.md) |
| Offers and acceptance | [Offers](../../ios/Beckon/Beckon/Features/Groomer/Offers/), [Customer requests](../../ios/Beckon/Beckon/Features/Customer/Requests/) | [RLS/RPC](../03_backend/RLS_RPC_POLICY.md) |
| Bookings, fulfillment and reviews | [Bookings](../../ios/Beckon/Beckon/Features/Bookings/) | [Fulfillment](../03_backend/BOOKING_FULFILLMENT_CONTRACT.md), [rescheduling](../03_backend/BOOKING_RESCHEDULING_CONTRACT.md) |
| Participant chat | [Chat](../../ios/Beckon/Beckon/Features/Chat/) | [Module boundaries](../02_architecture/MODULE_BOUNDARIES.md) |
| Diagnostics | [Debug](../../ios/Beckon/Beckon/Features/Debug/) | [Debug Console](../04_ios/DEBUG_CONSOLE.md) |
| Account deletion and privacy | [Delete account function](../../supabase/functions/delete-account/) | [Storage](../03_backend/STORAGE_POLICY.md), [privacy policy](../04_ios/release/PRIVACY_POLICY.md) |
| Build and TestOps | [Scripts](../../scripts/), [TestOps tests](../../tests/testops/) | [Build/test](../04_ios/IOS_BUILD_AND_TESTING.md), [TestOps](../04_ios/testops/README.md) |

Use source and the affected domain contract for exact behavior; this index does not summarize RPC revisions or prescribe reading unrelated documents.
