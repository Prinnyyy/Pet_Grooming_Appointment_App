# Screen Inventory

Status values are `baseline`, `planned`, and `deferred`. A planned source path is a placement contract, not an existing file.

| Screen | Purpose | Role | Planned Data Source | State Owner | Source / Task | Status |
|---|---|---|---|---|---|---|
| AuthenticationBootstrapView | Blocking missing/invalid Supabase configuration state | Shared | App configuration | View | `Features/Auth/AuthenticationBootstrapView.swift` | baseline |
| AuthenticationGateView | Restore/observe Auth session and select signed-out or authenticated entry UI | Shared | Supabase Auth session | `AuthenticationStore` | `Features/Auth/AuthenticationGateView.swift` / T-006–T-007 | baseline |
| AuthenticationView | Email/password sign-in and account creation with confirmation notice | Shared | Supabase Auth | `AuthenticationStore` | `Features/Auth/AuthenticationView.swift` / T-006 | baseline |
| AuthenticatedEntryView | Load authoritative profile and select onboarding, Customer tabs, Groomer tabs, or retryable failure | Shared | `profiles` | `AuthenticatedEntryStore` | `Features/Auth/AuthenticatedEntryView.swift` / T-007 | baseline |
| RoleOnboardingView | Enter display name, select immutable role, and create profile rows | Shared | `create_my_profile` | `AuthenticatedEntryStore` | `Features/Auth/RoleOnboardingView.swift` / T-007 | baseline |
| CustomerHomeView | Start request and summarize active work | Customer | Own requests, bookings | Customer home view model | `Features/Customer/` / T-013, T-019 | planned |
| PetListView | List and manage owned pets | Customer | `pets`, `pet_photos` | Pet list view model | `Features/Pets/` / T-009 | planned |
| PetEditorView | Create/edit pet and upload photos | Customer | `pets`, `pet_photos`, Storage | Pet editor view model | `Features/Pets/` / T-009 | planned |
| RequestWizardView | Compose and publish one request | Customer | Pet repository, request RPC | `CustomerRequestsStore` | `Features/Customer/Requests/CustomerRequestsView.swift` / T-013 | baseline |
| CustomerRequestDetailView | Show owned request status, frozen pet snapshot, time, location, received offers, and offer acceptance entry point | Customer | `grooming_requests`, `groomer_offers`, active `groomer_profiles` summaries, `accept_groomer_offer` | `CustomerRequestsStore` | `Features/Customer/Requests/CustomerRequestsView.swift` / T-013, T-017, T-019 | baseline |
| CustomerOfferReviewSection | Compare pending offers, separate offer history, and open offer details inside owned request detail | Customer | `groomer_offers`, active `groomer_profiles` summaries | `CustomerRequestsStore` | `Features/Customer/Requests/CustomerRequestsView.swift` / T-017 | baseline |
| CustomerBookingListView | Show owned bookings with appointment time/price/status context, support references, booking details, and completed-booking review state | Customer | `bookings`, `reviews`, `cancel_booking`, `create_review` | `BookingsStore` | `Features/Bookings/BookingsView.swift` / T-019, T-021 | baseline |
| GroomerProfileEditorView | Maintain groomer profile and services | Groomer | `groomer_profiles`, `groomer_services` | `GroomerProfileStore` | `Features/Groomer/Profile/GroomerProfileManagementView.swift` / T-011 | baseline |
| GroomerPortfolioView | Manage portfolio image metadata and upload/delete path | Groomer | `groomer_portfolio_photos`, Storage | `GroomerProfileStore` | `Features/Groomer/Profile/GroomerProfileManagementView.swift` / T-011 | baseline |
| MatchedRequestFeedView | Browse assigned open requests | Groomer | `request_matches`, `grooming_requests` | `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` / T-014 | baseline |
| GroomerRequestDetailView | Review matched request, dismiss, submit an offer, and withdraw a pending offer | Groomer | Match/request reads and offer RPCs | `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` / T-014, T-016 | baseline |
| MakeOfferSection | Validate and submit a groomer offer inside matched request detail | Groomer | `create_groomer_offer`, `withdraw_groomer_offer` | `GroomerRequestsStore` | `Features/Groomer/Requests/GroomerRequestsView.swift` / T-016 | baseline |
| GroomerBookingListView | Show groomer participant bookings with appointment time/price/status context, support references, booking details, and completion state | Groomer | `bookings`, `reviews`, `cancel_booking`, `complete_booking` | `BookingsStore` | `Features/Bookings/BookingsView.swift` / T-019, T-021 | baseline |
| BookingDetailView | Show shared participant booking details, support references, cancellation state, groomer completion action, and customer review form/display | Shared | `bookings`, `reviews`, `cancel_booking`, `complete_booking`, `create_review` | `BookingsStore` | `Features/Bookings/BookingsView.swift` / T-019, T-021 | baseline |
| ConversationListView | Show booking conversations with participant-readable booking context | Shared | `conversations`, `bookings`, active `groomer_profiles` summaries where RLS permits | `ChatStore` | `Features/Chat/ChatView.swift` / T-020 | baseline |
| ChatView | Participant-only text booking chat with booking support context | Shared | `messages`, `bookings` | `ChatStore` | `Features/Chat/ChatView.swift` / T-020 | baseline |
| BookingReviewSection | Submit or display one review for a completed booking inside booking detail | Customer | `create_review`, `reviews` | `BookingsStore` | `Features/Bookings/BookingsView.swift` / T-021 | baseline |
| AuthenticatedAccountView | Show minimal authenticated identity/role and sign out | Shared | Auth session, loaded profile | `AuthenticationStore` | `Features/Auth/AuthenticatedAccountView.swift` / T-007 | baseline |
| DebugPanel | Show safe development diagnostics without tokens, passwords, full keys, or full user identifiers | Developer only | Sanitized app/session/config values | `DebugDiagnostics` | `Features/Debug/` / T-022 | baseline |
| Admin Dashboard | Administrative management | Admin | Not defined | Not defined | No MVP task | deferred |

The current customer `TabView` renders customer pet management on Home, request wizard/list/detail/offer acceptance on Requests, participant bookings on Bookings, participant text chat on Messages, and authenticated Account content. The current groomer `TabView` renders matched request feed/detail/dismiss/offer creation on Requests, participant bookings on Bookings, participant text chat on Messages, groomer profile/services/portfolio management on Account, and generic placeholder content for Offers.
