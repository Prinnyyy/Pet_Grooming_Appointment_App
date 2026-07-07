# App Store Privacy

This is the Groomly 1.0 privacy submission checklist. Keep it aligned with `ios/PetGroomerMarketplace/PetGroomerMarketplace/PrivacyInfo.xcprivacy` and App Store Connect before TestFlight or App Store submission.

## Release URLs

| Field | Value | Status |
|---|---|---|
| Privacy Policy URL | TBD | Blocking before App Store Connect metadata submission. Requires a production HTTPS page that matches the nutrition label below. |
| Support URL | TBD | Blocking before App Store Connect metadata submission. Requires a production HTTPS support/contact page. |

Do not submit App Store metadata until both TBD values are replaced with real, user-owned URLs.

## Tracking

- No tracking.
- No advertising identifiers.
- No tracking domains.
- No data is shared with third-party advertisers or data brokers.

## Required Reason APIs

| API category | Reason | App use |
|---|---|---|
| UserDefaults | `CA92.1` | Stores app-specific state such as push installation ID and booking handoff fallback read state. |
| File timestamp | `C617.1` | Reads app-container file metadata for local image snapshot cache ordering and debug log size/metadata checks. |

## Nutrition Label Posture

All listed data is linked to the signed-in account, is not used for tracking, and is collected for app functionality.

| App Store data type | Manifest value | Product source |
|---|---|---|
| Name | `NSPrivacyCollectedDataTypeName` | Profile display name and groomer business name. |
| Email address | `NSPrivacyCollectedDataTypeEmailAddress` | Auth email and optional customer contact email. |
| Phone number | `NSPrivacyCollectedDataTypePhoneNumber` | Optional customer profile phone number. |
| Physical address | `NSPrivacyCollectedDataTypePhysicalAddress` | Customer service address and groomer base/service address. |
| Coarse location | `NSPrivacyCollectedDataTypeCoarseLocation` | City/state/ZIP and service-area matching context. |
| User ID | `NSPrivacyCollectedDataTypeUserID` | Supabase Auth/profile UUID and support references. |
| Device ID | `NSPrivacyCollectedDataTypeDeviceID` | Push notification device token and app installation ID when notification registration is active. |
| Photos or videos | `NSPrivacyCollectedDataTypePhotosorVideos` | Customer pet/request photos and groomer avatar/portfolio photos. |
| Other user content | `NSPrivacyCollectedDataTypeOtherUserContent` | Pet details, request notes, offers, chat messages, reviews, availability, and notification records. |

## Not Collected For Groomly 1.0

- Payment info, credit info, purchases, or financial data.
- Contacts, browsing history, search history, sensitive human health data, or fitness data.
- Precise device location from Core Location.
- Analytics, product interaction analytics, crash reports, or diagnostic uploads in production.
- Audio, gameplay content, environment scanning, hands, or head data.

Pet temperament, medical, grooming, and service notes are app-specific user content about pets. They are represented as other user content, not human health data.

## Update Triggers

Update this document and `PrivacyInfo.xcprivacy` before release if the app adds payments, public analytics, crash reporting uploads, ads, third-party tracking, attachments beyond photos, precise location, contact import, APNs payload changes that add data categories, or a new third-party SDK with its own privacy manifest.
