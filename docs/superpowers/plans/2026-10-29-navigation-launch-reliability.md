<!-- task-artifact
task: T-423
status: completed
type: plan
-->
# Customer navigation and launch reliability

Adopt the user's 57-route register and eight reported problems; preserve the latest UI, business validation, request publication guarantees and account boundaries. Read-only source: `CLAUDE_sandbox/CLAUDE_SANDBOX_JUMPS.md`. One implementation and evidence record; no package checkpoints or unrelated redesign.

## Decisions and acceptance
- Home Next up selects the matching Grooming card. Explicit Details and notification/reminder destinations open their owning tab's detail.
- Each tab retains its independent history on manual selection. Programmatic cross-feature/finished-flow routes clear the source and target paths without recreating stores or whole tab roots. Push only within a feature; do not combine a tab cut with a second competing entrance.
- A successful new/revised/template request lands on its Grooming card after the sheet dismisses. Failed or partial publication stays in the existing recovery UI; cancel returns to its origin.
- Wizard Add pet is connected. Suspend the existing draft, dismiss the wizard, use Home's existing form, then resume with the saved pet selected (cancel also resumes unchanged). Ordinary no-pet entry continues to save on Home, as adopted in T-422.
- Notifications route to Grooming or Messages; reminders use the authenticated owning tab and verify account/role. Existing error/retry and notification authorization remain.
- Password recovery is an isolated root surface, not a cover above a signed-in screen. Preserve the independently scoped recovery session and return to the previous session after Done; never change accounts implicitly.
- One immediately visible startup animation, complete before handoff; never replay the launch gate after interactive sign-in. Account/profile resolution shows an appropriate loading layout; page skeleton/reveal clocks begin when visible, not behind the opening overlay. Retain reduced motion, cancellation and errors.
- Navigation/motion standards go into the existing UI spec: stable identity, lightweight route values, one transition owner, visible-only animation clocks, no main-thread synchronous I/O in interaction paths and no arbitrary sleep-based navigation.

## Work
- [x] Route ownership, completion and pet continuation; notification/reminder/recovery wiring.
- [x] Startup/visible loading timing and measured transition bottlenecks.
- [x] Focused regression + existing local Simulator host, integration/build/audit/hygiene; scoped completion Git authorized.

## Evidence
Initial code review confirmed the eight reported route/launch issues. Implementation retains publication/session checks and uses the shared route owner and existing repositories. Apple references: [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [Responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness).

Register disposition (all 57 entries reviewed by owner; frozen designer document is not edited):

| Group | Entries | Adopted disposition |
|---|---:|---|
| Shell | J-01–06 | Card focus, typed owning-tab paths, one request presenter, Home pet owner |
| Home | J-07–13 | Ordinary pet save stays; wizard pet edit suspends/resumes; bell is a shell route |
| Grooming/history/detail | J-14–24 | Existing detail actions retained; new/revised/template completion selects the new request |
| Wizard/discovery | J-25–31 | Cancel returns; clean completion routes after dismissal; failures retain recovery; profile/address modals unchanged |
| Offers | J-32–34 | Offers under Grooming; confirmation replaces selection with booked detail and clears source |
| Messages | J-35–39 | Thread belongs to Messages; booking cards open Grooming; Message returns via owning Messages route; send stays |
| Notifications | J-40–41 | Resolved destination routes to its owning tab; read/authorization behavior retained |
| Account/favorites | J-42–47 | Saved-groomer creation clears source; local editor paths reset on action handoff; other save/sign-out/delete outcomes retained |
| Auth/recovery | J-48–56 | Form/onboarding outcomes retained; no launch replay after sign-in; recovery is an isolated root with the previous session preserved |
| Reminder | J-57 | Verified customer account/role routes to Grooming, using the shared stores and Message action |

Code-level performance causes addressed: tab identity reset rebuilt the destination tree; log writers synchronously read entire files on append/init; Home serialized independent reads; hidden descendants consumed animation time; first-mounted deep-link stacks updated navigation during layout; date formatting and tab-image generation repeated expensive construction. New code retains identity, mounts stored paths once, builds destinations lazily, queues log I/O, overlaps reads and reuses the same date/icon semantics.

Evidence directory: `artifacts/evidence/T-423/` (ignored local artifacts).

- `integration-recheck.log`: 846 Swift Testing tests in 91 suites passed; 47 XCTest tests passed with 5 opt-in tests skipped. Three new XCUITest journeys passed: Home card focus; notification → booking → Message with source-stack cleanup; wizard Add pet cancel/save → resumed draft → publish → selected new card. The remaining launch/recovery failure was corrected and its entire three-test suite passed in both `recovery-root-recheck.log` and the final `launch-layout-recheck.log`.
- Initial `./scripts/ios-test.sh` rendered 458 declared screen/state/size combinations successfully (render smoke, not visual-equivalence proof). Unchanged matrix evidence was reused; changed routes were exercised through native XCUITest. The integration run's 40 opt-in UI skips require remote/seeded TestOps context, outside this client-only change. No backend deployment claim.
- The native route test uses first visits after startup, retains the 0.5 s scheduling-gap ceiling, and verifies destination paths survive native layout. Final Debug Simulator result: max 0.444 s, p95 0.153 s; repeated navigation-update warnings eliminated. This detects large main-actor stalls, not rendered-frame cadence or a guarantee of zero stutter. Startup is measured separately.
- `launch-layout.mp4` visually checked: background → orb entrance → complete text mask → aligned landing/buttons. Earlier recordings caught the static storyboard wordmark flashing before intro and an estimated-height layout causing double text; both corrected by a background-only storyboard and shared landing geometry. Latest Debug compilation and all three launch/recovery UI tests passed in `launch-layout-recheck.log`.
- Important regression corrections: dismiss readiness now reads current state; wizard completion retains its publication result for replay/recovery; closing recovery restores the signed-out form. The tool's empty native AX snapshots were bypassed using the existing XCUITest runner and a DEBUG-only isolated fixture entry; no production data/service override.

Final Release build passed (`final-release-build.log`); preflight and full documentation hygiene passed (`final-preflight.log`, `final-hygiene.log`); diff review passed. Current-branch completion Git is the final delivery step; Git owns its result/hash. Existing user rule documents, local signing settings and frozen prototype directories remain excluded from the completion commit.
