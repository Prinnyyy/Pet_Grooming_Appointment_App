# Chat and Notification Acceptance

<!-- task-artifact
task: T-404
status: completed
type: plan
-->

## Objective and Boundaries

Accept the adopted local chat/notification loop: booking/notification entry, correct participant conversation, return navigation, unread state, duplicate taps, stale targets and connection recovery. SwiftUI stays behind existing Store/repository boundaries. No new messaging capability, dependency, backend writes, APNs or release work. Preserve pre-existing user changes. Execute continuously in this session without subagents; one validated completion commit/push.

## Ownership and Checks

| Owner | Required evidence |
|---|---|
| `Features/Chat/ChatStore.swift`, `ChatView.swift` | Failed/cancelled sends preserve draft; concurrent loads/events preserve messages; read state reflects delivered content; leaving cannot retain a late subscription; retry is reachable. |
| Customer/Groomer notification Stores and views | Exact identity and participant validation, missing/stale target, repeated selection, read acknowledgement failure and return path. Reuse existing all-kind routing tests. |
| Existing role shells and shared booking chat action | Booking to correct conversation, notification to thread, thread booking detail and back without duplicate navigation. |
| Existing Fake repositories and feature tests | Deterministic failing regressions before fixes; local production-view interaction without credentials or test routes in the app. |

## Execution

- [x] Inspect code/contracts and reuse unchanged routing/keyboard evidence from T-403.
- [x] Reproduce concrete defects in focused tests; repair in the existing owners and verify negative/recovery behavior.
- [x] Simulator semantic interaction: both roles, notification/booking entry and return, send/retry, stale notification, long messages and software keyboard. Use only selected visual captures.
- [x] Full iOS regression/build and preflight at final integration; document evidence/limits here and close Current State. Completion commit/push is identified by Git under T-404.

## Findings and Evidence

Confirmed and repaired in the existing owners:

- A stale first-page response erased messages sent while loading. Merge immutable messages while retaining authoritative refreshed rows.
- Read markers acknowledged unseen summary content and could move backward after an older reload. Mark only delivered history and keep the watermark monotonic. Parse message timestamps as instants, not lexicographic strings (fractional precision reproduced wrong order).
- A subscription finishing setup after exit could remain active. Use one generation identity from setup through consumption, invalidate pending starts on exit, and consume cancellation to invoke the stream's channel cleanup.
- Cancelled sends cleared the composer; a successful slow send could erase a newer draft. `sendMessage` returns an explicit success Boolean; clear only the submitted, unchanged draft. Duplicate sends report false.
- Failed history reads looked like an empty conversation, with no inline retry. Per-conversation read errors and interrupted live-update state now expose Refresh Messages; subscribe before snapshot load, with view/foreground-scoped lifecycle.
- Unread dots had no spoken state. Chat and notification rows now expose Read/Unread values; composer controls have explicit labels.
- Groomer chats all used Booking Customer and Message Booking placeholder text. Existing participant references distinguish customers without introducing identity data.
- Older message pages omitted the existing booking-detail Store reconciliation, making valid historical appointment cards unavailable. Reuse the same reconciliation as the first page.
- AX3 long drafts were clipped by a capsule mask; narrow appointment cards broke status text and truncated dates; the long thread title consumed keyboard space. Use the existing rounded input shape, an accessibility-size full-width card layout, and a focus-driven compact header that restores on Done. No keyboard observer or new design-system module.

## Acceptance Evidence

- Deterministic RED: initial five regression tests reproduced eight failed assertions; groomer title/placeholder test reproduced two; older-page booking test reproduced a nil detail Store. The first repair set and existing routing/notification suites passed 68 tests; the expanded 11-test reliability suite is included in final regression.
- iPhone 17 Pro Max and compact iPhone 17e, iOS 26.5: production-view interactions verified both roles' exact notification entry/stale rejection, booking-chat-booking-return, chat read badge and notification readback, cancellation/failure draft retention, retry, one accepted slow send without erasing a newer draft, history/live-update recovery, normal and AX3 long text, and real software-keyboard Done retaining input/restoring the header. Interaction used semantic targets, with selected visual captures only.
- Local opt-in `ChatUIAcceptanceTests` completed successfully on both sizes. Final compact log: `/tmp/t404-compact-layout.log`; selected visual evidence: `artifacts/testops/T404-chat/ax3-before.jpg` and `artifacts/testops/T404-chat/ax3-keyboard-after.jpg` (ignored local artifacts). Reproduce with `TEST_RUNNER_BECKON_CHAT_AUDIT=1 xcodebuild -project ios/Beckon/Beckon.xcodeproj -scheme Beckon -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:BeckonTests/ChatUIAcceptanceTests test`, then use Audit Controls and Finish Audit. Default regression skips this manual host.
- Test-host corrections: a manually hosted UIKit window needs explicit active scene phase; notification Fakes must retain acknowledged reads across reload. Neither was an app defect. One per-method Swift Testing filter selected zero tests and was discarded; suite-level execution supplied the valid evidence.
- Self-review covered lifecycle generation guards, message merging, identity routing, read-state account/role isolation and diff scope. Subagents remain disabled; this was not independent review.

Final integration (same source, no assertion or timeout changes):

- `./scripts/ios-test.sh` on iPhone 17e initially failed: Xcode parallel clones reported launch/IPC failures, and two existing time-bounded tests failed (`BeckonFeedbackCenterTests.errorPromptAutoDismissesAndDoesNotReplayUntilSourceClears`, `GroomerProfileStoreTests.loadRestoresAvatarBeforeSlowPortfolioPhotoHydrationCompletes`). That run is not claimed as passing. Its separate `BeckonUITests` target completed with 4 passed, 40 authorized-fixture-dependent skips and no failures; this valid UI evidence was reused.
- Serial full `BeckonTests` rerun: `xcodebuild -project ios/Beckon/Beckon.xcodeproj -scheme Beckon -destination 'platform=iOS Simulator,id=429D1A58-4FD3-4091-A5F8-26212FFBACF8' -parallel-testing-enabled NO -only-testing:BeckonTests test-without-building` passed. Result bundle `Test-Beckon-2026.10.04_22-05-31--0700.xcresult` reports 780 passed, 6 conditional skips, 0 failures; all 11 reliability tests and both previously failing tests passed unchanged. Log: `/tmp/t404-unit-serial.log`. Combined accepted target results: 784 passed, 46 explicit skips. Skips retain existing opt-in manual/remote/process requirements, not weakened gates.
- `CODEX_IOS_DESTINATION='generic/platform=iOS Simulator' ./scripts/ios-build.sh` passed. Log: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/ios-build.I38u8Yx1S6`. Only AppIntents metadata extraction warning; no AppIntents capability was added.
- Final `./scripts/preflight.sh` passed: UI/brand checks and 218 Node tests, no failures. Log: `/tmp/t404-preflight-completion.log`. Full context hygiene and `git diff --check` passed; no baseline, test threshold, dependency or project-setting changes.

Local Fake-backed validation does not establish APNs delivery, remote persistence, cross-device read receipts or audible VoiceOver certification. No remote data or release settings were changed. Existing user documentation/archive, project signing and AppInfo edits remain outside this task.
