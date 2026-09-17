# Accessibility Contract

1. Every interactive target is at least 44×44pt, including date chips and row actions.
2. Appointment, summary, empty, and error surfaces use content-driven height.
3. Pet name, service, status, date, and action labels cannot be truncated.
4. Status always combines text with an icon/shape; color alone is insufficient.
5. Accessibility XL may recompose horizontal rows vertically.
6. Do not use `minimumScaleFactor` as the primary solution for business text.
7. Scroll content must clear the native bottom `TabView` bar and safe area; the last appointment and Load More must be fully reachable.
8. Horizontal date navigation must remain scrollable and expose selection semantically.
9. Test the long pet name `Princess Penelope Buttercup`, the long service name, and the long address fixture even though address remains detail-only.
10. A row's VoiceOver order is: start/end time → pet → breed/service → status → customer reference/location → available actions.
11. The entire row announces that it opens booking details. Nested Message/Complete controls must remain separately discoverable and must not create ambiguous duplicate activation.
12. At XL, keep the primary task operable without hidden hover, swipe-only, or precision gestures.
13. Reduce Motion: avoid required parallax, auto-scrolling, spring-only status communication, or animation-dependent transitions; use short fades or no animation.
14. Increase Contrast: strengthen semantic text/border contrast while retaining the same hierarchy; do not compensate with large saturated status fills.
15. Dynamic Type must not allow action bars, tab bars, badges, or fixed frames to cover content.
16. Completed/cancelled meaning and mutation success/failure must be announced to assistive technologies.
