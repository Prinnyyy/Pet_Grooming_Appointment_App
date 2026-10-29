# Screen Inventory

Customer ownership updated: 2026-10-29 (T-421); implementation/acceptance status is recorded in its adoption plan.
Groomer ownership and navigation rechecked: 2026-10-04 (T-402); other role entries retain their previous verification date.

Status values: `beckon adapted`, `planned`, `deferred`. Planned paths are placement contracts, not proof that a file exists.

Future UI work is screenshot-driven. Map every visible module to this table plus the existing SwiftUI view, Store, repository, and model path before editing. If a screenshot implies new persistence, schema, RLS, RPC, Storage, navigation, role capability, or deferred feature, stop for approval.

| Screen | Role | Data/State Owner | Source | Status |
|---|---|---|---|---|
| AuthenticationBootstrapView | Shared | App config / View | `Features/Auth/AuthenticationBootstrapView.swift` | beckon adapted |
| AuthenticationGateView | Shared | Auth session / `AuthenticationStore` | `Features/Auth/AuthenticationGateView.swift` | beckon adapted |
| AuthenticationView | Shared | Supabase Auth / `AuthenticationStore` | `Features/Auth/AuthenticationView.swift` | beckon adapted |
| AuthenticatedEntryView | Shared | `profiles` / `AuthenticatedEntryStore` | `Features/Auth/AuthenticatedEntryView.swift` | beckon adapted |
| RoleOnboardingView | Shared | `create_my_profile` / `AuthenticatedEntryStore` | `Features/Auth/RoleOnboardingView.swift` | beckon adapted |
| CustomerHomeView | Customer | pets, pet photos, unread notifications / `CustomerPetsStore`, `CustomerNotificationsStore` | `Features/Customer/Home/CustomerHomeView.swift` | beckon adapted; semantic/AX3 reference |
| CustomerNotificationsView | Customer | `customer_notifications`, mark-read RPCs / `CustomerNotificationsStore` | `Features/Customer/Notifications/CustomerNotificationsView.swift` | beckon adapted |
| CustomerHomePetsSection / CustomerPetFormView | Customer | `pets`, `pet_photos`, Storage / `CustomerPetsStore` | `Features/Customer/Home/CustomerHomeView.swift` | beckon adapted |
| CustomerGroomingView / CustomerRequestWizardView | Customer | request and booking Stores / wizard state | `Features/Customer/Grooming/CustomerGroomingView.swift`, `Features/Customer/Requests/CustomerRequestWizardView.swift` | beckon adapted; T-421 acceptance in progress |
| GroomingDetailView / CustomerRequestOffersView / CustomerOfferDetailView | Customer | requests, offers, bookings, review eligibility and accept/recovery | `Features/Customer/Grooming/GroomingDetailView.swift`, `Features/Customer/Requests/CustomerRequestOffersView.swift`, `CustomerOfferDetailView.swift` | beckon adapted; T-421 acceptance in progress |
| GroomingHistoryView | Customer | closed requests and inactive bookings / shared Stores | `Features/Customer/Grooming/GroomingHistory.swift` | beckon adapted; T-421 acceptance in progress |
| GroomerHomeView | Groomer | Read-only profile/request/offer/booking summary / `GroomerHomeStore`; shared notification/chat badge sources | `Features/Groomer/Home/GroomerHomeView.swift` | beckon adapted; failed reads are unknown, not zero |
| GroomerAccountHomeView / profile routes | Groomer | profile, services, availability, fit claims and evidence / `GroomerProfileStore` | `Features/Groomer/Profile/GroomerProfileManagementView.swift`, `GroomerProfileAccountView.swift` | beckon adapted; direct Account tab |
| Profile / Services / Portfolio editors | Groomer | Existing profile/service/photo mutations / `GroomerProfileStore` | `Features/Groomer/Profile/GroomerProfileFormView.swift`, `GroomerServicesEditorView.swift`, `GroomerPortfolioEditorView.swift` | beckon adapted; one back route per editor |
| Availability editor | Groomer | Weekly hours, capacity, buffers and time off / `GroomerProfileStore` | `Features/Groomer/Profile/GroomerAvailabilityEditorView.swift` | beckon adapted; Account owns editing, Home is a shortcut |
| Fit Signals / Evidence | Groomer | Editable claims versus read-only outcome evidence / `GroomerProfileStore` | `Features/Groomer/Profile/GroomerFitSignalsEditorView.swift` | beckon adapted; separate user jobs |
| GroomerNotificationsView | Groomer | Existing notification inbox and destination stores | `Features/Groomer/Notifications/GroomerNotificationsView.swift` | beckon adapted; opens from Home |
| MatchedRequestFeedView | Groomer | `request_matches`, `grooming_requests` / `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` | beckon adapted |
| GroomerRequestDetailView / MakeOfferSection | Groomer | match/request reads, offer RPCs / `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` | beckon adapted |
| GroomerOffersView | Groomer | offers with visible request/booking context / `GroomerOffersStore` | `Features/Groomer/Offers/GroomerOffersView.swift` | beckon adapted |
| GroomerBookingListView | Groomer | participant bookings, reviews, cancel/complete RPCs / `BookingsStore` | `Features/Bookings/BookingsView.swift` | beckon adapted |
| BookingDetailView / BookingReviewSection | Shared | booking, review, cancel/complete/review RPCs / `BookingsStore` | `Features/Bookings/BookingsView.swift` | beckon adapted |
| ChatConversationsView / ChatThreadView / ChatComposerBar | Shared | participant-pair `conversations`, typed `messages`, live bookings / `ChatStore`, `BookingsStore` | `Features/Chat/ChatView.swift` | beckon adapted; booking-event cards route to role Booking detail |
| AuthenticatedAccountView | Shared | Auth session and loaded profile / `AuthenticationStore` | `Features/Auth/AuthenticatedAccountView.swift` | beckon adapted |
| CustomerAccountView | Customer | Customer profile plus Auth session / `CustomerProfileStore`, `AuthenticationStore` | `Features/Customer/Profile/CustomerAccountView.swift` | beckon adapted; semantic/AX3 reference |
| CustomerTabView | Customer | injected customer repositories / View | `Features/Customer/CustomerTabView.swift` | beckon adapted |
| GroomerTabView | Groomer | injected groomer repositories / View | `Features/Groomer/GroomerTabView.swift` | beckon adapted |
| FeaturePlaceholderView | Shared | disconnected fallback / View | `DesignSystem/FeaturePlaceholderView.swift` | beckon adapted |
| DebugPanel / Debug Console | Developer | sanitized diagnostics and DEBUG event logs / diagnostics helpers | `Features/Debug/`, `Core/Diagnostics/`, `scripts/ios-debug-events.sh` | beckon adapted |
| Admin Dashboard | Admin | Not defined | No MVP task | deferred |

## Customer composition and expressive tiers

D-064 extends [Lively UI Spec](LIVELY_UI_SPEC.md). Customer Home and authentication landing use Tier L illustration; customer lists/details, form chrome, account/settings, notifications and dialogs use Tier M. Inputs and chat-thread content stay calm; chat receives no page entrance. Groomer workspaces retain Tier C, with the approved shared account actions/booking dialogs. `LEDGE_TIER_PATHS` enumerates the adopted files; role-scoped branches in shared files preserve groomer presentation.

- `CustomerTabView` owns Home / Grooming / Messages / Account, entrance activation, programmatic routes and one shared request-modal presenter for all four tabs.
- `CustomerRequestWizardView` and `CustomerRequestWizardChrome` own six steps; `CustomerGroomerDiscoveryView` supplies step six and Invite more. `GroomerChoice` owns selection, capacity hints and pool controls; the server retains final authority.
- `GroomingCard`, `GroomingFeed`, `GroomingDetailView` and `GroomingHistoryView` own the unified journey. Home uses the same feed at glance size; notification, reminder and customer chat booking links resolve that detail.
- `CustomerFavoriteGroomersView` uses `GroomerFavoritesStore`, starts without a selected request, then applies explicit batch selection in the chosen request context. `CustomerAccountView` owns its entry; no duplicate create-request action.
- `CustomerPetFormView` lives in `Features/Customer/Pets/`; `CustomerProfileSettingsView` in `Features/Customer/Profile/`. They retain real Stores and edit reconciliation.
- `DesignKit`, `DesignDialog`, `DesignSnackbar`, `BeckonMotion` and `FeedbackTimingPolicy` own shared presentation, not business actions. `FlowSandbox/Customer` hosts those real views with DEBUG-only local dependencies; `FlowSandbox/Prototype` remains the frozen design reference.

### Handoff 2 customer module ownership (D-065)

All files below are Tier M except the Tier L authentication landing. The existing Stores remain business owners. This adoption does not require connecting customer pages to current groomer pages; groomer UX is a separate future update.

| Module | Source under `ios/Beckon/Beckon/` | Data owner |
|---|---|---|
| Grooming, card, detail, History, dialogs, review | `Features/Customer/Grooming/CustomerGroomingView.swift`, `GroomingCard.swift`, `GroomingDetailView.swift`, `GroomingDetailParts.swift`, `GroomingDetailActions.swift`, `GroomingHistory.swift`, `GroomingPageParts.swift`, `GroomingActionDialogs.swift`, `GroomingReview.swift` | `CustomerRequestsStore`, `BookingsStore`; `GroomingLifecycle` owns timing |
| Six-step request form | `Features/Customer/Requests/CustomerRequestPetAndService.swift`, `CustomerRequestTimeAndPlace.swift`, `CustomerRequestDetails.swift`, existing Wizard/View/Chrome | `CustomerRequestWizardState`, `CustomerRequestsStore` |
| Saved request strip | `Features/Customer/Favorites/CustomerFavoriteRequestStrip.swift` | existing favorites and request Stores |
| Groomer profile and horizontal photo viewer | `Features/Customer/Discovery/GroomerProfileView.swift`, `CustomerGroomerProfilePage.swift` | `CustomerGroomerProfileStore`, discovery repository; customer-safe profile RPC and existing private image loader |
| Landing | `Features/Auth/AuthenticationLanding.swift` | `AuthenticationStore`; presentation receives values/actions |

## Role Tab Summary

- Customer tabs: Home, Grooming, Messages, Account.
- Groomer tabs: Home, Requests, Schedule, Messages, Account. No system More tab.
- Requests owns the `Matches` / `Offers` workspace. Notifications open from Home. Offer creation and withdrawal remain owned by the existing request/offer features.
- Visual adaptation must preserve Open Request -> Groomer Offer -> Customer Confirmation -> Booking.

## Groomer Module Ownership

- `DesignSystem` owns `BeckonSection`, grouped surfaces/dividers, status/action controls, adaptive section/photo-editor layouts and keyboard handling. Do not reintroduce role-named forwarding wrappers with identical behavior.
- `SharedFeatures` and the shared Bookings/Chat features retain cross-role domain composition. Groomer views reuse these owners rather than copying booking or messaging flows.
- `Features/Groomer/Profile/GroomerSizeRangeControl.swift` owns the slider and legend shared by Services and Fit Signals. It remains feature-local because its size-range semantics are not a generic visual primitive.
- Home summaries route to existing owners; Schedule inspects booked work while Availability edits working rules. Fit Signals are self-declared; Evidence reports outcomes. These distinctions are intentional, not duplicate modules.
