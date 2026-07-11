# Information Hierarchy

## Default density

1. **Primary:** start time, pet name, appointment status. These are the schedule's scan anchors.
2. **Secondary:** end time, breed/species plus service name, Mobile/Studio.
3. **Tertiary:** customer reference, selected-day summary, reminder notice, navigation disclosure, Message and eligible Complete actions.

Suggested semantic hierarchy: navigation Large Title/Title 1 for `Schedule`; Headline for pet; Headline or tabular emphasized Callout for time; Subheadline for service; Caption/Footnote for customer reference, location, end time, and summary labels; Caption Emphasized for the status badge. These are semantic roles, not fixed pixel heights.

## Accessibility XL

- Keep time, pet, status, and service visible in that reading order.
- Move the badge to its own row when the horizontal composition no longer fits.
- Stack Message and Complete vertically; each remains at least 44pt high.
- Allow appointment rows and day summaries to grow naturally.
- A compact date control may horizontally scroll, but its selected date must remain explicit to VoiceOver.
- Customer reference and location can move below the service. They must not collide with actions.

## Wrapping and truncation

- Never truncate: pet name, service name, status text, selected date, primary error/empty message, action labels.
- May wrap: pet name, breed/species + service, customer reference + location, long reminder notice.
- May use one line only when the full value remains available through accessibility: formatted time, short Mobile/Studio label.
- May move to detail if space is constrained: full address, price, booking/request/offer references, creation metadata, cancellation/completion metadata, review, groomer business address.
- The customer reference currently has no more human-friendly source; do not invent a name.

## Scanning rhythm

- Align start times consistently as the left-side anchor at default density.
- Use status as a small text-and-icon badge, never a full-card fill.
- Preserve chronological order from `sortedByScheduledStart(ascending: true)`.
- Separate appointments through spacing/dividers and content grouping rather than strong color blocks.
