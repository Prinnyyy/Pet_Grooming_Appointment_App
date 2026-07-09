# Groomly Privacy Policy

Last updated: July 9, 2026

Groomly is a pet grooming marketplace app that helps pet owners request grooming services and helps groomers review requests, make offers, manage bookings, and communicate with customers.

## Data We Collect

Groomly collects account and marketplace data needed to run the service:

- Name, display name, groomer business name, and account role.
- Email address and optional customer contact email.
- Optional phone number for customer profile contact.
- Customer service address and groomer base or service address.
- City, state, ZIP code, and service-area information used for marketplace matching.
- Supabase Auth user ID, profile ID, support references, and app installation identifiers.
- Pet profile details, request notes, service preferences, offers, bookings, reviews, availability, and chat messages.
- Customer pet photos, request photos, groomer avatar photos, and groomer portfolio photos.
- Push notification device token when notification registration is active.

## How We Use Data

Groomly uses this data for app functionality:

- Creating and managing customer and groomer accounts.
- Matching grooming requests with eligible groomers.
- Creating offers, bookings, reviews, notifications, and chat conversations.
- Showing private photos and profile information to authorized participants.
- Supporting account deletion, support troubleshooting, and marketplace safety.

Groomly does not use collected data for tracking, advertising identifiers, third-party advertising, or data broker sharing.

## Third-Party Services

Groomly uses Supabase for authentication, database, storage, realtime messaging, and Edge Functions. Supabase stores and processes app data only to provide Groomly service functionality.

Groomly does not currently include production advertising SDKs, public analytics uploads, or production crash-report uploads.

## Photos and Private Storage

Pet, request, avatar, and portfolio images are stored in private Supabase Storage buckets. The app reads those images through authenticated requests for signed-in users with permission to view the related profile, pet, request, or booking.

## Data Retention and Deletion

Users can request account deletion from the Account screen in the app. Account deletion removes or anonymizes personal profile details, clears local cached profile and image snapshots on the device, and deletes the sign-in user. Some marketplace records may remain in anonymized form when needed to preserve booking history, review integrity, or records involving another user.

Users can also update profile details, pet details, grooming requests, and photos from the relevant app screens when those records are editable.

## Support and Privacy Requests

Use the Groomly support page for app issues, general feedback, feature requests, privacy questions, or account deletion questions:

https://github.com/Prinnyyy/Pet_Grooming_Appointment_App/blob/codex/pet-fit-structure-cleanup/docs/04_ios/release/SUPPORT.md
