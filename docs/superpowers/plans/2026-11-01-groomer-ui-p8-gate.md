<!-- task-artifact
task: T-436
status: completed
type: plan
-->

# Handoff 4 P8 — integration gate

Reads: sections 0, 8, 9, 10 and named state previews in section 7. P2-P7 adopted under D-069; protected prototype/governance/signing material remains untouched.

- Reproduce named module states in owned groomer host on existing local dependencies.
- Retire the design adoption flag and obsolete shared branches, retaining current navigation/cache/launch/auth/data plumbing.
- Focused runtime checks for navigation, presentations, forms, error/load state, AX layouts and core actions; one final full regression, Release, preflight/audit/hygiene. User owns visual sign-off.
- Report section 10, validated scoped commit/push and completion state.

## Section 10 report

Completed. No protected prototype, governance or signing file was changed by this package.

### Port map and retained production plumbing

| Production scope | Twin / change |
|---|---|
| `BeckonActionPrimitives`, `BeckonLayoutPrimitives`, `BeckonModuleImage`, `BeckonFormPrimitives` | Corresponding handoff shared primitives: remove obsolete adoption-switch/legacy appearance branches; keep real role-specific content and action availability |
| `BeckonCustomerDesign` | Runtime switch retired; DEBUG-only always-true accessor keeps protected prototype sources compiling without editing them |
| `ChatView` ⚑ | Corresponding prototype's adopted surfaces now shared by both roles; retain T-426/T-427 cached thread, Updating header, direct conversation resolution, composer and production navigation; no thread skeleton |
| Both tab shells/navigation owners, `BeckonTabBarOwner`, `DesignKit` ⚑, shared settings row | D3 path reset now also resets local destination bindings and shortcut/photo pushes. No root generation identity, Store reconstruction or UIKit forced pop |
| Home/account/notifications/request/chat roots | Subscribe their local destination bindings to outgoing-tab reset; typed customer routes and incoming handoff targets retained |
| Auth, booking/reminder, customer page and owned host call sites | Remove adoption-flag setters only; launch/auth/recovery/reminder/cache/business contracts retained |
| `GroomerOfferFormState` | Preserve seconds of an unchanged initial server/window instant; a manually edited wall minute still resolves normally and DST repeated time still requires an explicit occurrence |
| `FlowSandbox/Groomer/GroomerModulePreviews`, `GroomerAppFlowPreviews`, `GroomerChatCardPreviews`, existing host/session | Reproduce named handoff module, booking-ticket and setup states on production Views and existing isolated memory dependencies. Add explicit paused Home and maximum-AX samples; fix loading Requests' initial tab and mock timing-version/current-zero-buffer metadata |
| Specs, screen inventory, navigation standard, audit baseline and affected tests | Record final role adoption, reset-aware shared links and service-only availability; remove stale findings only, no new audit exemption |

Self-review found that clearing a NavigationPath alone missed `navigationDestination` bindings and opaque links. The runtime Home → bell → Schedule → Home sequence reproduced the defect. The shared reset observer now handles both count changes and reappearance after inactivity; destination links participate without rebuilding roots. Customer profile/debug and fallback notification pushes use the same rule. Shared shortcut tiles and settings rows retain their existing action-based overloads.

### Decisions D1–D10

D-068/D-069 remain authoritative. D1: bridged UIKit role trait and presentation carrier. D2: user-approved service-only migration and explicit zero future snapshots, retaining actual overlap/hours/time-off/quota/notice guards; inert Auto-ready removed, compatibility field kept. D3: user-approved outgoing-root reset with stable roots/Stores. D4: only already-authorized immutable booking pet/visit snapshots. D5: bounded next-four chronological Home read; paused opens Account root, missing hours opens Availability. D6: unanswered Matches and stage-grouped Offers, earlier closed by default. D7: T-428 remains independent and unexecuted. D8: keep current chat Updating/cache/no skeleton. D9: semantic tokens and documented adopted shared kit, no broad audit exemption. D10: pet owner in user-facing role selection. The user's later clarification confirms that the validated handoff UX supersedes legacy presentation/process rules.

### Verification and limits

- Focused serial Simulator run passed **17 tests** (5 XCTest + 12 Swift Testing), including original-time precision, manual edit, repeated-time occurrence, exact-window submission, navigation and role/carrier geometry. The preceding parallel attempt built but XCTest failed before tests with a missing cloned test bundle; serial execution resolved the test-host problem.
- Bounded local rendering initially passed **54** state/size samples. Expanded final samples and final regression results are recorded below when complete. Rendering checks first-viewport presence, not visual equivalence or animation smoothness.
- Semantic Simulator taps use the real groomer shell/Views/Stores with memory repositories, never live account data. The completed opt-in walk passed **1/1** and was explicitly finished after 236 seconds. Submitted the unchanged default Mochi quote ($95, exact requested interval), observed Customer to answer, confirmed withdrawal and observed the new-offer form again; edited/saved an existing service through its sheet; opened Availability/time-off, typed a title, added it to the draft; confirmed unsaved-change discard; opened Fit signals and returned to Account. The availability save correctly surfaced a toast because the original mock lacked timingVersion; the mock is now aligned, with a focused save assertion. One attempted Evidence tap hit the tab bar because the row was outside the visible viewport; it is not counted as successful Evidence navigation.
- Earlier diagnostic UI runs timed out while investigating the navigation/precision bugs; they are retained as failed diagnostics, not counted as passes. In the corrected navigation diagnostic, Home/bell departure returned Home root; Home booking → Schedule appointment → Message your customer opened the exact cached conversation/ticket; returning Schedule and Messages showed agenda/list roots. No thread skeleton returned.
- The full integration run exposed a customer notification→appointment→Message smoke failure: a parent accessibility identifier was masking the shared Message button. Both role appointment containers now group children explicitly; the original smoke assertion remains unchanged and will be rerun, rather than accepting a renamed/missing control. Final shortcut/customer local-binding resets were completed during diff review; their affected tests are rerun against the final binaries.
- Source/boundary/color assertions **17/17**, preflight, UI audit and full document hygiene passed before final result collection. P7's deployed metadata, authenticated admission/Save races, restoration and empty migration dry run remain valid and were not repeated.
- User owns visual sign-off: exact prototype resemblance, animated bar/pop timing, full-page largest-text reading and VoiceOver operation are not asserted from still rendering or semantic taps. No device/store/signing gate was added.

Final integration recovery: the standard full run recorded 911 passed, 47 opt-in skipped, one customer Message identifier failure and four cloned-runner bundle startup errors. Its scheduling log identifies exactly four unexecuted XCTest groups: AuthenticationBrandRenderingTests, GroomerModuleRenderingTests, GroomerOfferTimingRenderingTests and UIColorImplementationSnapshotTests. Keep that failed result; do not report it as a green full run. The final affected serial run passed **24/24**, including all three original customer navigation smoke tests, the mock availability save, role/dialog/button geometry, both navigation owners, keyboard layouts and **72** first-viewport render samples. Subsequent serial execution covers the other unexecuted groups. The existing test script now adds only `-parallel-testing-enabled NO` to avoid these repeated local cloned-bundle failures; shell syntax checked, no new harness or scheme.

The recovered timing-render group exposed stale fixtures: both UI setup paths inherited a June request expiry, so the new clock-aware page correctly showed a closed request and no offer form. Only those live-form scenarios now supply future expiry/service dates. Historical default fixtures, clock/expiry rules and all form/cancellation/timezone assertions remain unchanged. This is test-state alignment, not a date/validation bypass. Final results: the unchanged remaining groups passed AuthenticationBrandRenderingTests **3/3** and UIColorImplementationSnapshotTests **8/8**; updated live timing scenarios passed **7/7**, including cancellation/return, draft preservation, missing/confirmed service zone, device-environment changes and matching checks. Deduplicating the full run with ordered recoveries yields **931 passed, 47 opt-in skipped, 0 unresolved failures** across 978 test identities (parameterized invocations counted separately by Xcode). The isolated completed semantic walkthrough remains separate evidence, not a replacement for skipped live TestOps runs. Debug final test builds, preflight, boundary/color assertions, UI audit, shell syntax and full hygiene passed. Release Simulator build passed (arm64 and x86_64); the DEBUG-only adoption compatibility accessor is excluded from shipping. It retains non-blocking actor-isolation warnings in the existing Portfolio and Customer Pet PhotosPicker labels and the standard no-AppIntents metadata warning; no warning-free claim is made. No further production change followed final validation. Final full hygiene and staged whitespace/scope review precede the authorized T-436 completion commit/push on main; Git owns the completion hash. No unresolved handoff decision or implementation blocker remains; T-428 and T-157 retain their independent status.
