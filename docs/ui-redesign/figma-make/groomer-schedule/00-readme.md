# Groomer Schedule — Figma Make Input Package

This package is the product and design contract for exploring the production `Groomer Schedule / Daily Agenda` screen in Figma Make. It does not authorize production code changes, formal Figma Design changes, or implementation work.

## Recommended order

1. `01-functional-contract.md` — production facts and forbidden inventions.
2. `02-information-hierarchy.md` — scanning and content priority.
3. `03-visual-brief.md` — approved Beckon visual direction.
4. `04-accessibility-contract.md` — layout and accessibility acceptance rules.
5. `05-content-fixtures.md` — one shared data set for every concept.
6. `06-concept-requirements.md` — required concept outputs.
7. `07-evaluation-rubric.md` — scoring and rejection criteria.
8. `08-figma-make-prompt.md` — paste-ready English prompt.

## References

| File | Source | Purpose |
| --- | --- | --- |
| `references/current-groomer-schedule.png` | Figma calibration Existing Reference `26:19`, previously reconstructed from the running production app | Current structure and shortcomings |
| `references/calibrated-normalized-default.png` | Approved frame `26:74` | Default-density baseline |
| `references/calibrated-normalized-xl.png` | Approved frame `26:136` | Accessibility XL baseline |
| `references/customer-home-brand-reference.png` | Approved frame `23:31` | Customer brand warmth reference |
| `references/pet-selection-brand-reference.png` | Approved frame `25:40` | Brand/form composition reference |

The first image is not a new Simulator capture from this task. It is the approved Existing Reference derived during the earlier Simulator-and-code calibration. The other four images are read-only exports of approved Figma frames. No formal Figma node was modified.

## Source-of-truth code

- `ios/Beckon/Beckon/Features/Bookings/BookingsView.swift`
- `ios/Beckon/Beckon/Features/Bookings/BookingsStore.swift`
- `ios/Beckon/Beckon/Features/Bookings/GroomerSchedulePresentation.swift`
- `ios/Beckon/Beckon/Core/Models/Booking.swift`
- `ios/Beckon/Beckon/Core/Repositories/BookingRepository.swift`
- `ios/Beckon/Beckon/Core/Infrastructure/Supabase/SupabaseBookingRepository.swift`
- `ios/Beckon/Beckon/Features/Groomer/GroomerTab.swift`
- `ios/Beckon/Beckon/Features/Groomer/GroomerTabView.swift`
- `ios/Beckon/BeckonTests/BookingFeatureTests.swift`
