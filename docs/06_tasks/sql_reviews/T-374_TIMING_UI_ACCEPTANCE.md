# T-374 Timing UI Acceptance

Status: original WP-03 changed-flow evidence collected, 2026-09-08; package closeout pending. Owner: [functional reliability plan](../../superpowers/plans/2026-09-07-functional-reliability-task-plan.md).

## Evidence And Boundaries

Tests host the real SwiftUI views and Stores with local repository/provider adapters. Native control events, actual Simulator menu/button taps and submitted draft assertions verify the client boundary. They do not prove remote writes; see [backend acceptance](T-374_TIMING_BACKEND_ACCEPTANCE.md).

| Requirement | Verified evidence |
|---|---|
| Mobile zone, repeated hour, elapsed duration | Actual occurrence/Submit taps send 05:30Z-06:30Z and 06:30Z-07:30Z. `/tmp/beckon-t374-offer-live-selection-green.log`, `/tmp/beckon-t374-offer-live-second.log`. End labels include their own offset. |
| Destination source and retry | NY preference bounds retained; Retry resolves LA destination and retains duration 60/price 127. `/tmp/beckon-t374-destination-live-retry.log`; inspected attachment. Source/retry evidence, not a remote destination booking. |
| Missing zone | No device fallback/date input/submission; customer replacement guidance fits. `/tmp/beckon-t374-offer-missing-recovery.log`; inspected attachment. |
| Spring gap | 2027-03-14 02:30 remains visible with invalid-time feedback and disabled Submit. `/tmp/beckon-t374-offer-spring-input/9292E653-8F5C-4052-956E-76A208D3099E.png`. |
| Choice invalidation | Edit to 01:31 clears occurrence/end and disables Submit; reselecting sends 05:31Z-06:31Z with duration/price preserved. `/tmp/beckon-t374-offer-invalidation.log`. |
| Device environment | Tokyo timezone/Buddhist calendar/accessibility text do not change Gregorian wall input/duration. Actual Submit sends original NY 05:30Z-06:30Z. `/tmp/beckon-t374-compact-layout-retry.log`. |
| Initialization race | Navigation push/pop cancels first read, starts a second; late completion cannot overwrite start, duration 45 or price 127. `/tmp/beckon-t374-init-late-read.log`. |
| Wizard recovery/publication | Actual Cancel Outdated -> confirmation -> Create From Template -> Confirm Address -> Continue -> Review -> Publish. One cancellation, geocode called, confirmed LA zone, preserved pet/service and one new identity asserted. `/tmp/beckon-t374-wizard-complete.log`. Provider/network results are injected, not live Apple Maps/Supabase. |
| Layout | Known/unknown schedule and accessibility3 scroll/actions inspected; time/offset labels and controls readable. `/tmp/beckon-t374-scroll-actions-render.log`, `/tmp/beckon-t374-accessibility-combined.log`. Compact offer scrolls and actual Submit is reachable. |

## Integration

- Last production change: finite request-detail form uses VStack to avoid the observed lazy-layout/focus geometry loop. Initial hung run is not passing evidence; compact retry and subsequent submissions pass.
- Full regression: `/tmp/beckon-t374-final-integration.log`, underlying `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/ios-test.XXqoNKek4s`, TEST SUCCEEDED. Default UI: three executed, six environment-gated cases skipped; skipped cases are not acceptance evidence.
- Build: `/tmp/beckon-t374-final-build.log`, BUILD SUCCEEDED. AppIntents metadata-skipped warning is toolchain information.
- Optional interaction flags removed. Account-timezone settings are explicitly outside this task.

## Release Limits

System-keyboard-visible screenshot is NOT verified. Window-only attachments omit the system keyboard; Simulator frontend/input attempts still did not establish visibility. A primary-window experiment was reverted. Do not describe passing submissions as keyboard-visible proof. Carry this supplemental check into WP-14; it was added during execution, not an independent requirement of original WP-03. Original Wizard/offer interaction, timing, backend and normal integration gates are not waived.

Physical-device interruption, compatible-client distribution and the full two-role release matrix remain WP-14. Matching remains WP-04; fulfillment remains WP-06. These tests do not close those packages.
