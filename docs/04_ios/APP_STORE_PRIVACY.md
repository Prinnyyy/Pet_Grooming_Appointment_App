# App Store Privacy

This is the Beckon 1.0 privacy submission checklist. Keep it aligned with `ios/Beckon/Beckon/PrivacyInfo.xcprivacy` and App Store Connect before TestFlight or App Store submission.

## Release URLs

| Field | Value | Status |
|---|---|---|
| Privacy Policy URL | `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App/blob/codex/pet-fit-structure-cleanup/docs/04_ios/release/PRIVACY_POLICY.md` | Ready for App Store Connect metadata. Public HTTPS page matches the Beckon 1.0 nutrition label below. |
| Support URL | `https://github.com/Prinnyyy/Pet_Grooming_Appointment_App/blob/codex/pet-fit-structure-cleanup/docs/04_ios/release/SUPPORT.md` | Ready for App Store Connect version metadata. Public HTTPS support page links to the issue tracker for app issues, general feedback, and feature requests. |

These GitHub-hosted URLs are the current canonical release URLs for Beckon 1.0. Replace them in this document, `AppReleaseLinks.swift`, and App Store Connect if a custom production domain is adopted later.

Latest local release-readiness evidence: `release/RELEASE_READINESS_DRY_RUN.md`.

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

## Not Collected For Beckon 1.0

- Payment info, credit info, purchases, or financial data.
- Contacts, browsing history, search history, sensitive human health data, or fitness data.
- Precise device location from Core Location.
- Analytics, product interaction analytics, crash reports, or diagnostic uploads in production.
- Audio, gameplay content, environment scanning, hands, or head data.

Pet temperament, medical, grooming, and service notes are app-specific user content about pets. They are represented as other user content, not human health data.

## Local Operational Evidence

Beckon records a small on-device operational event log for release evidence and local support diagnosis. These rows stay inside the app container, are sanitized before writing, and are not uploaded to Supabase, third-party analytics, crash-reporting services, or App Store Connect. The log records lifecycle and funnel states such as launch, foreground/background, auth restored/signed out, role resolved, and suspected prior-run interruption.

## Update Triggers

Update this document and `PrivacyInfo.xcprivacy` before release if the app adds payments, public analytics, crash reporting uploads, ads, third-party tracking, attachments beyond photos, precise location, contact import, APNs payload changes that add data categories, or a new third-party SDK with its own privacy manifest.
