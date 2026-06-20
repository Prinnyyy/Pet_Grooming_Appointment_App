# Fresh Pet Groomer Marketplace — Product & Engineering Brief

## 0. Project Reset Policy

This is a completely fresh project.

Do **not** copy old iOS source code, old local data models, old Supabase migrations, old repository files, old RPC functions, or old UI screens.

The previous project can be used only as product context. The new implementation must use a clean architecture, clean naming, and a revised product model.

The new product model is:

```text
Customer publishes an open grooming request.
Matched groomers can make offers.
Customer chooses one offer.
Booking is created after customer confirmation.
```

This replaces the old model:

```text
Customer sends a task card directly to groomers.
Groomers accept or reject.
```

The old “task card delivery” model should not be the primary product flow.

---

## 1. Product Summary

The app is an iOS marketplace for independent pet groomers and pet owners.

Customers create grooming requests for their pets. Groomers discover matched requests and submit offers with proposed time, price, and optional message. The customer reviews offers and confirms one groomer. A booking is created only after the customer accepts an offer.

The platform should feel like a lightweight service marketplace, not a job application system.

---

## 2. Core Product Philosophy

### 2.1 Main Principle

Do not make the customer repeatedly send requests to individual groomers.

Instead:

```text
Customer creates one request.
Groomers respond if interested.
Customer selects the best offer.
```

This reduces spam, rejection friction, duplicate submissions, and groomer inbox pollution.

### 2.2 User Experience Goal

The customer should feel:

```text
“I posted a grooming request and received options.”
```

Not:

```text
“I kept asking groomers and they rejected me.”
```

The groomer should feel:

```text
“I can browse suitable requests and respond only when I want.”
```

Not:

```text
“My inbox is filled with repeated task cards.”
```

---

## 3. User Roles

### 3.1 Customer

A customer can:

* Create an account
* Create pet profiles
* Upload pet photos
* Publish grooming requests
* View groomer offers
* Accept one offer
* View bookings
* Chat with the booked groomer
* Leave reviews after completed bookings

### 3.2 Groomer

A groomer can:

* Create an account
* Create a groomer profile
* Add service settings
* Add portfolio photos
* View matched open requests
* Dismiss requests that are not a fit
* Submit offers
* Manage bookings
* Chat with booked customers
* Complete bookings

### 3.3 Admin

Admin tools are not required for MVP.

Do not build admin dashboards in the first version.

---

## 4. MVP Scope

### 4.1 Must Have

The MVP must include:

* Email/password authentication
* Role onboarding: customer or groomer
* Customer pet profile creation
* Pet photo upload
* Groomer profile creation
* Groomer service settings
* Customer grooming request creation
* Matched request list for groomers
* Groomer offer creation
* Customer offer review
* Customer accepts one offer
* Booking creation
* Basic booking list
* Basic chat after booking
* Booking completion
* Customer review after completion

### 4.2 Should Have

If time allows:

* Request expiration
* Offer expiration
* Basic groomer availability windows
* Basic service radius
* Basic portfolio gallery
* Basic booking conflict protection

### 4.3 Not in MVP

Do not implement in the first version:

* Payments
* Stripe
* Push notifications
* Google login
* Apple login
* Complex calendar sync
* AI recommendations
* Admin dashboard
* Real-time chat polish
* Complex map UI
* Subscription plans
* Dynamic pricing
* Multi-pet request bundles
* Dispute system
* Refunds

---

## 5. Product Flow

## 5.1 Customer Flow

```text
Sign up / Sign in
→ Choose role: Customer
→ Create pet profile
→ Upload pet photos
→ Start grooming request
→ Choose pet
→ Choose service type
→ Choose preferred time window
→ Add notes and photos
→ Publish request
→ Wait for groomer offers
→ Review offers
→ Accept one offer
→ Booking created
→ Chat with groomer
→ Service completed
→ Leave review
```

## 5.2 Groomer Flow

```text
Sign up / Sign in
→ Choose role: Groomer
→ Create groomer profile
→ Add service settings
→ Add portfolio photos
→ View matched open requests
→ Open request detail
→ Make offer or dismiss
→ If customer accepts offer, booking is created
→ Chat with customer
→ Complete booking
```

---

## 6. Naming Rules

Use these product terms consistently.

### 6.1 Correct Terms

Use:

```text
Grooming Request
Matched Request
Groomer Offer
Booking
Conversation
Review
```

### 6.2 Avoid Old Terms

Do not use as primary product terms:

```text
Task Card
Submission
Recipient
Card Exchange
Customer Order Record
Groomer Order Record
```

These terms belong to the old architecture and should not appear in new user-facing UI.

### 6.3 Internal Naming

Preferred internal model names:

```text
GroomingRequest
RequestMatch
GroomerOffer
Booking
Conversation
Message
Review
```

---

## 7. Recommended Project Structure

Create a clean iOS project structure.

```text
PetGroomerMarketplace/
  README.md
  docs/
    ProductBrief.md
    DataModel.md
    APIContract.md
    MVPTestPlan.md
  ios/
    PetGroomerMarketplace/
      App/
      Core/
      DesignSystem/
      Features/
        Auth/
        Onboarding/
        Customer/
        Groomer/
        Pets/
        Requests/
        Offers/
        Bookings/
        Chat/
        Reviews/
        Account/
      Services/
        AuthService.swift
        APIClient.swift
        StorageService.swift
      Repositories/
        ProfileRepository.swift
        PetRepository.swift
        GroomerRepository.swift
        RequestRepository.swift
        OfferRepository.swift
        BookingRepository.swift
        ChatRepository.swift
        ReviewRepository.swift
      Models/
      ViewModels/
      Utilities/
  supabase/
    migrations/
    seed.sql
    README.md
```

Do not create a large monolithic `AppModel` as the main database.

Use small feature-oriented view models and repositories.

---

## 8. Architecture

### 8.1 High-Level Architecture

```text
SwiftUI Views
→ ViewModels
→ Repositories
→ API Client / Supabase Client
→ Supabase Postgres / Storage / Auth
```

### 8.2 View Responsibility

Views should only handle:

* Layout
* User input
* Loading state
* Empty state
* Error display
* Navigation

Views should not contain business rules.

### 8.3 ViewModel Responsibility

ViewModels handle:

* Screen state
* Form validation
* Calling repositories
* Mapping API errors to UI messages
* Refreshing data after mutation

### 8.4 Repository Responsibility

Repositories handle:

* Fetching data
* Creating records
* Calling RPC functions
* Uploading metadata
* Mapping DTOs

### 8.5 Backend Responsibility

Backend handles:

* Authentication identity
* Database constraints
* RLS policies
* Booking conflict protection
* Offer acceptance transaction
* Review eligibility
* Storage access control

---

## 9. Authentication & Onboarding

### 9.1 Auth Gate

App launch flow:

```text
App starts
→ Check backend configuration
→ Check auth session
→ If signed out: show AuthView
→ If signed in but no profile: show RoleOnboardingView
→ If signed in with profile: enter app
```

### 9.2 AuthView

Minimum UI:

* Email field
* Password field
* Sign In button
* Create Account button
* Loading state
* Error message

Do not implement social login in MVP.

### 9.3 RoleOnboardingView

The user chooses:

```text
I am a pet owner
I am a groomer
```

After selection:

* Create profile row
* Create customer profile or groomer profile row
* Route to correct home screen

Role should not be manually switchable in normal UI.

---

## 10. Main Tabs

### 10.1 Customer Tabs

Recommended customer tabs:

```text
Home
Requests
Bookings
Messages
Account
```

### 10.2 Groomer Tabs

Recommended groomer tabs:

```text
Requests
Offers
Bookings
Messages
Account
```

Keep tabs simple. Do not overload the first version.

---

## 11. Customer Screens

### 11.1 Customer Home

Purpose:

* Start a new grooming request
* Show active request status
* Show upcoming booking

Primary CTA:

```text
Start Grooming Request
```

Do not use:

```text
Create Task Card
```

### 11.2 Pet List

Features:

* List pets
* Add pet
* Edit pet
* Soft delete pet

### 11.3 Pet Form

Fields:

* Pet name
* Species
* Breed
* Size
* Weight
* Age or birthday
* Temperament
* Medical notes
* Grooming notes
* Photos

### 11.4 Grooming Request Wizard

Steps:

```text
1. Choose pet
2. Choose service
3. Choose preferred time window
4. Add photos and notes
5. Review and publish
```

### 11.5 Request Detail

Customer sees:

* Request status
* Pet snapshot
* Preferred time
* Notes
* Received offers
* Expiration time
* Cancel request button

### 11.6 Offer Review

Customer sees each offer:

* Groomer name
* Groomer rating
* Portfolio preview
* Proposed time
* Estimated price
* Groomer message
* Accept offer button

Only one offer can be accepted.

---

## 12. Groomer Screens

### 12.1 Groomer Request Feed

Groomer sees matched open requests.

Each card shows:

* Pet summary
* Service type
* Preferred time window
* Distance or city
* Estimated duration
* Customer notes preview
* Photo preview

Actions:

```text
View Details
Dismiss
Make Offer
```

### 12.2 Request Detail for Groomer

Show:

* Pet snapshot
* Photo snapshot
* Service notes
* Preferred time window
* Customer city or service area
* Any safety or temperament notes

Actions:

```text
Make Offer
Not a Fit
```

Do not show unnecessary customer private data before booking.

### 12.3 Make Offer Form

Fields:

* Proposed start
* Proposed end
* Estimated price
* Message
* Optional service notes

Validation:

* Proposed end must be after proposed start
* Price must be non-negative
* Groomer must not have a conflicting active booking

### 12.4 Groomer Bookings

List:

* Upcoming bookings
* Completed bookings
* Cancelled bookings

---

## 13. Booking Flow

### 13.1 Booking Creation

A booking is created only when the customer accepts a groomer offer.

Do not create booking when the groomer merely responds.

Correct flow:

```text
Groomer makes offer
→ Customer accepts offer
→ Backend validates offer and time conflict
→ Booking is created
```

### 13.2 Booking Status

Use:

```text
pending_confirmation
confirmed
in_progress
completed
cancelled_by_customer
cancelled_by_groomer
no_show
disputed
```

For MVP, only implement:

```text
confirmed
completed
cancelled_by_customer
cancelled_by_groomer
```

### 13.3 Booking Conflict Rule

A groomer cannot have overlapping active bookings.

Active statuses:

```text
confirmed
in_progress
```

Completed and cancelled bookings do not block time.

Time overlap rule:

```text
startA < endB AND startB < endA
```

Boundary example:

```text
10:00–12:00 and 12:00–14:00 do not conflict.
10:00–12:00 and 11:30–13:00 conflict.
```

---

## 14. Request and Offer Statuses

### 14.1 Grooming Request Status

Use:

```text
open
has_offers
booked
cancelled
expired
```

Meaning:

* `open`: request published, waiting for offers
* `has_offers`: one or more offers received
* `booked`: customer accepted an offer
* `cancelled`: customer cancelled request
* `expired`: request expired without booking

### 14.2 Request Match Status

Use:

```text
visible
viewed
dismissed
offered
hidden
expired
```

Meaning:

* `visible`: groomer can see it
* `viewed`: groomer opened it
* `dismissed`: groomer marked not a fit
* `offered`: groomer submitted an offer
* `hidden`: system hides it
* `expired`: no longer valid

### 14.3 Groomer Offer Status

Use:

```text
pending
accepted_by_customer
declined_by_customer
withdrawn_by_groomer
expired
```

---

## 15. Anti-Spam and Elegance Rules

The new model should avoid direct repeated sending.

### 15.1 Customer Cannot Spam One Groomer

Because customers do not directly send the same request repeatedly to one groomer, spam risk is reduced.

### 15.2 Groomer Can Dismiss

Groomer can dismiss a matched request.

Dismissal should not create a harsh customer-facing rejection message.

Customer should see:

```text
Still waiting for offers.
```

Not:

```text
Groomer rejected you.
```

### 15.3 Offer Limits

MVP rules:

* One groomer can create at most one active offer per request.
* Groomer can withdraw an offer.
* Groomer can create a new offer only after withdrawing the old one.
* Customer can accept only one offer.
* After one offer is accepted, all other pending offers become declined or expired.

### 15.4 Request Limits

MVP rules:

* A customer can have a limited number of open requests.
* Suggested limit: 3 open requests per customer.
* Request expires after 48 hours by default.
* Customer can cancel an open request.

---

## 16. Database Model Overview

Use Supabase/Postgres for backend.

This section defines the clean schema conceptually. Exact SQL can be generated by Codex in migrations.

### 16.1 Tables

Required MVP tables:

```text
profiles
customer_profiles
groomer_profiles
pets
pet_photos
groomer_services
groomer_portfolio_photos
grooming_requests
request_matches
groomer_offers
bookings
conversations
messages
reviews
favorites
```

### 16.2 profiles

Fields:

```text
id uuid primary key references auth.users(id)
role text: customer / groomer
display_name text
avatar_url text
created_at
updated_at
```

### 16.3 customer_profiles

Fields:

```text
user_id uuid primary key
city
state
zip_code
default_notes
created_at
updated_at
```

### 16.4 groomer_profiles

Fields:

```text
user_id uuid primary key
business_name
bio
years_experience
base_city
base_state
service_radius_miles
rating_avg
rating_count
is_active
is_verified
created_at
updated_at
```

### 16.5 pets

Fields:

```text
id uuid primary key
customer_id uuid
name
species
breed
size
weight_lbs
birthday
temperament
medical_notes
grooming_notes
is_active
deleted_at
created_at
updated_at
```

### 16.6 pet_photos

Fields:

```text
id uuid primary key
pet_id uuid
customer_id uuid
storage_bucket
storage_path
caption
sort_order
is_primary
created_at
```

### 16.7 groomer_services

Fields:

```text
id uuid primary key
groomer_id uuid
title
description
base_price
duration_minutes
accepted_pet_sizes
is_active
created_at
updated_at
```

### 16.8 groomer_portfolio_photos

Fields:

```text
id uuid primary key
groomer_id uuid
storage_bucket
storage_path
caption
sort_order
created_at
```

### 16.9 grooming_requests

Fields:

```text
id uuid primary key
customer_id uuid
pet_id uuid nullable
pet_snapshot jsonb
photo_snapshot jsonb
service_type
service_notes
preferred_start timestamptz
preferred_end timestamptz
city
state
zip_code
status
expires_at
created_at
updated_at
```

Important:

* `pet_snapshot` freezes pet data at request creation.
* Future pet edits must not change old requests.

### 16.10 request_matches

Fields:

```text
id uuid primary key
request_id uuid
groomer_id uuid
customer_id uuid
match_score numeric nullable
match_reason text nullable
status
viewed_at
dismissed_at
created_at
updated_at
```

Rules:

* A request can match many groomers.
* One groomer should have at most one match per request.
* Customer does not manually spam groomers.

### 16.11 groomer_offers

Fields:

```text
id uuid primary key
request_id uuid
match_id uuid nullable
customer_id uuid
groomer_id uuid
proposed_start timestamptz
proposed_end timestamptz
price_estimate numeric
message text
status
expires_at
created_at
updated_at
```

Rules:

* One groomer can have at most one active pending offer per request.
* Offer time must be valid.
* Offer must belong to a visible request match.

### 16.12 bookings

Fields:

```text
id uuid primary key
request_id uuid
offer_id uuid
customer_id uuid
groomer_id uuid
scheduled_start timestamptz
scheduled_end timestamptz
price_estimate numeric
final_price numeric nullable
status
created_at
updated_at
```

Rules:

* Booking is created only from accepted offer.
* One request can create at most one booking.
* One offer can create at most one booking.
* Groomer cannot have overlapping active bookings.

### 16.13 conversations

Fields:

```text
id uuid primary key
request_id uuid nullable
booking_id uuid nullable
customer_id uuid
groomer_id uuid
created_at
updated_at
```

MVP rule:

* Create conversation when customer accepts offer.
* Do not enable full chat before booking unless explicitly required.

### 16.14 messages

Fields:

```text
id uuid primary key
conversation_id uuid
sender_id uuid
message_type text
body text nullable
storage_bucket text nullable
storage_path text nullable
created_at
read_at
```

### 16.15 reviews

Fields:

```text
id uuid primary key
booking_id uuid unique
customer_id uuid
groomer_id uuid
rating int
content text
created_at
```

Rules:

* Only completed bookings can be reviewed.
* One review per booking.

---

## 17. Backend RPC Requirements

Use RPC functions for critical business actions.

### 17.1 create_grooming_request

Purpose:

Customer publishes one open request.

Inputs:

```text
pet_id
service_type
service_notes
preferred_start
preferred_end
city
state
zip_code
```

Backend logic:

```text
1. Verify authenticated customer.
2. Verify pet belongs to customer.
3. Freeze pet_snapshot.
4. Freeze photo_snapshot.
5. Create grooming_request.
6. Generate request_matches for eligible groomers.
7. Return request_id and match count.
```

MVP matching can be simple:

```text
active groomers in same state or city
```

Do not build complex AI matching now.

### 17.2 create_groomer_offer

Purpose:

Groomer responds to an open request.

Inputs:

```text
request_id
proposed_start
proposed_end
price_estimate
message
```

Backend logic:

```text
1. Verify authenticated groomer.
2. Verify request is open or has_offers.
3. Verify groomer has a visible match for this request.
4. Verify offer time is valid.
5. Verify no active booking conflict.
6. Create offer.
7. Mark match as offered.
8. Mark request as has_offers.
```

### 17.3 accept_groomer_offer

Purpose:

Customer accepts one offer and creates booking.

Inputs:

```text
offer_id
```

Backend logic:

```text
1. Verify authenticated customer.
2. Verify offer belongs to customer's request.
3. Verify request is still open or has_offers.
4. Verify offer status is pending.
5. Re-check groomer booking conflict.
6. Create booking.
7. Mark offer accepted_by_customer.
8. Mark other offers declined_by_customer or expired.
9. Mark request booked.
10. Create conversation.
11. Return booking_id.
```

### 17.4 dismiss_request_match

Purpose:

Groomer hides a request that is not a fit.

Inputs:

```text
match_id
reason optional
```

Backend logic:

```text
1. Verify authenticated groomer.
2. Verify match belongs to groomer.
3. Mark match dismissed.
```

Do not show harsh rejection to customer.

### 17.5 complete_booking

Purpose:

Groomer marks service as completed.

Inputs:

```text
booking_id
```

Backend logic:

```text
1. Verify authenticated groomer.
2. Verify booking belongs to groomer.
3. Verify booking is confirmed.
4. Mark completed.
```

### 17.6 create_review

Purpose:

Customer reviews completed booking.

Inputs:

```text
booking_id
rating
content
```

Backend logic:

```text
1. Verify authenticated customer.
2. Verify booking belongs to customer.
3. Verify booking is completed.
4. Verify no existing review.
5. Create review.
6. Update groomer rating summary.
```

---

## 18. RLS Policy Requirements

Enable RLS on all public tables.

General rules:

### 18.1 Customers Can

* Read own profile
* Update own profile
* Read/write own pets
* Read own requests
* Read offers for own requests
* Accept offers for own requests through RPC only
* Read own bookings
* Read own conversations/messages
* Create reviews for own completed bookings through RPC

### 18.2 Groomers Can

* Read active groomer profiles
* Update own groomer profile
* Read matched requests assigned to them
* Read own matches
* Create offers through RPC only
* Read own offers
* Read own bookings
* Read own conversations/messages

### 18.3 Direct Writes to Restrict

Do not allow direct client insert/update for:

```text
bookings
request_matches
groomer_offers status changes
grooming_requests status changes
reviews if not using RPC
```

Critical state transitions should go through RPC.

---

## 19. Storage Requirements

Create buckets:

```text
avatars
pet-photos
groomer-portfolio
chat-attachments
```

### 19.1 Storage Rules

* Customers can upload pet photos only under their own user path.
* Groomers can upload portfolio photos only under their own user path.
* Pet photos are private by default.
* Groomer portfolio can be public or authenticated-readable.
* Chat attachments are private.

### 19.2 Paths

Use:

```text
avatars/{user_id}/{file_id}.jpg
pet-photos/{customer_id}/{pet_id}/{file_id}.jpg
groomer-portfolio/{groomer_id}/{file_id}.jpg
chat-attachments/{conversation_id}/{message_id}.jpg
```

Do not put service role keys in the iOS app.

---

## 20. Local State Rules

Local state should be lightweight.

Allowed local state:

```text
auth session cache
form draft
image upload draft
last selected pet
temporary request wizard state
lightweight UI cache
```

Not allowed as local fact source:

```text
bookings
offers
requests
reviews
messages
groomer profile
pet profile after sync
```

Backend is the source of truth.

---

## 21. MVP UI Design Direction

Keep UI clean, friendly, and lightweight.

Recommended style:

```text
soft cards
clear steps
friendly pet-focused language
minimal tab structure
simple request status chips
simple offer cards
```

Avoid:

```text
dense enterprise dashboards
large complex calendars
too many filters
heavy map-first UI
game-like animation before core flows work
```

A playful visual style can be added later.

---

## 22. Core Screens Checklist

### Auth

* [ ] AuthGate
* [ ] SignInView
* [ ] SignUpView
* [ ] RoleOnboardingView

### Customer

* [ ] CustomerHomeView
* [ ] PetListView
* [ ] PetEditorView
* [ ] RequestWizardView
* [ ] RequestDetailView
* [ ] OfferListView
* [ ] CustomerBookingListView

### Groomer

* [ ] GroomerHomeView
* [ ] GroomerProfileEditorView
* [ ] MatchedRequestFeedView
* [ ] GroomerRequestDetailView
* [ ] MakeOfferView
* [ ] GroomerBookingListView

### Shared

* [ ] ConversationListView
* [ ] ChatView
* [ ] ReviewView
* [ ] AccountView
* [ ] DebugPanel

---

## 23. Implementation Phases

## Phase 1 — Clean Project Bootstrap

Tasks:

```text
1. Create a fresh iOS SwiftUI project.
2. Add clean folder structure.
3. Add design tokens.
4. Add basic navigation shell.
5. Add placeholder repositories.
6. Add simple mock data only for UI previews.
```

Acceptance:

```text
Project builds.
No old code imported.
No old migrations imported.
No old local AppModel copied.
```

---

## Phase 2 — Auth and Role Onboarding

Tasks:

```text
1. Add Supabase configuration loader.
2. Add AuthRepository.
3. Add AuthGate.
4. Add SignIn/SignUp views.
5. Add RoleOnboardingView.
6. Create profile after role selection.
```

Acceptance:

```text
Customer account can sign up.
Groomer account can sign up.
Role determines app entry.
```

---

## Phase 3 — Profiles, Pets, Groomer Profiles

Tasks:

```text
1. Customer creates pet profile.
2. Customer uploads pet photo.
3. Groomer creates profile.
4. Groomer creates service settings.
5. Groomer uploads portfolio photo.
```

Acceptance:

```text
Customer can create pet.
Groomer can create profile.
Images upload correctly.
```

---

## Phase 4 — Grooming Request Creation

Tasks:

```text
1. Build request wizard.
2. Customer chooses pet.
3. Customer chooses service type.
4. Customer chooses preferred time window.
5. Customer publishes grooming request.
6. Backend creates request and request matches.
```

Acceptance:

```text
Customer can publish one open request.
Groomer can see matched request.
```

---

## Phase 5 — Offers

Tasks:

```text
1. Groomer opens matched request.
2. Groomer submits offer.
3. Customer sees offer.
4. Customer can compare offers.
```

Acceptance:

```text
Groomer can make offer.
Customer can see pending offers.
```

---

## Phase 6 — Booking

Tasks:

```text
1. Customer accepts one offer.
2. Backend creates booking.
3. Other offers become closed.
4. Request becomes booked.
5. Conversation is created.
```

Acceptance:

```text
Only one booking can be created per request.
Groomer time conflict is blocked.
Customer and groomer see same booking.
```

---

## Phase 7 — Chat and Completion

Tasks:

```text
1. Booking participants can chat.
2. Groomer can mark booking completed.
3. Customer can leave review.
```

Acceptance:

```text
Only booking participants can access chat.
Only completed booking can be reviewed.
```

---

## Phase 8 — Polish and Hardening

Tasks:

```text
1. Empty states.
2. Error states.
3. Loading states.
4. Validation messages.
5. Debug tools.
6. RLS negative tests.
7. Booking conflict tests.
```

Acceptance:

```text
Core flow is stable.
No fake local writes.
No forbidden cross-user access.
```

---

## 24. Testing Requirements

### 24.1 Core E2E Test

Run:

```text
Customer signs up
→ creates pet
→ creates request
→ groomer signs up
→ creates profile
→ sees matched request
→ creates offer
→ customer accepts offer
→ booking appears for both users
→ chat works
→ groomer completes booking
→ customer leaves review
```

### 24.2 Conflict Test

Run:

```text
Groomer has booking 10:00–12:00.
Groomer tries offer/book another request 11:00–13:00.
System blocks booking.
```

### 24.3 Boundary Test

Run:

```text
Groomer has booking 10:00–12:00.
Groomer books another request 12:00–14:00.
System allows booking.
```

### 24.4 RLS Negative Test

Run:

```text
Customer A cannot read Customer B pets.
Groomer A cannot read unmatched requests.
Groomer A cannot update Groomer B profile.
Customer cannot directly insert booking.
Groomer cannot directly create booking.
```

---

## 25. Debug Panel Requirements

Add a developer-only debug panel.

Show:

```text
backend environment
current auth user id
current profile role
last API error
request count
offer count
booking count
storage upload test result
RLS negative test result
```

Do not show:

```text
full access token
refresh token
full API key
password
```

---

## 26. Lightweight Rules for Codex

When implementing:

```text
Build in vertical slices.
Keep each slice compiling.
Do not implement deferred features early.
Do not create huge files.
Do not place business logic in views.
Do not fake successful backend operations.
Do not silently fall back to mock data in production backend mode.
Use clear English names.
Add README notes after each major phase.
```

Preferred order:

```text
1. Build app shell.
2. Build auth.
3. Build profiles/pets/groomer profile.
4. Build request creation.
5. Build matched request feed.
6. Build offer creation.
7. Build offer acceptance and booking.
8. Build chat/review.
9. Add debug and hardening.
```

---

## 27. Final MVP Acceptance Criteria

The MVP is acceptable only if:

```text
A customer can create a request.
A groomer can make an offer.
A customer can accept an offer.
A booking is created.
The same groomer cannot be double-booked.
A request cannot create multiple bookings.
Only correct users can read/write their data.
No old task-card direct-send flow is used as the main flow.
No old local dual order arrays exist.
No service role key exists in iOS.
The project builds cleanly.
```

---

## 28. Product Decision Summary

The final product should be built around:

```text
Open Request
→ Groomer Offer
→ Customer Confirmation
→ Booking
```

Not around:

```text
Direct Task Card Sending
→ Groomer Rejects
→ Customer Resends
```

This is the core product direction for the fresh rebuild.
