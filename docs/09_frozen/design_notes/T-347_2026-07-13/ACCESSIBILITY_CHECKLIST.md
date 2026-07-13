# Accessibility Checklist

For UI changes, check:

- [ ] Buttons have meaningful labels.
- [ ] Images have accessibility labels or are marked decorative.
- [ ] Text remains readable with Dynamic Type.
- [ ] Color is not the only state signal.
- [ ] Tap targets are reasonably sized.
- [ ] Loading and error states are accessible.

## Current Project Checks

- Semantic text tokens should keep at least 4.5:1 contrast on `DesignTokens.Colors.surface`.
- Primary action text should keep at least 4.5:1 contrast against customer and groomer primary backgrounds.
- Repeated tappable cards should expose one clear accessibility label/value/hint instead of forcing VoiceOver through every visual subview.
- Decorative avatars/icons should be hidden from accessibility when the parent element provides the readable summary.
- Booking and schedule errors should use role-specific copy so customer bookings and groomer schedule failures are not confused.
