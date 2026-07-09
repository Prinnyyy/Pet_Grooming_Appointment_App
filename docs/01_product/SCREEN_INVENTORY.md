# Screen Inventory

Last verified: 2026-07-08.

Status values: `groomly adapted`, `planned`, `deferred`. Planned paths are placement contracts, not proof that a file exists.

Future UI work is screenshot-driven. Map every visible module to this table plus the existing SwiftUI view, Store, repository, and model path before editing. If a screenshot implies new persistence, schema, RLS, RPC, Storage, navigation, role capability, or deferred feature, stop for approval.

| Screen | Role | Data/State Owner | Source | Status |
|---|---|---|---|---|
| AuthenticationBootstrapView | Shared | App config / View | `Features/Auth/AuthenticationBootstrapView.swift` | groomly adapted |
| AuthenticationGateView | Shared | Auth session / `AuthenticationStore` | `Features/Auth/AuthenticationGateView.swift` | groomly adapted |
| AuthenticationView | Shared | Supabase Auth / `AuthenticationStore` | `Features/Auth/AuthenticationView.swift` | groomly adapted |
| AuthenticatedEntryView | Shared | `profiles` / `AuthenticatedEntryStore` | `Features/Auth/AuthenticatedEntryView.swift` | groomly adapted |
| RoleOnboardingView | Shared | `create_my_profile` / `AuthenticatedEntryStore` | `Features/Auth/RoleOnboardingView.swift` | groomly adapted |
| CustomerHomeView | Customer | pets, pet photos, unread notifications / `CustomerPetsStore`, `CustomerNotificationsStore` | `Features/Customer/Pets/CustomerPetsView.swift` | groomly adapted |
| CustomerNotificationsView | Customer | `customer_notifications`, mark-read RPCs / `CustomerNotificationsStore` | `Features/Customer/Notifications/CustomerNotificationsView.swift` | groomly adapted |
| PetListView / PetEditorView | Customer | `pets`, `pet_photos`, Storage / `CustomerPetsStore` | `Features/Customer/Pets/CustomerPetsView.swift` | groomly adapted |
| CustomerRequestsView / RequestWizardView | Customer | own requests, pets, request RPC / `CustomerRequestsStore` | `Features/Customer/Requests/CustomerRequestsView.swift` | groomly adapted |
| CustomerRequestDetailView / CustomerOfferReviewSection | Customer | requests, offers, active groomer summaries, accept RPC / `CustomerRequestsStore` | `Features/Customer/Requests/CustomerRequestsView.swift` | groomly adapted |
| CustomerBookingListView | Customer | `bookings`, `reviews`, cancel/review RPCs / `BookingsStore` | `Features/Bookings/BookingsView.swift` | groomly adapted |
| GroomerProfileEditorView / PortfolioView | Groomer | profile, services, portfolio metadata, Storage / `GroomerProfileStore` | `Features/Groomer/Profile/GroomerProfileManagementView.swift` | groomly adapted |
| MatchedRequestFeedView | Groomer | `request_matches`, `grooming_requests` / `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` | groomly adapted |
| GroomerRequestDetailView / MakeOfferSection | Groomer | match/request reads, offer RPCs / `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` | groomly adapted |
| GroomerOffersView | Groomer | offers with visible request/booking context / `GroomerOffersStore` | `Features/Groomer/Offers/GroomerOffersView.swift` | groomly adapted |
| GroomerBookingListView | Groomer | participant bookings, reviews, cancel/complete RPCs / `BookingsStore` | `Features/Bookings/BookingsView.swift` | groomly adapted |
| BookingDetailView / BookingReviewSection | Shared | booking, review, cancel/complete/review RPCs / `BookingsStore` | `Features/Bookings/BookingsView.swift` | groomly adapted |
| ConversationListView / ChatView | Shared | `conversations`, `messages`, participant booking context / `ChatStore` | `Features/Chat/ChatView.swift` | groomly adapted |
| AuthenticatedAccountView | Shared | Auth session and loaded profile / `AuthenticationStore` | `Features/Auth/AuthenticatedAccountView.swift` | groomly adapted |
| CustomerTabView | Customer | injected customer repositories / View | `Features/Customer/CustomerTabView.swift` | groomly adapted |
| GroomerTabView | Groomer | injected groomer repositories / View | `Features/Groomer/GroomerTabView.swift` | groomly adapted |
| FeaturePlaceholderView | Shared | disconnected fallback / View | `DesignSystem/FeaturePlaceholderView.swift` | groomly adapted |
| DebugPanel / Debug Console | Developer | sanitized diagnostics and DEBUG event logs / diagnostics helpers | `Features/Debug/`, `Core/Diagnostics/`, `scripts/ios-debug-events.sh` | groomly adapted |
| Admin Dashboard | Admin | Not defined | No MVP task | deferred |

## Role Tab Summary

- Customer tabs: Home, Requests, Bookings, Messages, Account.
- Groomer tabs: Board, Offers, Schedule, Messages, Account.
- Offer creation and withdrawal remain inside groomer Board/request detail.
- Visual adaptation must preserve Open Request -> Groomer Offer -> Customer Confirmation -> Booking.
