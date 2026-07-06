# T-047 Groomly Customer Request Booked Card Layout

Task ID: `T-047`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Refine the booked quest action card in Customer Requests:

- Replace the booked-card supporting copy `Your grooming appointment is ready...` with the original quest task summary, such as `Bath for Banksy`.
- Add the request address under the booked appointment time.
- Make the unconfirmed quest action card and booked quest action card reuse the same card style and dimensions.
- Keep the booked quest behavior from T-046: green confirmed border, one `View Booking` button, and no reappearing after same-device app restart.
- Record the work as T-047.

Follow-up refinement request:

- Center the first quest action card in the screen.
- Make `Open request` and `Booking confirmed` occupy two lines and use a larger headline.
- Make the time range occupy two lines, with the second time moving after the `-` separator.
- Unify the visual style of `Detail`, `Cancel`, and `View Booking`.
- Continue optimizing the quest action card layout so it feels visually balanced.

Second follow-up bugfix request:

- After cancelling a quest action card, the bottom `Request cancelled` prompt must retract after 3 seconds with a fade.
- The bottom prompt must not have a full-width rectangular background outside the rounded toast itself.
- The bottom prompt text needs clearer title/detail layout.
- The same bottom prompt issue exists on other pages and should be checked uniformly.
- Title-like app text should use Title Case.
- Quest action card date ranges should omit the year and stop forcing a line break, e.g. `Jun 23 at 7:27 PM - Jun 23 at 9:27 PM`.

Third follow-up global notice request:

- The bottom text notice is a global module, not a single-page module.
- Switching pages must not make the current notice disappear; it should stay in place while its countdown continues.
- A new notice replaces the current notice and restarts the countdown.
- The countdown duration is 2 seconds.

Fourth follow-up Home sync and toast placement request:

- Customer Home `Active Request` should reuse the Requests page quest action card module as a summary card, without progress timeline or action buttons.
- When the Requests page has no visible quest action card, Customer Home must also show no quest action card and instead show no-request text.
- The bottom global toast should be repositioned so it no longer covers the tab bar.

Fifth follow-up Customer Home carousel and polish request:

- Swap the Customer Home welcome header text order so `Hi, [user name]` appears above `Welcome Back`.
- Make Customer Home `Active Request` a horizontally swipeable card column that reuses the Requests page quest-card swipe behavior.
- Prevent the Home `Start Grooming Request` button from briefly flashing disabled/gray when switching pages.
- Clip the decorative paw prints inside the `Need Grooming for Your Pet?` hero card's rounded mask.
- Prevent an empty rounded loading card from briefly appearing in Home `Active Request` when there are no quest action cards.
- Change Customer Requests empty state from `No Requests Yet` to the same text used by Customer Home `Active Request`: `No Active Request`.

## Existing Capability Audit

- T-046 already renders booked handoffs through `CustomerRequestProgressCard`; no separate card route needs to remain.
- The request summary already exists as `CustomerGroomingRequest.title`, and the address exists as `CustomerGroomingRequest.locationSummary`.
- Booking time remains available from the existing `Booking.scheduledTimeSummary`.
- Same-device handoff acknowledgement persistence already exists in `CustomerRequestsStore` through customer-scoped `UserDefaults`.
- No backend field, RPC, schema, RLS, repository method, or navigation route is required for this refinement.

## Implementation Plan

1. Add a failing presentation test that proves a booked handoff card uses the quest summary and includes appointment time plus address.
2. Add a small `CustomerRequestProgressCardPresentation` value model so active and booked cards consume the same header/info-line structure.
3. Remove booked-only card chrome differences by sharing padding, content spacing, and timeline density between active and booked quest action cards.
4. Keep booked-only behavior limited to selected green border, Booking chip, and one `View Booking` action.
5. Run Standard-mode validation and launch the app in Simulator.

## Implementation Notes

- `CustomerRequestProgressCardPresentation` now supplies headline, subtitle, chip, and info lines for both active requests and booked handoffs.
- Booked handoff cards now show:
  - headline: `Booking confirmed`
  - subtitle: the original request title, for example `Full groom for Mochi`
  - info line 1: confirmed booking time
  - info line 2: request address
- Active and booked cards now share the same `GroomlyCard` padding, content spacing, and regular timeline density.
- The regular timeline density was tightened so the header, timeline, and action row fit more cleanly in a phone viewport while preserving the same layout for both states.
- T-046 local acknowledgement persistence was preserved; no data deletion or backend mutation was added.
- Follow-up: card width now uses the horizontal scroll viewport length directly so the first card centers within the content column while preserving screen-edge scroll bleed.
- Follow-up: request-card headlines now use explicit two-line strings such as `Open\nrequest` and `Booking\nconfirmed`, rendered with a larger rounded heavy title.
- Follow-up: active and booked time ranges now format as `start -\nend`.
- Follow-up: `View Booking`, `Detail`, and `Cancel` now all render through `CustomerRequestActionLabel`, with tone-only color differences instead of unrelated button structures.
- Second follow-up: Customer Requests card time ranges now use a compact no-year single-line format (`MMM d at h:mm a - MMM d at h:mm a`) and no longer insert a manual newline.
- Second follow-up: `CustomerRequestsStore.clearNotice(ifCurrent:)` originally guarded the page-local dismiss task; the third follow-up superseded that view-local timer with the global 2-second `GroomlyFeedbackCenter` token.
- Second follow-up: `GroomlyNoticeToast` and `GroomlyStatusProgressToast` were added to the feedback design primitives for bottom status surfaces.
- Second follow-up: bottom notice/status surfaces were checked and updated in Customer Requests, Customer Home/Pets, Bookings, Groomer Requests, Groomer Profile, and Chat. The old full-width `.ultraThinMaterial` status backgrounds were removed from these status views; only the rounded toast/progress card carries material.
- Second follow-up: visible title-like text touched by this pass was updated to Title Case across the affected screens, including auth loading/error titles, Customer Home section titles, request card/timeline titles, booking/chat/groomer request status titles, and groomer profile field titles.
- Third follow-up: bottom success notices now use `GroomlyFeedbackCenter` as a global tab-shell state owner instead of being owned by each page status view.
- Third follow-up: `CustomerTabView` and `GroomerTabView` install the feedback center in the environment and render `GroomlyGlobalFeedbackOverlay` at the shell level, so switching tabs no longer removes the active notice.
- Third follow-up: feature status views now use zero-size `GroomlyNoticeForwarder` instances to forward store `noticeMessage` values into the global center and clear the page-local copy, preventing stale notices from reappearing when returning to a page.
- Third follow-up: global notice dismissal is token-based and set to 2 seconds. When a newer notice appears, the older countdown token can no longer clear it.
- Third follow-up: Chat thread view also forwards `ChatStore.noticeMessage`, so send-success feedback appears without requiring the user to return to the conversation list.
- Fourth follow-up: `CustomerRequestsStore.visibleActionCards` now centralizes the Requests/Home visible-card filter by combining unconfirmed `open`/`has_offers` requests with unacknowledged booked handoffs backed by confirmed bookings.
- Fourth follow-up: `CustomerRequestActionCardItem` represents one visible quest action card and carries either an active request or an optional booking handoff.
- Fourth follow-up: `CustomerRequestProgressCarousel` now renders from `visibleActionCards`, establishing the shared visible-card source later reused by Customer Home.
- Fourth follow-up: Customer Home's active card uses `CustomerRequestActionCardSummary`, which reuses the quest action card shell/header/presentation but omits the timeline and buttons.
- Fourth follow-up: Customer Home no longer falls back to cancelled, expired, or arbitrary non-visible requests. If `visibleActionCards` is empty, the module displays no-request text only.
- Fourth follow-up: `GroomlyGlobalFeedbackOverlay` now renders as a tab-shell bottom overlay with an explicit `bottomTabBarClearance` and disabled hit testing, instead of occupying the tab shell bottom safe-area inset.
- Fifth follow-up: Customer Home now renders all `visibleActionCards` through `CustomerRequestActionCardSummaryCarousel`, using the same horizontal ScrollView content margins, disabled scroll clipping, and view-aligned paging pattern as the Requests carousel.
- Fifth follow-up: `CustomerHomeActiveRequestPresentation` removes the previous loading-card branch for an empty active-request section, so no blank rounded loading card flashes while requests reload.
- Fifth follow-up: `CustomerHomeRequestHeroPresentation` gates the `Start Grooming Request` button only on whether pets exist; request-store busy/loading state no longer turns the CTA gray during tab/page switches.
- Fifth follow-up: Customer Home's welcome header now places `Hi, [displayName]` above `Welcome Back`.
- Fifth follow-up: the request hero's decorative paw prints are clipped by the hero's rounded rectangle mask.
- Fifth follow-up: `CustomerRequestEmptyCopy` now centralizes the shared empty title/message for Customer Home and Customer Requests; Customer Requests now shows `No Active Request`.

## Files Changed

- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsStore.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/GroomlyFeedbackPrimitives.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticatedEntryView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticationView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/CustomerTabView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Profile/GroomerProfileManagementView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/Requests/GroomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Groomer/GroomerTabView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/AppEntryModelsTests.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/06_tasks/T-047_GROOMLY_CUSTOMER_REQUEST_BOOKED_CARD_LAYOUT.md`
- `docs/06_tasks/TASK_LEDGER.md`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`

## Validation Plan

```sh
xcodebuild -project ios/PetGroomerMarketplace/PetGroomerMarketplace.xcodeproj -scheme PetGroomerMarketplace -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16 Pro' test -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress
git diff --check
./scripts/ios-build.sh
```

Completion launch:

- Launch the app in the iOS Simulator for inspection.

## Validation Results

- Targeted TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress` failed before implementation because `CustomerRequestProgressCardPresentation` did not exist.
- Targeted green check: the same test passed after adding the presentation model and shared card layout.
- `git diff --check` passed.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`). App launched successfully for inspection.
- Simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_944098b2-cb6c-45d1-be79-9e4a1d32606b.jpg`.

Follow-up validation:

- Follow-up TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` failed before implementation on `bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress` and `openRequestCardPresentationUsesTwoLineHeadlineAndTimeRange`.
- Follow-up green check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` passed after the presentation and card layout updates.
- Follow-up `git diff --check` passed.
- Follow-up `./scripts/ios-build.sh` passed.
- Follow-up XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`). App launched successfully for inspection.
- Follow-up simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_21a2af42-0578-4de8-bdab-6dd390783648.jpg`.

Second follow-up validation:

- TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` failed before implementation because `CustomerRequestsStore.clearNotice(ifCurrent:)` did not exist.
- TDD green check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests` passed after adding the notice clear guard, compact date formatting expectations, and Title Case card presentation expectations.
- `git diff --check` passed before documentation updates.
- `./scripts/ios-build.sh` passed after cross-page bottom status/toast and Title Case updates.
- Repository scan found no remaining `.background(.ultraThinMaterial)`, `ChatNoticeView`, `CustomerRequestsNoticeToast`, or `twoLineDisplayRange` uses in Swift files.
- Final `git diff --check` passed after documentation and memory updates.
- Final XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`). App launched successfully for inspection.
- Final simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_81971db6-f8b1-456b-b616-f282751eeea6.jpg`.

Third follow-up validation:

- TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/GroomlyFeedbackCenterTests` failed before implementation because `GroomlyFeedbackCenter` did not exist.
- TDD green check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/GroomlyFeedbackCenterTests` passed after adding the global center, 2-second countdown constant, and token-based replacement/clear behavior.
- Repository scan found no remaining page-level `GroomlyNoticeToast`, `noticeDismissDelay`, `dismissNoticeAfterDelay`, `.task(id: store.noticeMessage)`, `noticeMessage != nil`, or `3_000_000_000` uses in Swift files outside the global feedback primitive.
- `./scripts/ios-build.sh` passed after moving notice ownership to the tab shell.
- Final `git diff --check` passed after documentation and memory updates.
- Final `./scripts/ios-build.sh` passed after removing one redundant `await` warning from `GroomlyNoticeForwarder`.
- Final XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`) with no diagnostics warnings or errors. App launched successfully for inspection.
- Final simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_7a4c6238-985e-44e2-8a30-56e2ec80995c.jpg`.

Fourth follow-up validation:

- TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/visibleActionCardsMirrorRequestsDashboardFilteringForHome -only-testing:PetGroomerMarketplaceTests/GroomlyFeedbackCenterTests/globalNoticeOverlayKeepsClearanceAboveTabBar` failed before implementation because `GroomlyGlobalFeedbackOverlay.bottomTabBarClearance` did not exist.
- TDD green check: the same targeted test command passed after adding `visibleActionCards`, the shared Home summary card, and the tab-bar clearance constant.
- Targeted scan found no remaining old Home active-card component, old `requestStore.requests.first` fallback, or `GroomlyGlobalFeedbackOverlay` bottom safe-area inset use in Swift files.
- `./scripts/ios-build.sh` passed after the Home/Requests shared-card and toast placement changes.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`) with no diagnostics warnings or errors. App launched successfully for inspection.
- Simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_6ca15fda-57cd-4667-a6ed-1fb45e85db0d.jpg`.
- Final `git diff --check` passed after documentation and memory updates.

Fifth follow-up validation:

- TDD red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/homeRequestHeroStaysEnabledWhileRequestsReloadWhenPetsExist -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/homeActiveRequestPresentationUsesAllCardsAndNeverShowsLoadingCard` failed before implementation because `CustomerHomeRequestHeroPresentation` and `CustomerHomeActiveRequestPresentation` did not exist.
- Additional red check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/requestEmptyCopyIsSharedByHomeAndRequests` failed before implementation because `CustomerRequestEmptyCopy` did not exist.
- Targeted green check: `xcodebuild ... -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/homeRequestHeroStaysEnabledWhileRequestsReloadWhenPetsExist -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/homeActiveRequestPresentationUsesAllCardsAndNeverShowsLoadingCard -only-testing:PetGroomerMarketplaceTests/CustomerRequestsStoreTests/requestEmptyCopyIsSharedByHomeAndRequests` passed.
- Targeted scan found no remaining old `No Requests Yet` copy, Home first-card-only `visibleActionCard` path, Home active-request loading card identifier, or old `Start a grooming quest` empty copy in Swift files.
- `./scripts/ios-build.sh` passed.
- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`) with no diagnostics warnings or errors. App launched successfully for inspection. Process id: `9792`.
- Simulator screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_015aeb39-3733-44a2-b8ce-a507ced874d8.jpg`.
- Final `git diff --check` passed after documentation and memory updates.

## Risks And Follow-Up

- The card layout is now structurally shared, but visual verification still depends on available runtime data containing booked and unconfirmed cards.
- Same-device handoff acknowledgement remains local `UserDefaults` state from T-046. It still does not survive reinstall, app data clearing, or cross-device use.
- Global notice persistence is intentionally in-memory UI state only. It survives tab/page switches in the current app session but is not persisted across app termination.
- Customer Home now shows the same visible quest action card set as a summary carousel, but card actions still live only in Customer Requests.
- No Supabase changes were made in this task.
