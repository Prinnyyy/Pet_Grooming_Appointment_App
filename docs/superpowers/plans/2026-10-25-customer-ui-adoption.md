<!-- task-artifact
task: T-420
status: active
type: plan
-->
# Customer UI adoption

Approved scope is the user's adoption handoff, with design source in `FlowSandbox/Prototype` and vocabulary/decisions in `CLAUDE_sandbox/CLAUDE_SANDBOX_PAGEMAP.md`, `CLAUDE_SANDBOX_COMPONENTS.md` and `CLAUDE_SANDBOX_LOG.md`. Adopt all customer screens without redesign; preserve real Stores, repositories, production error copy, navigation contracts and accessibility identifiers. Keep groomer layouts except the approved shared booking confirmations/account components. No remote data change or new dependency.

## Ordered work packages

- [x] Foundations: tokens, three entrance families, on-screen active replay, cascade/clock, settled presses, scroll guard. Runtime feel remains in integrated acceptance.
- [ ] Kit: shared design pieces, dialog/modal presenter, snackbar, center-owned reading-time feedback, quiet clearing.
- [ ] Shell: one plain-cut tab selection function, tab entrance activation, request result focus, feedback above tab bar.
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
