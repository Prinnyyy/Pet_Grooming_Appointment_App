# Groomly UI Implementation Notes

## 1. Design Sources Inspected

- `docs/08_design/Apply Groomly Design Prototype to Existing SwiftUI App.md`
- `docs/08_design/Groomly.html`
- `docs/08_design/Groomly/Groomly.html`
- `docs/08_design/Groomly/Groomly.dc.html`
- `docs/08_design/Groomly/support.js`
- `docs/08_design/Groomly/dev/01-check.png`
- `docs/08_design/Groomly/dev/02-check.png`
- `docs/08_design/Groomly/uploads/draw-b974a192-01e5-4421-9201-efb7d1591dc9.png`
- `docs/08_design/Groomly/uploads/draw-e8537263-4c6b-4780-896e-8815543ecb60.png`
- `docs/08_design/Groomly/.thumbnail`
- `docs/08_design/Groomly/.DS_Store`
- `docs/01_product/SCREEN_INVENTORY.md`
- Current SwiftUI source file list from `rg --files ios/PetGroomerMarketplace/PetGroomerMarketplace`

User confirmed `docs/08_design/Groomly.zip` has already been extracted as `docs/08_design/Groomly/`. The audit uses the extracted folder as the ZIP source of truth.

## 2. Detected Brand Name

The prototype brand is `Groomly`.

The prototype subtitle is "Find trusted independent groomers for your pet." The product model shown in the prototype is broadly compatible with the current app's marketplace model, as long as unsupported demo-only items remain deferred.

## 3. Core Visual Direction

- Warm, soft mobile UI on a cream/off-white background.
- High-radius white cards with thin warm-gray borders and low-opacity shadows.
- Mint/teal primary customer actions and progress states.
- Coral secondary/accent styling for groomer mode and groomer primary actions.
- Friendly pet-care cues through paw/dog/scissors icons, emoji placeholders, rounded avatars, and gentle status copy.
- iPhone-frame prototype with bottom tab bars, sticky headers, bottom sheets, toast feedback, and subtle fade/slide/pop motion.

## 4. Core Colors Observed

Most frequent or semantically important colors:

- App/background: `#FAF7F2`, `#EFEAE1`, `#EBE4D9`, `#E7E0D5`
- Surface/card: `#FFFFFF`, with borders `#EFEAE1`, `#E8E2D8`, `#F2EDE4`
- Text primary: `#232323`
- Text secondary/muted: `#6F767E`, `#9AA0A6`, `#C4BCAE`
- Customer primary mint: `#7ECFC0`
- Customer primary darker mint: `#5FBFAE`, `#3A8D7E`, `#3A7A6E`
- Soft teal: `#A8DADC`, `#EAF6F3`, `#EDF6F3`, `#DDEEEA`
- Groomer/coral accent: `#FF9A8B`, `#F58575`, `#C8675A`
- Success: `#6CBF84`, `#3F9159`
- Warning: `#F2B84B`, `#B9842A`
- Error/destructive: `#E56B6F`, `#C85A5E`

T-023B should not carry every observed color into `design_tokens.json`. It should choose conservative semantic tokens from this audit, for example treating `#7ECFC0` as the primary mint source unless the token task finds a stronger source of truth.

## 5. Typography Direction

- Prototype imports Inter and falls back to `-apple-system`, `SF Pro Display`, and `system-ui`.
- iOS implementation should prefer native SF typography while matching the weight/scale direction.
- Large screen titles are usually 24-30 pt, bold/700, tight but readable.
- Brand splash title is larger, around 40 pt bold.
- Body and supporting copy are usually 13-16 pt, regular to medium, with secondary text in muted gray.
- Labels and chips are compact, usually 10.5-13.5 pt, semibold.

## 6. Spacing, Radius, and Shadow Patterns

- Screen padding is mostly 20-24 pt horizontally, with top content offset around the safe area.
- Common vertical spacing: 8, 10, 12, 14, 16, 18, 20, 22, 24, 28, and 34 pt.
- Primary buttons are 54-56 pt tall with 18 pt corner radius.
- Inputs are about 50-54 pt tall with 14-16 pt corner radius.
- Cards commonly use 20-24 pt corner radius; larger hero cards use 24-26 pt.
- Pills/chips use full capsule radius.
- Bottom sheets use 28 pt top corner radius and an overlay.
- Shadows are soft and low contrast, often `rgba(35,35,35,0.04-0.08)` for cards and stronger colored shadows for primary CTAs.

## 7. Major Prototype Screens

- Splash / welcome
- Login
- Role selection
- Customer home
- Customer pets list
- Add/edit pet
- Grooming request wizard with pet, service, time, details, and review steps
- Request status / matching timeline
- Customer offers list and offer detail
- Customer-facing groomer profile
- Booking confirmation
- Customer bookings list and booking detail
- Customer messages and chat
- Customer account
- Groomer home
- Groomer open requests board
- Groomer request detail
- Make offer / suggest time
- Groomer offers list
- Groomer schedule
- Groomer profile editor
- Groomer messages and chat
- Groomer account

## 8. Reusable Components Detected

- Role/demo segmented control.
- Phone-safe screen scaffold with warm background.
- Rounded card containers with border and soft shadow.
- Primary gradient buttons.
- Secondary outline buttons.
- Text inputs and text areas.
- Selection cards with checkmark state.
- Horizontal filter chips and toggle chips.
- Status chips for waiting, reviewing, confirmed, accepted, suggested time, completed, and errors.
- Progress bars and vertical timeline rows.
- Pet/groomer avatar blocks.
- Bottom tab bars for customer and groomer modes.
- Bottom sheets for confirmations.
- Toast messages.
- Empty states.
- Chat bubbles and chat composer.

## 9. Customer Screens Detected

- Splash, login, role selection, and customer mode entry.
- Customer home with pet cards, active request, next booking, and request CTA.
- Pets list and add/edit pet form.
- Multi-step request wizard.
- Request status with matching timeline and matched groomer rows.
- Offers list with sorting/filter chips and accept CTA.
- Offer detail with groomer summary, price, proposed time, message, recent work placeholders, and accept/message/profile actions.
- Booking confirmation.
- Bookings list, booking detail, messages/chat, and account.

## 10. Groomer Screens Detected

- Groomer home with metrics, today's schedule, and nearby requests CTA.
- Open requests board with filters and request cards.
- Request detail with pet/request context, note, customer preferences, not-a-fit action, make offer, and suggest time.
- Make offer/suggest time form with proposed time, price, duration, message, included services, and validation errors.
- My Offers with pending/accepted/expired tabs.
- Schedule view with day strip, timeline, booking card, message, and complete action.
- Profile editor with display name, bio, experience, service radius, specialties, base prices, and accepting-new-clients toggle.
- Groomer messages/chat and account.

## 11. Current App States That Must Be Preserved

- Supabase configuration bootstrap and blocking missing/invalid configuration state.
- Auth session restore/observation, signed-out auth UI, authenticated profile loading, and retryable profile failures.
- Email/password auth and confirmation notice.
- Role onboarding and immutable customer/groomer role separation.
- Customer pet loading, empty, error, add/edit, soft-delete, and photo metadata/storage path states.
- Customer request publishing, request list/detail, frozen pet snapshot display, match-count feedback, loading, empty, error, and offer review states.
- Current Open Request -> Groomer Offer -> Customer Confirmation -> Booking model.
- Groomer matched request feed/detail/dismiss flow.
- Groomer offer creation, validation, pending status, and withdrawal.
- Customer pending/historical offer review and acceptance.
- Booking list/detail for both roles, cancellation, groomer completion, and customer review.
- Participant-only text chat and booking context.
- Groomer profile/services/portfolio metadata management.
- Authenticated Account and safe developer Debug Panel.
- Repository/service boundaries; SwiftUI views must not call Supabase directly.

## 12. Prototype-to-SwiftUI Screen Mapping

| Prototype area | Current SwiftUI target |
|---|---|
| Splash, login, auth entry, role selection | `Features/Auth/AuthenticationBootstrapView.swift`, `Features/Auth/AuthenticationGateView.swift`, `Features/Auth/AuthenticationView.swift`, `Features/Auth/AuthenticatedEntryView.swift`, `Features/Auth/RoleOnboardingView.swift` |
| Authenticated account | `Features/Auth/AuthenticatedAccountView.swift` |
| Customer tab shell | `Features/Customer/CustomerTabView.swift`, `Features/Customer/CustomerTab.swift` |
| Customer home/pets/add pet | `Features/Customer/Pets/CustomerPetsView.swift`, `Features/Customer/Pets/CustomerPetsStore.swift` |
| Customer request wizard/status/offers/offer detail | `Features/Customer/Requests/CustomerRequestsView.swift`, `Features/Customer/Requests/CustomerRequestsStore.swift` |
| Groomer tab shell | `Features/Groomer/GroomerTabView.swift`, `Features/Groomer/GroomerTab.swift` |
| Groomer open requests board/request detail/make offer | `Features/Groomer/Requests/GroomerRequestsView.swift`, `Features/Groomer/Requests/GroomerRequestsStore.swift` |
| Groomer account/profile editor/services/portfolio | `Features/Groomer/Profile/GroomerProfileManagementView.swift`, `Features/Groomer/Profile/GroomerProfileStore.swift` |
| Customer and groomer bookings, booking detail, completion, review | `Features/Bookings/BookingsView.swift`, `Features/Bookings/BookingsStore.swift` |
| Customer and groomer messages/chat | `Features/Chat/ChatView.swift`, `Features/Chat/ChatStore.swift` |
| Safe developer diagnostics | `Features/Debug/DebugPanelView.swift`, `Features/Debug/DebugDiagnostics.swift` |
| Shared visual primitives for later T-023 child tasks | `DesignSystem/DesignTokens.swift`, `DesignSystem/FeaturePlaceholderView.swift`. These files are existing SwiftUI design-system targets; this audit does not mean they already contain Groomly tokens. |

## 13. Deferred or Unsupported Prototype Ideas

Treat these as visual inspiration only unless a later task explicitly authorizes product/backend work:

- Customer cancellation of open grooming requests.
- Reschedule action on booking detail.
- Standalone full groomer offers tab beyond the current request-detail offer flow.
- Groomer schedule/availability calendar beyond existing booking list/detail behavior.
- Offer-time conflict validation in the client/prototype; backend-authoritative conflict behavior must stay in existing RPCs.
- Customer-facing groomer profile discovery/start-request-from-profile flow.
- Payments, payment methods, payouts, subscriptions, refunds, and disputes.
- Avatar upload/display and fully wired remote image rendering.
- Chat attachments, read receipts, typing states, and realtime polish.
- Favorites, maps, complex calendar UI, push notifications, admin dashboard, and production email/deep-link setup.
- Demo role switching, demo data, demo controls, and any local fake success path.

## 14. Asset Notes and Open Risks

- The prototype mainly uses inline SVGs, emoji placeholders, CSS gradients, and generated HTML/CSS. Do not copy web code directly into SwiftUI.
- `support.js` is generated prototype runtime code and is not an app dependency.
- The two `dev/*check.png` images are identical and appear to show an incomplete/blank prototype render, so they are weak visual references.
- The two `uploads/draw-*.png` files are screenshots of the splash screen. One includes a red hand-drawn annotation. They should not be imported as production app assets.
- `.thumbnail` is a WebP preview artifact; `.DS_Store` is macOS metadata. Neither is an app asset.
- User confirmed `Groomly.zip` has already been extracted as `docs/08_design/Groomly/`; future asset use still needs explicit source/licensing review.
- No reusable production logo, icon set, pet photos, groomer photos, or licensed illustration package was identified.
- Prototype-only backend/product concepts are present. Later implementation tasks must preserve current repositories, RLS/RPC contracts, role routing, loading/empty/error states, and Debug Panel behavior.
