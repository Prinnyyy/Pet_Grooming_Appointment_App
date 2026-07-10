# Screen Inventory

Last verified: 2026-07-08.

Status values: `beckon adapted`, `planned`, `deferred`. Planned paths are placement contracts, not proof that a file exists.

Future UI work is screenshot-driven. Map every visible module to this table plus the existing SwiftUI view, Store, repository, and model path before editing. If a screenshot implies new persistence, schema, RLS, RPC, Storage, navigation, role capability, or deferred feature, stop for approval.

| Screen | Role | Data/State Owner | Source | Status |
|---|---|---|---|---|
| AuthenticationBootstrapView | Shared | App config / View | `Features/Auth/AuthenticationBootstrapView.swift` | beckon adapted |
| AuthenticationGateView | Shared | Auth session / `AuthenticationStore` | `Features/Auth/AuthenticationGateView.swift` | beckon adapted |
| AuthenticationView | Shared | Supabase Auth / `AuthenticationStore` | `Features/Auth/AuthenticationView.swift` | beckon adapted |
| AuthenticatedEntryView | Shared | `profiles` / `AuthenticatedEntryStore` | `Features/Auth/AuthenticatedEntryView.swift` | beckon adapted |
| RoleOnboardingView | Shared | `create_my_profile` / `AuthenticatedEntryStore` | `Features/Auth/RoleOnboardingView.swift` | beckon adapted |
| CustomerHomeView | Customer | pets, pet photos, unread notifications / `CustomerPetsStore`, `CustomerNotificationsStore` | `Features/Customer/Pets/CustomerPetsView.swift` | beckon adapted |
| CustomerNotificationsView | Customer | `customer_notifications`, mark-read RPCs / `CustomerNotificationsStore` | `Features/Customer/Notifications/CustomerNotificationsView.swift` | beckon adapted |
| PetListView / PetEditorView | Customer | `pets`, `pet_photos`, Storage / `CustomerPetsStore` | `Features/Customer/Pets/CustomerPetsView.swift` | beckon adapted |
| CustomerRequestsView / RequestWizardView | Customer | own requests, pets, request RPC / `CustomerRequestsStore` | `Features/Customer/Requests/CustomerRequestsView.swift` | beckon adapted |
| CustomerRequestDetailView / CustomerOfferReviewSection | Customer | requests, offers, active groomer summaries, accept RPC / `CustomerRequestsStore` | `Features/Customer/Requests/CustomerRequestsView.swift` | beckon adapted |
| CustomerBookingListView | Customer | `bookings`, `reviews`, cancel/review RPCs / `BookingsStore` | `Features/Bookings/BookingsView.swift` | beckon adapted |
| GroomerHomeView | Groomer | Existing profile/request/offer/booking/notification/chat repositories / planned `GroomerHomeStore` | Planned `Features/Groomer/Home/` | planned R-039/Q-97 |
| GroomerProfileEditorView / PortfolioView | Groomer | profile, services, portfolio metadata, Storage / `GroomerProfileStore` | `Features/Groomer/Profile/GroomerProfileManagementView.swift` | beckon adapted |
| MatchedRequestFeedView | Groomer | `request_matches`, `grooming_requests` / `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` | beckon adapted |
| GroomerRequestDetailView / MakeOfferSection | Groomer | match/request reads, offer RPCs / `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` | beckon adapted |
| GroomerOffersView | Groomer | offers with visible request/booking context / `GroomerOffersStore` | `Features/Groomer/Offers/GroomerOffersView.swift` | beckon adapted |
| GroomerBookingListView | Groomer | participant bookings, reviews, cancel/complete RPCs / `BookingsStore` | `Features/Bookings/BookingsView.swift` | beckon adapted |
| BookingDetailView / BookingReviewSection | Shared | booking, review, cancel/complete/review RPCs / `BookingsStore` | `Features/Bookings/BookingsView.swift` | beckon adapted |
| ConversationListView / ChatView | Shared | `conversations`, `messages`, participant booking context / `ChatStore` | `Features/Chat/ChatView.swift` | beckon adapted |
| AuthenticatedAccountView | Shared | Auth session and loaded profile / `AuthenticationStore` | `Features/Auth/AuthenticatedAccountView.swift` | beckon adapted |
| CustomerTabView | Customer | injected customer repositories / View | `Features/Customer/CustomerTabView.swift` | beckon adapted |
| GroomerTabView | Groomer | injected groomer repositories / View | `Features/Groomer/GroomerTabView.swift` | beckon adapted |
| FeaturePlaceholderView | Shared | disconnected fallback / View | `DesignSystem/FeaturePlaceholderView.swift` | beckon adapted |
| DebugPanel / Debug Console | Developer | sanitized diagnostics and DEBUG event logs / diagnostics helpers | `Features/Debug/`, `Core/Diagnostics/`, `scripts/ios-debug-events.sh` | beckon adapted |
| Admin Dashboard | Admin | Not defined | No MVP task | deferred |

## Role Tab Summary

- Customer tabs: Home, Requests, Bookings, Messages, Account.
- Current Groomer code exposes Board, Offers, Schedule, Messages, Alerts, and Account; iOS places Alerts/Account under a system More tab.
- Approved R-039 Groomer target: Home, Requests, Schedule, Messages, Account.
- R-039 moves submitted-offer tracking into the Requests `Matches` / `Offers` workspace and opens Notifications from Groomer Home. Offer creation and withdrawal behavior remains owned by the existing request/offer features.
- Visual adaptation must preserve Open Request -> Groomer Offer -> Customer Confirmation -> Booking.
