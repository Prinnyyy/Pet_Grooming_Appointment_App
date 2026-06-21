# Codex Task Prompt — Apply Groomly Design Prototype to Existing SwiftUI App

## Task Title

Apply the Groomly Claude Design UI direction to the existing iOS SwiftUI app.

## Current Project Context

This repository is an existing iOS SwiftUI app:

```text
Pet_Grooming_Appointment_App
```

The app already has a working marketplace MVP flow:

```text
Customer publishes an open grooming request
→ matched groomers can view the request
→ groomer makes an offer
→ customer accepts one offer
→ booking is created
→ participants can chat
→ groomer completes the booking
→ customer leaves a review
```

This UI task must preserve the current product model.

Do not reintroduce the old direct “task card sent to groomer” flow.

Do not rewrite the backend.

Do not replace the repository layer.

Do not modify Supabase migrations unless the task explicitly requires a small UI-supporting metadata change, and stop for approval before doing so.

---

## Design Source Files

The new design files are located at:

```text
docs/08_design/
```

Expected files:

```text
docs/08_design/Groomly.html
docs/08_design/Groomly.zip
docs/08_design/<unzipped Groomly export folder>/
```

The ZIP will be unzipped in the same folder before or during the task.

Use these files as design references:

1. `Groomly.html` — interactive/bundled HTML prototype.
2. `Groomly.zip` and its extracted contents — source/export package.
3. Any screenshots, assets, CSS, images, or metadata inside the extracted design folder.

If the ZIP has not been extracted yet, extract it into:

```text
docs/08_design/groomly_export/
```

Do not place extracted design files inside the iOS source tree.

Do not copy web/HTML/React code directly into the SwiftUI app.

The HTML/CSS export is a visual and interaction reference, not production iOS code.

---

## Required First Step: Inspect and Document the Design

Before editing Swift files, inspect the design files and create a design handoff summary.

Create:

```text
docs/08_design/UI_IMPLEMENTATION_NOTES.md
```

This file must summarize:

```text
1. Detected brand name
2. Core colors
3. Typography direction
4. Spacing/radius/shadow patterns
5. Major screens present in the design
6. Reusable components detected
7. Customer screens detected
8. Groomer screens detected
9. Missing states that must be preserved from the current app
10. Mapping between design screens and current SwiftUI files
```

Also create or update:

```text
docs/08_design/design_tokens.json
```

If exact tokens can be extracted from CSS/HTML, use them.

If exact tokens are not available, infer conservative tokens from the design and label them as inferred.

Example structure:

```json
{
  "colors": {
    "appBackground": "#EBE4D9",
    "primary": "#7ECFC0",
    "textPrimary": "#232323"
  },
  "spacing": {
    "xs": 4,
    "sm": 8,
    "md": 16,
    "lg": 24,
    "xl": 32
  },
  "radius": {
    "card": 20,
    "button": 14,
    "input": 12
  },
  "typography": {
    "largeTitle": {
      "size": 34,
      "weight": "bold"
    },
    "title": {
      "size": 24,
      "weight": "semibold"
    },
    "body": {
      "size": 16,
      "weight": "regular"
    }
  }
}
```

Do not start broad UI changes until this summary exists.

---

## Implementation Goal

Adapt the existing SwiftUI app to match the Groomly design direction while preserving all existing business behavior.

This is a UI adaptation task.

It is not:

```text
a backend rewrite
a schema migration task
a product-flow rewrite
a repository rewrite
a local demo rewrite
a new app generation task
```

---

## Non-Negotiable Rules

Follow these rules exactly:

1. Preserve the current Open Request → Groomer Offer → Customer Confirmation → Booking model.
2. Do not reintroduce the old task-card push model.
3. Do not add local fake success paths.
4. Do not bypass repositories.
5. Do not call Supabase directly from SwiftUI views.
6. Do not expose tokens, full user IDs, API keys, passwords, or raw backend secrets.
7. Do not break auth/session/profile routing.
8. Do not break customer/groomer role separation.
9. Do not remove loading, empty, or error states.
10. Do not remove the developer Debug Panel.
11. Do not implement deferred product features during this UI pass.
12. Do not change RLS policies or RPC functions unless explicitly authorized.
13. Keep every slice buildable.
14. Run the required validation after each major slice.
15. Update project memory after meaningful changes.

---

## Current Product Boundaries to Preserve

The existing app already supports:

```text
email/password auth
role onboarding
customer pet management
pet photo metadata/storage path work
groomer profile management
groomer service management
groomer portfolio metadata/storage path work
customer request publishing
request matches
groomer request feed/detail/dismiss
groomer offer creation/withdrawal
customer offer review
offer acceptance
booking creation
booking cancellation
booking completion
text-only booking chat
customer review
safe Debug Panel
```

Do not regress these flows.

---

## Deferred Features Not to Implement in This UI Pass

Do not implement the following unless separately requested:

```text
favorites
customer cancellation of open grooming requests
fully wired standalone Groomer Offers tab
chat attachments
chat read receipts
chat-attachments UI
signed URL image rendering for all photos
remote smoke tests for groomer portfolio upload/delete
availability windows
true radius matching
offer-time conflict check at offer creation
background expiration jobs
avatar upload/display flow
native email confirmation deep link flow
production SMTP setup
payments
push notifications
admin dashboard
subscriptions
refunds
disputes
complex map UI
complex calendar UI
```

If the design prototype shows one of these features, treat it as visual inspiration only and do not implement the full feature in this task.

---

## How to Use the Design Files

### Use the design for:

```text
visual direction
colors
spacing
card shape
button style
input style
status chip style
empty-state mood
screen hierarchy
illustration/logo inspiration
tab and navigation feel
```

### Do not use the design for:

```text
changing backend contracts
inventing new data models
removing existing app states
hardcoding fake demo data into production screens
copying web code into SwiftUI
creating unsupported features
```

### If the design and current app conflict:

Use this priority order:

```text
1. Current verified product flow
2. Current backend/repository contract
3. Existing role-based navigation
4. Existing loading/empty/error states
5. Groomly visual design
6. Minor layout preferences from the prototype
```

Product correctness beats visual matching.

---

## Required SwiftUI Design System Work

Before changing many screens, create or update shared SwiftUI design primitives.

Look for the existing `DesignSystem` folder first.

If it exists, extend it.

If it does not exist, create one under the existing project conventions.

Suggested components:

```text
GroomlyColors
GroomlyTypography
GroomlySpacing
GroomlyRadius
GroomlyShadow
GroomlyButton
GroomlyCard
GroomlyTextField
GroomlyStatusChip
GroomlyEmptyState
GroomlyErrorBanner
GroomlyLoadingView
GroomlySectionHeader
```

Do not scatter raw hex colors and magic spacing numbers throughout feature views.

Use central tokens.

---

## Required UI Slices

Implement in small slices. Do not attempt to redesign every screen in one patch.

### Slice 1 — Design Audit and Tokens

Tasks:

```text
1. Inspect docs/08_design/Groomly.html.
2. Inspect the unzipped design export folder.
3. Create docs/08_design/UI_IMPLEMENTATION_NOTES.md.
4. Create or update docs/08_design/design_tokens.json.
5. Create or update SwiftUI design tokens/components.
6. Run build.
```

Acceptance:

```text
Design notes exist.
Tokens exist.
Shared SwiftUI components exist.
No product behavior changed.
Build passes.
```

---

### Slice 2 — Auth and Onboarding UI

Apply Groomly visual style to:

```text
AuthGate loading/error state
Sign In
Sign Up
Role Onboarding
```

Rules:

```text
Do not change auth repository logic.
Do not change session persistence.
Do not change profile onboarding RPC behavior.
Do not add social login.
Do not add forgot password unless already implemented.
```

Acceptance:

```text
Auth flow still works.
Customer/groomer role routing still works.
Build passes.
```

---

### Slice 3 — Customer Home and Pet UI

Apply Groomly visual style to:

```text
Customer Home
Pet List
Pet Editor
Pet photo metadata/upload controls
```

Rules:

```text
Do not invent signed URL image rendering if not already supported.
If images are metadata-only today, preserve that and make the placeholder beautiful.
Do not change pet repository contracts.
```

Acceptance:

```text
Customer can create/edit/delete pets.
Photo metadata/upload controls still work.
Loading/error/empty states remain.
Build passes.
```

---

### Slice 4 — Customer Request and Offer UI

Apply Groomly visual style to:

```text
Customer Requests tab
Request wizard
Request list
Request detail
Offer list/review
Accept offer UI
```

Rules:

```text
Use “Grooming Request”, “Publish Request”, “Offers”, “Accept Offer”.
Do not use “Task Card” as the main product term.
Do not change create_grooming_request behavior.
Do not change accept_groomer_offer behavior.
Do not fake bookings locally.
```

Acceptance:

```text
Customer can publish request.
Customer can review offers.
Customer can accept eligible offer.
Booking is created through existing backend flow.
Build/tests pass.
```

---

### Slice 5 — Groomer Request and Offer UI

Apply Groomly visual style to:

```text
Groomer Requests tab
Matched request feed
Request detail
Dismiss / Not a Fit
Make Offer
Withdraw Offer
```

Rules:

```text
Use “Open Requests”, “Make Offer”, “Not a Fit”.
Do not use harsh rejection wording.
Do not reintroduce direct accept/reject task-card wording.
Do not change offer backend logic.
```

Acceptance:

```text
Groomer can view matched requests.
Groomer can dismiss request.
Groomer can create offer.
Groomer can withdraw pending offer.
Build/tests pass.
```

---

### Slice 6 — Bookings UI

Apply Groomly visual style to:

```text
Customer booking list
Groomer booking list
Booking detail
Cancel booking
Complete booking
Review entry points
```

Rules:

```text
Do not change booking status machine.
Do not make cancellation reopen requests/offers unless backend already supports it.
Do not add payments.
```

Acceptance:

```text
Customer and groomer can view participant bookings.
Confirmed booking can be cancelled where currently allowed.
Groomer can complete booking.
Customer can review completed booking.
Build/tests pass.
```

---

### Slice 7 — Chat UI

Apply Groomly visual style to:

```text
Messages tab
Conversation list
Chat view
Text input
Message bubbles
```

Rules:

```text
Text-only chat remains text-only.
Do not implement attachments.
Do not implement read receipts.
Do not implement realtime unless already supported.
```

Acceptance:

```text
Participants can send and read text messages.
No token/private data exposure.
Build/tests pass.
```

---

### Slice 8 — Account, Groomer Profile, Debug

Apply Groomly visual style to:

```text
Account screen
Groomer profile editor
Services editor
Portfolio metadata controls
Safe Debug Panel
```

Rules:

```text
Debug Panel must remain sanitized.
Do not show full user IDs, full API keys, access tokens, refresh tokens, passwords, or raw secrets.
Portfolio image display can remain metadata-only unless signed URL rendering already exists.
```

Acceptance:

```text
Groomer can update profile.
Groomer can manage services.
Groomer can manage portfolio metadata/upload/delete controls.
Debug Panel remains safe.
Build passes.
```

---

## Copy and Terminology Rules

Use warm, marketplace-oriented language.

Preferred copy:

```text
Groomly
Find a groomer
Start a grooming request
Publish request
Open requests
Make offer
Review offers
Accept offer
Booking confirmed
Not a fit
Waiting for offers
No offers yet
```

Avoid:

```text
Task card
Send task
Reject customer
Reject task
Recipient
Submission
Card exchange
```

For groomer dismissals, avoid customer-facing rejection language.

Customer should see:

```text
No offers yet.
Try adjusting the time or details.
```

Not:

```text
The groomer rejected you.
```

---

## Accessibility Rules

Maintain or add:

```text
Dynamic Type compatibility
VoiceOver labels for buttons
Minimum 44pt tap targets
Sufficient color contrast
Readable error messages
No color-only status indicators
```

Do not make the UI purely decorative.

---

## Image and Asset Rules

If the design export includes images/icons:

```text
1. Inspect licensing/source if visible.
2. Use only assets that are included in the design export or are safe placeholders.
3. Place app assets in the appropriate Xcode asset catalog.
4. Use vector/SF Symbol alternatives when better.
5. Do not add large unoptimized images.
6. Do not commit redundant design export build artifacts into iOS assets.
```

If asset usage is unclear, stop and report.

---

## Validation Rules

After each slice, run the appropriate validation.

Use existing scripts where available:

```text
./scripts/ios-build.sh
./scripts/ios-test.sh
./scripts/preflight.sh
```

At minimum:

```text
Run ./scripts/ios-build.sh after every UI slice.
Run ./scripts/ios-test.sh after any behavior-affecting change.
Run ./scripts/preflight.sh before final report.
```

If build fails:

```text
1. Fix only errors caused by this UI task.
2. Do not perform broad cleanup.
3. Stop after two targeted repair attempts and report clearly.
```

---

## Required Memory and Documentation Updates

After meaningful changes, update:

```text
docs/00_memory/CURRENT_STATE.md
docs/00_memory/WORKLOG.md
docs/00_memory/FEATURE_INDEX.md if file mappings changed
docs/08_design/UI_IMPLEMENTATION_NOTES.md if design interpretation changed
```

Do not rely on conversation memory.

---

## Stop Conditions

Stop and report before editing further if:

```text
The design export cannot be read.
The ZIP extraction produces unclear or unsafe files.
The prototype appears to describe a different product flow.
The UI change requires backend/schema changes.
The task requires implementing deferred features.
The build fails after two focused repair attempts.
There are uncommitted user changes that conflict with the planned patch.
A file seems generated and should not be manually edited.
```

---

## Final Report Format

At the end of the run, report:

```text
1. Design files inspected
2. Design tokens identified
3. Screens updated
4. Shared components created/updated
5. Business logic touched or not touched
6. Deferred features intentionally not implemented
7. Checks run and results
8. Files changed
9. Risks
10. Recommended next slice
```

Do not start the next slice unless explicitly instructed.

---

## Initial Task for This Run

Start with Slice 1 only:

```text
Design Audit and Tokens
```

Do not redesign all screens in the first run.

For this first run:

```text
1. Inspect docs/08_design/Groomly.html.
2. Extract docs/08_design/Groomly.zip into docs/08_design/groomly_export/ if not already extracted.
3. Inspect extracted files.
4. Create docs/08_design/UI_IMPLEMENTATION_NOTES.md.
5. Create docs/08_design/design_tokens.json.
6. Create or update SwiftUI design tokens/components in the existing DesignSystem area.
7. Do not change feature screens yet except if needed to compile shared components.
8. Run ./scripts/ios-build.sh.
9. Update memory docs.
10. Stop and report.
```