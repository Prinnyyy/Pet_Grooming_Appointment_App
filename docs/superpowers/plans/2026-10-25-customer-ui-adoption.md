<!-- task-artifact
task: T-420
status: active
type: plan
-->
# Customer UI adoption

Approved scope is the user's adoption handoff, with design source in `FlowSandbox/Prototype` and vocabulary/decisions in `CLAUDE_sandbox/CLAUDE_SANDBOX_PAGEMAP.md`, `CLAUDE_SANDBOX_COMPONENTS.md` and `CLAUDE_SANDBOX_LOG.md`. Adopt all customer screens without redesign; preserve real Stores, repositories, production error copy, navigation contracts and accessibility identifiers. Keep groomer layouts except the approved shared booking confirmations/account components. No remote data change or new dependency.

## Ordered work packages

- [x] Foundations: tokens, three entrance families, on-screen active replay, cascade/clock, settled presses, scroll guard. Runtime feel remains in integrated acceptance.
- [x] Kit: shared design pieces, dialog/modal presenter, snackbar, center-owned reading-time feedback, quiet clearing. Full accessibility/keyboard coverage remains in integrated acceptance.
- [x] Shell: one plain-cut tab selection function, tab entrance activation, request result focus, feedback above tab bar. End-to-end routing/replay acceptance follows screen adoption.
- [ ] Screens: Home; Requests/history; detail/offers/confirmation/reach; six-step wizard and picker/profile; Bookings/detail; Messages/chat; Account/profile/favorites/notifications; auth/recovery/onboarding/generic account.
- [ ] Renames/cleanup; sandbox host uses real views, existing mock isolation retained; boundary check updated explicitly.
- [ ] Canonical design/a11y/inventory/governance and audit updates; integrated acceptance and scoped Git closeout.

## Decisions and acceptance

User-approved behavior: embedded sixth wizard step, sorted selectable groomer list with Saved filter and shared invitation/pool actions; Done focuses Requests; active requests only on root; four feedback layers; custom decision dialogs; customer booking ticket/path/next actions/review/manage/record; pet removal confirmation; favorite removal Undo; typed reminder notice; first eligible active request selected for favorites. Preserve real transaction/recovery/validation semantics. Invitation capacity remains server-authoritative; offer badges must not imply a global minimum from incomplete pages.

Do not port DEBUG wrappers, preview initializers into normal runtime, sandbox validation bypasses, fixtures, preview notices, legacy aliases or unused host shims. The existing DEBUG dependency injection remains for sandbox isolation.

Validate relevant behavior with focused tests, compile via repository script, then integrated iOS unit/UI tests, Release build, UI audit, boundary test and preflight. Runtime checks cover tab replay, wizard ownership and send/result routing, dialogs/keyboard, Dynamic Type, VoiceOver semantics, Reduce Motion, taps/scrolls. Report unperformed checks accurately. Commit validated slices as explicitly requested; leave signing and unrelated dirty work local.

## Execution record

- Intake complete; current branch main. Existing dirty content preserved under `artifacts/evidence/T-420/pre-adoption/`; prototype stays unchanged. Follow the approved packages rather than adding a parallel planning process.
- Foundations: adopted the reviewed token/motion/ledge definitions and guarded-action helpers; retained existing base button styles for groomer callers and temporary old tokens until consumers migrate. Settled press cancels its delayed task when removed. Three foundation behavior tests passed (RTL travel, nested-scroll blocking, next tap after movement); repository build passed after an initial existing Canvas build lock cleared. Evidence: `artifacts/evidence/T-420/foundations-build.log`, `foundation-feedback-red.log`. The same test run deliberately reproduced all three feedback defects before kit work: fixed 2s floor, premature error dismissal, notice never expiring without an overlay. No screen/runtime acceptance claimed yet.
- Kit: shared layout/dialog/snackbar and expressive pieces adopted. Production feedback center owns both notice/error timers, preserves queue/scope/deduplication and original error copy; overlay renders remaining duration without retaining a second error. Quiet overlay has an always-present task and single announcement consumption. Alert escape cannot bypass its explicit decision. Focused 17 tests passed (`kit-feedback-green.log`), including the three reproduced defects; two hosted Simulator tests passed (`kit-dialogs.log`) for a State-driven modal rendering/reopening and quiet notice clearing. Two transient build-lock failures were resolved by unpinning the hidden Canvas; no source or test failure was suppressed. Existing base primitives remain for role-specific reconciliation during screen adoption.
- Shell: request-result routing and tab arrival now belong to CustomerTabView; all programmatic tab changes use a plain-cut select function. Bookings uses the existing wizard-owner policy and ignores dismissals while inactive. Shell compiled in `shell-dialogs.log`; two dialog tests passed with a settled-frame screenshot (the earlier attachment captured the entrance's invisible first frame). The targeted Swift Testing method filter matched no tests, so wizard-owner regression is still to be run with its suite at the next screen integration. Scoped staging keeps the user's sandbox injection hunks local until host adoption, avoiding commits that depend on untracked prototype files.
