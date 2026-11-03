import SwiftUI

private enum BookingReviewStarter: String, CaseIterable {
    case gentle, result, updates, punctual, finish, timing
    var title: String {
        switch self {
        case .gentle: "Gentle handling"
        case .result: "Great result"
        case .updates: "Clear updates"
        case .punctual: "On time"
        case .finish: "Uneven finish"
        case .timing: "Timing issue"
        }
    }
    func sentence(for pet: String) -> String {
        switch self {
        case .gentle: "Handled \(pet) gently."
        case .result: "\(pet)’s groom looked great."
        case .updates: "Communication was clear."
        case .punctual: "The appointment started on time."
        case .finish: "The finish looked uneven."
        case .timing: "The appointment timing could be better."
        }
    }
}

struct BookingReviewSheet: View {
    let booking: Booking
    let store: BookingsStore
    @Environment(\.dismiss) private var dismiss
    private var current: Booking { store.booking(withID: booking.id) ?? booking }
    private var draft: Binding<BookingReviewComposeDraft> {
        Binding(get: { store.reviewComposeDraft(for: booking.id) },
            set: { store.updateReviewComposeDraft($0, for: current) })
    }
    @FocusState private var writing: Bool

    var body: some View {
        VStack(spacing: 0) {
            BookingReviewHeading(context: "\(current.reviewPetName)’s \(current.appointmentServiceTitle.lowercased()) with \(current.partnerDisplayTitle(for: .customer))")
            ScrollViewReader { proxy in
                ScrollView {
                    BookingReviewFields(draft: draft, writing: $writing, petName: current.reviewPetName, isSubmitting: store.isSubmittingReview)
                        .padding(DesignTokens.Spacing.screenHorizontal)
                        .disabled(store.isSubmittingReview)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: writing) { _, focused in
                    if focused {
                        withAnimation(DesignTokens.Motion.reveal) {
                            proxy.scrollTo("review-input", anchor: .top)
                        }
                    }
                }
            }
            // One keyboard-safe layout owner: siblings resize with the sheet's safe area.
            // Do not add another composer inset or ignore the keyboard's safe area.
            VStack(spacing: DesignTokens.Spacing.sm) {
                if let error = store.errorMessage {
                    Text(error).font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.statusErrorText)
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                }
                if let error = store.reviewContextErrors[booking.id] {
                    Text(error).font(DesignTokens.Typography.Expressive.chip)
                    Button("Retry") { Task { await store.loadReviewContext(for: current) } }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                }
                BookingReviewSubmit(title: store.isSubmittingReview ? "Submitting…" : "Submit review") {
                    writing = false
                    Task {
                        let values = draft.wrappedValue
                        await store.createReview(for: current, rating: values.rating, content: values.content)
                        if store.booking(withID: booking.id)?.review != nil { dismiss() }
                    }
                }
                .disabled(store.isSubmittingReview || store.reviewContexts[booking.id] == nil || !current.canReview(for: .customer))
            }
        }
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .environment(\.beckonRole, .customer)
        .task(id: booking.id) { await store.loadReviewContext(for: current) }
    }
}

private struct BookingReviewHeading: View {
    let context: String
    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            Text("Review").font(DesignTokens.Typography.Expressive.section)
            Text(context)
                .font(DesignTokens.Typography.Expressive.supporting)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .foregroundStyle(DesignTokens.Colors.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal).padding(.top, DesignTokens.Spacing.lg).padding(.bottom, DesignTokens.Spacing.md)
    }
}

private struct BookingReviewFields: View {
    @Binding var draft: BookingReviewComposeDraft
    @FocusState.Binding var writing: Bool
    var petName = "Your pet"
    var isSubmitting = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 10) {
                Text("How was it?").font(DesignTokens.Typography.Expressive.title)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button { draft.rating = star } label: {
                            Image(systemName: star <= draft.rating ? "star.fill" : "star")
                                .font(DesignTokens.Typography.Expressive.glyphLarge)
                                .foregroundStyle(DesignTokens.Colors.ratingStar)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(BeckonGuardedPlainButtonStyle())
                            .accessibilityLabel("\(star) of 5 stars")
                    }
                }
                Text(["", "Disappointing", "Could be better", "Okay", "Good", "Excellent"][max(0, min(5, draft.rating))])
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
            }
            .padding(DesignTokens.Spacing.lg).frame(maxWidth: .infinity)
            .background(DesignTokens.Colors.customerTint, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card))
            .beckonLedge(.card)

            // Same section, inset field and choice-chip language as Request > Details > Notes.
            DesignSection(title: "Your review", systemImage: "text.bubble") {
                TextField("How did the groom go?", text: $draft.content, axis: .vertical)
                    .lineLimit(4...7).focused($writing)
                    .accessibilityIdentifier("bookings.review.content")
                .font(DesignTokens.Typography.Expressive.body)
                .beckonFormField()
                .disabled(isSubmitting)

                LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                    [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(BookingReviewStarter.allCases, id: \.self) { starter in
                        let selected = draft.content.contains(starter.sentence(for: petName))
                        DesignChoiceChip(title: starter.title, systemImage: selected ? "checkmark" : "plus", isSelected: selected) {
                            draft.toggleStarter(starter.sentence(for: petName))
                        }
                    }
                }
                if draft.content.count >= 1800 {
                    Text("\(draft.content.count) / 2,000")
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }.id("review-input")
        }
        .foregroundStyle(DesignTokens.Colors.textPrimary)
        .onChange(of: draft.content) { _, value in
            if value.count > 2000 { draft.content = String(value.prefix(2000)) }
        }
    }

 }

private struct BookingReviewSubmit: View {
    var title = "Submit review"
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            DesignActionLabel(title: title, systemImage: "star.bubble.fill")
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .accessibilityIdentifier("bookings.review.submit")
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal).padding(.vertical, DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.appBackground)
    }
}


struct BookingReviewEntry: View {
    let booking: Booking
    let store: BookingsStore
    @State private var isPresented = false
    private var current: Booking { store.booking(withID: booking.id) ?? booking }
    var body: some View {
        Group {
            if current.review != nil {
                Label("Review submitted", systemImage: "star.fill")
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.statusSuccessText)
            } else if current.canReview(for: .customer) {
                Button { isPresented = true } label: {
                    DesignActionLabel(title: "Leave a review", systemImage: "star.fill")
                }.buttonStyle(BeckonLedgeButtonStyle(.pill))
                    .accessibilityIdentifier("bookings.review.open")
            }
        }
        .beckonSheet(isPresented: $isPresented) {
            BookingReviewSheet(booking: current, store: store)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }
}

private extension Booking {
    var reviewPetName: String { agreementSnapshot?.petSnapshot.name ?? requestPetSnapshot?.name ?? "Your pet" }
}
