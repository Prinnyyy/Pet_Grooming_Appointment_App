# Screen Inventory

Status values are `baseline`, `planned`, and `deferred`. A planned source path is a placement contract, not an existing file.

| Screen | Purpose | Role | Planned Data Source | State Owner | Source / Task | Status |
|---|---|---|---|---|---|---|
| AuthenticationBootstrapView | Honest launch placeholder before Auth exists | Shared | None | View | `Features/Auth/AuthenticationBootstrapView.swift` | baseline |
| AuthGate | Resolve configuration, session, profile, and role entry | Shared | Auth session, `profiles` | App/Auth state | `Features/Auth/` / T-006–T-007 | planned |
| SignInView | Email/password sign-in | Shared | Supabase Auth | Auth view model | `Features/Auth/` / T-006 | planned |
| SignUpView | Email/password account creation | Shared | Supabase Auth | Auth view model | `Features/Auth/` / T-006 | planned |
| RoleOnboardingView | Select role and create profile rows | Shared | `profiles`, role profile | Onboarding view model | `Features/Auth/` or `Features/Onboarding/` / T-007 | planned |
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
| AccountView | Show account/role information and sign out | Shared | Auth session, profile | Account view model | `Features/Account/` / T-006–T-011 | planned |
| DebugPanel | Show safe development diagnostics | Developer only | Sanitized repositories/checks | Debug state | `Features/Debug/` / T-022 | planned |
| Admin Dashboard | Administrative management | Admin | Not defined | Not defined | No MVP task | deferred |

The current customer and groomer `TabView` files render generic placeholder content; they are navigation shells, not implemented versions of the planned screens above.
