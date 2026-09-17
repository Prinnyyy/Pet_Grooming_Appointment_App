# Paste-ready Figma Make Prompt

```text
Design three exploratory iPhone concepts for the Beckon pet-grooming app's production Groomer Schedule / Daily Agenda screen. This is a visual and interaction exploration only. Do not write production code, do not change the formal Figma Design file, and do not invent product capabilities.

Use these attached references:
- current-groomer-schedule.png: current production-derived structure reference
- calibrated-normalized-default.png: approved default calibration
- calibrated-normalized-xl.png: approved Accessibility XL calibration
- customer-home-brand-reference.png: Beckon Customer brand reference
- pet-selection-brand-reference.png: Beckon form and selection brand reference

VISUAL SYSTEM
Use the approved “Beckon Warm Utility System”: warm off-white background, muted mint/teal primary brand color, white solid surfaces, soft borders and restrained shadows, one consistent generous radius scale, SF Pro semantic typography, SF Symbols semantics, pet imagery/paw treatment, and measured emotional warmth. Groomer screens share the Customer design language but use higher density, smaller headers, less decoration, and stronger operational hierarchy. Do not make this look like an enterprise dashboard, generic SaaS, or plain system-default app. Status color is limited to a small text-and-icon badge or timeline marker; never use a saturated full-card status background.

PRODUCTION CONTRACT
This is the Schedule tab root for an authenticated Groomer. It sits in a native five-tab structure: Home, Requests, Schedule, Messages, Account. Schedule is selected. The page is a vertically scrolling daily agenda with a date selector, selected-day summary, chronological appointments, pull-to-refresh semantics, pagination when more data exists, and native bottom safe-area clearance.

Production appointment states are only Confirmed, Completed, Cancelled by customer, Cancelled by groomer, and Unknown fallback. The active daily timeline filters out cancelled bookings, so the visible fixture rows are Confirmed or Completed. Do not invent Upcoming, Checked In, In Progress, or Start Service states.

Each visible appointment can open Booking Detail. Message is a real row action. Complete is a real action only when the booking is Confirmed and the user is a Groomer. Cancel is available for Confirmed bookings in Booking Detail, not as a permanent full-width Schedule action. The currently implemented detail action lacks a confirmation dialog, but the approved future design requires confirmation; annotate this distinction instead of claiming it already exists. Check In and Start Service do not exist. Do not add drag-to-reschedule, maps routing, staff assignment, payments, calendar sync, travel-time calculation, or conflict detection.

Travel Buffer has no production model, repository field, Store logic, UI, fixture, or test. Do not render a Travel Buffer as real schedule data. You may add an annotation outside the product UI that says “Travel Buffer — Not implemented; product decision required.”

DISPLAYED DATA
Date selector and selected day; appointment count; next start; total booked duration; start/end time; pet name; breed/species plus service; Customer reference code; Mobile/Studio; status. Customer full name and avatar are unavailable. Street address exists only for Booking Detail and must not be promoted into the list without approval.

Use exactly this data in every concept:
Selected date: Saturday, Aug 22.
Day strip: Thu 20, Fri 21, Sat 22, Sun 23, Mon 24, Tue 25, Wed 26.
Summary: 3 appointments; Next 9:00 AM; 4h 45m booked.
1) 9:00–11:00 AM; Mochi; Poodle · Full Groom; Confirmed; Customer ref 123E4567; Mobile.
2) 12:00–1:15 PM; Princess Penelope Buttercup; Bernese Mountain Dog · Deshedding, Bath, Nail Trim & Coat Conditioning; Confirmed; Customer ref A11CE204; Studio.
3) 3:00–4:30 PM; Luna; Domestic Longhair · Bath & Brush; Completed; Customer ref C0FFEE12; Mobile.
State-spec annotation only: Cancelled by customer.
Detail-only long-address stress value: 1847 West Dravus Street, Apartment 12B, Seattle, Washington 98199.

CREATE THREE CONCEPTS
1. Balanced Operations: balanced summary, date navigation, appointment objects, and restrained real actions; evolve the approved normalized calibration.
2. Agenda First: time is the dominant continuous scan rail, but remain a native scrolling iPhone agenda rather than a desktop calendar grid.
3. Compact Schedule: highest useful Groomer density while preserving touch size, status clarity, pet/service priority, content-driven height, and Beckon warmth.

For each concept create two 393pt-wide frames: Default and Accessibility XL. Use identical business content across all six frames. Also show or link state samples for initial Loading, selected-day Empty, and persistent Error with Try Again.

INFORMATION PRIORITY
Primary: start time, pet name, status.
Secondary: end time, breed/species plus service, Mobile/Studio.
Tertiary: customer reference, day summary, reminder warning, disclosure, Message, eligible Complete.
Never truncate pet name, service, status, selected date, primary feedback, or action labels. Full address, price, IDs, audit metadata, and review belong in detail. Keep chronological ordering.

ACCESSIBILITY
Every target is at least 44×44pt. Use content-driven heights. Status must include text plus icon/shape, not color alone. Accessibility XL must visibly reflow rather than scale down: allow multiline text, move status to a new row, stack actions vertically, and let cards grow. Do not use minimumScaleFactor for primary content. Keep all scroll content above the bottom TabView and safe area. The last appointment and Load More must be fully reachable. VoiceOver order per row: start/end time, pet, breed/service, status, customer reference/location, actions. The row announces that it opens details while Message and Complete remain separate controls. Respect Reduce Motion and Increase Contrast.

DELIVERABLE
Produce a clearly labelled comparison board for the three concepts and their Default/Accessibility XL frames. Add short annotations for information hierarchy, adaptive behavior, SwiftUI feasibility, and any unresolved product decision. Use native-iOS-feasible patterns that can later be rebuilt with NavigationStack, TabView, ScrollView/LazyVStack, semantic Font, ViewThatFits/AnyLayout, safeAreaInset, and the approved Beckon Figma components. Do not output web-only interactions or implementation code.
```
