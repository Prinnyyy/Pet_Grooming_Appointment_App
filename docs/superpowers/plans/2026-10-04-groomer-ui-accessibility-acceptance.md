# Groomer UI, Module and Accessibility Acceptance

<!-- task-artifact
task: T-402
status: completed
type: plan
-->

## Adopted Objective

Resume Q-104 on the existing Groomer experience. First verify design/module rules and inventory the actual UI, then repair verified workflow, duplication and accessibility defects. Judge placement by the user's next action, not by visual similarity alone. No new marketplace behavior, backend writes, dependencies, dark mode, physical-device or release work.

Canonical rules: [Design System](../../01_product/DESIGN_SYSTEM.md), [Accessibility](../../01_product/ACCESSIBILITY_RULES.md), [UI Code Governance](../../04_ios/UI_CODE_GOVERNANCE.md), [Groomer contract](../../08_design/GROOMER_UI_REDESIGN.md). Screen inventory must reflect verified code, not its obsolete six-tab description. Existing user edits remain separate.

## Workflow and Module Review

| Surface | User job and ownership | Review decision |
|---|---|---|
| Home | Next appointment, actionable counts, availability summary, notification entry; read-only aggregator | Shortcuts are useful; do not duplicate editing or imply failed reads mean zero work. |
| Requests / Matches | Assess eligible demand, open request, send a deliberate offer | Keep one request-detail/offer flow; inspect summary density, time/location, disabled/busy/error states. |
| Requests / Offers | Track pending/past offers and their booking outcome | Keep inside Requests, not a sixth tab; inspect information truncation and return flow. |
| Schedule | Inspect confirmed appointments by day and open fulfillment/chat | Separate booked work from availability configuration; date strip and picker may serve different time horizons. |
| Messages | Conversation list, thread, booking context, composer | Shared business feature; do not duplicate it under Groomer. Verify actions and keyboard access. |
| Account | Profile, services, portfolio, availability, fit claims, evidence, support/account access | Keep editable claims distinct from read-only evidence; settings must have one editing owner and one back route. |
| Notifications | Updates reached from Home, routing to existing request/booking/thread | Preserve shared inbox behavior, mark-read semantics and stable selectors. |
| Visual primitives | DesignSystem owns surfaces, sections, status/actions/forms; SharedFeatures owns cross-role business UI | Remove wrappers only if they add no semantics; keep feature-specific composites local. |

## Execution

- [x] Inspect owners, consumers and current screens; record evidence-backed findings and keep/merge/fix decisions below.
- [x] Reproduce material defects with local hosted views and focused tests before repair; reuse existing Fake repositories.
- [x] Fix verified current-flow issues without new navigation capabilities or persistence; preserve selectors and business transitions.
- [x] Validate compact/large widths, default/AX3 text, labels/actions/headings/44pt targets, approved colors, image fallback and async states. Use semantic controls; only targeted visual captures, not screenshot-per-click driving.
- [x] Run focused tests during changes, integrated build/test/preflight at completion, full hygiene and diff review. Record skips/limits and actual evidence here.
- [x] Reconcile affected design inventory/contract text and Current State; keep completion changes scoped. Git owns completion commit/push evidence.

## Findings and Evidence

| Finding | Repair and boundary |
|---|---|
| Home failed/cancelled reads looked like zero work; failed availability looked like missing hours | Unknown counts stay unknown; verified-empty stays zero. Current profile/hours are required for availability claims. First-page counts are not advertised as complete totals. |
| Initial Account failure exposed empty editable sections | Inline unavailable state, retry and sign-out; do not present an unloaded account as an empty one. |
| Account Fit Signals summary counted unsaved draft initialization | Summary now uses persisted active claims; entering/leaving the editor does not imply a saved change. |
| Long titles, status chips, section accessories, date/breed details collided or truncated at AX3 | Adaptive stacks in shared section headings, photo editor and feature headers; full-width metadata; semantic fonts and wrapping. |
| Availability time menus shrank text and had undersized targets | Start/end labels include weekday and current value; content-sized controls with 44pt minimum. Preferences and buffer fields reflow vertically at AX3. |
| Focusing a low Availability field hung SwiftUI | Sample showed repeated LazySubviewPlacements/GraphHost transactions. The bounded four-section form uses VStack, parent-owned focus and existing shared keyboard avoidance/stationary action. Focus regression and actual software-keyboard entry/Done/discard passed. |
| Range thumbs lacked accessible adjustment | Shared feature-local range control exposes two named adjustable elements with bounded increment/decrement; 48pt targets and wrapped AX3 legend. Native AX tree exposes the range as descriptive value. Numeric-only AXe slider setting cannot drive it; no claim of spoken VoiceOver adjustment testing. |
| Coral/white and pale status text failed contrast intent | Existing groomerOnAccent/status-text roles replace pale foregrounds. Measured extra approved pairs are recorded in Accessibility Rules; warning text uses a white failure surface. |
| Parent selectors overrode child booking/offer/form controls | Explicit accessibility containers preserve independently actionable children. |
| Chat displayed a nonfunctional attachment plus | Removed the decorative false affordance; retained the actual text/send workflow in the shared Chat feature. |
| Three role-specific wrappers only forwarded to DesignSystem | Removed GroomerWorkspaceSection/GroupedSurface/Divider; consumers use canonical primitives. Deleted unused Availability matching block and made the one-use profile toggle private. |
| Size control was owned by one of two consumer editors | Moved slider/legend into GroomerSizeRangeControl, feature-local to Profile. No new generic framework or dependency. |
| Shared async feedback had no explicit announcement | Add visible-prompt announcement at the existing overlay, preserving queue/deduplication; verify content and reduction of motion. |
| Screen inventory still described planned Home and six tabs/More | Reconciled to the actual five tabs, editors and ownership. |

Keep decisions: Home shortcuts versus tabs are purposeful; Schedule date strip versus date picker serve short/long horizons; Availability versus Schedule separates configuration from booked work; claims versus evidence separates edits from outcomes. Request/offer rows are different domain objects, not candidates for a universal card abstraction. No backend, transaction or navigation capability was added.

## Validation

Local fixture host uses the real GroomerTabView with existing Fake repositories, future long-name requests/offers/bookings, seven-day hours, image success/failure and outcome evidence. It asserts no offer submission, dismissal, profile save, availability save or chat send. It is opt-in; normal regressions skip this manual host. No remote-account or real-order acceptance is inferred.

Runtime evidence lives in ignored `artifacts/testops/T402-ui/`:

- iPhone 17e (390pt) and iPhone 17 Pro Max (440pt), iOS 26.5, normal/AX3. Sheet AX3 was tested with the Simulator's actual content-size setting as well as hosted environment values; settings are restored afterward.
- Home populated/empty/partial-error; retry and route actions; Requests/Offers long rows and details; Schedule day strip, zone, summary and timeline; Messages draft/disabled-empty send; Account profile/services/portfolio/availability/fit/evidence routes; empty Notifications; no More/duplicate back.
- `after-request-ax3.jpg`, `after-offer-ax3.jpg`, `after-profile-ax3.jpg`, `after-chat-ax3.jpg`, `after-availability-keyboard-ax3.jpg`, `after-home-default.jpg`. Layout captures named `schedule-layout-ax3` and `services-layout-ax3` precede the final foreground-color correction; they prove layout, not final palette. Synthetic scissors PNG verifies decoding/reuse, not production photography.
- Initial state/heading RED in `t402-red.log`; focused GREEN in `t402-green.log` and `t402-focused2.log`. Photo-editor test RED in `t402-photo-red.log` (three layout assertions), then GREEN in `t402-ui5.log` (4 hosted geometry/focus tests plus the manual host, 0 failures). `t402-ui4.log` also passed its fixture safety assertions.
- One intermediate UI run was stopped after reproducing the Availability focus hang (`t402-sample.txt`); later focused/runtime results verify its repair. AX snapshot timeouts and offscreen target centers were tool-navigation limitations, not app failures; semantic scrolling/refreshed snapshots were used instead of screenshot-per-click driving.
- The first integrated run found one existing fulfillment-recovery test using a fixed 2026-10-01 appointment, already past at execution. Cancellation was correctly unavailable, so the recovery scenario never started. The test now reuses the existing future-booking fixture and asserts cancellation is available before exercising all original recovery assertions. No booking rule changed; the 8-test fulfillment suite passed (`t402-fulfillment-green.log`).

Integration results:

| Gate | Result and evidence |
|---|---|
| `./scripts/ios-build.sh` | PASS, `t402-build-final.log`; Simulator build, no release/signing change. |
| `./scripts/ios-test.sh` on iPhone 17e | PASS after the fixture repair, `t402-tests-final.log` and `t402-tests-final-summary.json`: 770 passed, 0 failed, 44 skipped (814 test cases; 899 passing executions when dynamic parameters are counted). Includes all four Groomer layout/focus tests and feedback-announcement content/deduplication. |
| Skip boundary | 40 gated TestOps UI cases; email delivery, independent-process recovery and two opt-in manual hosts. T-402's manual host ran separately with its no-mutation assertions. No disabled gate is presented as passing evidence. |
| Announcement RED/GREEN | `t402-announcement-red-suite.log` reproduced three intended content failures; final integrated run passed `feedbackAnnouncementContainsOnlyTheVisiblePrompt`. |
| `./scripts/preflight.sh` | PASS, `t402-preflight.log`; reused after the test-only fixture correction because relevant checks/configuration were unchanged. |
| UI source ratchet | PASS; removed 54 resolved baseline entries, no loosened rules. 144 repository findings remain, 115 baselined; this is debt reduction, not zero repository-wide debt. |
| Full context hygiene and diff review | PASS; affected design routing/ownership and Q-104 status reconciled. Existing user docs, archives and project configuration remain outside this completion change. |

Local Q-104 acceptance is complete within this boundary. The final Xcode result is `Test-Beckon-2026.10.04_19-18-25--0700.xcresult`; copied logs and summary remain in the ignored evidence directory so Xcode log rotation does not erase the recorded result.

Limit: this local acceptance inspects runtime labels, grouping, headings, targets and adjustment semantics, plus announcement content/code. It does not claim an audible VoiceOver walkthrough, rotor/speech timing certification, or physical-device validation. [Apple's accessibility testing guidance](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app) distinguishes Simulator inspection from on-device VoiceOver. No device/signing/release task is added to the user's local scope.
