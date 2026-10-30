<!-- task-artifact
task: T-422
status: completed
type: plan
-->
# Handoff 3: loading, opening and Home

Adopt the S-090→S-103 design delta and changed interactions from the read-only handoff 3. Preserve T-421 navigation, shared stores, backend safeguards and existing user work. Continue through the whole objective; one concise evidence record, no per-slice commits or repeated heavy validation.

## Decisions
- D1: one launch overlay spanning bootstrap, session and profile resolution. Build the destination underneath; dismiss after readiness and at least 0.7 s. Configuration/auth/profile failures remain actionable, never concealed by an infinite launch overlay. Match the static system launch artwork using existing project assets/configuration.
- D2: explicit first-load completion on existing Stores, scoped to their current session/read. Success and actual failure settle; cancellation or a six-second timer does not invent a response. Cached content can appear immediately. Refresh/load-more retains content.
- D3: Home pull refresh adopted: 72 pt and release, one in-flight refresh, existing loadHome, minimum 1 s, light haptic, no extra spinner/scene decoration.
- D4: retain B1E0C5 lawn and latest cloud/mountain layout/motion.
- D5: user supersedes customer-only shared-component restriction: common title/layout/loading components may update together. Preserve groomer role actions, semantics and accent; no additional groomer-page redesign.
- D6: semantic tokens for reusable sizes/color/timing; drawing geometry stays in its design-system component. No blanket audit exemptions.
- No pet: request buttons remain tappable after first data response; shared Add pet / Not now dialog. Grooming→Home→existing pet form. Saving stays on Home, with no automatic request creation.

## Work and acceptance
1. [x] Shared skeleton/reveal, tokens, motion, dialog and title primitives; deterministic timing checks.
2. [x] Home scene, header/hero, first-load sections, empty pets row and pull refresh; preserve data/error/recovery behavior.
3. [x] Grooming/detail skeletons and add-pet route through the existing shell; test both entry points.
4. [x] Messages/Account placeholders and aligned title rows; shared-role behavior review.
5. [x] One launch gate, shared lockup and static launch artwork; cold/session/error/signed-out paths.
6. [x] Reuse sandbox fixtures/replay, focused tests and integration regression; targeted Simulator motion/AX/loading interactions, Release, UI audit/boundary/preflight/hygiene and scoped completion Git.

## Evidence and recovery
Startup: main at T-421 completion; five existing tracked user edits plus frozen untracked prototype/design sources excluded from task changes. No backend migration or remote test-data operation is needed by the adopted delta.

First integration: Debug build passed; deterministic reveal and five-Store first-answer tests passed (success/empty/failure/cancellation/retry). Boundary + UI audit tests: 21 passed. Preflight and full context hygiene passed before the final integration changes. Native Simulator reproduced and then prompted a fix for stale pet data: after Grooming→Home→save, the immediately opened wizard still saw the previous empty list. Home now synchronizes its confirmed pet snapshot into the shared request Store; a pet snapshot revision prevents an older in-flight read from overwriting it. Ownership/session checks remain in place. No automatic request starts after save.

Simulator acceptance uses the existing XCTest interaction host, production views and local repositories. Semantic taps verified Home no-pet dialog→pet form→Cancel; Grooming no-pet dialog→Home form→save Peanut→Home success feedback→immediate request with Peanut selectable (after the stale-data fix). Home, Messages, Account and detail were held in loading then released; business controls were absent while waiting. Standalone Grooming replay revealed missing host activation, fixed by invoking the existing shared reads when no tab shell exists; a focused fixture regression covers it. Default/AX3 Home renders and video cover the reveal/pup/pull; Reduce Motion was enabled in the task Simulator, confirmed through the native environment, and restored to its original off value. Simulator haptic-library and IOSurface warnings are toolchain noise; no modal presentation failure was observed. No physical-device haptic or spoken VoiceOver certification is claimed.

Evidence directory (ignored): `artifacts/evidence/T-422/`. Recordings: `home-reveal-pull.mp4`, `reduced-reveal.mp4`; `motion-contact.jpg` samples the former. First-answer/race tests: `loading-fixed.log`; local native interaction results: `local-journey.xcresult` (repro) and `local-journey-fixed.xcresult` (fix). Final integration, focused corrections and build results are recorded below.

The launch uses the standard storyboard resource path described in [Apple’s launch-screen guide](https://help.apple.com/xcode/mac/current/en.lproj/dev765148f31.html), with `UILaunchStoryboardName` and exported local assets. No signing, entitlements or external launch-store capability changed.

Full integration via `./scripts/ios-test.sh`: 458 declared screen/state/default+AX3 render combinations passed (rendering smoke, not automatic visual equivalence). XCTest unit suite: 53 tests, 6 opt-in skips, 1 failing geometry test; Swift Testing: 838 tests, 1 failing fixture test; UI suite: 44 tests, 40 opt-in skips, 4 passed including cold signed-out launch and recovery. Two distinct failures were investigated: the request identity fixture assertion omitted the already-seeded booking request, and a card's intrinsic width rounded up one pixel. The fixture now verifies the original ID set plus exactly two new IDs; the card accepts its parent's width with `minWidth: 0` and the strict 320 pt assertion is unchanged. Focused rechecks passed: all 16 sandbox/loading tests (`integration-recheck.log`) and default/AX3 geometry (`card-geometry.log`). The passing full matrix is reused; no claim is made that the original full command was green.

Final local interaction follow-up passed (`final-local-journey.xcresult`): standalone Grooming loading→release reveals New Request and the request cards; Home's corrected capped greeting at AX3 was inspected (`home-ax3-final.jpg`). Launch routing's bootstrap/session/profile/loading/error leaves were reviewed; runtime cold signed-out/recovery coverage is the UI suite above. Debug compilation passed via `./scripts/ios-build.sh` (`final-build.log`). The existing 46 opt-in skips require remote fixtures or explicit interactive capture and are not an executed remote acceptance claim; this delta changes no backend contract.

Final builds and repository gates: Debug (`final-build.log`) and Release (`release-build.log`) both succeeded on the task Simulator. Final `./scripts/preflight.sh` passed, including UI audit (145 findings, existing 82-entry baseline unchanged) and source/backend safety contracts. Boundary/UI-audit behavior tests previously passed 21/21 and remain applicable. Full context hygiene and staged diff review accompany the completion commit. The original rule-document edits, local signing configuration and frozen prototype/design trees remain outside this task's commit. No D1–D6 question remains unresolved.
