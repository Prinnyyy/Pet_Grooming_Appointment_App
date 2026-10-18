# UI Consistency Debt

Latest source check: 2026-10-18, authentication brand correction T-416.

This inventory describes remaining source findings, not unfinished functionality. [UI Code Governance](UI_CODE_GOVERNANCE.md) owns rule meanings, severity, commands and baseline lifecycle.

## Current Check

The Feature ratchet reports **130 findings**, including **100 baselined findings** and 30 unbaselined review warnings. There are zero new errors, zero stale baseline entries and zero UI012-014 color/status violations. T-416 pruned nine obsolete entries after moving brand artwork to its explicit DesignSystem boundary and correcting wordmark scaling. The lower Feature count is not proof of fewer visual defects; the artwork still requires rendered review.

| Rule | Count |
|---|---:|
| UI001 fixed typography | 6 |
| UI002 platform typography | 37 |
| UI004 numeric spacing | 2 |
| UI005 numeric radius | 9 |
| UI008 low text scaling | 3 |
| UI101 fixed geometry review | 63 |
| UI102 layout repair review | 10 |
| UI003, UI006-007, UI009-014, UI201 | 0 |

## Concentration

| Feature area | Findings |
|---|---:|
| Groomer | 57 |
| Customer | 28 |
| Auth | 9 |
| Bookings | 18 |
| Chat | 18 |

Largest files: BookingsView and ChatView (18 each), GroomerRequestsView (10), GroomerHomeView (8), AuthenticationView (7). These are source candidates, not automatically confirmed visual defects or a new execution queue.

## Accepted Scope

Customer Home, Requests dashboard, Offers and Request Detail passed the strict zero-error audit for this migration. Color/status constraints are enforced across all Features and by shared-color source tests. Fixed media, icon and decorative geometry remains visible as review warnings rather than silently entering the baseline.

The T-409 through T-415 [implementation plan](../superpowers/plans/2026-10-17-ui-color-implementation.md) owns acceptance evidence. Groomer workspace and Customer/shared UI acceptance were already handled by T-402/T-403; the old Q-104 deferral is not an active functional blocker. No unrelated broad typography or layout migration is authorized by this inventory.

## Historical Context

T-343 recorded 203 source findings; T-396 recorded 182. The former table mixed these two snapshots and its migration ordering predated the completed Groomer work. Git retains those details; current counts above replace them, without treating a reduced count as proof of runtime accessibility.
