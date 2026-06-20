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
| RequestWizardView | Compose and publish one request | Customer | Pet repository, request RPC | Request wizard view model | `Features/Requests/` / T-013 | planned |
| CustomerRequestDetailView | Show owned request, status, and offers | Customer | `grooming_requests`, `groomer_offers` | Request detail view model | `Features/Requests/` / T-013, T-017 | planned |
| OfferListView | Compare offers for an owned request | Customer | `groomer_offers`, groomer summary | Offer list view model | `Features/Offers/` / T-017 | planned |
| CustomerBookingListView | Show owned upcoming/completed bookings | Customer | `bookings` | Booking list view model | `Features/Bookings/` / T-019 | planned |
| GroomerProfileEditorView | Maintain groomer profile and services | Groomer | `groomer_profiles`, `groomer_services` | Groomer profile view model | `Features/Groomer/` / T-011 | planned |
| GroomerPortfolioView | Manage portfolio images | Groomer | `groomer_portfolio_photos`, Storage | Portfolio view model | `Features/Groomer/` / T-011 | planned |
| MatchedRequestFeedView | Browse assigned open requests | Groomer | `request_matches`, `grooming_requests` | Request feed view model | `Features/Requests/` / T-014 | planned |
| GroomerRequestDetailView | Review matched request and act | Groomer | Match and request repository | Request detail view model | `Features/Requests/` / T-014 | planned |
| MakeOfferView | Validate and submit an offer | Groomer | Offer RPC | Offer form view model | `Features/Offers/` / T-016 | planned |
| GroomerBookingListView | Show groomer bookings by status | Groomer | `bookings` | Booking list view model | `Features/Bookings/` / T-019 | planned |
| ConversationListView | Show booking conversations | Shared | `conversations` | Conversation list view model | `Features/Chat/` / T-020 | planned |
| ChatView | Participant-only booking chat | Shared | `messages`, optional Storage | Chat view model | `Features/Chat/` / T-020 | planned |
| ReviewView | Submit one review for completed booking | Customer | Review RPC | Review view model | `Features/Reviews/` / T-021 | planned |
| AuthenticatedAccountView | Show minimal authenticated identity/role and sign out | Shared | Auth session, loaded profile | `AuthenticationStore` | `Features/Auth/AuthenticatedAccountView.swift` / T-007 | baseline |
| DebugPanel | Show safe development diagnostics | Developer only | Sanitized repositories/checks | Debug state | `Features/Debug/` / T-022 | planned |
| Admin Dashboard | Administrative management | Admin | Not defined | Not defined | No MVP task | deferred |

The current customer and groomer `TabView` files render the authenticated Account destination and generic placeholder content for all other tabs; they remain navigation shells rather than implemented marketplace features.
