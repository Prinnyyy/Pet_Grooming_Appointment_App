# UX Rules

## General

- Every async action needs loading feedback.
- Every failed backend action needs visible error feedback.
- Every empty list needs an empty state.
- Avoid forcing users to understand backend states.
- Avoid deep navigation for primary actions.

## Forms

- Validate required fields before submission.
- Preserve user input after recoverable errors.
- Show clear confirmation after success.

## Marketplace/Booking-Style Flows

- Avoid duplicate submissions.
- Disable submit buttons while requests are in flight.
- Make status transitions explicit.
- Do not show impossible actions for the current state.
