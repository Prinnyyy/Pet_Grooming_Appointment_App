// The review a customer writes once a grooming is finished: the form, the fit outcome per pet, the focus target and the keyboard
// presentation (S-089: lived in the snapshot of Features/Bookings/BookingsView.swift).
import SwiftUI
import UIKit


nonisolated enum GroomingReviewFocusTarget: String, Hashable {
    case content = "bookings.review.content.container"
}

nonisolated enum GroomingReviewKeyboardPresentation {
    static let contentFocusTarget = GroomingReviewFocusTarget.content.rawValue
}

struct GroomingReviewForm: View {
    let booking: Booking
    let store: BookingsStore
    let accent: BeckonPrimaryButtonStyle.Accent
    @State private var rating = 5
    @State private var content = ""
    @State private var fitOutcomeSelections: [BookingReviewPetFitOutcomeSelection]
    @FocusState.Binding var focusedTarget: GroomingReviewFocusTarget?

    init(
        booking: Booking,
        store: BookingsStore,
        accent: BeckonPrimaryButtonStyle.Accent,
        focusedTarget: FocusState<GroomingReviewFocusTarget?>.Binding
    ) {
        self.booking = booking
        self.store = store
        self.accent = accent
        _focusedTarget = focusedTarget
        _fitOutcomeSelections = State(initialValue: [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("How was it?")
                    .font(DesignTokens.Typography.Expressive.title)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(1...5, id: \.self) { value in
                        Button { rating = value } label: {
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .font(DesignTokens.Typography.Expressive.display)
                                .foregroundStyle(DesignTokens.Colors.ratingStar)
                                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                        }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                        .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rating")
                .accessibilityValue("\(rating) of 5 stars")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: rating = min(5, rating + 1)
                    case .decrement: rating = max(1, rating - 1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier("bookings.review.rating")
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                TextEditor(text: $content)
                    .focused($focusedTarget, equals: .content)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .beckonFormField()
                    .accessibilityLabel("Review text, optional")
                    .accessibilityIdentifier("bookings.review.content")

                Text("Optional review text, up to 2,000 characters.")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .beckonKeyboardFocusTarget(
                GroomingReviewKeyboardPresentation.contentFocusTarget
            )

            if !fitOutcomeSelections.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Pet fit notes")
                        .font(DesignTokens.Typography.Expressive.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    ForEach($fitOutcomeSelections) { $selection in
                        GroomingReviewFitOutcomePicker(selection: $selection)
                    }
                }
                .disabled(store.reviewContexts[booking.id] == nil)
            }

            if store.loadingReviewContexts.contains(booking.id) {
                DesignInfoLine(systemImage: "hourglass", text: "Loading service details…")
            } else if let error = store.reviewContextErrors[booking.id] {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(error).font(DesignTokens.Typography.Expressive.chip)
                    Button {
                        Task { await store.loadReviewContext(for: booking) }
                    } label: { DesignQuietAction(title: "Retry service details", systemImage: "arrow.clockwise") }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                        .accessibilityIdentifier("bookings.review.retry-context")
                }
            }

            Button {
                Task {
                    await store.createReview(
                        for: booking,
                        rating: rating,
                        content: content,
                        petFitOutcomes: fitOutcomeSelections.selectedOutcomes
                    )
                }
            } label: {
                DesignActionLabel(title: store.isSubmittingReview ? "Submitting review…" : "Submit review", systemImage: "star.bubble.fill")
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill))
            .disabled(store.isSubmittingReview || store.reviewContexts[booking.id] == nil)
            .accessibilityIdentifier("bookings.review.submit")
        }
        .disabled(store.isSubmittingReview)
        .designCardBody()
        .task(id: booking.id) { await store.loadReviewContext(for: booking) }
        .onChange(of: store.reviewContexts[booking.id]) { _, context in
            guard let context else { return }
            let previous = fitOutcomeSelections
            fitOutcomeSelections = context.signals.map { signal in
                BookingReviewPetFitOutcomeSelection(signal: signal,
                    outcome: previous.first(where: { $0.signal == signal })?.outcome)
            }
        }
    }
}

private struct GroomingReviewFitOutcomePicker: View {
    @Binding var selection: BookingReviewPetFitOutcomeSelection

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(selection.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(selection.groupTitle)
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            Menu {
                Picker("Pet fit outcome", selection: $selection.outcome) {
                    Text("Skip").tag(nil as BookingReviewPetFitOutcome?)
                    ForEach(BookingReviewPetFitOutcome.allCases) { outcome in
                        Text(outcome.title).tag(Optional(outcome))
                    }
                }
            } label: {
                Label(selection.outcome?.title ?? "Skip", systemImage: "chevron.up.chevron.down")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            }
            .buttonStyle(BeckonLedgePressStyle(.card))
            .accessibilityLabel("\(selection.title), \(selection.groupTitle)")
            .accessibilityValue(selection.outcome?.title ?? "Skip")
            .accessibilityIdentifier(
                "bookings.review.fit.\(selection.signal.id)"
            )
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.iconTileFill)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.input,
                style: .continuous
            )
        )
    }
}
