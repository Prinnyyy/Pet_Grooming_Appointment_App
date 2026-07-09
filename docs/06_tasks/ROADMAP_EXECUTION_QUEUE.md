# Roadmap Execution Queue

Last verified: 2026-07-09.

Purpose: turn `ROADMAP.md` candidates into adoptable execution packages. This file does not assign `T-###` IDs or task status. When a package is adopted, use the next task ID from `TASK_LEDGER.md`, keep one primary package per run, and close status in the ledger/worklog.

## Selection Rules

- Start with the first unblocked M1/M2/M3 package unless the user names another item.
- Split a package if it touches Supabase plus visible SwiftUI, or if validation risk becomes Deep.
- Do not start blocked packages until the blocker is cleared and recorded.
- Keep release work behind M1-M4 exit evidence.

## Queue

| Order | Roadmap | Proposed package | Mode | Scope | Primary validation |
|---|---|---|---|---|---|
| Q-01 | R-005 | Private image contract audit | Deep | Verify buckets, RLS, signed/download paths, cache expectations, and current broken/placeholder image surfaces. | Supabase read-only checks, `git diff --check` |
| Q-02 | R-005 | Shared private image renderer | Standard | Add/reuse a single authorized image loading path with local fallback and safe cache behavior. | Targeted tests, `./scripts/ios-build.sh` |
| Q-03 | R-005 | Customer private images | Standard | Render customer pet avatars, pet detail photos, request photos, and empty/error states through the shared renderer. | Targeted tests, simulator spot check, iOS build |
| Q-04 | R-005 | Groomer private images | Standard | Render groomer avatar, portfolio photos, and service/profile image surfaces through the shared renderer. | Targeted tests, simulator spot check, iOS build |
| Q-05 | R-006 | Request wizard persistence decision | Standard | Decide whether draft request input persists, is removed, or is scoped per session; implement the chosen UX/data behavior. | Store tests, iOS build |
| Q-06 | R-007 | Email deep-link and SMTP design | Deep | Define production email provider, redirect URLs, templates, secrets, and app-link behavior. | Docs/config review, no remote write without approval |
| Q-07 | R-007 | Email deep-link implementation | Deep | Wire approved SMTP/deep-link behavior and verify auth/email flows. | Supabase validation, targeted iOS tests |
| Q-08 | R-008 | Realtime foreground chat | Standard | Add foreground message refresh/realtime subscription without attachments/read receipts. | Chat tests, simulator two-role smoke, iOS build |
| Q-09 | R-009 | APNs dispatch deploy | Deep | Deploy T-157 dispatcher after Apple Developer credentials and APNs secrets exist. | Edge deploy validation, push smoke |
| Q-10 | R-010 | Privacy and Support URLs | Quick | Provide production-ready URLs and update app metadata/docs references. | Link check, `git diff --check` |
| Q-11 | R-011 | Crash and funnel events | Standard | Add minimal privacy-safe crash/funnel instrumentation for release evidence. | Unit checks, iOS build |
| Q-12 | R-012 | Accessibility and copy audit | Standard | Audit MVP screens for labels, Dynamic Type, contrast, and confusing marketplace copy. | Accessibility-focused simulator pass, iOS build |
| Q-13 | R-013 | Performance and network resilience | Standard | Add targeted loading, retry, cancellation, and image/network resilience improvements. | Focused tests, iOS build |
| Q-14 | R-014 | Test expansion | Standard | Expand Store/model/state/UI coverage around marketplace, image, notification, and TestOps risks. | New focused tests, `./scripts/ios-test.sh` if known blocker is resolved |
| Q-15 | R-015 | Release readiness dry run | Deep | Run E2E/security/release gates and prepare TestFlight/App Store evidence after M1-M4 exits. | TestOps, advisors, build/test gates |
