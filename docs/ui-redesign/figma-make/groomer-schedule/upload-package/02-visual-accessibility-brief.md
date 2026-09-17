# Groomer Schedule — Visual and Accessibility Brief

## Beckon Warm Utility System

- Use a warm off-white page background, muted mint/teal primary brand color, and stable white content surfaces.
- Use soft borders, restrained shadows, a consistent generous radius scale, SF Pro semantic typography, and SF Symbols semantics.
- Express pet-care warmth through pet imagery or paw/avatar treatment, friendly copy, and measured decoration.
- Customer and Groomer experiences share one brand language and component system. Groomer composition is denser: smaller headers, tighter rows, fewer decorative elements, stronger time/status alignment, and clearer operational actions.
- Do not make Schedule look like an enterprise operations dashboard, generic SaaS product, or unbranded system-default screen.
- Status uses a small text-and-icon badge or timeline marker. Never use color alone or a saturated full-card status background.
- Cards represent complete business objects; do not turn every metric or line into a floating card.
- Preserve native iOS navigation and bottom-tab semantics beneath the Beckon visual layer.

## Accessibility and adaptive layout

1. Every interactive target, including date controls and row actions, is at least 44×44pt.
2. Appointment, summary, feedback, and action surfaces use content-driven height.
3. Pet name, service, status, selected date, primary feedback, and action labels cannot truncate.
4. Long pet names, long service names, customer references, and location content may wrap.
5. Do not use `minimumScaleFactor` as the primary solution for business text.
6. Accessibility XL must visibly recompose: horizontal content may become vertical, badges may move to a new row, actions may stack, and cards must grow naturally.
7. A horizontally scrolling date selector must keep selection clear visually and semantically.
8. Scroll content must clear the native bottom navigation and safe area. The final appointment and Load More must scroll fully above the tab bar.
9. Do not rely on hover, swipe-only, precision gestures, or animation to complete a core task.
10. Row VoiceOver order is start/end time → pet → breed/service → status → customer reference/location → actions.
11. The row announces that it opens Booking Detail. Message and eligible Complete remain distinct accessible controls without ambiguous duplicate activation.
12. Status, completion, cancellation, success, and failure require text or spoken meaning, not color alone.
13. Reduce Motion removes required parallax, auto-scrolling, and spring-dependent meaning; use short fades or no animation.
14. Increase Contrast strengthens semantic text and borders while preserving hierarchy and avoiding large saturated fills.
15. Dynamic Type must not let the bottom tab, action controls, badges, or fixed frames cover content.

Use the supplied Customer Home and Pet Selection images to preserve Beckon warmth, and the two normalized Schedule images for Groomer density and XL reflow. Treat them as references, not pixel dimensions to copy mechanically.
