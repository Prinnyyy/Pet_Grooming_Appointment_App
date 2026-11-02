<!-- task-artifact
task: T-434
status: completed
type: plan
-->

# Handoff 4 P6 — Account and setup

Reads: section 3 items 10, 11, 12; D2 (Availability, approved); D10; appendix A P6. User-approved UI/UX takes precedence over older flows (D-069).

Port Account and its six pages, pinned controls/fit vocabulary and role onboarding. Reuse Store mutation/address/receipt protections; separate load and action failures. Auto-ready removal approved; compatibility field retained. Timing backend is coordinated in P7. Focused acceptance, report and continue P7.

## Section 10 report

Completed.

Port map: `GroomerAccountView`, shared `GroomerAccountParts` and `GroomerFitParts` come from their named P6 twins. Existing Profile Form, Services, Availability, Fit Signals/Evidence, Portfolio and size-range files receive the corresponding new view bodies, retaining their public names/focus APIs and the real Store. Avatar encoder/photo presentation helpers remain production-owned. `GroomerProfileManagementView` is now a thin compatibility entry; `GroomerTabView` supplies its retained profile Store directly to Account. `RoleOnboardingView` adopts the new layout and selected-role accent. `AccountDangerActionsSkeleton` adds only `showsDelete`; production customer deletion/reauthentication behavior is preserved. No prototype/fixture is used at runtime.

Behavior: new Account hierarchy, shortcuts, pinned save bars, service/time-off sheets, portfolio grid, bounded fit chips, confidence evidence and role choices follow the approved design. Auto-ready UI is removed per the user's explicit answer; the compatibility field remains. “Pet owner” is the shared onboarding wording (D10). Main Account reveals core/cached identity without waiting for optional photos. Existing atomic availability revision/reconciliation, draft preservation, address confirmation, upload/delete protection and fit limits remain. Separate Store read/action error sources prevent load cards and action feedback from leaking into each other; sheet form errors retain their prototype-owned inline location. Timing SQL/model cleanup is coordinated in P7, not claimed deployed here.

Validation: Debug Simulator build passed. Initial focused run **92/93** passed; the new validation test incorrectly assumed an inactive empty draft must fail. Corrected it to incomplete activation (the existing rule); the follow-up profile Store suite **59/59** passed, zero skips, reusing unchanged passing layout/entry/core-first evidence. New tests distinguish read failure from save/validation failure. Updated obsolete buffer-keyboard coverage to the new profile field and time chip, role wording, Account sign-out and release-link source ownership. Node boundary/source/audit **29/29**, preflight, UI audit and hygiene passed. The final staged check also flagged one trailing blank line in the new FitParts file, corrected in the following integration slice. Twenty-six resolved legacy baseline entries pruned, no widened rule exemption. Evidence `/tmp/beckon-handoff4/p6-*`. Integration taps/visual limits remain P8/user inspection. Release Simulator build passed.

D1/D3–D9 retain their recorded answers; D2 is approved and P7 follows immediately, D10 implemented. Protected prototype and user governance/signing changes remain untouched.
